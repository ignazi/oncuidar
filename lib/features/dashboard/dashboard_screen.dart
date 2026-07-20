import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../models/alert_level.dart';
import '../../models/daily_record.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _downloadTriggered = false;

  @override
  void initState() {
    super.initState();
    // Trigger auto-download después del login (solo una vez)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_downloadTriggered) {
        _downloadTriggered = true;
        _triggerAutoDownload();
      }
    });
  }

  void _triggerAutoDownload() {
    try {
      final connectivity = ref.read(isConnectedProvider).value ?? true;
      if (connectivity) {
        ref.read(autoDownloadServiceProvider).downloadAll();
      }
    } catch (_) {
      // Providers not available (e.g., in tests) — skip auto-download
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPatient = ref.watch(currentPatientProvider);
    final asyncRecords = ref.watch(dailyRecordsProvider);
    final asyncUser = ref.watch(userProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Block system back on main dashboard
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: asyncPatient.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.goldPrimary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar datos.',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        data: (patient) => asyncRecords.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.goldPrimary),
          ),
          error: (e, _) => Center(
            child: Text(
              'Error al cargar registros.',
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          data: (records) => asyncUser.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.goldPrimary),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error al cargar usuario.',
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
            data: (user) {
              final patientName = patient?.fullName ?? '';
              final caregiverName = user?.displayName ?? '';

              DailyRecord? lastRecord;
              if (records.isNotEmpty) {
                lastRecord = records.first;
              }

              final todayCount = _countTodayRecords(records);

              final vitals = lastRecord?.vitalSigns;
              final lastTemp = vitals?.temperature;
              final lastHr = vitals?.heartRate;
              final lastO2 = vitals?.oxygenSaturation;
              final lastRr = vitals?.respiratoryRate;

              final globalStatus = switch (lastRecord?.alertLevel) {
                AlertLevel.critico => 'Crítico',
                AlertLevel.alerta => 'Alerta',
                _ => 'Normal',
              };

              final lastRecordDate = lastRecord?.createdAt;
              final lastRecordStr = lastRecordDate != null
                  ? '${lastRecordDate.day.toString().padLeft(2, '0')}-${lastRecordDate.month.toString().padLeft(2, '0')}-${lastRecordDate.year}, '
                      '${lastRecordDate.hour.toString().padLeft(2, '0')}:${lastRecordDate.minute.toString().padLeft(2, '0')}'
                  : 'Sin registros';

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GradientHeader(),
                    _buildGreeting(caregiverName, patientName, lastRecordStr),
                    const SizedBox(height: 2),
                    _buildVitalSignsCard(
                      lastTemp: lastTemp,
                      lastHr: lastHr,
                      lastO2: lastO2,
                      lastRr: lastRr,
                      globalStatus: globalStatus,
                      todayCount: todayCount,
                    ),
                    const SizedBox(height: 10),
                    _buildQuickAccess(),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
    );
  }

  int _countTodayRecords(List<DailyRecord> records) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return records.where((r) => r.createdAt.isAfter(startOfDay)).length;
  }

  Widget _buildGreeting(
      String caregiverName, String patientName, String lastRecordStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, ${caregiverName.isNotEmpty ? caregiverName : 'Cuidador'}',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C1A00),
              height: 1.2,
            ),
          ),
          if (patientName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Paciente activo: $patientName',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A5A05),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            'Último registro: $lastRecordStr',
            style: GoogleFonts.nunito(
              fontSize: 14.5,
              color: const Color(0xFF9A8060),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsCard({
    double? lastTemp,
    int? lastHr,
    int? lastO2,
    int? lastRr,
    required String globalStatus,
    required int todayCount,
  }) {
    final statusColor = switch (globalStatus) {
      'Crítico' => AppColors.alertRed,
      'Alerta' => AppColors.alertYellow,
      _ => AppColors.alertGreen,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.goldPrimary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.goldPrimary.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signos vitales recientes',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2C1A00),
                      ),
                    ),
                    Text(
                      'Registros de hoy: $todayCount realizados',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF8A5A05),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      globalStatus,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grid 2x2 de signos vitales — layout manual para evitar
          Column(
            children: [
              // Row 1: Temperatura + Frec. cardíaca
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildVitalSignItem(
                        Icons.thermostat,
                        'Temperatura',
                        lastTemp != null ? '${lastTemp.toStringAsFixed(1)} °C' : '-- °C',
                        const Color(0xFFF07830),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: AppColors.goldPrimary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _buildVitalSignItem(
                        Icons.favorite,
                        'Frec. cardíaca',
                        lastHr != null ? '$lastHr lpm' : '-- lpm',
                        const Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
              ),
              // Divider horizontal
              Container(
                height: 1,
                color: AppColors.goldPrimary.withValues(alpha: 0.1),
              ),
              // Row 2: Saturación O₂ + Frec. respiratoria
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildVitalSignItem(
                        Icons.show_chart,
                        'Saturación O₂',
                        lastO2 != null ? '$lastO2 %' : '-- %',
                        const Color(0xFF4EC4D4),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: AppColors.goldPrimary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _buildVitalSignItem(
                        Icons.air,
                        'Frec. respiratoria',
                        lastRr != null ? '$lastRr rpm' : '-- rpm',
                        const Color(0xFFA78BFA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Botón ver registros del día
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  final today = DateTime.now();
                  final todayOnly = DateTime(today.year, today.month, today.day);
                  context.push('/history', extra: {'filterDate': todayOnly});
                },
                icon: const Icon(Icons.history, size: 18),
                label: Text(
                  'Ver registros del día',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC08808),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF4D0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
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
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C1A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCESO RÁPIDO',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9A8060),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              // Fila 1: Orientación | Recordatorios
              Row(
                children: [
                  Expanded(
                    child: _buildGoldQuickAccessCard(
                      Icons.chat_bubble_outline,
                      'Orientación',
                      'Asistente de ayuda',
                      () => context.push('/orientation'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildWhiteQuickAccessCard(
                      Icons.notifications_outlined,
                      'Recordatorios',
                      'Alertas y citas',
                      () => context.push('/reminders'),
                      const Color(0xFFF07830),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: Preguntas frecuentes | Biblioteca educativa
              Row(
                children: [
                  Expanded(
                    child: _buildWhiteQuickAccessCard(
                      Icons.help_outline,
                      'Preguntas frecuentes',
                      'Consultas comunes',
                      () => context.push('/faq'),
                      const Color(0xFFE8A820),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildWhiteQuickAccessCard(
                      Icons.book_outlined,
                      'Biblioteca educativa',
                      'Videos y guías',
                      () => context.push('/library'),
                      const Color(0xFF4EC4D4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 3: Registro | Historial
              Row(
                children: [
                  Expanded(
                    child: _buildWhiteQuickAccessCard(
                      Icons.assignment_outlined,
                      'Registro',
                      'Registrar datos',
                      () => context.push('/record'),
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildWhiteQuickAccessCard(
                      Icons.history,
                      'Historial',
                      'Registros pasados',
                      () => context.push('/history', extra: {'origin': 'dashboard'}),
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoldQuickAccessCard(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8A820), Color(0xFFC08808)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8A820).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteQuickAccessCard(
      IconData icon, String title, String subtitle, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C1A00),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF9A8060),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
