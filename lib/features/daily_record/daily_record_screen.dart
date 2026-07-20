import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/services/clinical_rules_engine.dart';
import '../../core/utils/offline_utils.dart';
import '../../core/providers/providers.dart';
import '../../models/daily_record.dart';
import '../../models/patient.dart';
import '../../models/vital_signs.dart';
import '../../models/symptom_entry.dart';
import '../../models/alert_level.dart';

class DailyRecordScreen extends ConsumerStatefulWidget {
  final String? recordId;
  const DailyRecordScreen({super.key, this.recordId});

  @override
  ConsumerState<DailyRecordScreen> createState() => _DailyRecordScreenState();
}

class _DailyRecordScreenState extends ConsumerState<DailyRecordScreen> {
  String _recordType = 'programado';
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _oxygenController = TextEditingController();
  final _respRateController = TextEditingController();
  final _notesController = TextEditingController();

  int _selectedIntensity = 5;
  final List<SymptomEntry> _symptoms = [];
  String _selectedSymptom = '';

  AlertLevel _currentAlert = AlertLevel.normal;
  bool _isLoading = false;
  bool _recordLoaded = false;
  DateTime? _originalDate;
  DateTime? _originalCreatedAt;

  static const _symptomOptions = [
    'Fiebre',
    'Vómito',
    'Dolor',
    'Fatiga',
    'Diarrea',
    'Tos',
    'Pérdida de apetito',
    'Dificultad respiratoria',
    'Sangrado',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _tempController.addListener(_evaluateAlert);
    _heartRateController.addListener(_evaluateAlert);
    _oxygenController.addListener(_evaluateAlert);
    _respRateController.addListener(_evaluateAlert);
  }

  void _loadExistingRecord(List<DailyRecord> records) {
    final record = records.where((r) => r.id == widget.recordId).firstOrNull;
    if (record == null) return;

    _recordLoaded = true;
    _recordType = record.recordType;
    _originalDate = record.date;
    _originalCreatedAt = record.createdAt;
    if (record.vitalSigns != null) {
      if (record.vitalSigns!.temperature != null) {
        _tempController.text = record.vitalSigns!.temperature!.toString();
      }
      if (record.vitalSigns!.heartRate != null) {
        _heartRateController.text = record.vitalSigns!.heartRate!.toString();
      }
      if (record.vitalSigns!.oxygenSaturation != null) {
        _oxygenController.text = record.vitalSigns!.oxygenSaturation!.toString();
      }
      if (record.vitalSigns!.respiratoryRate != null) {
        _respRateController.text = record.vitalSigns!.respiratoryRate!.toString();
      }
    }
    _symptoms.addAll(record.symptoms);
    if (record.generalNotes != null) {
      _notesController.text = record.generalNotes!;
    }
    _currentAlert = record.alertLevel;
  }

  void _evaluateAlert() {
    final vitals = _buildVitalSigns();
    final result = ClinicalRulesEngine.evaluate(vitals, _symptoms);
    setState(() => _currentAlert = result.level);
  }

  VitalSigns? _buildVitalSigns() {
    final temp = double.tryParse(_tempController.text);
    final hr = int.tryParse(_heartRateController.text);
    final o2 = int.tryParse(_oxygenController.text);
    final rr = int.tryParse(_respRateController.text);
    if (temp == null && hr == null && o2 == null && rr == null) return null;
    return VitalSigns(
      temperature: temp,
      heartRate: hr,
      oxygenSaturation: o2,
      respiratoryRate: rr,
    );
  }

  void _addSymptom() {
    if (_selectedSymptom.isEmpty) return;
    final exists = _symptoms.any(
      (s) => s.name.toLowerCase() == _selectedSymptom.toLowerCase(),
    );
    if (exists) return;
    setState(() {
      _symptoms.add(
        SymptomEntry(name: _selectedSymptom, intensity: _selectedIntensity),
      );
      _selectedSymptom = '';
      _selectedIntensity = 5;
    });
    _evaluateAlert();
  }

  void _removeSymptom(SymptomEntry s) {
    setState(() => _symptoms.remove(s));
    _evaluateAlert();
  }

  Future<void> _saveRecord() async {
    final patient = ref.read(currentPatientProvider).value;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay paciente seleccionado'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final recordId = widget.recordId ?? const Uuid().v4();

      final record = DailyRecord(
        id: recordId,
        patientId: patient.id,
        date: _originalDate ?? now,
        createdAt: _originalCreatedAt ?? now,
        recordType: _recordType,
        vitalSigns: _buildVitalSigns(),
        symptoms: _symptoms,
        generalNotes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        alertLevel: _currentAlert,
      );

      await ref
          .read(firestoreServiceProvider)
          .saveDailyRecord(patient.id, record);

      if (mounted) {
        final isOnline = ref.read(isConnectedProvider).value ?? true;
        showOfflineSaveSuccess(context, isOnline: isOnline);
        if (widget.recordId != null && context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        final isOnline = ref.read(isConnectedProvider).value ?? true;
        showOfflineAwareError(
          context,
          isOnline: isOnline,
          onlineMessage: 'Error al guardar: $e',
          offlineMessage: 'No se pudo guardar — intenta cuando vuelva internet',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(dailyRecordsProvider);
    if (widget.recordId != null && !_recordLoaded && recordsAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_recordLoaded) {
          setState(() => _loadExistingRecord(recordsAsync.value!));
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          // ── Header con botón de historial ──
          GradientHeader(
            showBackButton: true,
            title: widget.recordId != null ? 'Editar registro' : 'Registro diario',
            onBackPressed: _goBack,
            trailing: widget.recordId == null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/history', extra: {'origin': 'record'}),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final patient = ref.read(currentPatientProvider).value;
                          if (patient != null) _showConfigureRecordDialog(patient);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          // ── Contenido scrollable ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tipo de registro ──
                  _buildSectionTitle('Tipo de registro'),
                  const SizedBox(height: 8),
                  _buildRecordTypeGrid(),
                  const SizedBox(height: 16),

                  // ── Signos vitales ──
                  _buildSectionTitle('Signos vitales'),
                  const SizedBox(height: 8),
                  _buildVitalSignsGrid(),
                  const SizedBox(height: 16),

                  // ── Síntomas observados ──
                  _buildSectionTitle('Síntomas observados'),
                  const SizedBox(height: 8),
                  _buildSymptomSection(),
                  const SizedBox(height: 16),

                  // ── Observaciones ──
                  _buildSectionTitle('Observaciones'),
                  const SizedBox(height: 8),
                  _buildNotesField(),
                  const SizedBox(height: 16),

                  // ── Alert indicator ──
                  _buildAlertIndicator(),
                  const SizedBox(height: 16),

                  // ── Guardar ──
                  _buildSaveButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Section title (uppercase, font-bold) ──
  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF8A5A05),
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Tipo de registro: 2 columnas ──
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _showConfigureRecordDialog(Patient patient) {
    int maxRecords = patient.maxRecordsPerDay;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Configurar registro',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registros programados por día:',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCountButton(
                    icon: Icons.remove,
                    onTap: maxRecords > 1
                        ? () => setDialogState(() => maxRecords--)
                        : null,
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.goldPrimary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$maxRecords',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ),
                  _buildCountButton(
                    icon: Icons.add,
                    onTap: maxRecords < 10
                        ? () => setDialogState(() => maxRecords++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.nunito(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(firestoreServiceProvider).updatePatient(
                  patient.id,
                  {'maxRecordsPerDay': maxRecords},
                );
              },
              child: Text(
                'Guardar',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.goldPrimary : AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildRecordTypeGrid() {
    final records = ref.watch(dailyRecordsProvider).value ?? [];
    final patient = ref.watch(currentPatientProvider).value;
    final maxPerDay = patient?.maxRecordsPerDay ?? 3;

    final today = DateTime.now();
    final todayCount = records.where((r) {
      final isSameDay = r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day;
      final isScheduled = r.recordType == 'programado';
      final isNotCurrent = r.id != widget.recordId;
      return isSameDay && isScheduled && isNotCurrent;
    }).length;

    final displayCount = todayCount + 1;

    return Row(
      children: [
        Expanded(
          child: _buildRecordTypeButton(
            'programado',
            widget.recordId != null
                ? 'Registro programado'
                : 'Registro programado $displayCount/$maxPerDay',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRecordTypeButton('extra', 'Registro extra'),
        ),
      ],
    );
  }

  Widget _buildRecordTypeButton(String value, String label) {
    final selected = _recordType == value;
    return GestureDetector(
      onTap: () => setState(() => _recordType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0C2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFD99A16) : const Color(0xFFE8A820).withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF7A4E05)
                  : const Color(0xFF9A8060),
            ),
          ),
        ),
      ),
    );
  }

  // ── Signos vitales: grid 2x2 ──
  Widget _buildVitalSignsGrid() {
    return Column(
      children: [
        // Row 1: Temperatura + Frec. cardíaca
        Row(
          children: [
            Expanded(
              child: _buildVitalInputCard(
                icon: Icons.thermostat,
                label: 'Temperatura',
                placeholder: '37.0',
                unit: '°C',
                controller: _tempController,
                color: const Color(0xFFF07830),
                step: '0.1',
                allowDecimal: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildVitalInputCard(
                icon: Icons.favorite,
                label: 'Frec. cardíaca',
                placeholder: '80',
                unit: 'lpm',
                controller: _heartRateController,
                color: const Color(0xFFF43F5E),
                step: '1',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Saturación O₂ + Frec. respiratoria
        Row(
          children: [
            Expanded(
              child: _buildVitalInputCard(
                icon: Icons.show_chart,
                label: 'Saturación O₂',
                placeholder: '98',
                unit: '%',
                controller: _oxygenController,
                color: const Color(0xFF4EC4D4),
                step: '1',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildVitalInputCard(
                icon: Icons.air,
                label: 'Frec. respiratoria',
                placeholder: '18',
                unit: 'rpm',
                controller: _respRateController,
                color: const Color(0xFFA78BFA),
                step: '1',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalInputCard({
    required IconData icon,
    required String label,
    required String placeholder,
    required String unit,
    required TextEditingController controller,
    required Color color,
    required String step,
    bool allowDecimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          // Label + input + unit
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF9A8060),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: allowDecimal
                            ? TextInputType.numberWithOptions(decimal: true)
                            : TextInputType.number,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C1A00),
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: GoogleFonts.nunito(
                            fontSize: 14,
                            color: const Color(0xFFD0BFA0),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Text(
                      unit,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: const Color(0xFF9A8060),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Síntomas ──
  Widget _buildSymptomSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8A820).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8A820).withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Selector + botón agregar
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE8A820).withValues(alpha: 0.25),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSymptom.isEmpty ? null : _selectedSymptom,
                    hint: Text(
                      'Selecciona un síntoma',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _symptomOptions.map((s) {
                      return DropdownMenuItem(value: s, child: Text(
                        s,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ));
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedSymptom = v ?? '');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSymptom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A820),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Intensidad 1-10 grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Intensidad',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A5A05),
                ),
              ),
              Text(
                '$_selectedIntensity/10',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF9A8060),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 10,
            itemBuilder: (ctx, i) {
              final val = i + 1;
              final selected = _selectedIntensity == val;
              return GestureDetector(
                onTap: () => setState(() => _selectedIntensity = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8A820)
                        : const Color(0xFFFFF4D0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '$val',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF7A6030),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Chips de síntomas agregados
          if (_symptoms.isEmpty)
            SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Puedes agregar más de un síntoma.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: const Color(0xFF9A8060),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _symptoms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final s = _symptoms[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8A820).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${s.name} · ${s.intensity}/10',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7A4E05),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeSymptom(s),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Color(0xFF9A8060),
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
    );
  }

  // ── Observaciones ──
  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 4,
      style: GoogleFonts.nunito(fontSize: 14),
      decoration: InputDecoration(
        hintText:
            'Observaciones adicionales (opcional). Puedes guardar solo este campo si es lo disponible.',
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.goldPrimary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ── Alert indicator ──
  Widget _buildAlertIndicator() {
    final (color, bgColor, icon, title, subtitle) = switch (_currentAlert) {
      AlertLevel.critico => (
          AppColors.alertRed,
          AppColors.alertRedBg,
          Icons.error_outline,
          'Se recomienda atención urgente',
          'Contacta al equipo de salud inmediatamente',
        ),
      AlertLevel.alerta => (
          AppColors.alertYellow,
          AppColors.alertYellowBg,
          Icons.warning_amber_rounded,
          'Se recomienda consultar',
          'Contacta al equipo de salud',
        ),
      _ => (
          AppColors.alertGreen,
          AppColors.alertGreenBg,
          Icons.check_circle_outline,
          'Todo parece normal',
          'Continúa con la vigilancia habitual',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Guardar ──
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD99A16),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: const Color(0xFFD99A16).withValues(alpha: 0.25),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Guardar registro',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _tempController.dispose();
    _heartRateController.dispose();
    _oxygenController.dispose();
    _respRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
