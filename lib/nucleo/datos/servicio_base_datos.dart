import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/material_educativo.dart';
import 'package:oncuidar/caracteristicas/chat/dominio/conversacion.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/recordatorios/dominio/recordatorio.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
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

  // ── Cuidador ──
  /// Guarda al cuidador cifrando los datos personales.
  Future<void> crearCuidador(Map<String, dynamic> datos) async {
    final plano = <String, dynamic>{};
    // Solo el servidor (registerRecoveryEmail) escribe correo_respaldo_hash.
    if (datos['email'] != null) plano['email'] = datos['email'];
    final correoRespaldo = datos['correo_respaldo'] as String?;
    if (correoRespaldo != null && correoRespaldo.isNotEmpty) {
      plano['correo_respaldo_cifrado'] = await bd.cifrado.cifrar(
        bd.uid,
        correoRespaldo.trim().toLowerCase(),
      );
    }
    if (datos['createdAt'] != null) plano['createdAt'] = datos['createdAt'];
    await bd.reemplazarPorCifrado(
      plano,
      plano: datos['displayName'] as String?,
      cifrado: 'nombre_cifrado',
    );
    await bd.reemplazarPorCifrado(
      plano,
      plano: datos['phone'] as String?,
      cifrado: 'telefono_cifrado',
    );
    await bd.reemplazarPorCifrado(
      plano,
      plano: datos['relationship'] as String?,
      cifrado: 'relacion_cifrada',
    );
    await bd.reemplazarPorCifrado(
      plano,
      plano: datos['address'] as String?,
      cifrado: 'direccion_cifrada',
    );
    plano['version_encriptacion'] = 2;
    await bd.docUsuario.set(plano, SetOptions(merge: true));
  }

  /// Rollback tras un registro fallido: borra el doc del usuario (la cuenta de
  /// Auth ya se eliminó en ServicioRegistro). Best-effort; si el doc no existe
  /// o la red falla, se ignora para no enmascarar el error original.
  Future<void> limpiarRegistro(String uid) async {
    try {
      await bd.firestore.collection('users').doc(uid).delete();
    } catch (_) {}
  }

  /// Devuelve los datos visibles del cuidador con sus campos personales ya
  /// descifrados. El correo se devuelve en texto plano por ser el
  /// identificador de acceso.
  ///
  /// `correoRespaldo` es el correo de respaldo descifrado (solo existe si se
  /// registró vía la app; los usuarios legacy que solo tienen `correo_respaldo_hash`
  /// devolverán null porque un hash no se puede invertir).
  /// `pendienteCorreo` expone el estado "verificación pendiente" de un cambio
  /// de correo (principal o respaldo), o null si no hay ningún cambio pendiente.
  Future<Map<String, dynamic>> obtenerCuidador() async {
    final doc = await bd.docUsuario.get();
    return _mapearCuidador((doc.data() as Map<String, dynamic>?) ?? {});
  }

  Stream<Map<String, dynamic>?> cuidadorEnTiempoReal() {
    if (!bd.tieneIdentidad()) return Stream.value(null);
    return bd.docUsuario.snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      try {
        return await _mapearCuidador(
          (doc.data() as Map<String, dynamic>?) ?? {},
        );
      } catch (_) {
        return null;
      }
    });
  }

  Future<Map<String, dynamic>> _mapearCuidador(
    Map<String, dynamic> datos,
  ) async {
    final correoPendiente = datos['pendiente_correo'] as String?;
    return {
      'email': datos['email'] as String?,
      'nombre': await bd.descifrarCampo(datos, 'nombre_cifrado'),
      'telefono': await bd.descifrarCampo(datos, 'telefono_cifrado'),
      'relacion': await bd.descifrarCampo(datos, 'relacion_cifrada'),
      'direccion': await bd.descifrarCampo(datos, 'direccion_cifrada'),
      'correoRespaldo': await bd.descifrarCampo(
        datos,
        'correo_respaldo_cifrado',
      ),
      'respaldoPendienteServidor': datos['respaldo_pendiente_servidor'] == true,
      'pendienteCorreo': (correoPendiente == null || correoPendiente.isEmpty)
          ? null
          : {
              'correo': correoPendiente,
              'tipo':
                  (datos['pendiente_correo_tipo'] as String?) ?? 'principal',
            },
    };
  }

  /// Actualiza los datos personales del cuidador cifrando solo los campos
  /// no nulos. Un campo vacío (teléfono/parentesco) se borra; el nombre se
  /// trata igual que el resto para mantener el contrato simple.
  Future<void> actualizarCuidador({
    String? nombre,
    String? telefono,
    String? relacion,
    String? direccion,
  }) async {
    final plano = <String, dynamic>{};
    if (nombre != null) {
      await bd.reemplazarPorCifrado(
        plano,
        plano: nombre,
        cifrado: 'nombre_cifrado',
      );
    }
    if (telefono != null) {
      await bd.reemplazarPorCifrado(
        plano,
        plano: telefono,
        cifrado: 'telefono_cifrado',
      );
    }
    if (relacion != null) {
      await bd.reemplazarPorCifrado(
        plano,
        plano: relacion,
        cifrado: 'relacion_cifrada',
      );
    }
    if (direccion != null) {
      await bd.reemplazarPorCifrado(
        plano,
        plano: direccion,
        cifrado: 'direccion_cifrada',
      );
    }
    if (plano.isEmpty) return;
    await bd.sinEsperarSinRed(
      () => bd.docUsuario.set(plano, SetOptions(merge: true)),
    );
  }

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

  // ── Registro clínico ──

  CollectionReference _registrosClinicos(String idPaciente) => bd.docUsuario
      .collection('patients')
      .doc(idPaciente)
      .collection('clinicalRecords');

  /// Guarda un registro clínico cifrando los campos sensibles.
  Future<void> guardarRegistroClinico(
    String idPaciente,
    RegistroClinico registro,
  ) async {
    if (registro.pacienteId != idPaciente) {
      throw ArgumentError(
        'El registro pertenece a "${registro.pacienteId}", no a "$idPaciente"',
      );
    }
    await verificarEscrituraDisponible();
    final signos = registro.signosVitales;
    final datos = <String, dynamic>{
      'id': registro.id,
      'paciente_id': registro.pacienteId,
      'fecha': registro.fecha,
      'creadoEn': registro.creadoEn,
      'tipoRegistro': registro.tipoRegistro,
      'nivelAlerta': registro.nivelAlerta.name,
      if (signos != null)
        'signos_vitales_cifrado': await bd.cifrado.cifrar(
          bd.uid,
          jsonEncode({
            'temperature': signos.temperature,
            'heartRate': signos.heartRate,
            'oxygenSaturation': signos.oxygenSaturation,
            'respiratoryRate': signos.respiratoryRate,
          }),
        )
      else
        'signos_vitales_cifrado': FieldValue.delete(),
      'sintomas_cifrado': await bd.cifrado.cifrar(
        bd.uid,
        jsonEncode([
          for (final sintoma in registro.sintomas)
            {
              'name': sintoma.name,
              'intensity': sintoma.intensity,
              if (sintoma.notes != null && sintoma.notes!.isNotEmpty)
                'notes': sintoma.notes,
            },
        ]),
      ),
    };
    await bd.reemplazarPorCifrado(
      datos,
      plano: registro.observaciones,
      cifrado: 'contenido_registro_cifrado',
    );
    await bd.reemplazarPorCifrado(
      datos,
      plano: registro.mensajeAlerta,
      cifrado: 'mensaje_alerta_cifrado',
    );
    datos['version_encriptacion'] = 3;
    await bd.escribir(
      _registrosClinicos(idPaciente).doc(registro.id),
      datos,
      operacion: OperacionPendiente.guardar,
      idPaciente: idPaciente,
    );
  }

  /// Elimina un registro clínico del paciente.
  Future<void> eliminarRegistroClinico(
    String idPaciente,
    String idRegistro,
  ) async {
    await bd.borrar(_registrosClinicos(idPaciente).doc(idRegistro), idPaciente);
  }

  Stream<List<RegistroClinico>> registrosClinicosEnTiempoReal(
    String idPaciente,
  ) {
    if (!bd.tieneIdentidad()) return Stream.value(const []);
    return _registrosClinicos(idPaciente)
        .orderBy('creadoEn', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs.map(
              (d) => _descifrarRegistroClinico(
                d.id,
                d.data() as Map<String, dynamic>,
              ),
            ),
          ),
        );
  }

  Future<List<RegistroClinico>> cargarMasRegistrosClinicos(
    String idPaciente,
    DateTime ultimoCreadoEn,
  ) async {
    if (!bd.tieneIdentidad()) return const [];
    final snap = await _registrosClinicos(idPaciente)
        .orderBy('creadoEn', descending: true)
        .startAfter([Timestamp.fromDate(ultimoCreadoEn)])
        .limit(50)
        .get();
    final lista = <RegistroClinico>[];
    for (final doc in snap.docs) {
      lista.add(
        await _descifrarRegistroClinico(
          doc.id,
          doc.data() as Map<String, dynamic>,
        ),
      );
    }
    return lista;
  }

  /// Todos los registros del paciente con `fecha` en [desde, hasta), en orden ascendente.
  Future<List<RegistroClinico>> registrosClinicosEnRango(
    String idPaciente, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    if (!bd.tieneIdentidad()) return const [];
    Query consulta = _registrosClinicos(idPaciente);
    if (desde != null) {
      consulta = consulta.where(
        'fecha',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde),
      );
    }
    if (hasta != null) {
      consulta = consulta.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    }
    final snap = await consulta.orderBy('fecha').get();
    final lista = <RegistroClinico>[];
    for (final doc in snap.docs) {
      final registro = await _descifrarRegistroClinico(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      // Defensa extra: descarta cualquier documento declarado de otro paciente.
      if (registro.pacienteId.isEmpty || registro.pacienteId == idPaciente) {
        lista.add(registro);
      }
    }
    return lista;
  }

  // ── Biblioteca educativa ──

  CollectionReference _contenidoEducativo() =>
      bd.firestore.collection('educationalContent');

  Stream<List<MaterialEducativo>> contenidoEducativoEnTiempoReal() {
    return _contenidoEducativo().snapshots().map(
      (snap) => [
        for (final doc in snap.docs)
          MaterialEducativo.fromMap(doc.id, doc.data() as Map<String, dynamic>),
      ],
    );
  }

  Future<MaterialEducativo?> obtenerContenidoEducativo(String id) async {
    final doc = await _contenidoEducativo().doc(id).get();
    if (!doc.exists) return null;
    return MaterialEducativo.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>,
    );
  }

  Stream<List<String>> idsFavoritosEnTiempoReal() {
    if (!bd.tieneIdentidad()) return Stream.value(const []);
    return bd.docUsuario.snapshots().map((snap) {
      final datos = snap.data() as Map<String, dynamic>?;
      return List<String>.from(datos?['favoriteArticleIds'] ?? const []);
    });
  }

  Future<void> alternarFavorito(String materialId) async {
    var favoritos = <String>[];
    try {
      final doc = await bd.docUsuario.get(
        const GetOptions(source: Source.cache),
      );
      final datos = doc.data() as Map<String, dynamic>?;
      favoritos = List<String>.from(datos?['favoriteArticleIds'] ?? const []);
    } catch (_) {
      try {
        final doc = await bd.docUsuario.get();
        final datos = doc.data() as Map<String, dynamic>?;
        favoritos = List<String>.from(datos?['favoriteArticleIds'] ?? const []);
      } catch (_) {
        favoritos = const [];
      }
    }
    if (favoritos.contains(materialId)) {
      favoritos.remove(materialId);
    } else {
      favoritos.add(materialId);
    }
    await bd.sinEsperarSinRed(
      () => bd.docUsuario.set({
        'favoriteArticleIds': favoritos,
      }, SetOptions(merge: true)),
    );
  }

  // ── Conversaciones ──

  CollectionReference _conversaciones() =>
      bd.docUsuario.collection('conversations');

  /// Stream en tiempo real de las conversaciones del chat del cuidador,
  /// ordenadas por última actividad y descifrando título y mensajes.
  Stream<List<Conversacion>> conversacionesEnTiempoReal() {
    if (!bd.tieneIdentidad()) return Stream.value(const []);
    return _conversaciones()
        .orderBy('ultimaActividad', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs.map(
              (d) => _descifrarConversacion(
                d.id,
                d.data() as Map<String, dynamic>,
              ),
            ),
          ),
        );
  }

  /// Crea una conversación con título y mensajes cifrados y devuelve su id.
  Future<String> crearConversacion({
    required String titulo,
    required List<MensajeConversacion> mensajes,
  }) async {
    final datos = <String, dynamic>{
      'mensajes_cifrado': await bd.cifrado.cifrar(
        bd.uid,
        jsonEncode([for (final mensaje in mensajes) mensaje.aMapa()]),
      ),
      'ultimaActividad': DateTime.now(),
      'creadoEn': DateTime.now(),
      'version_encriptacion': 3,
    };
    await bd.reemplazarPorCifrado(
      datos,
      plano: titulo,
      cifrado: 'titulo_cifrado',
    );
    final ref = _conversaciones().doc();
    await bd.sinEsperarSinRed(() => ref.set(datos));
    return ref.id;
  }

  /// Actualiza los mensajes (y el título si se indica) de una conversación.
  Future<void> actualizarConversacion(
    String id, {
    String? titulo,
    required List<MensajeConversacion> mensajes,
  }) async {
    final datos = <String, dynamic>{
      'mensajes_cifrado': await bd.cifrado.cifrar(
        bd.uid,
        jsonEncode([for (final mensaje in mensajes) mensaje.aMapa()]),
      ),
      'ultimaActividad': DateTime.now(),
    };
    if (titulo != null) {
      await bd.reemplazarPorCifrado(
        datos,
        plano: titulo,
        cifrado: 'titulo_cifrado',
      );
    }
    await bd.sinEsperarSinRed(
      () => _conversaciones().doc(id).set(datos, SetOptions(merge: true)),
    );
  }

  /// Renombra una conversación sin tocar sus mensajes.
  Future<void> renombrarConversacion(String id, String titulo) async {
    final datos = <String, dynamic>{};
    await bd.reemplazarPorCifrado(
      datos,
      plano: titulo,
      cifrado: 'titulo_cifrado',
    );
    await bd.sinEsperarSinRed(
      () => _conversaciones().doc(id).set(datos, SetOptions(merge: true)),
    );
  }

  /// Elimina definitivamente una conversación.
  Future<void> eliminarConversacion(String id) async {
    await bd.sinEsperarSinRed(() => _conversaciones().doc(id).delete());
  }

  Future<Conversacion> _descifrarConversacion(
    String id,
    Map<String, dynamic> datos,
  ) async {
    return Conversacion(
      id: id,
      titulo: (await bd.descifrarCampo(datos, 'titulo_cifrado')) ?? '',
      ultimaActividad: bd.fechaTolerante(datos['ultimaActividad']),
      creadoEn: bd.fechaTolerante(datos['creadoEn']),
      mensajes: await _descifrarMensajesConversacion(datos),
    );
  }

  Future<List<MensajeConversacion>> _descifrarMensajesConversacion(
    Map<String, dynamic> datos,
  ) async {
    final cifrado = datos['mensajes_cifrado'] as String?;
    if (cifrado != null && cifrado.isNotEmpty) {
      try {
        final texto = await bd.cifrado.descifrar(bd.uid, cifrado);
        final lista = jsonDecode(texto) as List<dynamic>;
        return [
          for (final item in lista.cast<Map<String, dynamic>>())
            MensajeConversacion.desdeMapa(item),
        ];
      } catch (e, pila) {
        debugPrint('No se pudo descifrar mensajes_cifrado: $e\n$pila');
      }
    }
    final mensajesRaw = datos['mensajes'];
    if (mensajesRaw is List) {
      return [
        for (final item in mensajesRaw.cast<Map<String, dynamic>>())
          MensajeConversacion.desdeMapa(item),
      ];
    }
    return const [];
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

  // ── Cambio de correo ──
  Future<void> _reautenticar(String contrasena) async {
    final usuario = _usuarioAutenticado;
    final email = usuario.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final credencial = EmailAuthProvider.credential(
      email: email,
      password: contrasena,
    );
    await usuario
        .reauthenticateWithCredential(credencial)
        .timeout(const Duration(seconds: 5));
  }

  User get _usuarioAutenticado {
    final auth = bd.auth ?? FirebaseAuth.instance;
    final usuario = auth.currentUser;
    if (usuario == null) throw StateError('No user authenticated');
    return usuario;
  }

  Future<void> cambiarCorreoPrincipal({
    required String contrasena,
    required String nuevoCorreo,
  }) async {
    await _reautenticar(contrasena);
    final normalizado = nuevoCorreo.trim().toLowerCase();
    await _usuarioAutenticado
        .verifyBeforeUpdateEmail(normalizado)
        .timeout(const Duration(seconds: 5));
    await bd.docUsuario.set({
      'pendiente_correo': normalizado,
      'pendiente_correo_tipo': 'principal',
      'pendiente_correo_solicitado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> cambiarCorreoRespaldo({
    required String contrasena,
    required String nuevoCorreo,
  }) async {
    await _reautenticar(contrasena);
    final normalizado = nuevoCorreo.trim().toLowerCase();
    // La marca queda hasta que el servidor registre el correo; así se reintenta al volver al perfil.
    await bd.docUsuario.set({
      'correo_respaldo_cifrado': await bd.cifrado.cifrar(bd.uid, normalizado),
      'respaldo_pendiente_servidor': true,
    }, SetOptions(merge: true));
    return _registrarRespaldoEnServidor(normalizado);
  }

  /// Registra el hash del respaldo vía Cloud Function; reemplazable en pruebas.
  @visibleForTesting
  Future<void> Function(String correo) registrarCorreoRespaldoServidor =
      (correo) => FirebaseFunctions.instanceFor(region: 'southamerica-west1')
          .httpsCallable('registerRecoveryEmail')
          .call({'email': correo})
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Sin conexión',
            ),
          );

  /// Devuelve true si el servidor confirmó; si falla deja la marca pendiente.
  Future<bool> _registrarRespaldoEnServidor(String correo) async {
    try {
      await registrarCorreoRespaldoServidor(correo);
    } catch (e) {
      debugPrint('Registro del correo de respaldo pendiente: $e');
      return false;
    }
    await bd.docUsuario.set({
      'respaldo_pendiente_servidor': FieldValue.delete(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Reintenta registrar en el servidor un respaldo que quedó pendiente; true si ya no queda pendiente.
  Future<bool> reintentarRegistroRespaldo() async {
    final datos =
        ((await bd.docUsuario.get()).data() as Map<String, dynamic>?) ?? {};
    if (datos['respaldo_pendiente_servidor'] != true) return true;
    final correo = await bd.descifrarCampo(datos, 'correo_respaldo_cifrado');
    if (correo == null || correo.isEmpty) return false;
    return _registrarRespaldoEnServidor(correo);
  }

  Future<void> limpiarCambioCorreoPendiente() async {
    await bd.docUsuario.set({
      'pendiente_correo': FieldValue.delete(),
      'pendiente_correo_tipo': FieldValue.delete(),
      'pendiente_correo_solicitado_en': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> sincronizarCorreoPrincipal(String email) async {
    await bd.docUsuario.set({
      'email': email.trim().toLowerCase(),
    }, SetOptions(merge: true));
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

  Future<SignosVitales?> _descifrarSignosVitales(
    Map<String, dynamic> datos,
  ) async {
    final cifrado = datos['signos_vitales_cifrado'] as String?;
    if (cifrado != null && cifrado.isNotEmpty) {
      try {
        final texto = await bd.cifrado.descifrar(bd.uid, cifrado);
        final mapa = jsonDecode(texto) as Map<String, dynamic>;
        return SignosVitales(
          temperature: (mapa['temperature'] as num?)?.toDouble(),
          heartRate: (mapa['heartRate'] as num?)?.toInt(),
          oxygenSaturation: (mapa['oxygenSaturation'] as num?)?.toInt(),
          respiratoryRate: (mapa['respiratoryRate'] as num?)?.toInt(),
        );
      } catch (e, pila) {
        debugPrint('No se pudo descifrar signos_vitales_cifrado: $e\n$pila');
      }
    }
    final signosMapa = datos['signosVitales'];
    if (signosMapa is Map<String, dynamic>) {
      return SignosVitales(
        temperature: (signosMapa['temperature'] as num?)?.toDouble(),
        heartRate: signosMapa['heartRate'] as int?,
        oxygenSaturation: signosMapa['oxygenSaturation'] as int?,
        respiratoryRate: signosMapa['respiratoryRate'] as int?,
      );
    }
    return null;
  }

  Future<List<EntradaSintoma>> _descifrarSintomas(
    Map<String, dynamic> datos,
  ) async {
    final cifrado = datos['sintomas_cifrado'] as String?;
    if (cifrado != null && cifrado.isNotEmpty) {
      try {
        final texto = await bd.cifrado.descifrar(bd.uid, cifrado);
        final lista = jsonDecode(texto) as List<dynamic>;
        return [
          for (final item in lista)
            EntradaSintoma(
              name: (item['name'] as String?) ?? '',
              intensity: (item['intensity'] as num?)?.toInt() ?? 0,
              notes: item['notes'] as String?,
            ),
        ];
      } catch (e, pila) {
        debugPrint('No se pudo descifrar sintomas_cifrado: $e\n$pila');
      }
    }
    final sintomasRaw = datos['sintomas'];
    if (sintomasRaw is List) {
      final sintomas = <EntradaSintoma>[];
      for (final item in sintomasRaw.cast<Map<String, dynamic>>()) {
        final notesCifradas = item['notes_cifrado'] as String?;
        final notas = (notesCifradas != null && notesCifradas.isNotEmpty)
            ? await bd.descifrarCampo(item, 'notes_cifrado')
            : item['notes'] as String?;
        sintomas.add(
          EntradaSintoma(
            name: (item['name'] as String?) ?? '',
            intensity: (item['intensity'] as num?)?.toInt() ?? 0,
            notes: notas,
          ),
        );
      }
      return sintomas;
    }
    return const [];
  }

  Future<RegistroClinico> _descifrarRegistroClinico(
    String id,
    Map<String, dynamic> datos,
  ) async {
    final signos = await _descifrarSignosVitales(datos);
    final sintomas = await _descifrarSintomas(datos);

    final contenidoCifrado = datos['contenido_registro_cifrado'] as String?;
    final observaciones =
        (contenidoCifrado != null && contenidoCifrado.isNotEmpty)
        ? await bd.descifrarCampo(datos, 'contenido_registro_cifrado')
        : datos['observaciones'] as String?;

    final nivelRaw = datos['nivelAlerta'] as String?;
    final nivel = NivelAlerta.values.firstWhere(
      (v) => v.name == nivelRaw,
      orElse: () => NivelAlerta.normal,
    );

    return RegistroClinico(
      id: id,
      pacienteId: (datos['paciente_id'] as String?) ?? '',
      fecha: bd.fechaTolerante(datos['fecha']),
      creadoEn: bd.fechaTolerante(datos['creadoEn']),
      tipoRegistro: (datos['tipoRegistro'] as String?) ?? 'programado',
      signosVitales: signos,
      sintomas: sintomas,
      observaciones: observaciones,
      nivelAlerta: nivel,
      mensajeAlerta: await bd.descifrarCampo(datos, 'mensaje_alerta_cifrado'),
    );
  }
}
