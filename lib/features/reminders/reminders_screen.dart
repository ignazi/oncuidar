import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../core/services/notification_service.dart';
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
  //  TYPE CHIP (fixed — receives isSelected + onTap)
  // ─────────────────────────────────────
  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldPrimary : AppColors.goldLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF7A6030),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  DAY CHIP
  // ─────────────────────────────────────
  Widget _buildDayChip({
    required String day,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldPrimary : AppColors.goldLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDay(day),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF7A6030),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  TIME PICKER — Bottom sheet con scroll wheels
  //  Más amigable que el reloj de Material para
  //  cuidadores en contexto de estrés.
  // ─────────────────────────────────────
  Widget _buildTimePicker({
    required BuildContext ctx,
    required TimeOfDay selectedTime,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    return GestureDetector(
      onTap: () => _openTimePickerSheet(ctx, selectedTime, onPicked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.goldPrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              _formatTimeOfDay(selectedTime, ctx),
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Formatea la hora según el locale del dispositivo (12h/24h)
  String _formatTimeOfDay(TimeOfDay t, BuildContext ctx) {
    return MaterialLocalizations.of(ctx).formatTimeOfDay(t);
  }

  /// Bottom sheet con 3 wheels: hora, minuto, AM/PM (solo en modo 12h)
  void _openTimePickerSheet(
      BuildContext ctx, TimeOfDay current, ValueChanged<TimeOfDay> onPicked) {
    final use24h = MediaQuery.of(ctx).alwaysUse24HourFormat;

    final hourLabels = use24h
        ? List.generate(24, (i) => i.toString().padLeft(2, '0'))
        : List.generate(12, (i) => i == 0 ? '12' : i.toString().padLeft(2, '0'));
    final minuteLabels =
        List.generate(60, (i) => i.toString().padLeft(2, '0'));
    final amPmLabels = ['AM', 'PM'];

    int hourIndex;
    if (use24h) {
      hourIndex = current.hour;
    } else {
      int h12 = current.hour % 12;
      hourIndex = h12;
    }
    int minuteIndex = current.minute;
    int amPmIndex = current.hour < 12 ? 0 : 1;

    showModalBottomSheet(
      context: ctx,
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
                            onPicked(picked);
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

  /// Widget de scroll wheel individual
  Widget _buildWheel({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: selectedIndex),
      itemExtent: 40,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.5,
      perspective: 0.003,
      onSelectedItemChanged: (i) => onChanged(i),
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

  // ─────────────────────────────────────
  //  STYLED TEXT FIELD
  // ─────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.nunito(fontSize: 14, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  SECTION LABEL
  // ─────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }

  // ─────────────────────────────────────
  //  DIALOG CONTENT BUILDER (shared create/edit)
  // ─────────────────────────────────────
  Widget _buildDialogBody({
    required TextEditingController titleCtrl,
    required TextEditingController? descCtrl,
    required String selectedType,
    required ValueChanged<String> onTypeChanged,
    required StateSetter setDialogState,
    required TimeOfDay selectedTime,
    required ValueChanged<TimeOfDay> onTimeChanged,
    required List<String> selectedDays,
    required BuildContext dialogContext,
  }) {
    final allDays = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(controller: titleCtrl, hintText: 'Título del recordatorio'),
          if (descCtrl != null) ...[
            const SizedBox(height: 12),
            _buildTextField(
                controller: descCtrl,
                hintText: 'Descripción (opcional)',
                maxLines: 2),
          ],
          const SizedBox(height: 16),
          _buildSectionLabel('Tipo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip(
                label: 'Medicamento',
                isSelected: selectedType == 'medicamento',
                onTap: () => onTypeChanged('medicamento'),
              ),
              _buildTypeChip(
                label: 'Medición',
                isSelected: selectedType == 'medicion',
                onTap: () => onTypeChanged('medicion'),
              ),
              _buildTypeChip(
                label: 'Cita médica',
                isSelected: selectedType == 'cita',
                onTap: () => onTypeChanged('cita'),
              ),
              _buildTypeChip(
                label: 'Otro',
                isSelected: selectedType == 'otro',
                onTap: () => onTypeChanged('otro'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Hora'),
          const SizedBox(height: 8),
          _buildTimePicker(
            ctx: dialogContext,
            selectedTime: selectedTime,
            onPicked: onTimeChanged,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Días de repetición'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allDays.map((day) {
              return _buildDayChip(
                day: day,
                isSelected: selectedDays.contains(day),
                onTap: () => setDialogState(() {
                  if (selectedDays.contains(day)) {
                    selectedDays.remove(day);
                  } else {
                    selectedDays.add(day);
                  }
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  DIALOG ACTION BUTTONS (shared)
  // ─────────────────────────────────────
  Widget _buildDialogActions({
    required BuildContext ctx,
    required VoidCallback onCancel,
    required VoidCallback onSave,
    String saveLabel = 'Guardar',
    IconData saveIcon = Icons.check_rounded,
    Color saveColor = AppColors.goldPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // ── Cancelar ──
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
                    Text(
                      'Cancelar',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
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
          // ── Guardar ──
          Expanded(
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [saveColor, saveColor.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: saveColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(saveIcon, size: 17, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      saveLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
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
    );
  }

  // ─────────────────────────────────────
  //  DELETE DIALOG ACTION BUTTONS
  // ─────────────────────────────────────
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
                          fontSize: 14,
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
                          fontSize: 14,
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
  //  CREATE DIALOG
  // ─────────────────────────────────────
  Future<void> _showCreateDialog({String initialType = 'medicamento'}) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = initialType;
    TimeOfDay selectedTime = TimeOfDay.now();
    List<String> selectedDays = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          actionsPadding: EdgeInsets.zero,
          title: Text(
            'Nuevo recordatorio',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: _buildDialogBody(
            titleCtrl: titleCtrl,
            descCtrl: descCtrl,
            selectedType: selectedType,
            onTypeChanged: (v) => setDialogState(() => selectedType = v),
            setDialogState: setDialogState,
            selectedTime: selectedTime,
            onTimeChanged: (t) => setDialogState(() => selectedTime = t),
            selectedDays: selectedDays,
            dialogContext: ctx,
          ),
          actions: [
            _buildDialogActions(
              ctx: ctx,
              onCancel: () => Navigator.pop(ctx, false),
              onSave: () {
                if (titleCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      final dt = _buildDateTime(DateTime.now(), selectedTime);
      final patient = ref.read(currentPatientProvider).value;
      if (patient == null) return;

      final reminder = Reminder(
        id: '',
        patientId: patient.id,
        type: selectedType,
        title: titleCtrl.text.trim(),
        description:
            descCtrl.text.isNotEmpty ? descCtrl.text.trim() : null,
        dateTime: dt,
        repeatDays: selectedDays,
        isActive: true,
        createdAt: DateTime.now(),
      );

      try {
        final docId = await ref
            .read(firestoreServiceProvider)
            .addReminder(patient.id, reminder);

        await NotificationService().scheduleReminder(
          id: NotificationService.safeId(docId),
          title: _getTypeLabel(reminder.type),
          body: '${reminder.title}${reminder.description != null ? ' · ${reminder.description}' : ''}',
          scheduledTime: dt,
          repeatDays: selectedDays,
        );
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

    titleCtrl.dispose();
    descCtrl.dispose();
  }

  // ─────────────────────────────────────
  //  EDIT DIALOG
  // ─────────────────────────────────────
  Future<void> _showEditDialog(Reminder reminder) async {
    final titleCtrl = TextEditingController(text: reminder.title);
    final descCtrl = TextEditingController(text: reminder.description ?? '');
    String selectedType = reminder.type;
    TimeOfDay selectedTime =
        TimeOfDay(hour: reminder.dateTime.hour, minute: reminder.dateTime.minute);
    List<String> selectedDays = List<String>.from(reminder.repeatDays ?? []);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          actionsPadding: EdgeInsets.zero,
          title: Text(
            'Editar recordatorio',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: _buildDialogBody(
            titleCtrl: titleCtrl,
            descCtrl: descCtrl,
            selectedType: selectedType,
            onTypeChanged: (v) => setDialogState(() => selectedType = v),
            setDialogState: setDialogState,
            selectedTime: selectedTime,
            onTimeChanged: (t) => setDialogState(() => selectedTime = t),
            selectedDays: selectedDays,
            dialogContext: ctx,
          ),
          actions: [
            _buildDialogActions(
              ctx: ctx,
              onCancel: () => Navigator.pop(ctx, false),
              onSave: () {
                if (titleCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
              saveLabel: 'Actualizar',
              saveIcon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final patient = ref.read(currentPatientProvider).value;
      if (patient == null) return;

      final newDt = _buildDateTime(reminder.dateTime, selectedTime);

      try {
        await ref.read(firestoreServiceProvider).updateReminder(
              patient.id,
              reminder.id,
              {
                'title': titleCtrl.text.trim(),
                'description':
                    descCtrl.text.isNotEmpty ? descCtrl.text.trim() : null,
                'type': selectedType,
                'dateTime': newDt.toIso8601String(),
                'repeatDays': selectedDays,
              },
            );

        await NotificationService().cancelReminder(NotificationService.safeId(reminder.id));
        if (reminder.isActive) {
          await NotificationService().scheduleReminder(
            id: NotificationService.safeId(reminder.id),
            title: _getTypeLabel(selectedType),
            body: '${titleCtrl.text.trim()}${descCtrl.text.isNotEmpty ? ' · ${descCtrl.text.trim()}' : ''}',
            scheduledTime: newDt,
            repeatDays: selectedDays,
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

    titleCtrl.dispose();
    descCtrl.dispose();
  }

  // ─────────────────────────────────────
  //  DELETE DIALOG
  // ─────────────────────────────────────
  Future<void> _showDeleteDialog(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsPadding: EdgeInsets.zero,
        title: Text(
          '¿Eliminar este recordatorio?',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          reminder.title,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          _buildDeleteDialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            onDelete: () => Navigator.pop(ctx, true),
          ),
        ],
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
        await NotificationService().scheduleReminder(
          id: NotificationService.safeId(reminder.id),
          title: _getTypeLabel(reminder.type),
          body: '${reminder.title}${reminder.description != null ? ' · ${reminder.description}' : ''}',
          scheduledTime: reminder.dateTime,
          repeatDays: reminder.repeatDays,
        );
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

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);

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
                      _buildSectionLabel('Agregar recordatorio'),
                      const SizedBox(height: 10),
                      _buildQuickAddGrid(),
                      const SizedBox(height: 24),

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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text('Usa los botones de arriba para crear uno.',
                                    style: GoogleFonts.nunito(
                                        fontSize: 13,
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
                                child: _buildReminderCard(r),
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
  Widget _buildQuickAddGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: [
        _buildQuickAddButton(Icons.medication, 'Medicamento', 'medicamento'),
        _buildQuickAddButton(Icons.thermostat, 'Medición', 'medicion'),
        _buildQuickAddButton(Icons.event, 'Cita médica', 'cita'),
        _buildQuickAddButton(Icons.add, 'Nuevo +', 'medicamento'),
      ],
    );
  }

  Widget _buildQuickAddButton(IconData icon, String label, String initialType) {
    return GestureDetector(
      onTap: () => _showCreateDialog(initialType: initialType),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.goldPrimary.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                color: const Color(0xFFFFF0C2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.goldPrimary, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7A5F30),
                height: 1.2,
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
  Widget _buildReminderCard(Reminder reminder) {
    final config = _getTypeConfig(reminder.type);
    final days = (reminder.repeatDays ?? []).map(_formatDay).toList();

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
              color: reminder.isActive
                  ? const Color(0xFFFFF0C2)
                  : const Color(0xFFF0EDE8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              config.icon,
              color: reminder.isActive
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: reminder.isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(reminder.dateTime),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
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
                      fontSize: 12,
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
                          color: reminder.isActive
                              ? const Color(0xFFFFF4D0)
                              : const Color(0xFFF0EDE8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: reminder.isActive
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
                color: reminder.isActive
                    ? AppColors.goldMid
                    : const Color(0xFFD8D0C8),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: reminder.isActive
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
