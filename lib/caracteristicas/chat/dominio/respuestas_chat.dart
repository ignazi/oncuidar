import 'package:oncuidar/caracteristicas/preguntas_frecuentes/dominio/catalogo_preguntas.dart';
import 'package:oncuidar/caracteristicas/preguntas_frecuentes/dominio/pregunta_base.dart';

/// Pregunta frecuente que mejor responde al texto, o null si ninguna calza.
///
/// Suma puntos por la frase completa, por cada palabra y por cada clave.
PreguntaBase? resolverPregunta(String texto, List<PreguntaBase> preguntas) {
  final entrada = normalizarTexto(texto);
  if (entrada.isEmpty) {
    return null;
  }
  final tokens = entrada
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toList();
  PreguntaBase? mejor;
  var mejorPuntaje = 0;
  for (final pregunta in preguntas) {
    final cuerpo = normalizarTexto(
      '${pregunta.pregunta} ${pregunta.claves.join(' ')}',
    );
    var puntaje = 0;
    if (cuerpo.contains(entrada)) {
      puntaje += 6;
    }
    for (final token in tokens) {
      if (cuerpo.contains(token)) {
        puntaje += token.length >= 6 ? 2 : 1;
      }
    }
    for (final clave in pregunta.claves) {
      final claveNormalizada = normalizarTexto(clave);
      if (claveNormalizada.length > 2 && entrada.contains(claveNormalizada)) {
        puntaje += 2;
      }
    }
    if (puntaje > mejorPuntaje) {
      mejorPuntaje = puntaje;
      mejor = pregunta;
    }
  }
  return mejorPuntaje >= 2 ? mejor : null;
}

/// Señales en una consulta ante las que conviene sugerir hablar con el equipo médico.
const _senalesParaConsultar = [
  'fiebre',
  'sangr',
  'petequia',
  'moreton',
  'vomit',
  'respirar',
  'respiracion',
  'convuls',
  'desmay',
  'no despierta',
  'muy decaido',
  'dolor fuerte',
  'mucho dolor',
  'se ve mal',
];

/// true si la consulta menciona alguna señal por la que conviene sugerir consultar al equipo.
///
/// Es una ayuda por palabras clave: no diagnostica ni reemplaza el criterio médico.
bool sugiereConsultarEquipo(String texto) {
  final entrada = normalizarTexto(texto);
  if (entrada.isEmpty) return false;
  return _senalesParaConsultar.any(entrada.contains);
}

/// Largo máximo del título automático de una conversación.
const largoMaximoTituloConversacion = 40;

/// Recorta la primera pregunta del usuario para usarla como título; vacía cae a 'Consulta'.
String tituloAutomaticoConversacion(String primeraPregunta) {
  final limpio = primeraPregunta.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return 'Consulta';
  if (limpio.length <= largoMaximoTituloConversacion) return limpio;
  final corte = limpio.substring(0, largoMaximoTituloConversacion);
  final ultimoEspacio = corte.lastIndexOf(' ');
  final base = ultimoEspacio > 15 ? corte.substring(0, ultimoEspacio) : corte;
  return '${base.trimRight()}…';
}
