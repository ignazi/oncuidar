import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../models/orientation_rule.dart';

class OrientationScreen extends ConsumerStatefulWidget {
  const OrientationScreen({super.key});

  @override
  ConsumerState<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends ConsumerState<OrientationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _searchFocusNode = FocusNode();

  bool _isBotTyping = false;
  bool _isSearching = false;
  bool _initialized = false;
  bool _initPending = false;
  String? _currentChatId;
  List<_ChatMessage> _messages = [];
  List<Map<String, dynamic>> _cachedConversations = [];
  bool _isNewChat = false;

  static const _welcomeMessage =
      'Hola, estoy aquí para ayudarte con dudas frecuentes sobre el cuidado en casa. Puedes escribirme o usar las preguntas comunes.';

  // Palabras vacías para filtrar en el matching
  static const _stopWords = {
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
    'y', 'e', 'o', 'a', 'ante', 'bajo', 'cabe', 'con', 'contra',
    'de', 'del', 'desde', 'durante', 'en', 'entre', 'hacia', 'hasta',
    'mediante', 'para', 'por', 'según', 'sin', 'so', 'sobre', 'tras',
    'su', 'sus', 'tu', 'tus', 'mi', 'mis', 'nuestro', 'vuestro',
    'qué', 'cómo', 'cuándo', 'dónde', 'quién', 'quiénes', 'cuál', 'cuáles',
    'que', 'como', 'cuando', 'donde', 'quien', 'cual',
    'es', 'son', 'está', 'están', 'fue', 'era',
    'se', 'le', 'les', 'lo',
    'si', 'no', 'me', 'te', 'nos', 'os',
    'al', 'más', 'menos', 'muy', 'tan', 'tanto',
    'bien', 'mal', 'ya', 'también', 'pero', 'sino',
    '¿', '?', '¡', '!', '.', ',', ';', ':', '-', '_',
    'hago', 'hace', 'hacer', 'puedo', 'puede',
    'tengo', 'tiene', 'tenemos', 'debo', 'debe', 'deber',
    'hay', 'ser', 'estar', 'tener', 'haber',
  };

  @override
  void initState() {
    super.initState();
    _messages = [_ChatMessage(text: _welcomeMessage, isUser: false)];
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Inicialización: cargar conversación existente ──

  void _tryInit() {
    if (_initialized || _initPending) return;
    final chats = ref.read(conversationsProvider).value;
    if (chats == null) return; // el provider todavía está cargando
    _initPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (chats.isNotEmpty) {
        _loadChat(chats.first['id'] as String).then((_) {
          if (mounted) setState(() => _initialized = true);
        });
      } else {
        setState(() => _initialized = true);
      }
    });
  }

  // ── Matching mejorado (palabras clave) ──

  OrientationRule? _matchRule(List<OrientationRule> rules, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    // Extraer palabras significativas
    final words = q
        .split(RegExp(r'[\s,;.:¿?¡!()/@#$%&*+\-]+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();

    if (words.isEmpty) {
      // Si no hay palabras significativas, usar la query completa
      // solo si tiene más de 2 caracteres
      if (q.length > 2) words.add(q);
      if (words.isEmpty) return null;
    }

    // 1. Exact match en subQuestion
    for (final rule in rules) {
      if (rule.subQuestion.toLowerCase() == q) return rule;
    }

    // 2. Match por palabras en tags (bidireccional)
    for (final word in words) {
      for (final rule in rules) {
        for (final tag in rule.tags) {
          final t = tag.toLowerCase();
          if (t.contains(word) || word.contains(t)) return rule;
        }
      }
    }

    // 3. Match por palabras en subQuestion
    for (final word in words) {
      for (final rule in rules) {
        if (rule.subQuestion.toLowerCase().contains(word)) return rule;
      }
    }

    // 4. Match por palabras en category
    for (final word in words) {
      for (final rule in rules) {
        if (rule.category.toLowerCase().contains(word)) return rule;
      }
    }

    // 5. Match por palabras en answer
    for (final word in words) {
      for (final rule in rules) {
        if (rule.answer.toLowerCase().contains(word)) return rule;
      }
    }

    // 6. Fallback: query completa en tags
    for (final rule in rules) {
      if (rule.tags.any((tag) => q.contains(tag.toLowerCase()))) return rule;
    }

    // 7. Fallback: query completa en subQuestion
    for (final rule in rules) {
      if (rule.subQuestion.toLowerCase().contains(q)) return rule;
    }

    return null;
  }

  // ── Persistencia en Firestore ──

  Future<void> _saveChat() async {
    if (!mounted) return;
    try {
      final service = ref.read(firestoreServiceProvider);
      final messagesData =
          _messages.map((m) => m.toMap()).toList();

      // Auto-título desde el primer mensaje del usuario
      String title;
      if (_messages.length > 1) {
        final firstUserMsg = _messages.firstWhere(
          (m) => m.isUser,
          orElse: () => _messages.first,
        );
        title = firstUserMsg.text.length > 50
            ? '${firstUserMsg.text.substring(0, 50)}…'
            : firstUserMsg.text;
      } else {
        title = 'Nuevo chat';
      }

      if (_currentChatId != null) {
        await service.updateChat(_currentChatId!, messagesData, title: title);
      } else {
        final id = await service.createChat(title, messagesData);
        if (mounted) setState(() => _currentChatId = id);
      }
    } catch (e) {
      debugPrint('Error guardando chat: $e');
    }
  }

  Future<void> _loadChat(String chatId) async {
    final chat = await ref.read(firestoreServiceProvider).getChat(chatId);
    if (chat != null && mounted) {
      final messagesData =
          (chat['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _currentChatId = chatId;
        _isNewChat = false;
        _messages = messagesData
            .map((m) => _ChatMessage.fromMap(m))
            .toList();
        if (_messages.isEmpty) {
          _messages.add(_ChatMessage(text: _welcomeMessage, isUser: false));
        }
      });
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      await ref.read(firestoreServiceProvider).deleteChat(chatId);
    } catch (e) {
      debugPrint('Error eliminando chat: $e');
    }
    if (_currentChatId == chatId && mounted) {
      final remaining = _cachedConversations.where((c) => c['id'] != chatId).toList();
      if (remaining.isNotEmpty) {
        await _loadChat(remaining.first['id'] as String);
      } else {
        _startNewChat();
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _isNewChat = true;
      _messages = [_ChatMessage(text: _welcomeMessage, isUser: false)];
    });
    _scrollToBottom();
  }

  Future<void> _switchToChat(String chatId) async {
    // Guardar chat actual si tiene interacción
    if (_messages.length > 1) {
      await _saveChat();
    }
    await _loadChat(chatId);
  }

  // ── Envío de mensajes ──

  void _handleSend([String? preset]) {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _isBotTyping) return;

    setState(() {
      _isNewChat = false;
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        fechaHora: _formatFechaHora(),
      ));
    });
    _inputController.clear();
    _focusNode.unfocus();

    setState(() => _isBotTyping = true);

    final rulesAsync = ref.read(orientationRulesProvider);
    final rules = rulesAsync.value;
    if (rules == null || rules.isEmpty) {
      // Rules haven't loaded yet — show a helpful message
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _isBotTyping = false;
          _messages.add(_ChatMessage(
            text: 'Estoy cargando la información. Por favor, intentá de nuevo en unos segundos.',
            isUser: false,
            fechaHora: _formatFechaHora(),
          ));
        });
        _scrollToBottom();
      });
      return;
    }
    final matched = _matchRule(rules, text);

    final answer = matched != null
        ? matched.answer
        : 'No encontré una respuesta específica para tu pregunta. '
            'Recuerda observar el estado general del niño, registrar lo ocurrido '
            'y contactar al equipo médico si el síntoma aumenta o te genera preocupación.';

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isBotTyping = false;
        _messages.add(_ChatMessage(
          text: answer,
          isUser: false,
          fechaHora: _formatFechaHora(),
        ));
      });
      _scrollToBottom();
      // Auto-guardar después de cada intercambio
      _saveChat();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatFechaHora() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}, '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ── Sugerencias ──

  List<OrientationRule> _availableSuggestions(List<OrientationRule> allRules) {
    final usedQuestions =
        _messages.where((m) => m.isUser).map((m) => m.text).toList();
    return allRules
        .where((r) => !usedQuestions.contains(r.subQuestion))
        .take(3)
        .toList();
  }

  bool get _showInitialSuggestions => _messages.length == 1 && !_isBotTyping;

  bool _showFollowUpSuggestions(List<OrientationRule> allRules) =>
      _messages.length > 1 &&
      !_isBotTyping &&
      _messages.last.isUser == false &&
      _availableSuggestions(allRules).isNotEmpty;

  // ── Search ──

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      } else {
        _searchController.clear();
        // Pedir foco después de que el widget se monte
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  String _searchQuery = '';

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  List<_ChatMessage> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    final q = _searchQuery.toLowerCase();
    return _messages
        .where((m) => m.text.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _renameChat(String chatId, String newTitle) async {
    try {
      await ref.read(firestoreServiceProvider).renameChat(chatId, newTitle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al renombrar: $e')),
        );
      }
    }
  }

  // ── Drawer de conversaciones ──

  void _showConversationsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ConversationsSheet(
        currentChatId: _currentChatId,
        parentContext: context,
        firestoreService: ref.read(firestoreServiceProvider),
        onSelect: (chatId) {
          Navigator.pop(ctx);
          _switchToChat(chatId);
        },
        onNewChat: () {
          Navigator.pop(ctx);
          // Guardar chat actual si tiene interacción y crear nuevo
          if (_messages.length > 1) {
            _saveChat().then((_) => _startNewChat());
          } else {
            _startNewChat();
          }
        },
        onDelete: (chatId) {
          _deleteChat(chatId);
        },
        onRename: (chatId, newTitle) {
          _renameChat(chatId, newTitle);
        },
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(orientationRulesProvider);
    // Mantenemos la watch para que el provider se mantenga activo y cacheamos la lista
    final conversationsAsync = ref.watch(conversationsProvider);
    // Cachear conversaciones para usarlas desde el bottom sheet
    final convList = conversationsAsync.asData?.value;
    if (convList != null) {
      _cachedConversations = convList;
    }

    // Inicializar cuando lleguen los datos de Firestore
    _tryInit();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/dashboard');
      },
      child: Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          GradientHeader(
            showBackButton: true,
            title: 'Orientación',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _toggleSearch,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showConversationsDrawer,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Barra de búsqueda FUERA del header, entre este y el contenido
          if (_isSearching) _buildSearchField(),
          Expanded(
            child: rulesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                    'Error al cargar reglas de orientación.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              data: (rules) => Column(
                children: [
                  if (_isNewChat)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 12, color: AppColors.goldPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'Nueva conversación',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.goldPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: _buildMessagesList(rules)),
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      color: AppColors.cream,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
          child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar en el chat…',
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      ),
    );
  }

  // ── Messages list ──

  Widget _buildMessagesList(List<OrientationRule> rules) {
    final filtered = _filteredMessages;
    final suggestions = _availableSuggestions(rules);
    final showFollowUp = _showFollowUpSuggestions(rules);
    final showInitial = _showInitialSuggestions;

    // Si el buscador está activo y no hay resultados
    if (_isSearching && _searchQuery.isNotEmpty && filtered.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para "$_searchQuery"',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length +
          (!_isSearching && showInitial ? 1 : 0) +
          (!_isSearching && _isBotTyping ? 1 : 0) +
          (!_isSearching && showFollowUp ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Mensajes filtrados (o todos si no hay búsqueda)
        if (i < filtered.length) {
          return _buildMessage(filtered[i]);
        }

        // Solo mostrar extras si NO estamos en modo búsqueda
        if (!_isSearching) {
          int offset = filtered.length;

          if (showInitial && i == offset) {
            return _buildInitialSuggestions(rules);
          }
          if (_isBotTyping && i == offset + (showInitial ? 1 : 0)) {
            return _buildTypingIndicator();
          }
          if (showFollowUp) {
            return _buildFollowUpSuggestions(suggestions);
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    final isUser = msg.isUser;
    final fechaHora = msg.fechaHora;
    final isSearching = _isSearching;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isUser && !isSearching)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0B12A), AppColors.goldPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldPrimary.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
          if (!isUser && !isSearching) const SizedBox(width: 8),
          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFFFF1BF), Color(0xFFFFE5A3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFFAF0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.goldMid.withValues(alpha: 0.35)
                      : AppColors.goldMid.withValues(alpha: 0.20),
                ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: AppColors.goldPrimary.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: const Color(0xFFB7790B).withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  // Gold bar (absolute positioned, only for bot)
                  if (!isUser)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF2C14E), Color(0xFFD99A16)],
                          ),
                        ),
                      ),
                    ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        if (fechaHora != null)
                          Padding(
                            padding: isUser
                                ? const EdgeInsets.only(bottom: 6)
                                : const EdgeInsets.only(bottom: 6, left: 4),
                            child: Text(
                              fechaHora,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFB08A4F),
                              ),
                            ),
                          ),
                        // Message text
                        Padding(
                          padding: EdgeInsets.only(left: isUser ? 0 : 4),
                          child: Text(
                            msg.text,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSuggestions(List<OrientationRule> rules) {
    final suggestions = rules.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preguntas frecuentes',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A5A05),
            ),
          ),
          const SizedBox(height: 8),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => _handleSend(s.subQuestion),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.goldMid.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      s.subQuestion,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A4E05),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0B12A), AppColors.goldPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldPrimary.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFFFFAF0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.goldMid.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB7790B).withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              'Escribiendo respuesta...',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSuggestions(List<OrientationRule> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Otras preguntas:',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () => _handleSend(s.subQuestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D0),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.goldMid.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    s.subQuestion,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A4E05),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.goldMid.withValues(alpha: 0.25),
                  ),
                ),
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  enabled: !_isBotTyping,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu duda aquí…',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _handleSend(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldPrimary.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet de conversaciones ──

class _ConversationsSheet extends StatefulWidget {
  final String? currentChatId;
  final void Function(String chatId) onSelect;
  final VoidCallback onNewChat;
  final void Function(String chatId) onDelete;
  final void Function(String chatId, String newTitle) onRename;
  final BuildContext parentContext;
  final FirestoreService firestoreService;

  const _ConversationsSheet({
    required this.currentChatId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
    required this.onRename,
    required this.parentContext,
    required this.firestoreService,
  });

  @override
  State<_ConversationsSheet> createState() => _ConversationsSheetState();
}

class _ConversationsSheetState extends State<_ConversationsSheet> {
  List<Map<String, dynamic>> _chats = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    // Suscribirse al stream de Firestore para datos live
    _sub = widget.firestoreService.chatsStream().listen(
      (chats) { if (mounted) setState(() => _chats = chats); },
      onError: (e) { debugPrint('Error in chats stream: $e'); },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      return DateFormat('dd/MM/yy').format(date);
    }
    return '$timestamp';
  }

  void _showRenameDialog(Map<String, dynamic> chat) {
    final chatId = chat['id'] as String;
    final currentTitle = chat['title'] as String? ?? 'Chat';
    final controller = TextEditingController(text: currentTitle);

    showDialog<bool>(
      context: widget.parentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Renombrar conversación',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Nuevo nombre...',
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textHint,
            ),
            filled: true,
            fillColor: AppColors.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.goldMid.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.goldMid.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.goldPrimary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
          ),
          onSubmitted: (_) {
            final newTitle = controller.text.trim();
            if (newTitle.isNotEmpty && newTitle != currentTitle) {
              widget.onRename(chatId, newTitle);
              Navigator.pop(ctx, true);
            } else {
              Navigator.pop(ctx, false);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != currentTitle) {
                widget.onRename(chatId, newTitle);
                Navigator.pop(ctx, true);
              } else {
                Navigator.pop(ctx, false);
              }
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.goldPrimary,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showDeleteConfirmation(Map<String, dynamic> chat) {
    final chatId = chat['id'] as String;
    final title = chat['title'] as String? ?? 'Chat';

    showDialog<bool>(
      context: widget.parentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Eliminar conversación',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar "$title"? No se puede deshacer.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete(chatId);
              Navigator.pop(ctx, true);
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 18,
                  color: AppColors.goldPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conversaciones',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                  Text(
                    '${_chats.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: _chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 36,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay conversaciones',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                          'Creá una nueva para empezar',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _chats.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (ctx, i) {
                        final chat = _chats[i];
                        final chatId = chat['id'] as String;
                        final title = chat['title'] as String? ?? 'Chat';
                        final updatedAt = chat['updatedAt'];
                        final isActive = chatId == widget.currentChatId;

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onSelect(chatId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.goldPrimary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isActive
                                    ? Border.all(
                                        color: AppColors.goldPrimary
                                            .withValues(alpha: 0.2),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Chat icon
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.goldPrimary
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.grey.shade500,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title + date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            fontSize: 14,
                                            fontWeight: isActive
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(updatedAt),
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 3-dot menu
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_horiz_rounded,
                                      color: Colors.grey.shade400,
                                      size: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _showRenameDialog(chat);
                                      } else if (value == 'delete') {
                                        _showDeleteConfirmation(chat);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'rename',
                                        height: 38,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 15,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Renombrar',
                                              style: GoogleFonts.nunito(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        height: 38,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 15,
                                              color: Colors.red.shade400,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Eliminar',
                                              style: GoogleFonts.nunito(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.red.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // New chat button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Nuevo chat',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: AppColors.goldPrimary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelo interno para mensajes del chat ──

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? fechaHora;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.fechaHora,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'fechaHora': fechaHora,
      };

  factory _ChatMessage.fromMap(Map<String, dynamic> map) => _ChatMessage(
        text: map['text'] as String? ?? '',
        isUser: map['isUser'] as bool? ?? false,
        fechaHora: map['fechaHora'] as String?,
      );
}
