// Prueba de humo contra la API real: dart run tool/humo_api.dart [urlBase]
import 'dart:io';

import 'package:oncuidar/nucleo/almacen/almacen_secreto.dart';
import 'package:oncuidar/nucleo/cifrado/servicio_cifrado.dart';
import 'package:oncuidar/nucleo/red/cliente_api.dart';
import 'package:oncuidar/nucleo/sesion/servicio_sesion.dart';
import 'package:uuid/uuid.dart';

var _fallos = 0;

void _ok(bool condicion, String paso) {
  stdout.writeln('${condicion ? 'OK   ' : 'FALLA'} $paso');
  if (!condicion) _fallos++;
}

Future<void> main(List<String> args) async {
  final urlBase = args.isNotEmpty ? args.first : 'http://localhost:8080/api';
  late final ServicioSesion sesion;
  final api = ClienteApi(urlBase: urlBase, obtenerToken: () => sesion.token);
  sesion = ServicioSesion(api: api, almacen: AlmacenSecretoMemoria());
  final cifrado = ServicioCifrado(api: api, almacen: AlmacenSecretoMemoria());
  final correo = '${const Uuid().v4().substring(0, 8)}@prueba.cl';
  const contrasena = 'clave1234';

  try {
    final salud = await api.get('/salud');
    _ok(salud is Map && salud['ok'] == true, 'GET /salud');

    // Registro, clave de datos y login
    final registro = await sesion.registrar(correo, contrasena);
    _ok(sesion.actual?.uid == registro.uid, 'registro $correo');
    final uid = registro.uid;
    await cifrado.asegurarClave(uid);
    _ok(cifrado.tieneClave(uid), 'POST /clave-datos');

    // Un segundo cliente comparte la API pero no el token del primero
    late final ServicioSesion sesion2;
    final api2 = ClienteApi(
      urlBase: urlBase,
      obtenerToken: () => sesion2.token,
    );
    sesion2 = ServicioSesion(api: api2, almacen: AlmacenSecretoMemoria());
    final login = await sesion2.iniciarSesion(correo, contrasena);
    _ok(login.uid == uid, 'login');
    try {
      await sesion2.iniciarSesion(correo, 'incorrecta1');
      _ok(false, 'login con clave errada debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(
        e.codigo == CodigoErrorSesion.credencialesInvalidas,
        'login errado -> credencialesInvalidas',
      );
    }
    try {
      await sesion2.registrar(correo, contrasena);
      _ok(false, 'registro duplicado debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(
        e.codigo == CodigoErrorSesion.correoEnUso,
        'duplicado -> correoEnUso',
      );
    }
    try {
      await sesion2.registrar('sin-arroba', contrasena);
      _ok(false, 'correo inválido debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(e.codigo == CodigoErrorSesion.correoInvalido, 'correo inválido');
    }
    try {
      await sesion2.registrar('otro_$correo', '123');
      _ok(false, 'contraseña corta debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(e.codigo == CodigoErrorSesion.contrasenaDebil, 'contraseña débil');
    }
    api2.cerrar();

    // Perfil del cuidador
    await api.put('/cuidador', {
      'versionEncriptacion': 2,
      'cifrados': {'nombre_cifrado': await cifrado.cifrar(uid, 'Ana')},
    });
    final cuidador = await api.get('/cuidador') as Map;
    final nombreCuidador = await cifrado.descifrar(
      uid,
      (cuidador['cifrados'] as Map)['nombre_cifrado'] as String,
    );
    _ok(nombreCuidador == 'Ana', 'PUT/GET /cuidador (cifrado ida y vuelta)');

    // Paciente
    final pid = const Uuid().v4();
    await api.put('/pacientes/$pid', {
      'notificacionesActivas': true,
      'maximoRegistrosDia': 3,
      'creadoEn': DateTime.now().toUtc().toIso8601String(),
      'versionEncriptacion': 2,
      'cifrados': {
        'nombre_cifrado': await cifrado.cifrar(uid, 'Paciente Uno'),
        'rut_cifrado': await cifrado.cifrar(uid, '1-9'),
      },
    });
    final pacientes = await api.get('/pacientes') as List;
    final mio = pacientes.cast<Map>().where((p) => p['id'] == pid).toList();
    _ok(mio.length == 1, 'GET /pacientes contiene el paciente');
    final nombre = await cifrado.descifrar(
      uid,
      (mio.first['cifrados'] as Map)['nombre_cifrado'] as String,
    );
    _ok(nombre == 'Paciente Uno', 'nombre del paciente descifrado');

    // Un null dentro de cifrados borra la clave
    await api.put('/pacientes/$pid', {
      'cifrados': {'rut_cifrado': null},
    });
    final sinRut = (await api.get('/pacientes') as List).cast<Map>().first;
    _ok(
      !(sinRut['cifrados'] as Map).containsKey('rut_cifrado'),
      'null en cifrados borra la clave',
    );

    // Un campo clínico en claro se rechaza
    try {
      await api.put('/pacientes/$pid', {'diagnostico': 'x'});
      _ok(false, 'campo en claro debe rechazarse');
    } on ExcepcionApi catch (e) {
      _ok(e.codigoHttp == 400 && e.esPermanente, 'campo en claro -> 400');
    }

    // Registro clínico
    final rid = const Uuid().v4();
    final ahora = DateTime.now().toUtc();
    await api.put('/pacientes/$pid/registros/$rid', {
      'pacienteId': pid,
      'fecha': ahora.toIso8601String(),
      'creadoEn': ahora.toIso8601String(),
      'tipoRegistro': 'programado',
      'nivelAlerta': 'normal',
      'versionEncriptacion': 3,
      'cifrados': {'sintomas_cifrado': await cifrado.cifrar(uid, '[]')},
    });
    final registros = await api.get('/pacientes/$pid/registros?limite=50');
    _ok(
      registros is List &&
          registros.length == 1 &&
          registros.first['id'] == rid,
      'PUT/GET registros',
    );

    // Recordatorio
    final recId = const Uuid().v4();
    await api.put('/pacientes/$pid/recordatorios/$recId', {
      'pacienteId': pid,
      'activo': true,
      'creadoEn': ahora.toIso8601String(),
      'versionEncriptacion': 3,
      'cifrados': {
        'titulo_cifrado': await cifrado.cifrar(uid, 'Tomar remedio'),
        'datos_cifrados': await cifrado.cifrar(uid, '{}'),
      },
    });
    final recordatorios = await api.get(
      '/pacientes/$pid/recordatorios?limite=100',
    );
    _ok(
      recordatorios is List && recordatorios.length == 1,
      'PUT/GET recordatorios',
    );

    // Conversación y favoritos
    final cid = const Uuid().v4();
    await api.put('/conversaciones/$cid', {
      'ultimaActividad': ahora.toIso8601String(),
      'creadoEn': ahora.toIso8601String(),
      'cifrados': {'titulo_cifrado': await cifrado.cifrar(uid, 'Hola')},
    });
    final convs = await api.get('/conversaciones?limite=50');
    _ok(convs is List && convs.length == 1, 'PUT/GET conversaciones');
    await api.put('/favoritos/mat-1', const {});
    final favs = await api.get('/favoritos') as Map;
    _ok((favs['ids'] as List).contains('mat-1'), 'PUT/GET favoritos');

    // Correos y recuperación
    await api.post('/correo-respaldo', {'correo': 'respaldo_$correo'});
    _ok(true, 'POST /correo-respaldo');
    await sesion.verificarContrasena(contrasena);
    _ok(true, 'POST /auth/verificar-contrasena');
    try {
      await sesion.verificarContrasena('otraotra');
      _ok(false, 'verificar contraseña errada debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(
        e.codigo == CodigoErrorSesion.credencialesInvalidas &&
            sesion.actual != null,
        'contraseña errada -> credencialesInvalidas sin cerrar sesión',
      );
    }
    final nuevoCorreo = 'nuevo_$correo';
    await sesion.cambiarCorreo(contrasena, nuevoCorreo);
    final perfil = await api.get('/cuidador') as Map;
    _ok(
      perfil['correo'] == correo &&
          perfil['pendienteCorreo'] == nuevoCorreo &&
          sesion.actual?.correo == correo,
      'cambiar correo principal queda pendiente y no cambia hasta confirmar',
    );
    _ok(
      perfil['respaldoPendiente'] == true &&
          perfil['correoRespaldoVerificado'] == false &&
          perfil['correoVerificado'] == false,
      'respaldo pendiente y correo sin verificar',
    );
    await sesion.recuperarContrasena(correo);
    await sesion.recuperarPorRespaldo('respaldo_$correo');
    _ok(true, 'recuperar contraseña y por respaldo (ok:true)');

    // Borrado en cascada del paciente y de la cuenta
    await api.delete('/pacientes/$pid');
    final restantes = await api.get('/pacientes') as List;
    _ok(restantes.isEmpty, 'DELETE /pacientes/:id');
    try {
      await api.get('/pacientes/$pid/registros');
      _ok(false, 'registros de paciente borrado deben dar 404');
    } on ExcepcionApi catch (e) {
      _ok(e.codigoHttp == 404, 'cascada: registros del paciente -> 404');
    }
    await sesion.eliminarCuenta();
    _ok(sesion.actual == null, 'DELETE /cuenta (sesión cerrada)');
    late final ServicioSesion sesion3;
    final api3 = ClienteApi(
      urlBase: urlBase,
      obtenerToken: () => sesion3.token,
    );
    sesion3 = ServicioSesion(api: api3, almacen: AlmacenSecretoMemoria());
    try {
      await sesion3.iniciarSesion(correo, contrasena);
      _ok(false, 'login tras borrar la cuenta debe fallar');
    } on ExcepcionSesion catch (e) {
      _ok(
        e.codigo == CodigoErrorSesion.credencialesInvalidas,
        'cuenta borrada: login rechazado',
      );
    }
    api3.cerrar();

    // Sin servidor: error de red tipado y transitorio
    final apiMuerta = ClienteApi(
      urlBase: 'http://localhost:1/api',
      obtenerToken: () => null,
    );
    try {
      await apiMuerta.get('/salud');
      _ok(false, 'sin servidor debe fallar');
    } on ExcepcionApi catch (e) {
      _ok(e.esDeRed && e.esTransitorio, 'sin servidor -> ExcepcionApi de red');
    }
    apiMuerta.cerrar();
  } catch (e, pila) {
    stdout.writeln('FALLA excepción inesperada: $e\n$pila');
    _fallos++;
  } finally {
    api.cerrar();
  }
  stdout.writeln(_fallos == 0 ? 'HUMO OK' : 'HUMO CON $_fallos FALLAS');
  exit(_fallos == 0 ? 0 : 1);
}
