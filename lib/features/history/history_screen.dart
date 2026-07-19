import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../models/daily_record.dart';
import '../../models/vital_signs.dart';

const _statusConfig = {
  'normal': (
    label: 'Normal',
    dot: AppColors.alertGreen,
    text: AppColors.alertGreen,
    bg: AppColors.alertGreenBg,
  ),
  'alerta': (
    label: 'Alerta',
    dot: AppColors.alertYellow,
    text: AppColors.alertYellow,
    bg: AppColors.alertYellowBg,
  ),
  'critico': (
    label: 'Crítico',
    dot: AppColors.alertRed,
    text: AppColors.alertRed,
    bg: AppColors.alertRedBg,
  ),
};

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.filterDate});

  /// Si se prove, filtra registros de ese día (sin hora).
  final DateTime? filterDate;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'Todos';
  String? _expandedId;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final List<DailyRecord> _extraRecords = [];

  DateTime? get _activeDateFilter => widget.filterDate;

  static const _filters = [
    'Todos',
    'Normal',
    'Alerta',
    'Crítico',
  ];

  String _dateStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _timeStr(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : d.hour == 0 ? 12 : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(dailyRecordsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          GradientHeader(
            showBackButton: true,
            title: 'Ver historial',
            onBackPressed: () => context.pop(),
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.goldPrimary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar registros: $e',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (records) {
                // Combinar registros del stream con los cargados por paginación
                final allRecords = [
                  ...records,
                  ..._extraRecords.where(
                    (extra) => !records.any((r) => r.id == extra.id),
                  ),
                ];

                // Filtro por fecha del día (si vino del dashboard)
                final dateFiltered = _activeDateFilter != null
                    ? allRecords.where((r) {
                        final rd = r.date;
                        final f = _activeDateFilter!;
                        return rd.year == f.year &&
                            rd.month == f.month &&
                            rd.day == f.day;
                      }).toList()
                    : allRecords;

                final filtered = _selectedFilter == 'Todos'
                    ? dateFiltered
                    : dateFiltered.where((r) {
                        final cfg = _statusConfig[r.alertLevel.name];
                        return cfg != null && cfg.label == _selectedFilter;
                      }).toList();

                if (allRecords.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No hay registros aún',
                    subtitle: 'Crea el primer registro desde el botón de abajo.',
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyState(
                              icon: Icons.history,
                              title: 'No hay registros para este filtro.',
                              subtitle: 'Intenta con otro filtro.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 4,
                              ),
                              itemCount: filtered.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                if (i == filtered.length) {
                                  // Botón "Cargar más"
                                  return _buildLoadMoreButton(records);
                                }
                                return _buildRecordCard(filtered[i]);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8A820)
                    : const Color(0xFFFFF4D0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF7A6030),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreButton(List<DailyRecord> currentRecords) {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.goldPrimary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: () => _loadMore(currentRecords),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.goldPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Cargar más registros',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.goldDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(List<DailyRecord> currentRecords) async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final patientAsync = ref.read(currentPatientProvider);
      final patient = patientAsync.value;
      if (patient == null) {
        setState(() => _isLoadingMore = false);
        return;
      }

      // Obtener la fecha del último registro
      final allRecords = [...currentRecords, ..._extraRecords];
      if (allRecords.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final lastRecord = allRecords.last;
      final moreRecords = await ref
          .read(firestoreServiceProvider)
          .loadMoreDailyRecords(patient.id, lastRecord.createdAt);

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          if (moreRecords.isEmpty) {
            _hasMore = false;
          } else {
            _extraRecords.addAll(moreRecords);
            // Si cargamos menos del límite, no hay más
            if (moreRecords.length < 50) {
              _hasMore = false;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar más registros: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRecordCard(DailyRecord rec) {
    final isOpen = _expandedId == rec.id;
    final st = _statusConfig[rec.alertLevel.name] ?? _statusConfig['normal']!;
    final vs = rec.vitalSigns;

    String recordLabel;
    if (rec.recordType == 'programado') {
      final allRecords = ref.read(dailyRecordsProvider).value ?? [];
      final patient = ref.read(currentPatientProvider).value;
      final maxPerDay = patient?.maxRecordsPerDay ?? 3;
      final sameDayScheduled = allRecords.where((r) =>
          r.recordType == 'programado' &&
          r.date.year == rec.date.year &&
          r.date.month == rec.date.month &&
          r.date.day == rec.date.day).toList();
      final position = sameDayScheduled.indexOf(rec) + 1;
      recordLabel = '· Registro ${position > 0 ? position : 1}/$maxPerDay';
    } else {
      recordLabel = '· Registro extra';
    }

    return Dismissible(
      key: Key(rec.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Editar
          context.push('/record/edit/${rec.id}');
          return false;
        } else {
          // Swipe left → Eliminar
          return await _confirmDelete(rec);
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8A820),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.edit, color: Colors.white, size: 20),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedId = isOpen ? null : rec.id;
          });
        },
        child: Container(
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
              // ── Header row ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendar icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFE8A820),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + time + record type
                          Row(
                            children: [
                              Text(
                                _dateStr(rec.date),
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _timeStr(rec.createdAt),
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                recordLabel,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF8A5A05),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Vital signs mini grid (2x2)
                          if (vs != null)
                            _buildVitalMiniGrid(vs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Bottom row: status + chevron ──
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: st.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: st.dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            st.label,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: st.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              // ── Expanded detail ──
              if (isOpen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF0),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFE8A820).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (vs != null)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 3,
                          children: [
                            if (vs.temperature != null)
                              _vitalDetailCard('Temperatura', '${vs.temperature} °C'),
                            if (vs.heartRate != null)
                              _vitalDetailCard('Frec. cardíaca', '${vs.heartRate} lpm'),
                            if (vs.oxygenSaturation != null)
                              _vitalDetailCard('Saturación O₂', '${vs.oxygenSaturation} %'),
                            if (vs.respiratoryRate != null)
                              _vitalDetailCard('Frec. respiratoria', '${vs.respiratoryRate} rpm'),
                          ],
                        ),
                      if (rec.symptoms.isNotEmpty)
                        ...rec.symptoms.map((s) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE8A820).withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Síntoma',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${s.name} · ${s.intensity}/10',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      if (rec.generalNotes != null && rec.generalNotes!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE8A820).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Observaciones',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rec.generalNotes!,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalMiniGrid(VitalSigns vs) {
    return Column(
      children: [
        Row(
          children: [
            if (vs.temperature != null)
              Expanded(child: _vitalMini(Icons.thermostat, '${vs.temperature}°C', const Color(0xFFF07830))),
            if (vs.temperature != null && vs.heartRate != null) const SizedBox(width: 8),
            if (vs.heartRate != null)
              Expanded(child: _vitalMini(Icons.favorite, '${vs.heartRate} lpm', const Color(0xFFF43F5E))),
          ],
        ),
        if (vs.oxygenSaturation != null || vs.respiratoryRate != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (vs.oxygenSaturation != null)
                Expanded(child: _vitalMini(Icons.show_chart, '${vs.oxygenSaturation}%', const Color(0xFF4EC4D4))),
              if (vs.oxygenSaturation != null && vs.respiratoryRate != null) const SizedBox(width: 8),
              if (vs.respiratoryRate != null)
                Expanded(child: _vitalMini(Icons.air, '${vs.respiratoryRate} rpm', const Color(0xFFA78BFA))),
            ],
          ),
        ],
      ],
    );
  }

  Future<bool?> _confirmDelete(DailyRecord rec) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar este registro?',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
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
            onPressed: () async {
              Navigator.pop(ctx, true);
              final patientAsync = ref.read(currentPatientProvider);
              final patient = patientAsync.value;
              if (patient == null) return;
              try {
                await ref
                    .read(firestoreServiceProvider)
                    .deleteDailyRecord(patient.id, rec.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
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

  Widget _vitalMini(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalDetailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8A820).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
