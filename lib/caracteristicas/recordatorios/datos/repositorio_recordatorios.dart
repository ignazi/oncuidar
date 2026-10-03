import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oncuidar/caracteristicas/recordatorios/dominio/recordatorio.dart';
import 'package:oncuidar/nucleo/datos/base_datos_segura.dart';
import 'package:oncuidar/nucleo/notificaciones/servicio_notificaciones.dart';
import 'package:oncuidar/nucleo/sincronizacion/cola_escrituras.dart';

/// Recordatorios del paciente, con título, descripción y horario cifrados.
class RepositorioRecordatorios {
  RepositorioRecordatorios(this.bd);

  final BaseDatosSegura bd;

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
    await bd.verificarEscrituraDisponible();
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
    if (cifraAlgo) await bd.verificarEscrituraDisponible();
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
}
