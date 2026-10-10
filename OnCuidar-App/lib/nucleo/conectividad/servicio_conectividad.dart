import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de red del dispositivo; los tests lo reemplazan con un falso.
class ServicioConectividad {
  ServicioConectividad({
    Future<List<ConnectivityResult>> Function()? consultar,
    Stream<List<ConnectivityResult>> Function()? cambios,
  }) : _consultar = consultar ?? (() => Connectivity().checkConnectivity()),
       _cambios = cambios ?? (() => Connectivity().onConnectivityChanged);

  final Future<List<ConnectivityResult>> Function() _consultar;
  final Stream<List<ConnectivityResult>> Function() _cambios;

  // Tener interfaz de red no garantiza internet: las escrituras igual tienen tiempo límite.
  static bool _hayRed(List<ConnectivityResult> resultados) =>
      resultados.any((r) => r != ConnectivityResult.none);

  /// Si la consulta falla se asume en línea para no bloquear el guardado.
  Future<bool> estaEnLinea() async {
    try {
      return _hayRed(await _consultar());
    } catch (_) {
      return true;
    }
  }

  /// Emite cada vez que cambia entre con y sin conexión.
  Stream<bool> enLinea() => _cambios().map(_hayRed).distinct();
}
