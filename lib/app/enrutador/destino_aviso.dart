/// Rutas que no requieren haber pasado por el Splash (sesión y clave).
const rutasPublicas = {
  '/',
  '/bienvenida',
  '/iniciar-sesion',
  '/crear-cuenta',
  '/recuperar-acceso',
};

/// Indica si el Splash ya verificó la sesión y desbloqueó la clave de datos.
class EstadoArranque {
  static bool completado = false;

  /// Destino de un aviso tocado antes de tener sesión; se abre tras iniciar sesión.
  static String? destinoPendiente;

  static void reiniciar() {
    completado = false;
    destinoPendiente = null;
  }

  /// Ruta a la que ir tras el login: el destino pendiente o el panel principal.
  static String consumirDestino() {
    final destino = destinoInternoSeguro(destinoPendiente) ?? '/dashboard';
    destinoPendiente = null;
    return destino;
  }
}

/// Abre la ruta de un aviso tocado: navega ya con sesión validada o la deja pendiente.
void abrirDesdeNotificacion(
  String? payload,
  void Function(String ruta) ir, {
  required bool haySesion,
}) {
  final destino = destinoInternoSeguro(payload);
  if (destino == null) return;
  if (haySesion && EstadoArranque.completado) {
    ir(destino);
  } else {
    EstadoArranque.destinoPendiente = destino;
  }
}

/// Deja como destino de arranque la ruta del aviso que abrió la app cerrada.
void registrarLanzamientoPorNotificacion(String? payload) {
  final destino = destinoInternoSeguro(payload);
  if (destino != null) EstadoArranque.destinoPendiente = destino;
}

/// Acepta solo rutas internas y no públicas como destino tras el Splash.
String? destinoInternoSeguro(String? destino) {
  if (destino == null || !destino.startsWith('/') || destino.startsWith('//')) {
    return null;
  }
  final ruta = Uri.tryParse(destino)?.path;
  if (ruta == null || rutasPublicas.contains(ruta)) return null;
  return destino;
}
