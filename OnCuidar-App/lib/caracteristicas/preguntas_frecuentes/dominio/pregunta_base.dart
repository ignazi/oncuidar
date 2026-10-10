/// Modelo de una pregunta frecuente respaldada por el equipo clínico.
/// Se usa tanto en el FAQ como en el chat de orientación.
class PreguntaBase {
  const PreguntaBase({
    required this.id,
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    this.claves = const [],
    this.contenidoRelacionadoId,
  });

  final String id;
  final String categoria;
  final String pregunta;
  final String respuesta;

  /// Palabras clave usadas para emparejar el texto libre del usuario.
  final List<String> claves;

  /// Id del material afín en materialEducativo; sin él no se ofrece enlace.
  final String? contenidoRelacionadoId;
}
