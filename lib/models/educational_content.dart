class EducationalContent {
  final String id;
  final String title;
  final String category; // "Videos" | "Guías" | "PDFs" | "Infografías" | "Checklist"
  final String topic;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;

  // ── Campos para descarga offline ──
  final String? fileUrl;      // URL del archivo (video/PDF) en Firebase Storage
  final String? thumbnailUrl; // URL de la miniatura
  final String? fileType;     // "video", "pdf", "infographic", "guide"
  final int? fileSizeBytes;   // Tamaño del archivo en bytes (hint para UI)

  const EducationalContent({
    required this.id,
    required this.title,
    required this.category,
    required this.topic,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileType,
    this.fileSizeBytes,
  });

  /// Tamaño legible del archivo (ej: "~50 MB")
  String? get fileSizeLabel {
    if (fileSizeBytes == null) return null;
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb >= 1) return '~${mb.toStringAsFixed(0)} MB';
    final kb = fileSizeBytes! / 1024;
    return '~${kb.toStringAsFixed(0)} KB';
  }

  /// ID único para el archivo en caché
  String get cacheKey => 'edu_$id';

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category,
        'topic': topic,
        'body': body,
        'imageUrl': imageUrl,
        'createdAt': createdAt,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (fileType != null) 'fileType': fileType,
        if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      };

  factory EducationalContent.fromMap(String id, Map<String, dynamic> map) =>
      EducationalContent(
        id: id,
        title: map['title'] as String? ?? '',
        category: map['category'] as String? ?? '',
        topic: map['topic'] as String? ?? '',
        body: map['body'] as String? ?? '',
        imageUrl: map['imageUrl'] as String?,
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                DateTime.now(),
        fileUrl: map['fileUrl'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        fileType: map['fileType'] as String?,
        fileSizeBytes: map['fileSizeBytes'] as int?,
      );
}
