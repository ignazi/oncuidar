import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_header.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers Cuidador
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controllers Paciente
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _diagnosisController = TextEditingController();

  // Controllers Info de Apoyo
  final _centerNameController = TextEditingController();
  final _centerAddressController = TextEditingController();
  final _centerPhoneController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String? _selectedRelationship;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final _relationships = ['Madre', 'Padre', 'Tutor', 'Otro'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _patientNameController.dispose();
    _ageController.dispose();
    _diagnosisController.dispose();
    _centerNameController.dispose();
    _centerAddressController.dispose();
    _centerPhoneController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = credential.user!.uid;

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'relationship': _selectedRelationship,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final patientRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('patients')
            .doc();

        await patientRef.set({
          'fullName': _patientNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'diagnosis': _diagnosisController.text.trim(),
          'healthCenterName': _centerNameController.text.trim(),
          'healthCenterAddress': _centerAddressController.text.trim(),
          'healthCenterPhone': _centerPhoneController.text.trim(),
          'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Si los writes a Firestore fallan, limpiar la cuenta Auth huérfana
        try {
          await credential.user?.delete();
        } catch (_) {}
        rethrow;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Ya existe una cuenta con ese correo electrónico.';
          break;
        case 'invalid-email':
          message = 'El correo electrónico no es válido.';
          break;
        case 'weak-password':
          message = 'La contraseña es muy débil. Usa al menos 6 caracteres.';
          break;
        default:
          message = 'Error al crear la cuenta. Intenta de nuevo.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error inesperado. Intenta de nuevo.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          // ── Header con gradiente ──
          GradientHeader(
            showBackButton: true,
            title: 'Crear tu perfil',
            height: 160,
            onBackPressed: () => context.pop(),
            child: const SizedBox.shrink(),
          ),

          // ── Formulario ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ══════════════════════════════════════════
                    // CARD 1 — Datos del cuidador
                    // ══════════════════════════════════════════
                    _buildSectionCard(
                      icon: Icons.person_rounded,
                      title: 'Datos del cuidador',
                      children: [
                        _buildLabel('Nombre completo'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _nameController,
                          hintText: 'Nombre completo',
                          icon: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa tu nombre' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Relación con el paciente'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRelationship,
                          decoration: _inputDecoration(
                            hintText: 'Seleccionar',
                            icon: Icons.family_restroom_outlined,
                          ),
                          items: _relationships
                              .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r, style: GoogleFonts.nunito(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRelationship = v),
                          validator: (v) => v == null ? 'Selecciona una relación' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Teléfono'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _phoneController,
                          hintText: '+56 9 0000 0000',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Correo electrónico'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _emailController,
                          hintText: 'correo@ejemplo.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Contraseña'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _passwordController,
                          hintText: 'Mínimo 6 caracteres',
                          icon: Icons.lock_outlined,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Confirmar contraseña'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _confirmPasswordController,
                          hintText: 'Repite tu contraseña',
                          icon: Icons.lock_outlined,
                          obscure: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                            if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ══════════════════════════════════════════
                    // CARD 2 — Datos del paciente
                    // ══════════════════════════════════════════
                    _buildSectionCard(
                      icon: Icons.child_care_rounded,
                      title: 'Datos del paciente',
                      children: [
                        _buildLabel('Nombre del paciente'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _patientNameController,
                          hintText: 'Nombre completo',
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre del paciente' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Edad'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _ageController,
                          hintText: 'Años',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Diagnóstico'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _diagnosisController,
                          hintText: 'Tipo de cáncer / diagnóstico',
                          icon: Icons.medical_information_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el diagnóstico' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ══════════════════════════════════════════
                    // CARD 3 — Información de apoyo
                    // ══════════════════════════════════════════
                    _buildSectionCard(
                      icon: Icons.local_hospital_outlined,
                      title: 'Información de apoyo',
                      children: [
                        _buildLabel('Centro de salud'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _centerNameController,
                          hintText: 'Nombre del centro',
                          icon: Icons.apartment_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Dirección'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _centerAddressController,
                          hintText: 'Dirección del centro',
                          icon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Tel. contacto del centro'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _centerPhoneController,
                          hintText: '+56 2 0000 0000',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Tel. de urgencia'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _emergencyPhoneController,
                          hintText: '+56 2 0000 0000',
                          icon: Icons.emergency_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Botón Guardar ──
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldPrimary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.goldPrimary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: AppColors.goldPrimary.withValues(alpha: 0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Guardar y continuar',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Link a Login ──
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/login'),
                        child: Text.rich(
                          TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: GoogleFonts.nunito(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Iniciar sesión',
                                style: GoogleFonts.nunito(
                                  color: AppColors.goldDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de sección
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.goldDark, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hintText: hintText,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.nunito(color: AppColors.textHint, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: AppColors.goldDark),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.borderCard),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.borderCard),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.goldPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
