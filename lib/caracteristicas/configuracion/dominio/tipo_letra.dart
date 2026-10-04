/// Tipografías que el cuidador puede elegir para toda la app.
enum TipoLetra {
  sistema('Del sistema', 'Roboto en Android, San Francisco en iPhone'),
  nunito('Nunito', 'Redondeada y amable'),
  estiloIos('Estilo iPhone', 'San Francisco en iPhone; Inter en Android');

  const TipoLetra(this.etiqueta, this.descripcion);

  final String etiqueta;
  final String descripcion;

  /// Tipografía guardada con ese nombre; cualquier otro valor cae a [sistema].
  static TipoLetra desdeNombre(String? nombre) {
    for (final tipo in values) {
      if (tipo.name == nombre) return tipo;
    }
    return sistema;
  }
}
