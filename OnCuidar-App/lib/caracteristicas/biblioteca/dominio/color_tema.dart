/// Cantidad de acentos de color disponibles para los temas.
const cantidadAcentosTema = 12;

/// Índice de acento fijo de los temas conocidos del catálogo (todos distintos).
const _indicesTemasConocidos = {
  'signos de alarma': 0,
  'mucosas': 1,
  'el cancer': 2,
  'paliativos': 3,
  'cateter': 4,
  'quimioterapia': 5,
  'alimentacion': 6,
  'salud mental': 11,
  'efectos secundarios': 9,
  'unidad oncologica': 10,
};

const _tildes = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
};

/// Clave estable del tema: sin espacios sobrantes, tildes ni mayúsculas.
String claveColorTema(String tema) {
  final buffer = StringBuffer();
  for (final letra in tema.trim().toLowerCase().split('')) {
    buffer.write(_tildes[letra] ?? letra);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Hash FNV-1a de 32 bits: igual en todas las plataformas y ejecuciones.
int _hashEstable(String texto) {
  var hash = 0x811C9DC5;
  for (final unidad in texto.codeUnits) {
    hash = ((hash ^ unidad) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Índice de acento del tema; no depende del orden ni del contenido del catálogo.
int indiceColorTema(String tema) {
  final clave = claveColorTema(tema);
  return _indicesTemasConocidos[clave] ??
      _hashEstable(clave) % cantidadAcentosTema;
}
