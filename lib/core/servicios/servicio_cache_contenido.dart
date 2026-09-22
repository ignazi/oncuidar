import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave estable de SharedPreferences para el avance de un video: una por
/// ruta, de modo que cada material guarda su propia posición.
String claveAvanceVideo(String url) =>
    'avance_video_${Uri.encodeComponent(url)}';

/// Posición guardada (ms) del video, 0 si nunca se reprodujo.
Future<int> leerAvanceVideo(String url) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(claveAvanceVideo(url)) ?? 0;
}

/// Persiste la posición del video. Las posiciones triviales (< 1 s) no se
/// guardan para no sobrescribir el avance real al entrar y salir rápido.
Future<void> guardarAvanceVideo(String url, Duration avance) async {
  if (avance.inMilliseconds < 1000) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(claveAvanceVideo(url), avance.inMilliseconds);
}

class ServicioCacheContenido {
  ServicioCacheContenido({CacheManager? gestor})
      : _gestor =
            gestor ??
            CacheManager(
              Config(
                'material_educativo',
                stalePeriod: const Duration(days: 365),
                maxNrOfCacheObjects: 200,
              ),
            );

  final CacheManager _gestor;

  Future<File?> archivoEnCache(String url) async {
    final info = await _gestor.getFileFromCache(url);
    if (info != null && await info.file.exists()) return info.file;
    return null;
  }

  Future<File> descargar(String url) async {
    final existente = await archivoEnCache(url);
    if (existente != null) return existente;
    return _gestor.getSingleFile(url, key: url);
  }

  Future<bool> archivoDescargado(String url) async {
    return await archivoEnCache(url) != null;
  }

  Future<void> eliminar(String url) => _gestor.removeFile(url);
}