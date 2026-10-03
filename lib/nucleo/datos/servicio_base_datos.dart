import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
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
    if (notif != null) await cancelarNotificacionesPaciente(idPaciente, notif);
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
    if (notif != null) await cancelarNotificacionesPaciente(idPaciente, notif);
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

  /// Cancela los avisos locales de todos los recordatorios de un paciente.
  Future<void> cancelarNotificacionesPaciente(
    String idPaciente,
    ServicioNotificaciones notif,
  ) async {
    try {
      final snap = await _recordatorios(idPaciente).get();
      for (final doc in snap.docs) {
        await notif.cancelar(ServicioNotificaciones.idSeguro(doc.id));
      }
    } catch (_) {
      // Sin datos locales ni red no hay nada que cancelar; nunca bloquea el archivado.
    }
  }

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

  // ── Recordatorios ──

  CollectionReference _recordatorios(String idPaciente) => bd.docUsuario
      .collection('patients')
      .doc(idPaciente)
      .collection('recordatorios');

  /// Stream en tiempo real de los recordatorios del paciente, descifrando
  /// título y descripción.
  Stream<List<Recordatorio>> recordatoriosEnTiempoReal(String idPaciente) {
    if (!bd.tieneIdentidad()) return Stream.value(const []);
    return _recordatorios(idPaciente)
        .orderBy('creadoEn', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs.map(
              (d) => _descifrarRecordatorio(
                d.id,
                d.data() as Map<String, dynamic>,
              ),
            ),
          ),
        );
  }

  /// Crea un recordatorio cifrando título, descripción y el payload
  /// programático (tipo, fechaHora, días y recurrencia). Solo
  /// quedan en claro identificadores y flags no sensibles (pacienteId,
  /// activo, creadoEn).
  Future<String> agregarRecordatorio(String idPaciente, Recordatorio r) async {
    if (r.pacienteId != idPaciente) {
      throw ArgumentError(
        'El recordatorio pertenece a "${r.pacienteId}", no a "$idPaciente"',
      );
    }
    await verificarEscrituraDisponible();
    final datos = <String, dynamic>{
      'pacienteId': r.pacienteId,
      'activo': r.activo,
      'creadoEn': r.creadoEn.toIso8601String(),
      'version_encriptacion': 3,
    };
    datos['datos_cifrados'] = await _cifrarPayloadRecordatorio(r);
    await bd.reemplazarPorCifrado(
      datos,
      plano: r.titulo,
      cifrado: 'titulo_cifrado',
    );
    if (r.descripcion != null && r.descripcion!.isNotEmpty) {
      await bd.reemplazarPorCifrado(
        datos,
        plano: r.descripcion,
        cifrado: 'descripcion_cifrada',
      );
    }
    final ref = _recordatorios(idPaciente).doc();
    await bd.escribir(
      ref,
      datos,
      operacion: OperacionPendiente.crear,
      idPaciente: idPaciente,
    );
    return ref.id;
  }

  /// Actualiza los campos indicados re-cifrando título/descripción cuando
  /// vienen. Una descripción vacía borra el campo. `recurrencia` vacía borra
  /// la recurrencia mensual.
  Future<void> actualizarRecordatorio(
    String idPaciente,
    String idRecordatorio, {
    String? tipo,
    String? titulo,
    String? descripcion,
    DateTime? fechaHora,
    List<String>? diasRepeticion,
    String? recurrencia,
    String? asignadoA,
    bool? activo,
  }) async {
    final cifraAlgo =
        titulo != null ||
        descripcion != null ||
        tipo != null ||
        fechaHora != null ||
        diasRepeticion != null ||
        recurrencia != null ||
        asignadoA != null;
    if (cifraAlgo) await verificarEscrituraDisponible();
    final datos = <String, dynamic>{};
    if (titulo != null) {
      await bd.reemplazarPorCifrado(
        datos,
        plano: titulo,
        cifrado: 'titulo_cifrado',
      );
    }
    if (descripcion != null) {
      if (descripcion.isEmpty) {
        datos['descripcion_cifrada'] = FieldValue.delete();
      } else {
        await bd.reemplazarPorCifrado(
          datos,
          plano: descripcion,
          cifrado: 'descripcion_cifrada',
        );
      }
    }
    final tocaPayload =
        tipo != null ||
        fechaHora != null ||
        diasRepeticion != null ||
        recurrencia != null ||
        asignadoA != null;
    if (tocaPayload) {
      final sensibles = await _datosSensiblesActuales(
        idPaciente,
        idRecordatorio,
      );
      if (tipo != null) sensibles['tipo'] = tipo;
      if (fechaHora != null) {
        sensibles['fechaHora'] = fechaHora.toIso8601String();
      }
      if (diasRepeticion != null) {
        sensibles['diasRepeticion'] = diasRepeticion;
      }
      if (recurrencia != null) {
        if (recurrencia.isEmpty) {
          sensibles.remove('recurrencia');
        } else {
          sensibles['recurrencia'] = recurrencia;
        }
      }
      if (asignadoA != null) sensibles['asignadoA'] = asignadoA;
      // Un recordatorio guardado con una versión antigua pudo traer esta marca: se descarta.
      sensibles.remove('completadoEn');
      datos['datos_cifrados'] = await bd.cifrado.cifrar(
        bd.uid,
        jsonEncode(sensibles),
      );
      // Migración: un doc antiguo aún tenía estos campos en claro; al tocar
      // el payload se descartan para dejar el blob como única fuente.
      datos['tipo'] = FieldValue.delete();
      datos['fechaHora'] = FieldValue.delete();
      datos['diasRepeticion'] = FieldValue.delete();
      datos['recurrencia'] = FieldValue.delete();
      datos['completadoEn'] = FieldValue.delete();
    }
    if (activo != null) datos['activo'] = activo;
    if (datos.isEmpty) return;
    // El binding viaja en cada escritura: firestore.rules lo exige también al actualizar.
    datos['pacienteId'] = idPaciente;
    await bd.escribir(
      _recordatorios(idPaciente).doc(idRecordatorio),
      datos,
      operacion: OperacionPendiente.fusionar,
      idPaciente: idPaciente,
    );
  }

  /// Elimina definitivamente un recordatorio.
  Future<void> eliminarRecordatorio(
    String idPaciente,
    String idRecordatorio,
  ) async {
    await bd.borrar(_recordatorios(idPaciente).doc(idRecordatorio), idPaciente);
  }

  Future<Recordatorio> _descifrarRecordatorio(
    String id,
    Map<String, dynamic> datos,
  ) async {
    final sensibles = await _datosSensiblesRecordatorio(datos);
    return Recordatorio(
      id: id,
      pacienteId: (datos['pacienteId'] as String?) ?? '',
      tipo: (sensibles['tipo'] as String?) ?? 'otro',
      titulo: (await bd.descifrarCampo(datos, 'titulo_cifrado')) ?? '',
      descripcion: await bd.descifrarCampo(datos, 'descripcion_cifrada'),
      fechaHora: bd.fechaTolerante(sensibles['fechaHora']),
      diasRepeticion:
          (sensibles['diasRepeticion'] as List<dynamic>?)
              ?.map((d) => d.toString())
              .toList() ??
          const [],
      activo: (datos['activo'] as bool?) ?? true,
      recurrencia: sensibles['recurrencia'] as String?,
      asignadoA:
          (sensibles['asignadoA'] as String?) ?? Recordatorio.asignadoAPaciente,
      creadoEn: bd.fechaTolerante(datos['creadoEn']),
    );
  }

  /// Cifra el payload programático del recordatorio (tipo, horario, recurrencia
  /// y asignación) en un único campo JSON cifrado.
  Future<String> _cifrarPayloadRecordatorio(Recordatorio r) {
    return bd.cifrado.cifrar(
      bd.uid,
      jsonEncode(<String, dynamic>{
        'tipo': r.tipo,
        'fechaHora': r.fechaHora.toIso8601String(),
        'diasRepeticion': r.diasRepeticion,
        if (r.recurrencia != null) 'recurrencia': r.recurrencia,
        'asignadoA': r.asignadoA,
      }),
    );
  }

  /// Lee el payload programático: primero el blob cifrado `datos_cifrados`;
  /// si el documento es anterior a su introducción, intenta los campos planos
  /// legacy (`tipo`, `fechaHora`, `diasRepeticion`, `recurrencia`).
  Future<Map<String, dynamic>> _datosSensiblesRecordatorio(
    Map<String, dynamic> datos, {
    bool estricto = false,
  }) async {
    final cifrado = datos['datos_cifrados'] as String?;
    if (cifrado != null && cifrado.isNotEmpty) {
      try {
        final texto = await bd.cifrado.descifrar(bd.uid, cifrado);
        return jsonDecode(texto) as Map<String, dynamic>;
      } catch (e, pila) {
        // Devolver un mapa vacío aquí borraría el payload al re-cifrarlo.
        if (estricto) rethrow;
        debugPrint('No se pudo descifrar datos_cifrados: $e\n$pila');
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{
      if (datos['tipo'] != null) 'tipo': datos['tipo'],
      if (datos['fechaHora'] != null) 'fechaHora': datos['fechaHora'],
      if (datos['diasRepeticion'] != null)
        'diasRepeticion': datos['diasRepeticion'],
      if (datos['recurrencia'] != null) 'recurrencia': datos['recurrencia'],
    };
  }

  Future<Map<String, dynamic>> _datosSensiblesActuales(
    String idPaciente,
    String idRecordatorio,
  ) async {
    // Sin red el documento puede existir solo en la cola: esa es la fuente de verdad.
    final local = await _payloadEncolado(idPaciente, idRecordatorio);
    if (local != null) return local;
    final snap = await _recordatorios(idPaciente).doc(idRecordatorio).get();
    final datos = snap.data();
    if (datos == null) return <String, dynamic>{};
    return _datosSensiblesRecordatorio(
      datos is Map<String, dynamic>
          ? datos
          : Map<String, dynamic>.from(datos as Map),
      estricto: true,
    );
  }

  /// Devuelve el payload cifrado más reciente de un recordatorio encolado, o null.
  Future<Map<String, dynamic>?> _payloadEncolado(
    String idPaciente,
    String idRecordatorio,
  ) async {
    final cola = bd.cola;
    if (cola == null) return null;
    final ruta = _recordatorios(idPaciente).doc(idRecordatorio).path;
    final pendientes = await cola.pendientes(bd.uid);
    final propias = <EscrituraPendiente>[
      for (final e in pendientes)
        if (e.ruta == ruta) e,
    ]..sort((a, b) => a.encoladoEn.compareTo(b.encoladoEn));
    for (final e in propias.reversed) {
      final cifrado = e.datos['datos_cifrados'];
      if (cifrado is! String || cifrado.isEmpty) continue;
      final texto = await bd.cifrado.descifrar(bd.uid, cifrado);
      return jsonDecode(texto) as Map<String, dynamic>;
    }
    return null;
  }

  // ── Reagendado tras iniciar sesión ──

  String _etiquetaTipoRecordatorio(String tipo) => switch (tipo) {
    'medicamento' => 'Medicamento',
    'medicion' => 'Medición',
    'cita' => 'Cita médica',
    _ => 'Recordatorio',
  };

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
          final recordatorios = await recordatoriosEnTiempoReal(
            paciente.id,
          ).first;
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
                _etiquetaTipoRecordatorio(r.tipo),
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
