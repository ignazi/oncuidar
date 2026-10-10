/// Almacenamiento clave-valor para secretos (token de sesión, clave de datos).
abstract class AlmacenSecreto {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

/// Almacenamiento en memoria, para pruebas y scripts sin Flutter.
class AlmacenSecretoMemoria implements AlmacenSecreto {
  final _datos = <String, String>{};

  @override
  Future<String?> leer(String clave) async => _datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async =>
      _datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => _datos.remove(clave);
}
