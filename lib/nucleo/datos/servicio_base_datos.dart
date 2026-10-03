import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/recordatorios/datos/repositorio_recordatorios.dart';
import 'package:oncuidar/caracteristicas/recordatorios/dominio/recordatorio.dart';
import 'package:oncuidar/nucleo/cifrado/servicio_cifrado.dart';
import 'package:oncuidar/nucleo/conectividad/servicio_conectividad.dart';
import 'package:oncuidar/nucleo/datos/base_datos_segura.dart';
import 'package:oncuidar/nucleo/notificaciones/servicio_notificaciones.dart';
import 'package:oncuidar/nucleo/sincronizacion/cola_escrituras.dart';

class ServicioBaseDatos {
  ServicioBaseDatos({
    FirebaseFirestore? base,
    FirebaseAuth? auth,
    String? uidPrueba,
    required ServicioCifrado cifrado,
    ColaEscrituras? cola,
    ServicioConectividad? conectividad,
  }) : bd = BaseDatosSegura(
         base: base,
         auth: auth,
         uidPrueba: uidPrueba,
         cifrado: cifrado,
         cola: cola,
         conectividad: conectividad,
       );

  /// Usa una base ya creada (la del proveedor de infraestructura).
  ServicioBaseDatos.sobre(this.bd);

  final BaseDatosSegura bd;

  // Temporal hasta el caso de uso CicloDeVidaPaciente.
  RepositorioRecordatorios get _repositorioRecordatorios =>
      RepositorioRecordatorios(bd);

  Future<void> verificarEscrituraDisponible() =>
      bd.verificarEscrituraDisponible();

  Future<void> aplicarEscrituraPendiente(EscrituraPendiente escritura) =>
      bd.aplicarEscrituraPendiente(escritura);

  // ── Paciente ──
  Future<String> crearPaciente(Paciente paciente) async {
    final ref = bd.docUsuario.collection('patients').doc();
    final datos = await _cifrarPaciente(paciente);
    await bd.sinEsperarSinRed(() => ref.set(datos, SetOptions(merge: true)));
    return ref.id;
  }

  /// Actualiza un paciente cifrando solo los campos editables
  Future<void> actualizarPaciente(
    String idPaciente,
    Map<String, dynamic> datos,
  ) async {
    final plano = <String, dynamic>{};

    Future<void> campo({
      required String claveFormulario,
      required dynamic valor,
      required String clave,
    }) async {
      if (!datos.containsKey(claveFormulario)) return;
      final texto = valor?.toString();
      await bd.reemplazarPorCifrado(plano, plano: texto, cifrado: clave);
    }

    await campo(
      claveFormulario: 'fullName',
      valor: datos['fullName'],
      clave: 'nombre_cifrado',
    );
    await campo(
      claveFormulario: 'rut',
      valor: datos['rut'],
      clave: 'rut_cifrado',
    );
    await campo(
      claveFormulario: 'age',
      valor: datos['age'],
      clave: 'edad_cifrada',
    );
    await campo(
      claveFormulario: 'diagnosis',
      valor: datos['diagnosis'],
      clave: 'diagnostico_cifrado',
    );
    await campo(
      claveFormulario: 'tratamientoFase',
      valor: datos['tratamientoFase'],
      clave: 'fase_tratamiento_cifrado',
    );
    await campo(
      claveFormulario: 'centroSaludNombre',
      valor: datos['centroSaludNombre'],
      clave: 'centro_salud_nombre_cifrado',
    );
    await campo(
      claveFormulario: 'centroSaludDireccion',
      valor: datos['centroSaludDireccion'],
      clave: 'centro_salud_direccion_cifrado',
    );
    await campo(
      claveFormulario: 'centroSaludTelefono',
      valor: datos['centroSaludTelefono'],
      clave: 'centro_salud_telefono_cifrado',
    );
    await campo(
      claveFormulario: 'contactoEmergenciaNombre',
      valor: datos['contactoEmergenciaNombre'],
      clave: 'contacto_emergencia_nombre_cifrado',
    );
    await campo(
      claveFormulario: 'contactoEmergenciaTelefono',
      valor: datos['contactoEmergenciaTelefono'],
      clave: 'contacto_emergencia_telefono_cifrado',
    );
    // El tope diario de registros no es sensible: se guarda en claro.
    if (datos['maximo_registros_dia'] is int) {
      plano['maximo_registros_dia'] = datos['maximo_registros_dia'];
    }
    if (plano.isEmpty) return;
    await bd.docUsuario
        .collection('patients')
        .doc(idPaciente)
        .set(plano, SetOptions(merge: true));
  }

  /// Borrado LÓGICO del paciente: escribe archivado y apaga sus avisos locales.
  Future<void> archivarPaciente(
    String idPaciente, {
    ServicioNotificaciones? notif,
  }) async {
    await bd.sinEsperarSinRed(
      () => bd.docUsuario.collection('patients').doc(idPaciente).set({
        'archivado': true,
      }, SetOptions(merge: true)),
    );
    if (notif != null) {
      await _repositorioRecordatorios.cancelarNotificacionesPaciente(
        idPaciente,
        notif,
      );
    }
  }

  /// Restaura un paciente archivado y vuelve a programar sus avisos.
  Future<void> desarchivarPaciente(
    String idPaciente, {
    ServicioNotificaciones? notif,
  }) async {
    await bd.sinEsperarSinRed(
      () => bd.docUsuario.collection('patients').doc(idPaciente).set({
        'archivado': false,
      }, SetOptions(merge: true)),
    );
    if (notif != null) await reagendarNotificaciones(notif);
  }

  /// Borrado FÍSICO (irreversible) del paciente y de todos sus datos.
  Future<void> eliminarPaciente(
    String idPaciente, {
    ServicioNotificaciones? notif,
  }) async {
    // Los avisos se cancelan antes de borrar: después ya no hay cómo listarlos.
    if (notif != null) {
      await _repositorioRecordatorios.cancelarNotificacionesPaciente(
        idPaciente,
        notif,
      );
    }
    // Lo encolado del paciente se purga primero: si no, el drenaje recrearía documentos borrados.
    final cola = bd.cola;
    if (cola != null) await cola.quitarDePaciente(bd.uid, idPaciente);
    final docPaciente = bd.docUsuario.collection('patients').doc(idPaciente);
    for (final sub in subcoleccionesPaciente) {
      await bd.borrarColeccionEnLotes(docPaciente.collection(sub));
    }
    await bd.confirmarBorrado(docPaciente.delete());
  }

  /// Subcolecciones que cuelgan de un paciente y se borran con él.
  static const subcoleccionesPaciente = ['clinicalRecords', 'recordatorios'];

  /// Stream en tiempo real de los pacientes archivados (`archivado == true`).
  Stream<List<Paciente>> pacientesArchivadosEnTiempoReal() {
    return bd.docUsuario
        .collection('patients')
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs
                .where((d) => d.data()['archivado'] == true)
                .map((d) => _descifrarPaciente(d.id, d.data())),
          ),
        );
  }

  Stream<List<Paciente>> pacientesEnTiempoReal() {
    return bd.docUsuario
        .collection('patients')
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs
                .where((d) => d.data()['archivado'] != true)
                .map((d) => _descifrarPaciente(d.id, d.data())),
          ),
        );
  }

  // ── Reagendado tras iniciar sesión ──

  /// Vuelve a programar las notificaciones locales de todos los recordatorios
  /// activos y pendientes de todos los pacientes. Se invoca al iniciar sesión
  /// (HU-18): las notificaciones programadas se pierden al cerrar sesión en el
  /// mismo dispositivo. Cualquier fallo puntual se ignora; nunca lanza.
  Future<void> reagendarNotificaciones(ServicioNotificaciones notif) async {
    try {
      if (!bd.tieneIdentidad()) return;
      await notif.cancelarTodas();
      final pacientes = await pacientesEnTiempoReal().first;
      final ahora = DateTime.now();
      for (final paciente in pacientes) {
        try {
          final recordatorios = await _repositorioRecordatorios
              .recordatoriosEnTiempoReal(paciente.id)
              .first;
          for (final r in recordatorios) {
            if (!r.activo) continue;
            // Sin clave (sin red) el título queda vacío: no hay aviso que programar.
            if (r.titulo.isEmpty) continue;
            // Una sola vez y ya vencido: reprogramarlo lo dispararía mañana.
            if (!r.esRecurrente && r.fechaHora.isBefore(ahora)) continue;
            await notif.programar(
              id: ServicioNotificaciones.idSeguro(r.id),
              titulo: r.tituloAviso(
                paciente.fullName,
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

  // ── Mapeo de campos sensibles ──
  Future<Map<String, dynamic>> _cifrarPaciente(Paciente p) async {
    final data = <String, dynamic>{
      'notificaciones_activas': true,
      'maximo_registros_dia': 3,
      'creadoEn': FieldValue.serverTimestamp(),
    };
    await bd.reemplazarPorCifrado(
      data,
      plano: p.fullName,
      cifrado: 'nombre_cifrado',
    );
    await bd.reemplazarPorCifrado(data, plano: p.rut, cifrado: 'rut_cifrado');
    await bd.reemplazarPorCifrado(
      data,
      plano: p.age?.toString(),
      cifrado: 'edad_cifrada',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.diagnosis,
      cifrado: 'diagnostico_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.tratamientoFase,
      cifrado: 'fase_tratamiento_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.centroSaludNombre,
      cifrado: 'centro_salud_nombre_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.centroSaludDireccion,
      cifrado: 'centro_salud_direccion_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.centroSaludTelefono,
      cifrado: 'centro_salud_telefono_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.contactoEmergenciaNombre,
      cifrado: 'contacto_emergencia_nombre_cifrado',
    );
    await bd.reemplazarPorCifrado(
      data,
      plano: p.contactoEmergenciaTelefono,
      cifrado: 'contacto_emergencia_telefono_cifrado',
    );
    data['version_encriptacion'] = 2;
    return data;
  }

  Future<Paciente> _descifrarPaciente(
    String id,
    Map<String, dynamic> datos,
  ) async {
    final nombre = await bd.descifrarCampo(datos, 'nombre_cifrado');
    final edad = await bd.descifrarCampo(datos, 'edad_cifrada');
    return Paciente(
      id: id,
      fullName: nombre ?? '',
      rut: await bd.descifrarCampo(datos, 'rut_cifrado'),
      age: int.tryParse(edad ?? ''),
      diagnosis: await bd.descifrarCampo(datos, 'diagnostico_cifrado'),
      tratamientoFase: await bd.descifrarCampo(
        datos,
        'fase_tratamiento_cifrado',
      ),
      centroSaludNombre: await bd.descifrarCampo(
        datos,
        'centro_salud_nombre_cifrado',
      ),
      centroSaludDireccion: await bd.descifrarCampo(
        datos,
        'centro_salud_direccion_cifrado',
      ),
      centroSaludTelefono: await bd.descifrarCampo(
        datos,
        'centro_salud_telefono_cifrado',
      ),
      contactoEmergenciaNombre: await bd.descifrarCampo(
        datos,
        'contacto_emergencia_nombre_cifrado',
      ),
      contactoEmergenciaTelefono: await bd.descifrarCampo(
        datos,
        'contacto_emergencia_telefono_cifrado',
      ),
      createdAt: (datos['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maximoRegistrosDia: (datos['maximo_registros_dia'] as num?)?.toInt() ?? 3,
    );
  }
}
