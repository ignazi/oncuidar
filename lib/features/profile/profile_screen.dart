import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../models/app_user.dart';
import '../../models/patient.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final patientAsync = ref.watch(currentPatientProvider);
    final patientsAsync = ref.watch(patientsListProvider);

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
            title: 'Mi perfil',
            trailing: GestureDetector(
              onTap: _showLogoutDialog,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Cerrar sesión',
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
          ),
          Expanded(
            child: userAsync.when(
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
                  'Error al cargar perfil: $e',
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
        data: (user) {
          final patient = patientAsync.value;
          final patients = patientsAsync.value ?? [];
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Perfil no encontrado',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No se pudo cargar tu perfil. Intentá de nuevo.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildAvatarSection(user),
                const SizedBox(height: 20),
                _buildPatientCard(patient, patients),
                const SizedBox(height: 12),
                _buildSupportInfoCard(patient),
                const SizedBox(height: 20),
                Text(
                  'v1.0.0',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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

  // ── Sección 1: Avatar + datos cuidador ──

  Widget _buildAvatarSection(AppUser user) {
    final initials = _getInitials(user.displayName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldPrimary.withValues(alpha: 0.08),
            AppColors.goldLight.withValues(alpha: 0.15),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD99A16), Color(0xFFF0B94C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldPrimary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showEditCaregiverDialog(user),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Color(0xFF8A5A05)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName.isNotEmpty ? user.displayName : 'Sin nombre',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (user.email != null && user.email!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                user.email!,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if ((user.relationship?.isNotEmpty ?? false) ||
              (user.phone?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (user.relationship?.isNotEmpty ?? false) user.relationship,
                  if (user.phone?.isNotEmpty ?? false) user.phone,
                ].join(' · '),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  // ── Sección 2: Paciente ──

  Widget _buildPatientCard(Patient? patient, List<Patient> allPatients) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD99A16), Color(0xFFF0B94C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.child_care, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PACIENTE ACTIVO',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient?.fullName ?? 'Sin paciente',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (patient != null)
                      Text(
                        '${patient.age != null ? "${patient.age} años" : ""}${patient.age != null && patient.diagnosis.isNotEmpty ? " · " : ""}${patient.diagnosis}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: patient != null ? () => _showEditPatientDialog(patient) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Editar',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showChangePatientSheet(allPatients),
                  child: _buildPatientActionBtn(
                    icon: Icons.repeat,
                    label: 'Cambiar',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddPatientDialog(),
                  child: _buildPatientActionBtn(
                    icon: Icons.add,
                    label: 'Agregar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientActionBtn({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección 3: Información de apoyo ──

  Widget _buildSupportInfoCard(Patient? patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de apoyo',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.local_hospital,
            label: 'Centro de salud',
            value: patient?.healthCenterName ?? '--',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'Dirección',
            value: patient?.healthCenterAddress ?? '--',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.phone,
            label: 'Teléfono',
            value: patient?.healthCenterPhone ?? '--',
            trailing: patient?.healthCenterPhone != null
                ? GestureDetector(
                    onTap: () => _callPhone(patient!.healthCenterPhone!),
                    child: const Icon(Icons.call, size: 18, color: Color(0xFF10B981)),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.emergency,
            label: 'Contacto de emergencia',
            value: patient?.emergencyContactPhone ?? '--',
            trailing: patient?.emergencyContactPhone != null
                ? GestureDetector(
                    onTap: () => _callPhone(patient!.emergencyContactPhone!),
                    child: const Icon(Icons.call, size: 18, color: AppColors.error),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.goldLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.goldDark, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }



  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cerrar sesión', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Text('¿Estás seguro que deseas cerrar sesión?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go('/welcome');
            },
            child: Text(
              'Cerrar sesión',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Diálogos ──

  void _showEditCaregiverDialog(AppUser user) {
    final nameController = TextEditingController(text: user.displayName);
    final relationshipController = TextEditingController(text: user.relationship ?? '');
    final phoneController = TextEditingController(text: user.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar cuidador', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(controller: nameController, label: 'Nombre completo'),
              const SizedBox(height: 12),
              _buildDialogField(controller: relationshipController, label: 'Parentesco'),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: phoneController,
                label: 'Teléfono',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(firestoreServiceProvider).updateUser({
                  'displayName': nameController.text.trim(),
                  'relationship': relationshipController.text.trim(),
                  'phone': phoneController.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuidador actualizado')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Guardar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.goldPrimary)),
          ),
        ],
      ),
    );
  }

  void _showEditPatientDialog(Patient patient) {
    final nameController = TextEditingController(text: patient.fullName);
    final ageController = TextEditingController(text: patient.age?.toString() ?? '');
    final diagnosisController = TextEditingController(text: patient.diagnosis);
    final healthCenterController = TextEditingController(text: patient.healthCenterName ?? '');
    final healthAddressController = TextEditingController(text: patient.healthCenterAddress ?? '');
    final healthPhoneController = TextEditingController(text: patient.healthCenterPhone ?? '');
    final emergencyNameController = TextEditingController(text: patient.emergencyContactName ?? '');
    final emergencyPhoneController = TextEditingController(text: patient.emergencyContactPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar paciente', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(controller: nameController, label: 'Nombre completo'),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: ageController,
                label: 'Edad',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildDialogField(controller: diagnosisController, label: 'Diagnóstico'),
              const SizedBox(height: 12),
              _buildDialogField(controller: healthCenterController, label: 'Centro de salud'),
              const SizedBox(height: 12),
              _buildDialogField(controller: healthAddressController, label: 'Dirección'),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: healthPhoneController,
                label: 'Teléfono del centro',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildDialogField(controller: emergencyNameController, label: 'Contacto de emergencia'),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: emergencyPhoneController,
                label: 'Teléfono de emergencia',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final age = int.tryParse(ageController.text.trim());
              try {
                await ref.read(firestoreServiceProvider).updatePatient(patient.id, {
                  'fullName': nameController.text.trim(),
                  'age': age,
                  'diagnosis': diagnosisController.text.trim(),
                  'healthCenterName': healthCenterController.text.trim(),
                  'healthCenterAddress': healthAddressController.text.trim(),
                  'healthCenterPhone': healthPhoneController.text.trim(),
                  'emergencyContactName': emergencyNameController.text.trim(),
                  'emergencyContactPhone': emergencyPhoneController.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paciente actualizado')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Guardar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.goldPrimary)),
          ),
        ],
      ),
    );
  }

  void _showChangePatientSheet(List<Patient> patients) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pacientes registrados')),
      );
      return;
    }

    final currentId = ref.read(currentPatientProvider).value?.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccionar paciente',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los registros, recordatorios y favoritos se actualizan según el paciente seleccionado.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            ...patients.map((p) {
              final isActive = p.id == currentId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive
                      ? AppColors.goldPrimary
                      : AppColors.goldLight,
                  child: Text(
                    p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.goldDark,
                    ),
                  ),
                ),
                title: Text(
                  p.fullName,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.goldPrimary : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  p.diagnosis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: isActive
                    ? const Icon(Icons.check_circle, color: AppColors.goldPrimary)
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!isActive) {
                    await ref
                        .read(selectedPatientIdProvider.notifier)
                        .select(p.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Paciente activo: ${p.fullName}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddPatientDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final diagnosisController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Agregar paciente', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(controller: nameController, label: 'Nombre completo'),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: ageController,
                label: 'Edad',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildDialogField(controller: diagnosisController, label: 'Diagnóstico'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || diagnosisController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y diagnóstico son obligatorios')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final uid = user.uid;
                final age = int.tryParse(ageController.text.trim());
                final patient = Patient(
                  id: '',
                  caregiverId: uid,
                  fullName: nameController.text.trim(),
                  age: age,
                  diagnosis: diagnosisController.text.trim(),
                  createdAt: DateTime.now(),
                );
                await ref.read(firestoreServiceProvider).addPatient(patient);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paciente agregado')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Guardar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.goldPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.goldPrimary),
        ),
      ),
    );
  }
}
