import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compartidos/widgets/dialogo_confirmacion.dart';
import '../../core/proveedores/proveedores.dart';
import '../../core/router/destino_aviso.dart';
import '../../core/servicios/servicio_base_datos.dart';
import '../../core/tema/paleta.dart';
import 'widgets/boton_cerrar_sesion.dart';
import 'widgets/dialogo_correos.dart';
import 'widgets/dialogo_editar_cuidador.dart';
import 'widgets/mensaje_error_datos.dart';
import 'widgets/pie_version.dart';
import 'widgets/tarjeta_perfil_cuidador.dart';

class PerfilCuidador extends ConsumerStatefulWidget {
  const PerfilCuidador({super.key});

  @override
  ConsumerState<PerfilCuidador> createState() => _PerfilCuidadorState();
}

class _PerfilCuidadorState extends ConsumerState<PerfilCuidador> {
  Map<String, dynamic>? _cuidador;
  bool _cargando = true;
  bool _error = false;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (_cuidador == null) {
      setState(() {
        _cargando = true;
        _error = false;
      });
    }
    try {
      final base = ref.read(servicioBaseDatosProvider);
      var datos = await base.obtenerCuidador().timeout(
        const Duration(seconds: 5),
      );
      final pendiente = datos['pendienteCorreo'] as Map?;
      if (pendiente != null && pendiente['tipo'] == 'principal') {
        await _confirmarCambioCorreoConfirmado(base, datos);
        datos = await base.obtenerCuidador().timeout(
          const Duration(seconds: 5),
        );
      }
      if (datos['respaldoPendienteServidor'] == true) {
        datos = await _reintentarRespaldo(base, datos);
      }
      if (!mounted) return;
      setState(() => _cuidador = datos);
    } catch (_) {
      if (!mounted) return;
      if (_cuidador == null) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Si el usuario ya confirmó el nuevo correo principal desde el enlace de
  /// verificación, el email de Auth ya cambió: sincronizamos el doc del
  /// cuidador y limpiamos el marcador de cambio pendiente.
  Future<void> _confirmarCambioCorreoConfirmado(
    ServicioBaseDatos base,
    Map<String, dynamic> datos,
  ) async {
    final pendiente = datos['pendienteCorreo'] as Map?;
    if (pendiente == null) return;
    if (pendiente['tipo'] != 'principal') return;
    final correoPendiente = (pendiente['correo'] as String?)?.toLowerCase();
    final correoAuth = ref
        .read(firebaseAuthProvider)
        .currentUser
        ?.email
        ?.toLowerCase();
    if (correoPendiente == null || correoPendiente.isEmpty) return;
    if (correoAuth == correoPendiente) {
      await base.sincronizarCorreoPrincipal(correoPendiente);
      await base.limpiarCambioCorreoPendiente();
    }
  }

  /// Reintenta registrar el respaldo pendiente; si sigue fallando se avisa sin bloquear el perfil.
  Future<Map<String, dynamic>> _reintentarRespaldo(
    ServicioBaseDatos base,
    Map<String, dynamic> datos,
  ) async {
    var confirmado = false;
    try {
      confirmado = await base.reintentarRegistroRespaldo().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {}
    if (confirmado) {
      return {...datos, 'respaldoPendienteServidor': false};
    }
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Tu correo de respaldo aún no se registra en el servidor. '
            'Lo reintentaremos al volver a abrir tu perfil.',
          ),
        ),
      );
    }
    return datos;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_cargando)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error)
          MensajeErrorDatos(alReintentar: _cargar)
        else ...[
          _tarjetaPerfil(),
          const SizedBox(height: 28),
          const PieVersion(),
          const SizedBox(height: 8),
          BotonCerrarSesion(cargando: _cerrandoSesion, alPulsar: _cerrarSesion),
        ],
      ],
    );
  }

  // ── Tarjeta del cuidador (mismo lenguaje visual que paciente activo) ──

  Widget _tarjetaPerfil() {
    final nombre = (_cuidador?['nombre'] as String?) ?? '';
    final correoRespaldo = (_cuidador?['correoRespaldo'] as String?)?.trim();
    final telefono = (_cuidador?['telefono'] as String?)?.trim();
    final relacion = (_cuidador?['relacion'] as String?)?.trim();
    final direccion = (_cuidador?['direccion'] as String?)?.trim();
    final emailAuth =
        ref.read(firebaseAuthProvider).currentUser?.email?.trim() ?? '';
    final correoPrincipal =
        (_cuidador?['email'] as String?)?.trim() ?? emailAuth;
    final pendiente = _cuidador?['pendienteCorreo'] as Map?;

    return TarjetaPerfilCuidador(
      nombre: nombre,
      relacion: relacion,
      direccion: direccion ?? '',
      telefono: telefono ?? '',
      correoPrincipal: correoPrincipal,
      correoRespaldo: (correoRespaldo != null && correoRespaldo.isNotEmpty)
          ? correoRespaldo
          : null,
      correoPrincipalPendiente: pendiente?['tipo'] == 'principal'
          ? pendiente!['correo'] as String?
          : null,
      respaldoPendiente: _cuidador?['respaldoPendienteServidor'] == true,
      onEditarDatos: _dialogoEditarCuidador,
      onEditarCorreoPrincipal: () => _dialogoCorreos(editarPrincipal: true),
      onEditarCorreoRespaldo: () => _dialogoCorreos(editarRespaldo: true),
    );
  }

  // ── Editar datos personales (sin correos) ──

  Future<void> _dialogoEditarCuidador() async {
    final servicio = ref.read(servicioBaseDatosProvider);
    await mostrarDialogoEditarCuidador(
      context,
      cuidador: _cuidador ?? {},
      alGuardar:
          ({
            required String nombre,
            required String telefono,
            required String relacion,
            required String direccion,
          }) async {
            if (mounted) {
              setState(() {
                _cuidador = {
                  ...?_cuidador,
                  'nombre': nombre,
                  'telefono': telefono,
                  'relacion': relacion,
                  'direccion': direccion,
                };
              });
            }
            ref.invalidate(cuidadorProvider);
            unawaited(_cargar());
            // Si la escritura falla, la excepción llega al diálogo para que NUNCA
            // se muestre "Datos actualizados" cuando en realidad no se guardó.
            await servicio
                .actualizarCuidador(
                  nombre: nombre,
                  telefono: telefono,
                  relacion: relacion,
                  direccion: direccion,
                )
                .timeout(const Duration(seconds: 3));
            unawaited(_cargar());
          },
    );
  }

  // ── Editar correos (principal / respaldo) ──

  Future<void> _dialogoCorreos({
    bool editarPrincipal = false,
    bool editarRespaldo = false,
  }) async {
    final cuidador = _cuidador ?? {};
    final correoPrincipalOriginal =
        (cuidador['email'] as String?)?.trim() ?? '';
    final correoRespaldoOriginal =
        (cuidador['correoRespaldo'] as String?)?.trim() ?? '';
    await mostrarDialogoCorreos(
      context,
      servicio: ref.read(servicioBaseDatosProvider),
      correoPrincipalOriginal: correoPrincipalOriginal,
      correoRespaldoOriginal: correoRespaldoOriginal,
      editarPrincipal: editarPrincipal,
      editarRespaldo: editarRespaldo,
      alRefrescar: _cargar,
    );
  }

  // ── Cerrar sesión ──

  Future<void> _cerrarSesion() async {
    final confirmar = await mostrarDialogoConfirmacion(
      context,
      icono: Icons.logout_rounded,
      titulo: 'Cerrar sesión',
      mensaje: '¿Seguro que deseas cerrar tu sesión?',
      textoConfirmar: 'Cerrar sesión',
      colorConfirmar: Paleta.doradoOscuro,
      iconoConfirmar: Icons.logout_rounded,
    );
    if (confirmar != true || !mounted) return;
    setState(() => _cerrandoSesion = true);
    await ref.read(selectedPatientIdProvider.notifier).select(null);
    ref.read(servicioCifradoProvider).bloquear();
    ref.read(bloqueoCifradoProvider.notifier).fijarDesbloqueado(false);
    try {
      await ref.read(servicioNotificacionesProvider).cancelarTodas();
    } catch (_) {
      // Al cerrar sesión no se deben dejar avisos programados (HU-18).
    }
    try {
      await ref.read(firebaseAuthProvider).signOut();
    } catch (_) {
      // El estado de sesion se resuelve con el listener de autenticacion.
    }
    // Sin esto el gate de arranque queda abierto: un enlace profundo posterior
    // entraría a una ruta protegida sin volver a pasar por el Splash.
    EstadoArranque.reiniciar();
    if (mounted && context.mounted) context.go('/bienvenida');
  }
}
