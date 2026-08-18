import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../core/services/notification_service.dart';
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
            const GradientHeader(
              showBackButton: true,
              title: 'Mi perfil',
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
                        const SizedBox(height: 24),
                        // ── Cerrar sesión + versión ──
                        GestureDetector(
                          onTap: _showLogoutDialog,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, size: 18, color: AppColors.error.withValues(alpha: 0.8)),
                                const SizedBox(width: 8),
                                Text(
                                  'Cerrar sesión',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'v1.0.0',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  // ── Sección 2: Paciente (con swipe editar/eliminar) ──

  Widget _buildPatientCard(Patient? patient, List<Patient> allPatients) {
    if (patient == null) {
      return _buildEmptyPatientCard();
    }

    return Dismissible(
      key: ValueKey('patient_${patient.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe derecha → Editar
          _showEditPatientDialog(patient);
          return false;
        } else {
          // Swipe izquierda → Eliminar
          return await _confirmDeletePatient(patient);
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldPrimary.withValues(alpha: 0.9),
              AppColors.goldMid.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            const Icon(Icons.edit, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Editar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.error.withValues(alpha: 0.85),
              AppColors.error.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Eliminar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.child_care, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
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
                        patient.fullName,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        [
                          if (patient.age != null) '${patient.age} años',
                          if (patient.diagnosis.isNotEmpty) patient.diagnosis,
                        ].join(' · '),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                      icon: Icons.person_add_outlined,
                      label: 'Agregar',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPatientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.child_care_outlined, size: 40, color: AppColors.goldPrimary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Sin paciente activo',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agregá un paciente para comenzar',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showAddPatientDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD99A16), Color(0xFFF0B94C)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Agregar paciente',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
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

  Future<bool> _confirmDeletePatient(Patient patient) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar paciente',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Eliminar a ${patient.fullName}? Esta acción no se puede deshacer.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, false);
              try {
                await ref.read(firestoreServiceProvider).deletePatient(patient.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${patient.fullName} eliminado')),
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
            child: Text(
              'Eliminar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ),
        ],
      ),
    ).then((_) => false);
  }

  // ── Sección 3: Información de apoyo ──

  Widget _buildSupportInfoCard(Patient? patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, size: 15, color: AppColors.goldDark),
              ),
              const SizedBox(width: 8),
              Text(
                'Información de apoyo',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Centro de salud ──
          if (patient?.healthCenterName != null && patient!.healthCenterName!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.local_hospital,
              label: 'Centro de salud',
              value: patient.healthCenterName!,
            ),
          if (patient?.healthCenterName != null && patient!.healthCenterName!.isNotEmpty)
            const SizedBox(height: 10),
          // ── Dirección ──
          if (patient?.healthCenterAddress != null && patient!.healthCenterAddress!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'Dirección',
              value: patient.healthCenterAddress!,
              trailing: GestureDetector(
                onTap: () => _openMaps(patient.healthCenterAddress!),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.map_outlined, size: 14, color: AppColors.goldDark),
                ),
              ),
            ),
          if (patient?.healthCenterAddress != null && patient!.healthCenterAddress!.isNotEmpty)
            const SizedBox(height: 10),
          // ── Teléfono centro ──
          if (patient?.healthCenterPhone != null && patient!.healthCenterPhone!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.phone,
              label: 'Teléfono del centro',
              value: patient.healthCenterPhone!,
              trailing: GestureDetector(
                onTap: () => _callPhone(patient.healthCenterPhone!),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.alertGreenBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.call, size: 14, color: Color(0xFF10B981)),
                ),
              ),
            ),
          if (patient?.healthCenterPhone != null && patient!.healthCenterPhone!.isNotEmpty)
            const SizedBox(height: 10),
          // ── Contacto de emergencia (NOMBRE + TELÉFONO) ──
          if ((patient?.emergencyContactName?.isNotEmpty ?? false) ||
              (patient?.emergencyContactPhone?.isNotEmpty ?? false))
            _buildEmergencyContactRow(patient!),
          // ── Sin información ──
          if (patient == null ||
              (patient.healthCenterName?.isEmpty != false &&
               patient.healthCenterAddress?.isEmpty != false &&
               patient.healthCenterPhone?.isEmpty != false &&
               patient.emergencyContactName?.isEmpty != false &&
               patient.emergencyContactPhone?.isEmpty != false))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay información de apoyo registrada.\nEditá el paciente para agregar datos del centro de salud y contacto de emergencia.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactRow(Patient patient) {
    final name = patient.emergencyContactName;
    final phone = patient.emergencyContactPhone;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.alertRedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.emergency, color: AppColors.error, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contacto de emergencia',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                if (name != null && name.isNotEmpty)
                  Text(
                    name,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (phone != null && phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      phone,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            GestureDetector(
              onTap: () => _callPhone(phone),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.call, size: 16, color: AppColors.error),
              ),
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

  Future<void> _openMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Cerrar sesión ──

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
              await NotificationService().cancelAllReminders();
              ref.read(selectedPatientIdProvider.notifier).select(null);
              ref.read(encryptionServiceProvider).lock();
              ref.read(encryptionUnlockedProvider.notifier).setUnlocked(false);
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

  // ── Editar paciente (Bottom Sheet con secciones) ──

  void _showEditPatientDialog(Patient patient) {
    final nameController = TextEditingController(text: patient.fullName);
    final ageController = TextEditingController(text: patient.age?.toString() ?? '');
    final diagnosisController = TextEditingController(text: patient.diagnosis);
    final healthCenterController = TextEditingController(text: patient.healthCenterName ?? '');
    final healthAddressController = TextEditingController(text: patient.healthCenterAddress ?? '');
    final healthPhoneController = TextEditingController(text: patient.healthCenterPhone ?? '');
    final emergencyNameController = TextEditingController(text: patient.emergencyContactName ?? '');
    final emergencyPhoneController = TextEditingController(text: patient.emergencyContactPhone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD99A16), Color(0xFFF0B94C)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Editar paciente',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Content ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Datos del paciente ──
                    _buildSectionHeader(
                      icon: Icons.person,
                      title: 'Datos del paciente',
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: nameController,
                      label: 'Nombre completo',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: ageController,
                      label: 'Edad',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: diagnosisController,
                      label: 'Diagnóstico',
                      icon: Icons.medical_information_outlined,
                    ),
                    const SizedBox(height: 20),
                    // ── Centro de salud ──
                    _buildSectionHeader(
                      icon: Icons.local_hospital,
                      title: 'Centro de salud',
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: healthCenterController,
                      label: 'Nombre del centro',
                      icon: Icons.local_hospital_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: healthAddressController,
                      label: 'Dirección',
                      icon: Icons.location_on_outlined,
                      suffixIcon: GestureDetector(
                        onTap: () {
                          final addr = healthAddressController.text.trim();
                          if (addr.isNotEmpty) _openMaps(addr);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: healthPhoneController,
                      label: 'Teléfono del centro',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    // ── Contacto de emergencia ──
                    _buildSectionHeader(
                      icon: Icons.emergency,
                      title: 'Contacto de emergencia',
                      isEmergency: true,
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: emergencyNameController,
                      label: 'Nombre del contacto',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: emergencyPhoneController,
                      label: 'Teléfono de emergencia',
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    // ── Botones ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final age = int.tryParse(ageController.text.trim());
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);
                              try {
                                await ref.read(firestoreServiceProvider).updatePatient(
                                  patient.id,
                                  {
                                    'fullName': nameController.text.trim(),
                                    'age': age,
                                    'diagnosis': diagnosisController.text.trim(),
                                    'healthCenterName': healthCenterController.text.trim(),
                                    'healthCenterAddress': healthAddressController.text.trim(),
                                    'healthCenterPhone': healthPhoneController.text.trim(),
                                    'emergencyContactName': emergencyNameController.text.trim(),
                                    'emergencyContactPhone': emergencyPhoneController.text.trim(),
                                  },
                                );
                                if (mounted) {
                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Paciente actualizado')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              'Guardar cambios',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    bool isEmergency = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isEmergency ? AppColors.error : AppColors.goldDark,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isEmergency ? AppColors.error : AppColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.goldDark),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.goldPrimary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  // ── Change/Add Patient ──

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
    final healthCenterController = TextEditingController();
    final healthAddressController = TextEditingController();
    final healthPhoneController = TextEditingController();
    final emergencyNameController = TextEditingController();
    final emergencyPhoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD99A16), Color(0xFFF0B94C)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agregar paciente',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Content ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Datos del paciente ──
                    _buildSectionHeader(
                      icon: Icons.person,
                      title: 'Datos del paciente',
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: nameController,
                      label: 'Nombre completo',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: ageController,
                      label: 'Edad',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: diagnosisController,
                      label: 'Diagnóstico',
                      icon: Icons.medical_information_outlined,
                    ),
                    const SizedBox(height: 20),
                    // ── Centro de salud ──
                    _buildSectionHeader(
                      icon: Icons.local_hospital,
                      title: 'Centro de salud',
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: healthCenterController,
                      label: 'Nombre del centro',
                      icon: Icons.local_hospital_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: healthAddressController,
                      label: 'Dirección',
                      icon: Icons.location_on_outlined,
                      suffixIcon: GestureDetector(
                        onTap: () {
                          final addr = healthAddressController.text.trim();
                          if (addr.isNotEmpty) _openMaps(addr);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: healthPhoneController,
                      label: 'Teléfono del centro',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    // ── Contacto de emergencia ──
                    _buildSectionHeader(
                      icon: Icons.emergency,
                      title: 'Contacto de emergencia',
                      isEmergency: true,
                    ),
                    const SizedBox(height: 12),
                    _buildStyledField(
                      controller: emergencyNameController,
                      label: 'Nombre del contacto',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    _buildStyledField(
                      controller: emergencyPhoneController,
                      label: 'Teléfono de emergencia',
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    // ── Botones ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty ||
                                  diagnosisController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nombre y diagnóstico son obligatorios'),
                                  ),
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
                                  healthCenterName: healthCenterController.text.trim(),
                                  healthCenterAddress: healthAddressController.text.trim(),
                                  healthCenterPhone: healthPhoneController.text.trim(),
                                  emergencyContactName: emergencyNameController.text.trim(),
                                  emergencyContactPhone: emergencyPhoneController.text.trim(),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Guardar',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
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
