import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'content_cache_service.dart';
import '../../models/educational_content.dart';

/// Estado de la descarga automática.
enum DownloadState { idle, downloading, completed, error }

/// Servicio de descarga automática de contenido educativo.
///
/// Descarga todo el contenido (videos, PDFs, guías) en background
/// después del login, para que siempre esté disponible offline.
class AutoDownloadService {
  final ContentCacheService _cacheService;
  final FirebaseFirestore _db;

  DownloadState _state = DownloadState.idle;
  DownloadState get state => _state;

  int _totalFiles = 0;
  int get totalFiles => _totalFiles;

  int _downloadedFiles = 0;
  int get downloadedFiles => _downloadedFiles;

  String _currentFile = '';
  String get currentFile => _currentFile;

  double get progress => _totalFiles > 0 ? _downloadedFiles / _totalFiles : 0;

  final StreamController<DownloadState> _stateController =
      StreamController<DownloadState>.broadcast();
  Stream<DownloadState> get stateStream => _stateController.stream;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  AutoDownloadService({
    ContentCacheService? cacheService,
    FirebaseFirestore? db,
  })  : _cacheService = cacheService ?? ContentCacheService(),
        _db = db ?? FirebaseFirestore.instance;

  /// Descarga todo el contenido educativo en background.
  ///
  /// Retorna true si se completó, false si hubo error o ya estaba descargado.
  Future<bool> downloadAll() async {
    if (_state == DownloadState.downloading) return false;

    _state = DownloadState.downloading;
    _stateController.add(_state);
    _downloadedFiles = 0;

    try {
      // 1. Obtener todo el contenido de Firestore
      final snapshot = await _db.collection('educationalContent').get();
      final contents = snapshot.docs
          .map((doc) => EducationalContent.fromMap(doc.id, doc.data()))
          .toList();

      // 2. Filtrar los que tienen archivo para descargar
      final withFiles = contents.where((c) => c.fileUrl != null).toList();
      _totalFiles = withFiles.length;
      _progressController.add(0);

      if (_totalFiles == 0) {
        _state = DownloadState.completed;
        _stateController.add(_state);
        return true;
      }

      // 3. Descargar cada archivo
      for (final content in withFiles) {
        _currentFile = content.title;
        _progressController.add(progress);

        try {
          await _cacheService.downloadFile(content.fileUrl!, content.cacheKey);
          _downloadedFiles++;
          _progressController.add(progress);
        } catch (e) {
          // Si falla un archivo, continuamos con los demás
          debugPrint('Error descargando ${content.title}: $e');
        }
      }

      _state = DownloadState.completed;
      _stateController.add(_state);
      _progressController.add(1.0);
      return true;
    } catch (e) {
      _state = DownloadState.error;
      _stateController.add(_state);
      return false;
    }
  }

  /// Verifica si el contenido ya está descargado.
  Future<bool> isContentDownloaded(String cacheKey) async {
    return await _cacheService.isDownloaded(cacheKey);
  }

  /// Limpia el caché de contenido descargado.
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  void dispose() {
    _stateController.close();
    _progressController.close();
  }
}
