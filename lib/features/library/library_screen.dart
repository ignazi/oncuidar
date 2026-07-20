import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/utils/offline_utils.dart';
import '../../core/providers/providers.dart';
import '../../core/services/content_cache_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/educational_content.dart';
import '../../models/user_checklist.dart';
import 'video_player_screen.dart';

enum _ResourceSection { videos, guias, checklist }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _search = '';
  String _activeFilter = 'Todos';
  bool _showSavedOnly = false;
  final ContentCacheService _cacheService = ContentCacheService();
  final Map<String, bool> _downloadedFiles = {};
  final Map<String, double> _downloadProgress = {};

  bool _downloadStatusChecked = false;

  @override
  void initState() {
    super.initState();
    _refreshDownloadStatus();
  }

  /// Verifica qué archivos ya están en caché.
  Future<void> _refreshDownloadStatus() async {
    // No hacemos nada aquí — se actualiza cuando se cargan los artículos
  }

  Future<void> _checkDownloadStatus(List<EducationalContent> articles) async {
    if (_downloadStatusChecked) return;
    _downloadStatusChecked = true;
    for (final article in articles) {
      if (article.fileUrl != null) {
        final key = article.cacheKey;
        if (!_downloadedFiles.containsKey(key)) {
          final downloaded = await _cacheService.isDownloaded(key);
          if (mounted) {
            setState(() => _downloadedFiles[key] = downloaded);
          }
        }
      }
    }
  }

  Future<void> _toggleDownload(EducationalContent content) async {
    if (content.fileUrl == null) return;
    final fileId = content.cacheKey;

    // Si ya está descargado, preguntar si quiere eliminar
    if (_downloadedFiles[fileId] == true) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Eliminar descarga',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '¿Querés eliminar "${content.title}" del almacenamiento local?',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Eliminar',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.alertRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _cacheService.removeFile(fileId);
        setState(() => _downloadedFiles[fileId] = false);
      }
      return;
    }

    // Descargar
    setState(() {
      _downloadProgress[fileId] = 0.0;
    });

    try {
      await _cacheService.downloadFile(content.fileUrl!, fileId);
      if (mounted) {
        setState(() {
          _downloadedFiles[fileId] = true;
          _downloadProgress.remove(fileId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(fileId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al descargar: $e',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _openFile(EducationalContent content) async {
    if (content.fileUrl == null) {
      // Sin archivo — ir al detalle del artículo
      if (mounted) context.push('/library/${content.id}');
      return;
    }
    final fileId = content.cacheKey;

    try {
      final file = await _cacheService.getCachedFile(fileId);

      if (file == null) {
        // No está descargado — descargar automáticamente
        if (!mounted) return;
        await _toggleDownload(content);
        final downloadedFile = await _cacheService.getCachedFile(fileId);
        if (downloadedFile != null && mounted) {
          _openLocalFile(content, downloadedFile);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo descargar el archivo.',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              backgroundColor: AppColors.alertRed,
            ),
          );
        }
        return;
      }

      _openLocalFile(content, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al abrir el archivo: $e',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  void _openLocalFile(EducationalContent content, File file) {
    try {
      final type = content.fileType ?? content.category.toLowerCase();

      if (type == 'video') {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              videoFile: file,
              title: content.title,
            ),
          ),
        );
      } else {
        // PDFs, imágenes, etc. — abrir con url_launcher
        launchFile(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al abrir el archivo: $e',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  Future<void> launchFile(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'No hay una aplicación para abrir este tipo de archivo.',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al abrir el archivo: $e',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  bool _matchesSearch(String text) {
    if (_search.isEmpty) return true;
    return text.toLowerCase().contains(_search.toLowerCase());
  }

  List<EducationalContent> _filterByCategory(
    List<EducationalContent> items,
    String category,
  ) {
    return items
        .where(
          (a) =>
              a.category.toLowerCase() == category.toLowerCase() &&
              _matchesSearch(a.title),
        )
        .toList();
  }

  List<EducationalContent> _filterVideos(List<EducationalContent> items) {
    return items
        .where(
          (a) =>
              a.category.toLowerCase() == 'videos' &&
              _matchesSearch(a.title),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(educationalContentProvider);
    final favoritesAsync = ref.watch(favoriteArticlesProvider);
    final firestoreService = ref.read(firestoreServiceProvider);
    final userChecklistsAsync = ref.watch(userChecklistsProvider);

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
            title: 'Biblioteca educativa',
          ),
          Expanded(
            child: contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar contenido',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary),
                ),
              ),
              data: (articles) {
                final favorites = favoritesAsync.value ?? [];

                _checkDownloadStatus(articles);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    children: [
                      _buildSearchRow(favorites.length),
                      const SizedBox(height: 10),
                      _buildFilterChips(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildContent(
                          articles: articles,
                          favorites: favorites,
                          firestoreService: firestoreService,
                          userChecklists: userChecklistsAsync.value ?? [],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSearchRow(int savedCount) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar recurso educativo...',
              hintStyle: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textHint,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textHint,
                size: 18,
              ),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.goldMid.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.goldMid.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.goldPrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildSavedButton(savedCount),
      ],
    );
  }

  Widget _buildSavedButton(int count) {
    return GestureDetector(
      onTap: () => setState(() => _showSavedOnly = !_showSavedOnly),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _showSavedOnly
              ? AppColors.goldPrimary
              : const Color(0xFFFFF4D0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showSavedOnly
                ? AppColors.goldPrimary
                : AppColors.goldMid.withValues(alpha: 0.25),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.bookmark,
              color: _showSavedOnly ? Colors.white : AppColors.goldDark,
              size: 20,
            ),
            if (count > 0 && !_showSavedOnly)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.goldPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['Todos', 'Videos', 'Guías', 'Checklist'];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final selected = _activeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.goldMid : const Color(0xFFFFF4D0),
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.goldMid.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                f,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF7A6030),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required List<EducationalContent> articles,
    required List<String> favorites,
    required FirestoreService firestoreService,
    required List<UserChecklist> userChecklists,
  }) {
    var videos = _activeFilter == 'Todos' || _activeFilter == 'Videos'
        ? _filterVideos(articles)
        : <EducationalContent>[];
    var guias = _activeFilter == 'Todos' || _activeFilter == 'Guías'
        ? [
            ..._filterByCategory(articles, 'Guías'),
            ..._filterByCategory(articles, 'PDFs'),
            ..._filterByCategory(articles, 'Infografías'),
          ]
        : <EducationalContent>[];
    final checklists = <EducationalContent>[];

    // Filtrar guardados si está activo
    if (_showSavedOnly) {
      videos = videos.where((a) => favorites.contains(a.id)).toList();
      guias = guias.where((a) => favorites.contains(a.id)).toList();
    }

    final showUserChecklists =
        _activeFilter == 'Todos' || _activeFilter == 'Checklist';

    final hasAnyContent = videos.isNotEmpty ||
        guias.isNotEmpty ||
        showUserChecklists;

    if (!hasAnyContent) {
      return Center(
        child: Text(
          _showSavedOnly
              ? 'No hay recursos guardados.'
              : 'No se encontraron recursos.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (videos.isNotEmpty) ...[
          _buildSectionTitle('Videos'),
          const SizedBox(height: 8),
          ...videos.map(
            (a) => _buildVideoCard(
                          article: a,
                          isFavorite: favorites.contains(a.id),
                          onTap: () => _openFile(a),
                          onBookmark: () {
                firestoreService.toggleArticleFavorite(a.id);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (guias.isNotEmpty) ...[
          _buildSectionTitle('Guías'),
          const SizedBox(height: 8),
          ...guias.map(
            (a) => _buildResourceCard(
              article: a,
              isFavorite: favorites.contains(a.id),
              section: _ResourceSection.guias,
              onTap: () =>
                  a.fileUrl != null ? _openFile(a) : context.push('/library/${a.id}'),
              onBookmark: () {
                firestoreService.toggleArticleFavorite(a.id);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (checklists.isNotEmpty) ...[
          _buildSectionTitleWithAction(
            'Checklist',
            onTap: () => _showCreateChecklist(),
          ),
          const SizedBox(height: 8),
          ...checklists.map(
            (a) => _buildResourceCard(
              article: a,
              isFavorite: favorites.contains(a.id),
              section: _ResourceSection.checklist,
              onTap: () => _showChecklist(a),
              onBookmark: () {
                firestoreService.toggleArticleFavorite(a.id);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (showUserChecklists && userChecklists.isNotEmpty) ...[
          if (checklists.isEmpty)
            _buildSectionTitleWithAction(
              'Mis Checklists',
              onTap: () => _showCreateChecklist(),
            )
          else
            _buildSectionTitle('Mis Checklists'),
          const SizedBox(height: 8),
          ...userChecklists.map(
            (c) => _buildUserChecklistCard(c),
          ),
        ],
        if (showUserChecklists && userChecklists.isEmpty && checklists.isEmpty)
          _buildSectionTitleWithAction(
            'Mis Checklists',
            onTap: () => _showCreateChecklist(),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSectionTitleWithAction(String title, {required VoidCallback onTap}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.goldPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard({
    required EducationalContent article,
    required bool isFavorite,
    required VoidCallback onTap,
    required VoidCallback onBookmark,
  }) {
    final hasFile = article.fileUrl != null;

    // Colores por defecto para videos sin gradiente
    const gradientColors = [Color(0xFFE8A820), Color(0xFFF5C842)];

    return GestureDetector(
      onTap: hasFile ? () => _openFile(article) : () => context.push('/library/${article.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.goldPrimary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 112,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Video',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          article.topic.isNotEmpty
                              ? article.topic
                              : article.category,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onBookmark,
                    child: Icon(
                      isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      color: isFavorite
                          ? AppColors.goldPrimary
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard({
    required EducationalContent article,
    required bool isFavorite,
    required _ResourceSection section,
    required VoidCallback onTap,
    required VoidCallback onBookmark,
  }) {
    final (icon, gradient) = switch (section) {
      _ResourceSection.videos => (
        Icons.play_circle_outline_rounded,
        [const Color(0xFFE8A820), const Color(0xFFF5C842)],
      ),
      _ResourceSection.guias => (
        Icons.menu_book_rounded,
        [AppColors.goldMid, AppColors.goldPrimary],
      ),
      _ResourceSection.checklist => (
        Icons.check_circle_outline_rounded,
        [AppColors.goldMid, AppColors.goldLight],
      ),
    };

    final hasFile = article.fileUrl != null;

    return GestureDetector(
      onTap: hasFile ? () => _openFile(article) : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.goldPrimary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    article.topic.isNotEmpty ? article.topic : article.category,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasFile && article.fileSizeLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      article.fileSizeLabel!,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onBookmark,
              child: Icon(
                isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: isFavorite
                    ? AppColors.goldPrimary
                    : AppColors.textHint,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra un bottom sheet interactivo con los ítems del checklist.
  /// El body del contenido se parsea línea por línea: cada línea que empieza
  /// con "- " o "• " se convierte en un ítem marcable.
  void _showChecklist(EducationalContent content) {
    // Parsear ítems del body (líneas que empiecen con "- " o "• ")
    final lines = content.body.split('\n');
    final items = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        items.add(trimmed.substring(2).trim());
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        // Líneas no vacías que no son títulos
        items.add(trimmed);
      }
    }

    // Si no se parseó ningún ítem, mostrar el body completo
    if (items.isEmpty) {
      items.add(content.body);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChecklistSheet(
        title: content.title,
        items: items,
      ),
    );
  }

  Widget _buildUserChecklistCard(UserChecklist checklist) {
    final progress = checklist.items.isEmpty
        ? 0.0
        : checklist.checkedIndices.length / checklist.items.length;

    return GestureDetector(
      onTap: () => _showUserChecklist(checklist),
      onLongPress: () => _showUserChecklistOptions(checklist),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.goldPrimary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.goldMid, AppColors.goldLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          checklist.title,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldMid.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tú',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                AppColors.goldPrimary.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? AppColors.alertGreen
                                  : AppColors.goldPrimary,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${checklist.checkedIndices.length}/${checklist.items.length}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: progress >= 1.0
                              ? AppColors.alertGreen
                              : AppColors.goldDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showUserChecklistOptions(checklist),
              child: Icon(
                Icons.more_vert,
                color: AppColors.textHint,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserChecklistOptions(UserChecklist checklist) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                checklist.title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.goldPrimary),
              title: Text(
                'Editar',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditChecklist(checklist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.alertRed),
              title: Text(
                'Eliminar',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.alertRed,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteChecklist(checklist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUserChecklist(UserChecklist checklist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserChecklistSheet(
        checklist: checklist,
      ),
    );
  }

  void _showCreateChecklist() {
    final patientAsync = ref.read(currentPatientProvider);
    final patient = patientAsync.value;
    if (patient == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChecklistEditorSheet(
        patientId: patient.id,
        firestoreService: ref.read(firestoreServiceProvider),
      ),
    );
  }

  void _showEditChecklist(UserChecklist checklist) {
    final patientAsync = ref.read(currentPatientProvider);
    final patient = patientAsync.value;
    if (patient == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChecklistEditorSheet(
        patientId: patient.id,
        firestoreService: ref.read(firestoreServiceProvider),
        existingChecklist: checklist,
      ),
    );
  }

  void _deleteChecklist(UserChecklist checklist) async {
    final patientAsync = ref.read(currentPatientProvider);
    final patient = patientAsync.value;
    if (patient == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Eliminar checklist',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar "${checklist.title}"?',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.alertRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(firestoreServiceProvider)
            .deleteUserChecklist(patient.id, checklist.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar checklist: $e',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              backgroundColor: AppColors.alertRed,
            ),
          );
        }
      }
    }
  }
}

/// Bottom sheet con checklist interactivo.
class _ChecklistSheet extends StatefulWidget {
  final String title;
  final List<String> items;

  const _ChecklistSheet({required this.title, required this.items});

  @override
  State<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<_ChecklistSheet> {
  late final Set<int> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {};
  }

  int get _progress => _checked.length;
  double get _percent =>
      widget.items.isEmpty ? 0 : _checked.length / widget.items.length;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.goldMid, AppColors.goldPrimary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Barra de progreso
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _percent,
                              backgroundColor: AppColors.goldPrimary.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _percent >= 1.0
                                    ? AppColors.alertGreen
                                    : AppColors.goldPrimary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_progress/${widget.items.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _percent >= 1.0
                                ? AppColors.alertGreen
                                : AppColors.goldDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // ── Lista de ítems ──
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 24),
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final isChecked = _checked.contains(i);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _checked.remove(i);
                          } else {
                            _checked.add(i);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.alertGreen.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked
                                ? AppColors.alertGreen.withValues(alpha: 0.3)
                                : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? AppColors.alertGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked
                                      ? AppColors.alertGreen
                                      : AppColors.textHint,
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.items[i],
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: isChecked
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet para checklists del usuario con guardado en Firestore.
class _UserChecklistSheet extends StatefulWidget {
  final UserChecklist checklist;

  const _UserChecklistSheet({required this.checklist});

  @override
  State<_UserChecklistSheet> createState() => _UserChecklistSheetState();
}

class _UserChecklistSheetState extends State<_UserChecklistSheet> {
  late final Set<int> _checked;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checked = Set<int>.from(widget.checklist.checkedIndices);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get _progress => _checked.length;
  double get _percent => widget.checklist.items.isEmpty
      ? 0
      : _checked.length / widget.checklist.items.length;

  void _toggleItem(int index) {
    setState(() {
      if (_checked.contains(index)) {
        _checked.remove(index);
      } else {
        _checked.add(index);
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveToFirestore);
  }

  void _saveToFirestore() {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    final firestoreService = container.read(firestoreServiceProvider);
    final patientAsync = container.read(currentPatientProvider);
    final patient = patientAsync.value;
    if (patient == null) return;

    firestoreService.updateUserChecklist(
      patient.id,
      widget.checklist.id,
      {'checkedIndices': _checked.toList()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.goldMid, AppColors.goldPrimary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.checklist.title,
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Barra de progreso
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _percent,
                              backgroundColor:
                                  AppColors.goldPrimary.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _percent >= 1.0
                                    ? AppColors.alertGreen
                                    : AppColors.goldPrimary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_progress/${widget.checklist.items.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _percent >= 1.0
                                ? AppColors.alertGreen
                                : AppColors.goldDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // ── Lista de ítems ──
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 24),
                  itemCount: widget.checklist.items.length,
                  itemBuilder: (_, i) {
                    final isChecked = _checked.contains(i);
                    return GestureDetector(
                      onTap: () => _toggleItem(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.alertGreen.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked
                                ? AppColors.alertGreen.withValues(alpha: 0.3)
                                : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? AppColors.alertGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked
                                      ? AppColors.alertGreen
                                      : AppColors.textHint,
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.checklist.items[i],
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: isChecked
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet para crear/editar checklist del usuario.
class _ChecklistEditorSheet extends StatefulWidget {
  final String patientId;
  final FirestoreService firestoreService;
  final UserChecklist? existingChecklist;

  const _ChecklistEditorSheet({
    required this.patientId,
    required this.firestoreService,
    this.existingChecklist,
  });

  @override
  State<_ChecklistEditorSheet> createState() => _ChecklistEditorSheetState();
}

class _ChecklistEditorSheetState extends State<_ChecklistEditorSheet> {
  late final TextEditingController _titleController;
  late final List<TextEditingController> _itemControllers;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _isEditing => widget.existingChecklist != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingChecklist?.title ?? '',
    );
    _itemControllers = widget.existingChecklist != null
        ? widget.existingChecklist!.items
            .map((item) => TextEditingController(text: item))
            .toList()
        : [TextEditingController(), TextEditingController()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length <= 1) return;
    setState(() {
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final title = _titleController.text.trim();
    final items = _itemControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      setState(() => _saving = false);
      return;
    }

    try {
      if (_isEditing) {
        await widget.firestoreService.updateUserChecklist(
          widget.patientId,
          widget.existingChecklist!.id,
          {'title': title, 'items': items},
        );
      } else {
        final checklist = UserChecklist(
          id: '',
          title: title,
          items: items,
          checkedIndices: [],
          createdAt: DateTime.now(),
        );
        await widget.firestoreService.addUserChecklist(
          widget.patientId,
          checklist,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        final container = ProviderScope.containerOf(context);
        final isOnline = container.read(isConnectedProvider).value ?? true;
        showOfflineAwareError(
          context,
          isOnline: isOnline,
          onlineMessage: 'Error al guardar: $e',
          offlineMessage: 'No se pudo guardar — intenta cuando vuelva internet',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.goldMid, AppColors.goldPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit
                            : Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Editar checklist' : 'Nuevo checklist',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // ── Form ──
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      bottomPadding + 24,
                    ),
                    children: [
                      // Título
                      Text(
                        'Título',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nombre del checklist',
                          hintStyle: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.goldMid.withValues(alpha: 0.25),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.goldMid.withValues(alpha: 0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.goldPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 20),

                      // Ítems
                      Row(
                        children: [
                          Text(
                            'Ítems',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _addItem,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.goldPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Agregar',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_itemControllers.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _itemControllers[i],
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ítem ${i + 1}',
                                    hintStyle: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: AppColors.textHint,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.goldMid
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.goldMid
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.goldPrimary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_itemControllers.length > 1) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _removeItem(i),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.alertRed
                                          .withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      color: AppColors.alertRed,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      // Botón guardar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'Guardar cambios' : 'Crear checklist',
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
