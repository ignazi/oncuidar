import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché de contenido educativo (videos, PDFs, imágenes).
///
/// Baja archivos de Firebase Storage (o cualquier URL) y los guarda
/// local para acceso sin internet. Internamente usa flutter_cache_manager.
class ContentCacheService {
  // Singleton
  static final ContentCacheService _instance = ContentCacheService._();
  factory ContentCacheService() => _instance;
  ContentCacheService._()
      : _cacheManager = CacheManager(
          Config(
            'educational_content',
            stalePeriod: const Duration(days: 365),
            maxNrOfCacheObjects: 200,
          ),
        );

  final CacheManager _cacheManager;

  /// Descarga un archivo y lo mete en caché. Si ya lo tiene, lo retorna directo.
  Future<File> downloadFile(String url, String fileId) async {
    // Si ya está en caché, retorna directo
    final cached = await getCachedFile(fileId);
    if (cached != null) return cached;

    final file = await _cacheManager.getSingleFile(
      url,
      key: fileId,
    );
    return file;
  }

  /// Busca el archivo en caché, o null si no fue descargado.
  Future<File?> getCachedFile(String fileId) async {
    final file = await _cacheManager.getFileFromCache(fileId);
    if (file != null && await file.file.exists()) {
      return file.file;
    }
    return null;
  }

  /// Chequea si el archivo ya está descargado.
  Future<bool> isDownloaded(String fileId) async {
    final file = await getCachedFile(fileId);
    return file != null;
  }

  /// Saca un archivo específico del caché.
  Future<void> removeFile(String fileId) async {
    await _cacheManager.removeFile(fileId);
  }

  /// Tamaño total del caché en bytes.
  /// flutter_cache_manager no expone esto directamente, por ahora retornamos 0.
  Future<int> getCacheSize() async {
    return 0; // por ahora, se puede implementar escaneando el directorio
  }

  /// Limpia todo el caché de contenido educativo.
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }
}
