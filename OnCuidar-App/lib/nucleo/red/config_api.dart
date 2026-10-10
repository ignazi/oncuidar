/// Dirección base de la API propia.
/// Por defecto apunta al emulador de Android (10.0.2.2 es el equipo anfitrión).
/// En escritorio o iOS usar: --dart-define=API_URL=http://localhost:8080/api
class ConfigApi {
  const ConfigApi._();

  static const urlBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );
}
