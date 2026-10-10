import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Falla de la API: respuesta con error o ausencia de red.
class ExcepcionApi implements Exception {
  const ExcepcionApi(
    this.codigoHttp,
    this.mensaje, {
    this.esDeRed = false,
    this.esTokenInvalido = false,
    this.esTiempoAgotado = false,
  });

  /// Sin respuesta del servidor (socket caído o tiempo agotado).
  const ExcepcionApi.sinRed([this.mensaje = 'Sin conexión'])
    : codigoHttp = 0,
      esDeRed = true,
      esTokenInvalido = false,
      esTiempoAgotado = false;

  /// El servidor no respondió dentro del límite.
  const ExcepcionApi.tiempoAgotado()
    : codigoHttp = 0,
      mensaje = 'Tiempo de espera agotado',
      esDeRed = true,
      esTokenInvalido = false,
      esTiempoAgotado = true;

  final int codigoHttp;
  final String mensaje;
  final bool esDeRed;

  /// El servidor no aceptó el token enviado (falta, inválido o vencido).
  final bool esTokenInvalido;
  final bool esTiempoAgotado;

  static const _permanentes = {400, 401, 403, 404, 409, 422};

  /// Reintentar no sirve: la cola debe mover la escritura a fallidas.
  bool get esPermanente => !esDeRed && _permanentes.contains(codigoHttp);

  /// Red, tiempo agotado, 408, 429 o 5xx: conviene reintentar.
  bool get esTransitorio => !esPermanente;

  @override
  String toString() => 'ExcepcionApi($codigoHttp): $mensaje';
}

/// Cliente HTTP mínimo con token Bearer y errores tipados.
class ClienteApi {
  ClienteApi({
    required this.urlBase,
    required this.obtenerToken,
    http.Client? cliente,
    this.limite = const Duration(seconds: 8),
  }) : _cliente = cliente ?? http.Client();

  final String urlBase;
  final String? Function() obtenerToken;
  final Duration limite;
  final http.Client _cliente;

  /// Se invoca cuando el servidor rechaza el token enviado (sesión vencida).
  void Function()? alSesionVencida;

  static const _mensajesToken = {
    'Falta el token de acceso',
    'Token inválido o vencido',
  };

  Future<dynamic> get(String ruta, {Duration? limite}) =>
      _enviar('GET', ruta, limite: limite);

  Future<dynamic> put(String ruta, Object? cuerpo, {Duration? limite}) =>
      _enviar('PUT', ruta, cuerpo: cuerpo ?? const {}, limite: limite);

  Future<dynamic> post(String ruta, [Object? cuerpo, Duration? limite]) =>
      _enviar('POST', ruta, cuerpo: cuerpo ?? const {}, limite: limite);

  Future<dynamic> delete(String ruta, {Duration? limite}) =>
      _enviar('DELETE', ruta, limite: limite);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Duration? limite,
  }) async {
    final tope = limite ?? this.limite;
    final token = obtenerToken();
    final peticion = http.Request(metodo, Uri.parse('$urlBase$ruta'));
    peticion.headers['Accept'] = 'application/json';
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    if (cuerpo != null) {
      peticion.headers['Content-Type'] = 'application/json; charset=utf-8';
      peticion.body = jsonEncode(cuerpo);
    }
    final http.Response respuesta;
    try {
      final flujo = await _cliente.send(peticion).timeout(tope);
      respuesta = await http.Response.fromStream(flujo).timeout(tope);
    } on TimeoutException {
      throw const ExcepcionApi.tiempoAgotado();
    } on SocketException {
      throw const ExcepcionApi.sinRed();
    } on HandshakeException {
      throw const ExcepcionApi.sinRed();
    } on http.ClientException {
      throw const ExcepcionApi.sinRed();
    }
    final texto = utf8.decode(respuesta.bodyBytes);
    dynamic json;
    if (texto.isNotEmpty) {
      try {
        json = jsonDecode(texto);
      } catch (_) {
        json = null;
      }
    }
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return json;
    final mensaje = json is Map && json['error'] is String
        ? json['error'] as String
        : 'Error ${respuesta.statusCode}';
    // Un 401 por contraseña errada no es token vencido: solo estos mensajes cierran sesión.
    final tokenInvalido =
        respuesta.statusCode == 401 && _mensajesToken.contains(mensaje);
    if (tokenInvalido && token != null) alSesionVencida?.call();
    throw ExcepcionApi(
      respuesta.statusCode,
      mensaje,
      esTokenInvalido: tokenInvalido,
    );
  }

  void cerrar() => _cliente.close();
}
