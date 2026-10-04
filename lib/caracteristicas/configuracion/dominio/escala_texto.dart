/// Tamaños de texto que el cuidador puede elegir para toda la app.
enum EscalaTexto {
  normal('Normal', 1.0),
  grande('Grande', 1.15),
  muyGrande('Muy grande', 1.3);

  const EscalaTexto(this.etiqueta, this.factor);

  final String etiqueta;

  /// Multiplicador que se aplica sobre el tamaño de texto del sistema.
  final double factor;

  /// Escala guardada con ese nombre; cualquier otro valor cae a [normal].
  static EscalaTexto desdeNombre(String? nombre) {
    for (final escala in values) {
      if (escala.name == nombre) return escala;
    }
    return normal;
  }
}
