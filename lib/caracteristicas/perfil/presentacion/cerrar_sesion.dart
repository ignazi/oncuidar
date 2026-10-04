import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/app/enrutador/destino_aviso.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/pacientes/presentacion/proveedores_pacientes.dart';
import 'package:oncuidar/compartido/widgets/dialogo_confirmacion.dart';
import 'package:oncuidar/nucleo/proveedores.dart';

/// Pide confirmación y cierra la sesión. [alCambiarEstado] avisa si está en curso.
Future<void> cerrarSesionConfirmando(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<bool> alCambiarEstado,
}) async {
  final confirmar = await mostrarDialogoConfirmacion(
    context,
    icono: Icons.logout_rounded,
    titulo: 'Cerrar sesión',
    mensaje: '¿Seguro que deseas cerrar tu sesión?',
    textoConfirmar: 'Cerrar sesión',
    colorConfirmar: Paleta.doradoRelleno,
    iconoConfirmar: Icons.logout_rounded,
  );
  if (confirmar != true || !context.mounted) return;
  alCambiarEstado(true);
  await ref.read(idPacienteSeleccionadoProvider.notifier).seleccionar(null);
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
    // El estado de sesión se resuelve con el listener de autenticación.
  }
  // Sin esto el gate de arranque queda abierto: un enlace profundo posterior
  // entraría a una ruta protegida sin volver a pasar por el Splash.
  EstadoArranque.reiniciar();
  if (context.mounted) context.go('/bienvenida');
}
