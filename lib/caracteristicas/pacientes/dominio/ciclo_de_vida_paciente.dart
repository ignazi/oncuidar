import 'dart:async';

import 'package:oncuidar/caracteristicas/pacientes/datos/repositorio_pacientes.dart';
import 'package:oncuidar/caracteristicas/recordatorios/datos/repositorio_recordatorios.dart';
import 'package:oncuidar/caracteristicas/recordatorios/dominio/recordatorio.dart';
import 'package:oncuidar/nucleo/notificaciones/servicio_notificaciones.dart';

/// Coordina el ciclo de vida del paciente con los avisos de sus recordatorios.
class CicloDeVidaPaciente {
  CicloDeVidaPaciente({
    required this.pacientes,
    required this.recordatorios,
    required this.notificaciones,
  });

  final RepositorioPacientes pacientes;
  final RepositorioRecordatorios recordatorios;
  final ServicioNotificaciones notificaciones;

  /// Archiva al paciente y apaga sus avisos locales.
  Future<void> archivar(String idPaciente) async {
    await pacientes.archivarPaciente(idPaciente);
    await recordatorios.cancelarNotificacionesPaciente(
      idPaciente,
      notificaciones,
    );
  }

  /// Restaura al paciente y vuelve a programar los avisos.
  Future<void> desarchivar(String idPaciente) async {
    await pacientes.desarchivarPaciente(idPaciente);
    await reagendarNotificaciones();
  }

  /// Elimina al paciente y sus datos.
  Future<void> eliminar(String idPaciente) async {
    // Los avisos se cancelan antes de borrar: después ya no hay cómo listarlos.
    await recordatorios.cancelarNotificacionesPaciente(
      idPaciente,
      notificaciones,
    );
    await pacientes.eliminarPaciente(idPaciente);
  }

  /// Vuelve a programar las notificaciones locales de todos los recordatorios
  /// activos y pendientes de todos los pacientes. Se invoca al iniciar sesión
  /// (HU-18): las notificaciones programadas se pierden al cerrar sesión en el
  /// mismo dispositivo. Cualquier fallo puntual se ignora; nunca lanza.
  Future<void> reagendarNotificaciones() async {
    try {
      if (!pacientes.bd.tieneIdentidad()) return;
      await notificaciones.cancelarTodas();
      final activos = await pacientes.pacientesEnTiempoReal().first;
      final ahora = DateTime.now();
      for (final paciente in activos) {
        try {
          final delPaciente = await recordatorios
              .recordatoriosEnTiempoReal(paciente.id)
              .first;
          for (final r in delPaciente) {
            if (!r.activo) continue;
            // Sin clave (sin red) el título queda vacío: no hay aviso que programar.
            if (r.titulo.isEmpty) continue;
            // Una sola vez y ya vencido: reprogramarlo lo dispararía mañana.
            if (!r.esRecurrente && r.fechaHora.isBefore(ahora)) continue;
            await notificaciones.programar(
              id: ServicioNotificaciones.idSeguro(r.id),
              titulo: r.tituloAviso(
                paciente.nombreCompleto,
                etiquetaTipoRecordatorio(r.tipo),
              ),
              cuerpo: r.cuerpoAviso,
              fechaHora: r.fechaHora,
              diasRepeticion: r.diasRepeticion,
              mensual: r.esMensual,
            );
          }
        } catch (_) {
          // Un paciente con datos rotos no debe bloquear al resto.
        }
      }
    } catch (_) {
      // El reagendado nunca debe interferir con el flujo de inicio de sesión.
    }
  }
}

/// Reprograma los avisos locales sin bloquear la UI ni fallar sin red o permiso.
void reagendarAvisosEnSegundoPlano(CicloDeVidaPaciente cicloDeVida) {
  unawaited(
    cicloDeVida
        .reagendarNotificaciones()
        .timeout(const Duration(seconds: 20), onTimeout: () {})
        .catchError((_) {}),
  );
}
