class MaterialEducativo {
  final String id;
  final String titulo;
  final String categoria;
  final String tema;
  final String cuerpo;
  final String? urlImagen;
  final String? urlArchivo;
  final String? urlMiniatura;
  final String? tipoArchivo;
  final int? tamanoBytes;
  final DateTime creadoEn;

  const MaterialEducativo({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.tema,
    required this.cuerpo,
    this.urlImagen,
    this.urlArchivo,
    this.urlMiniatura,
    this.tipoArchivo,
    this.tamanoBytes,
    required this.creadoEn,
  });

  bool get esVideo => categoria.toLowerCase() == 'videos';

  bool get esChecklist => categoria.toLowerCase() == 'checklist';

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'title': titulo,
    'category': categoria,
    'topic': tema,
    'body': cuerpo,
    if (urlImagen != null) 'imageUrl': urlImagen,
    if (urlArchivo != null) 'fileUrl': urlArchivo,
    if (urlMiniatura != null) 'thumbnailUrl': urlMiniatura,
    if (tipoArchivo != null) 'fileType': tipoArchivo,
    if (tamanoBytes != null) 'fileSizeBytes': tamanoBytes,
    'createdAt': creadoEn.toIso8601String(),
  };

  factory MaterialEducativo.fromMap(String id, Map<String, dynamic> mapa) {
    final creado = mapa['createdAt'];
    return MaterialEducativo(
      id: (mapa['id'] as String?) ?? id,
      titulo: mapa['title'] as String? ?? '',
      categoria: mapa['category'] as String? ?? '',
      tema: mapa['topic'] as String? ?? '',
      cuerpo: mapa['body'] as String? ?? '',
      urlImagen: mapa['imageUrl'] as String?,
      urlArchivo: mapa['fileUrl'] as String?,
      urlMiniatura: mapa['thumbnailUrl'] as String?,
      tipoArchivo: mapa['fileType'] as String?,
      tamanoBytes: (mapa['fileSizeBytes'] as num?)?.toInt(),
      creadoEn: creado is DateTime
          ? creado
          : DateTime.tryParse(creado?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
