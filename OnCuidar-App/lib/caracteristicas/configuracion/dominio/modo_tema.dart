import 'dart:ui';

/// Apariencia elegida por el cuidador.
enum ModoTema {
  sistema('Automático'),
  claro('Claro'),
  oscuro('Oscuro');

  const ModoTema(this.etiqueta);

  final String etiqueta;

  /// Modo guardado con ese nombre; cualquier otro valor cae a [sistema].
  static ModoTema desdeNombre(String? nombre) {
    for (final modo in values) {
      if (modo.name == nombre) return modo;
    }
    return sistema;
  }

  /// true si con este modo y el brillo del sistema corresponde el tema oscuro.
  bool esOscuro(Brightness brilloSistema) => switch (this) {
    ModoTema.claro => false,
    ModoTema.oscuro => true,
    ModoTema.sistema => brilloSistema == Brightness.dark,
  };
}
