import 'dart:async';
import 'dart:convert';

import 'package:oncuidar/nucleo/almacen/almacen_secreto.dart';
import 'package:oncuidar/nucleo/red/cliente_api.dart';

/// Cuidador con sesión activa.
class SesionUsuario {
  const SesionUsuario({
    required this.uid,
    required this.correo,
    required this.token,
  });

  final String uid;
  final String correo;
  final String token;

  SesionUsuario conCorreo(String nuevo) =>
      SesionUsuario(uid: uid, correo: nuevo, token: token);

  Map<String, String> aMapa() => {'uid': uid, 'correo': correo, 'token': token};
}

/// Causas de fallo de la sesión que las pantallas traducen a mensajes.
enum CodigoErrorSesion {
  credencialesInvalidas,
  correoEnUso,
  correoInvalido,
  contrasenaDebil,
  demasiadosIntentos,
  sinRed,
  tiempoAgotado,
  otro,
}

class ExcepcionSesion implements Exception {
  const ExcepcionSesion(this.codigo, [this.mensaje = '']);

  final CodigoErrorSesion codigo;
  final String mensaje;

  /// Clasifica un error de la API según su código y su mensaje.
  factory ExcepcionSesion.desdeApi(ExcepcionApi e) {
    if (e.esDeRed) {
      return ExcepcionSesion(
        e.esTiempoAgotado
            ? CodigoErrorSesion.tiempoAgotado
            : CodigoErrorSesion.sinRed,
        e.mensaje,
      );
    }
    final texto = e.mensaje.toLowerCase();
    final codigo = switch (e.codigoHttp) {
      401 => CodigoErrorSesion.credencialesInvalidas,
      409 => CodigoErrorSesion.correoEnUso,
      429 => CodigoErrorSesion.demasiadosIntentos,
      400 when texto.contains('correo') => CodigoErrorSesion.correoInvalido,
      400 when texto.contains('contraseña') =>
        CodigoErrorSesion.contrasenaDebil,
      _ => CodigoErrorSesion.otro,
    };
    return ExcepcionSesion(codigo, e.mensaje);
  }

  @override
  String toString() => 'ExcepcionSesion(${codigo.name}): $mensaje';
}

/// Sesión del cuidador sobre la API del backend propio.
class ServicioSesion {
  ServicioSesion({required this._api, required this._almacen}) {
    _api.alSesionVencida = _expirar;
  }

  static const _claveAlmacen = 'oncuidar.sesion';
  static const _limiteRecuperacion = Duration(seconds: 5);

  final ClienteApi _api;
  final AlmacenSecreto _almacen;
  final _cambios = StreamController<SesionUsuario?>.broadcast();
  SesionUsuario? _actual;
  Future<void>? _inicializacion;
  bool _huboCambio = false;

  SesionUsuario? get actual => _actual;
  String? get token => _actual?.token;

  /// Emite el estado inicial (tras leer el almacenamiento) y cada cambio posterior.
  Stream<SesionUsuario?> get cambios => Stream<SesionUsuario?>.multi((c) {
    var recibido = false;
    final suscripcion = _cambios.stream.listen((sesion) {
      recibido = true;
      c.add(sesion);
    });
    c.onCancel = suscripcion.cancel;
    unawaited(
      inicializar().then((_) {
        if (!recibido && !c.isClosed) c.add(_actual);
      }),
    );
  });

  /// Lee la sesión guardada; es idempotente.
  Future<void> inicializar() => _inicializacion ??= _leerAlmacen();

  Future<void> _leerAlmacen() async {
    try {
      final texto = await _almacen.leer(_claveAlmacen);
      if (texto == null || _huboCambio) return;
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      _actual = SesionUsuario(
        uid: mapa['uid'] as String,
        correo: mapa['correo'] as String,
        token: mapa['token'] as String,
      );
    } catch (_) {
      // Un almacenamiento ilegible equivale a no tener sesión.
    }
  }

  Future<void> _fijar(SesionUsuario? sesion) async {
    _actual = sesion;
    _huboCambio = true;
    try {
      if (sesion == null) {
        await _almacen.borrar(_claveAlmacen);
      } else {
        await _almacen.escribir(_claveAlmacen, jsonEncode(sesion.aMapa()));
      }
    } catch (_) {
      // Sin almacenamiento la sesión vive solo mientras la app está abierta.
    }
    _cambios.add(sesion);
  }

  /// El servidor rechazó el token: la sesión terminó.
  void _expirar() {
    if (_actual != null) unawaited(_fijar(null));
  }

  Future<T> _traducir<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ExcepcionApi catch (e) {
      throw ExcepcionSesion.desdeApi(e);
    }
  }

  SesionUsuario _desdeRespuesta(dynamic json, String correo) {
    if (json is! Map || json['token'] is! String || json['uid'] is! String) {
      throw const ExcepcionSesion(CodigoErrorSesion.otro, 'Respuesta inválida');
    }
    return SesionUsuario(
      uid: json['uid'] as String,
      correo: correo,
      token: json['token'] as String,
    );
  }

  Future<SesionUsuario> registrar(String correo, String contrasena) async {
    final normalizado = correo.trim().toLowerCase();
    final json = await _traducir(
      () => _api.post('/auth/registro', {
        'correo': normalizado,
        'contrasena': contrasena,
      }),
    );
    final sesion = _desdeRespuesta(json, normalizado);
    await _fijar(sesion);
    return sesion;
  }

  Future<SesionUsuario> iniciarSesion(String correo, String contrasena) async {
    final normalizado = correo.trim().toLowerCase();
    final json = await _traducir(
      () => _api.post('/auth/login', {
        'correo': normalizado,
        'contrasena': contrasena,
      }),
    );
    final sesion = _desdeRespuesta(json, normalizado);
    await _fijar(sesion);
    return sesion;
  }

  Future<void> cerrarSesion() => _fijar(null);

  /// Reautentica con la contraseña; lanza credencialesInvalidas si no coincide.
  Future<void> verificarContrasena(String contrasena) => _traducir(
    () => _api.post('/auth/verificar-contrasena', {'contrasena': contrasena}),
  );

  /// Pide cambiar el correo principal: el servidor envía un enlace al correo nuevo
  /// y el cambio se aplica solo al confirmarlo (el correo de la sesión no cambia aquí).
  Future<void> cambiarCorreo(String contrasena, String nuevoCorreo) =>
      _traducir(
        () => _api.post('/auth/cambiar-correo', {
          'contrasena': contrasena,
          'nuevoCorreo': nuevoCorreo.trim().toLowerCase(),
        }),
      );

  /// Pide registrar el correo de respaldo: queda pendiente hasta confirmar el enlace.
  Future<void> pedirCorreoRespaldo(String correo) => _traducir(
    () =>
        _api.post('/correo-respaldo', {'correo': correo.trim().toLowerCase()}),
  );

  /// Reenvía el enlace de verificación del correo principal.
  Future<void> reenviarVerificacion() =>
      _traducir(() => _api.post('/auth/reenviar-verificacion', {}));

  /// Borra la cuenta y todos sus datos en el servidor y cierra la sesión.
  Future<void> eliminarCuenta() async {
    await _traducir(() => _api.delete('/cuenta'));
    await _fijar(null);
  }

  /// El servidor responde siempre ok (no revela si la cuenta existe).
  Future<void> recuperarContrasena(String correo) async {
    await _traducir(
      () => _api.post('/auth/recuperar-contrasena', {
        'correo': correo.trim(),
      }, _limiteRecuperacion),
    );
  }

  Future<void> recuperarPorRespaldo(String correo) async {
    final json = await _traducir(
      () => _api.post('/auth/recuperar-por-respaldo', {
        'correo': correo.trim(),
      }, _limiteRecuperacion),
    );
    if (json is! Map || json['ok'] != true) {
      throw const ExcepcionSesion(
        CodigoErrorSesion.otro,
        'Respuesta inesperada del servidor',
      );
    }
  }

  void dispose() => _cambios.close();
}
