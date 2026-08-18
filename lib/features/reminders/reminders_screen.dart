import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../core/services/notification_service.dart';
import '../../models/patient.dart';
import '../../models/reminder.dart';

class _TypeConfig {
  final IconData icon;
  final Color color;

  const _TypeConfig({required this.icon, required this.color});
}

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  _TypeConfig _getTypeConfig(String type) {
    return switch (type) {
      'medicamento' => const _TypeConfig(
          icon: Icons.medication, color: AppColors.goldPrimary),
      'medicion' => const _TypeConfig(
          icon: Icons.thermostat, color: AppColors.tealSoft),
      'cita' => const _TypeConfig(
          icon: Icons.event, color: AppColors.softOrange),
      _ => const _TypeConfig(
          icon: Icons.notifications, color: AppColors.goldDark),
    };
  }

  String _getTypeLabel(String type) => switch (type) {
        'medicamento' => 'Medicamento',
        'medicion' => 'Medición',
        'cita' => 'Cita médica',
        _ => 'Recordatorio',
      };

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDay(String day) => switch (day) {
        'lun' => 'Lun',
        'mar' => 'Mar',
        'mie' => 'Mié',
        'jue' => 'Jue',
        'vie' => 'Vie',
        'sab' => 'Sáb',
        'dom' => 'Dom',
        _ => day,
      };

  DateTime _buildDateTime(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  // ─────────────────────────────────────
  //  SECTION LABEL
  //  ─────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Calcula el texto del countdown hasta la próxima ocurrencia.
  /// Para create: si la hora ya pasó hoy, suma 1 día.
  /// Para edit: usa la fecha del reminder.
  String _formatCountdown(DateTime target) {
    final now = DateTime.now();
    var adjusted = target;
    // Si ya pasó, proyectar a mañana (create) o mantener (edit se basa en su fecha)
    if (adjusted.isBefore(now)) {
      adjusted = adjusted.add(const Duration(days: 1));
    }
    final diff = adjusted.difference(now);
    if (diff.isNegative) return '0h 00min';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }

  // ─────────────────────────────────────
  //  DELETE DIALOG ACTION BUTTONS
  //  ─────────────────────────────────────
  Widget _buildDeleteDialogActions({
    required VoidCallback onCancel,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 17, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('Cancelar',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 17, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Eliminar',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  DIALOG FRAME (shared — estilo dashboard: blanco + gold sutil)
  // ─────────────────────────────────────
  Widget _buildDialogFrame({
    required String title,
    required IconData icon,
    required Widget body,
    required Widget actions,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.goldPrimary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2C1A00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          body,

          // ── Actions ──
          actions,
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  CREATE DIALOG
  // ─────────────────────────────────────
  Future<void> _showCreateDialog({String initialType = 'medicamento'}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ReminderDialogBody(
        initialType: initialType,
        baseDateTime: DateTime.now(),
      ),
    );

    if (result == null) return;
    final title = result['title'] as String;
    final description = result['description'] as String?;
    final selectedType = result['type'] as String;
    final selectedTime = result['time'] as TimeOfDay;
    final selectedDays = result['days'] as List<String>;

    final dt = _buildDateTime(DateTime.now(), selectedTime);
    final patient = ref.read(currentPatientProvider).value;
    if (patient == null) return;

    final reminder = Reminder(
      id: '',
      patientId: patient.id,
      type: selectedType,
      title: title,
      description: description,
      dateTime: dt,
      repeatDays: selectedDays,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      final docId = await ref
          .read(firestoreServiceProvider)
          .addReminder(patient.id, reminder);

      if (patient.notificationsEnabled) {
        await NotificationService().scheduleReminder(
          id: NotificationService.safeId(docId),
          title: '${patient.fullName}: ${_getTypeLabel(reminder.type)}',
          body: '${reminder.title}${reminder.description != null ? ' · ${reminder.description}' : ''}',
          scheduledTime: dt,
          repeatDays: selectedDays,
          payload: patient.id,
        );
      }
    } catch (e, st) {
      debugPrint('ERROR saving reminder: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────
  //  EDIT DIALOG
  // ─────────────────────────────────────
  Future<void> _showEditDialog(Reminder reminder) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ReminderDialogBody(
        initialTitle: reminder.title,
        initialDescription: reminder.description ?? '',
        initialType: reminder.type,
        initialTime: TimeOfDay(
            hour: reminder.dateTime.hour, minute: reminder.dateTime.minute),
        initialDays: List<String>.from(reminder.repeatDays ?? []),
        isEditing: true,
        baseDateTime: reminder.dateTime,
      ),
    );

    if (result == null) return;

    final patient = ref.read(currentPatientProvider).value;
    if (patient == null) return;

    final title = result['title'] as String;
    final description = result['description'] as String?;
    final selectedType = result['type'] as String;
    final selectedTime = result['time'] as TimeOfDay;
    final selectedDays = result['days'] as List<String>;
    final newDt = _buildDateTime(reminder.dateTime, selectedTime);

    try {
      await ref.read(firestoreServiceProvider).updateReminder(
            patient.id,
            reminder.id,
            {
              'title': title,
              'description': description,
              'type': selectedType,
              'dateTime': newDt.toIso8601String(),
              'repeatDays': selectedDays,
            },
          );

      await NotificationService().cancelReminder(NotificationService.safeId(reminder.id));
      if (reminder.isActive && patient.notificationsEnabled) {
        await NotificationService().scheduleReminder(
          id: NotificationService.safeId(reminder.id),
          title: '${patient.fullName}: ${_getTypeLabel(selectedType)}',
          body: '${title}${description != null ? ' · $description' : ''}',
          scheduledTime: newDt,
          repeatDays: selectedDays,
          payload: patient.id,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar recordatorio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────
  //  DELETE DIALOG
  // ─────────────────────────────────────
  Future<void> _showDeleteDialog(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildDialogFrame(
        icon: Icons.delete_outline_rounded,
        title: 'Eliminar recordatorio',
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(reminder.dateTime),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTypeLabelRow(reminder.type),
                ],
              ),
              if (reminder.repeatDays != null &&
                  reminder.repeatDays!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: reminder.repeatDays!.map((d) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDay(d),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6030),
                      ),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '¿Estás seguro de eliminar este recordatorio?',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildDeleteDialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            onDelete: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final patient = ref.read(currentPatientProvider).value;
      if (patient == null) return;

      try {
        await ref
            .read(firestoreServiceProvider)
            .deleteReminder(patient.id, reminder.id);
        await NotificationService().cancelReminder(NotificationService.safeId(reminder.id));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar recordatorio'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─────────────────────────────────────
  //  TOGGLE
  // ─────────────────────────────────────
  Future<void> _toggleReminder(Reminder reminder) async {
    final patient = ref.read(currentPatientProvider).value;
    if (patient == null) return;

    final newActive = !reminder.isActive;
    try {
      await ref.read(firestoreServiceProvider).updateReminder(
            patient.id,
            reminder.id,
            {'isActive': newActive},
          );

      if (newActive) {
        if (patient.notificationsEnabled) {
          await NotificationService().scheduleReminder(
            id: NotificationService.safeId(reminder.id),
            title: '${patient.fullName}: ${_getTypeLabel(reminder.type)}',
            body: '${reminder.title}${reminder.description != null ? ' · ${reminder.description}' : ''}',
            scheduledTime: reminder.dateTime,
            repeatDays: reminder.repeatDays,
            payload: patient.id,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.alarm, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activado — suena en ${_formatCountdown(reminder.dateTime)}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.goldPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        await NotificationService().cancelReminder(NotificationService.safeId(reminder.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar recordatorio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────
  //  MASTER NOTIFICATION TOGGLE
  // ─────────────────────────────────────
  Widget _buildNotificationToggle(Patient patient) {
    final enabled = patient.notificationsEnabled;
    return GestureDetector(
      onTap: () => _toggleAllNotifications(patient),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          enabled ? Icons.notifications_active : Icons.notifications_off,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Future<void> _toggleAllNotifications(Patient patient) async {
    final enable = !patient.notificationsEnabled;

    try {
      await ref.read(firestoreServiceProvider).updatePatient(patient.id, {
        'notificationsEnabled': enable,
      });

      if (!enable) {
        final reminders = ref.read(remindersProvider).value ?? [];
        for (final r in reminders) {
          await NotificationService()
              .cancelReminder(NotificationService.safeId(r.id));
        }
      } else {
        final reminders = ref.read(remindersProvider).value ?? [];
        for (final r in reminders.where((r) => r.isActive)) {
          await NotificationService().scheduleReminder(
            id: NotificationService.safeId(r.id),
            title: '${patient.fullName}: ${_getTypeLabel(r.type)}',
            body:
                '${r.title}${r.description != null ? ' · ${r.description}' : ''}',
            scheduledTime: r.dateTime,
            repeatDays: r.repeatDays,
            payload: patient.id,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  enable ? Icons.notifications_active : Icons.notifications_off,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enable
                        ? 'Notificaciones activadas para ${patient.fullName}'
                        : 'Notificaciones desactivadas para ${patient.fullName}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: enable ? AppColors.goldPrimary : AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar preferencias'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);
    final patientAsync = ref.watch(currentPatientProvider);

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
            title: 'Recordatorios',
            trailing: patientAsync.value != null
                ? _buildNotificationToggle(patientAsync.value!)
                : null,
          ),
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error al cargar recordatorios.',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              data: (reminders) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick add ──
                      _buildQuickAddSection(),
                      const SizedBox(height: 20),

                      // ── Reminders list ──
                      _buildSectionLabel('Mis recordatorios'),
                      const SizedBox(height: 10),
                      if (reminders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.alarm_off,
                                    size: 48, color: AppColors.textHint),
                                const SizedBox(height: 10),
                                Text('No tienes recordatorios.',
                                    style: GoogleFonts.nunito(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Text('Usa los botones de arriba para crear uno.',
                                    style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        color: AppColors.textHint)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...reminders.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: Key(r.id),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    await _showEditDialog(r);
                                  } else {
                                    await _showDeleteDialog(r);
                                  }
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.goldPrimary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.white, size: 22),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_outline,
                                      color: Colors.white, size: 22),
                                ),
                                child: _buildReminderCard(r,
                                  notificationsEnabled: patientAsync.value?.notificationsEnabled ?? true,
                                ),
                              ),
                            )),
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

  // ─────────────────────────────────────
  //  QUICK ADD GRID
  // ─────────────────────────────────────
  Widget _buildQuickAddSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Agregar recordatorio'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildQuickAddButton(Icons.medication, 'Medicamento', 'medicamento')),
            const SizedBox(width: 6),
            Expanded(child: _buildQuickAddButton(Icons.thermostat, 'Medición', 'medicion')),
            const SizedBox(width: 6),
            Expanded(child: _buildQuickAddButton(Icons.event, 'Cita médica', 'cita')),
            const SizedBox(width: 6),
            Expanded(child: _buildQuickAddButton(Icons.add_rounded, 'Nuevo', 'medicamento')),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(IconData icon, String label, String initialType) {
    return GestureDetector(
      onTap: () => _showCreateDialog(initialType: initialType),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.goldPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  REMINDER CARD
  // ─────────────────────────────────────
  Widget _buildTypeLabelRow(String type) {
    final cfg = _getTypeConfig(type);
    return Row(
      children: [
        Icon(cfg.icon, size: 14, color: cfg.color),
        const SizedBox(width: 6),
        Text(
          _getTypeLabel(type),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cfg.color,
          ),
        ),
      ],
    );
  }
  Widget _buildReminderCard(Reminder reminder,
      {bool notificationsEnabled = true}) {
    final config = _getTypeConfig(reminder.type);
    final days = (reminder.repeatDays ?? []).map(_formatDay).toList();
    final isEffectivelyActive = reminder.isActive && notificationsEnabled;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEffectivelyActive
                  ? const Color(0xFFFFF0C2)
                  : const Color(0xFFF0EDE8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              config.icon,
              color: isEffectivelyActive
                  ? config.color
                  : const Color(0xFFB0A08A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isEffectivelyActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(reminder.dateTime),
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (reminder.description != null &&
                    reminder.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (days.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: days.map((day) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isEffectivelyActive
                              ? const Color(0xFFFFF4D0)
                              : const Color(0xFFF0EDE8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                          child: Text(
                            day,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isEffectivelyActive
                                  ? const Color(0xFF7A6030)
                                  : AppColors.textSecondary,
                            ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── Toggle ──
          GestureDetector(
            onTap: () => _toggleReminder(reminder),
            child: Container(
              width: 48,
              height: 26,
              decoration: BoxDecoration(
                color: isEffectivelyActive
                    ? AppColors.goldMid
                    : const Color(0xFFD8D0C8),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isEffectivelyActive
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
//  REMINDER DIALOG BODY (StatefulWidget)
//  Owns TextEditingControllers + Timer lifecycle.
//  On save, pops with Map<String, dynamic> containing the values.
//  Controllers are disposed in dispose() AFTER the route exit
//  animation finishes — preventing "used after disposed" crashes.
// ─────────────────────────────────────
class _ReminderDialogBody extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;
  final String initialType;
  final TimeOfDay initialTime;
  final List<String> initialDays;
  final bool isEditing;
  final DateTime baseDateTime;

  const _ReminderDialogBody({
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialType = 'medicamento',
    this.initialTime = const TimeOfDay(hour: 8, minute: 0),
    this.initialDays = const ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'],
    this.isEditing = false,
    required this.baseDateTime,
  });

  @override
  State<_ReminderDialogBody> createState() => _ReminderDialogBodyState();
}

class _ReminderDialogBodyState extends State<_ReminderDialogBody> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedType;
  late TimeOfDay _selectedTime;
  late List<String> _selectedDays;
  String _countdownText = '';
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _selectedType = widget.initialType;
    _selectedTime = widget.initialTime;
    _selectedDays = List<String>.from(widget.initialDays);
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    final base = widget.isEditing ? widget.baseDateTime : DateTime.now();
    _countdownText = _formatCountdown(_buildDateTime(base, _selectedTime));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _countdownText = _formatCountdown(_buildDateTime(base, _selectedTime));
        });
      }
    });
  }

  DateTime _buildDateTime(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  String _formatCountdown(DateTime target) {
    final now = DateTime.now();
    var adjusted = target;
    if (adjusted.isBefore(now)) {
      adjusted = adjusted.add(const Duration(days: 1));
    }
    final diff = adjusted.difference(now);
    if (diff.isNegative) return '0h 00min';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }

  String _formatDay(String day) => switch (day) {
        'lun' => 'Lun',
        'mar' => 'Mar',
        'mie' => 'Mié',
        'jue' => 'Jue',
        'vie' => 'Vie',
        'sab' => 'Sáb',
        'dom' => 'Dom',
        _ => day,
      };

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, <String, dynamic>{
      'title': title,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'type': _selectedType,
      'time': _selectedTime,
      'days': _selectedDays,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isEditing ? Icons.edit_rounded : Icons.add_rounded,
                    color: AppColors.goldPrimary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isEditing ? 'Editar recordatorio' : 'Nuevo recordatorio',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2C1A00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(controller: _titleCtrl, hintText: 'Título del recordatorio'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descCtrl,
                    hintText: 'Descripción (opcional)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Tipo'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _typeChip('Medicamento', _selectedType == 'medicamento', () => setState(() => _selectedType = 'medicamento')),
                      _typeChip('Medición', _selectedType == 'medicion', () => setState(() => _selectedType = 'medicion')),
                      _typeChip('Cita médica', _selectedType == 'cita', () => setState(() => _selectedType = 'cita')),
                      _typeChip('Otro', _selectedType == 'otro', () => setState(() => _selectedType = 'otro')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Hora'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openTimePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            MaterialLocalizations.of(context).formatTimeOfDay(_selectedTime),
                            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const Spacer(),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  if (_countdownText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.goldLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm, size: 18, color: AppColors.goldDark),
                            const SizedBox(width: 8),
                            Text(
                              'Suena en $_countdownText',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionLabel('Días de repetición'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'].map((day) {
                      final sel = _selectedDays.contains(day);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.goldPrimary : AppColors.goldLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatDay(day),
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : const Color(0xFF7A6030),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded, size: 17, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Cancelar',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.goldPrimary, AppColors.goldPrimary.withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldPrimary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.isEditing ? Icons.save_rounded : Icons.check_rounded, size: 17, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            widget.isEditing ? 'Actualizar' : 'Guardar',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ──

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.nunito(fontSize: 15, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _typeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldPrimary : AppColors.goldLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF7A6030),
          ),
        ),
      ),
    );
  }

  void _openTimePicker() {
    final use24h = MediaQuery.of(context).alwaysUse24HourFormat;
    final hourLabels = use24h
        ? List.generate(24, (i) => i.toString().padLeft(2, '0'))
        : List.generate(12, (i) => i == 0 ? '12' : i.toString().padLeft(2, '0'));
    final minuteLabels = List.generate(60, (i) => i.toString().padLeft(2, '0'));
    final amPmLabels = ['AM', 'PM'];

    int hourIndex = use24h ? _selectedTime.hour : _selectedTime.hour % 12;
    int minuteIndex = _selectedTime.minute;
    int amPmIndex = _selectedTime.hour < 12 ? 0 : 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Elegir la hora',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            int finalHour;
                            if (use24h) {
                              finalHour = hourIndex;
                            } else {
                              finalHour = hourIndex == 0 ? 12 : hourIndex;
                              if (amPmIndex == 1) {
                                if (finalHour != 12) finalHour += 12;
                              } else {
                                if (finalHour == 12) finalHour = 0;
                              }
                            }
                            final picked = TimeOfDay(hour: finalHour, minute: minuteIndex);
                            Navigator.pop(sheetCtx);
                            setState(() => _selectedTime = picked);
                          },
                          child: Text(
                            'Listo',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildWheel(
                              labels: hourLabels,
                              selectedIndex: hourIndex,
                              onChanged: (i) => setSheetState(() => hourIndex = i),
                            ),
                          ),
                          Text(
                            ':',
                            style: GoogleFonts.nunito(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: _buildWheel(
                              labels: minuteLabels,
                              selectedIndex: minuteIndex,
                              onChanged: (i) => setSheetState(() => minuteIndex = i),
                            ),
                          ),
                          if (!use24h) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: _buildWheel(
                                labels: amPmLabels,
                                selectedIndex: amPmIndex,
                                onChanged: (i) => setSheetState(() => amPmIndex = i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWheel({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: selectedIndex),
      itemExtent: 36,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.5,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: labels.length,
        builder: (context, index) {
          final isSelected = index == selectedIndex;
          return Center(
            child: Text(
              labels[index],
              style: GoogleFonts.nunito(
                fontSize: isSelected ? 20 : 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }
}
