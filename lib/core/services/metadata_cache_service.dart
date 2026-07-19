import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../models/educational_content.dart';

/// Caché local de metadata del contenido educativo.
///
/// Cuando hay internet, se sincroniza con Firestore.
/// Cuando no hay internet, se usa el caché local para mostrar
/// la lista de contenido (videos, guías, checklists).
class MetadataCacheService {
  static const String _cacheKey = 'educational_content_cache';
  static const String _cacheTimestampKey = 'educational_content_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  /// Guarda la metadata en caché local.
  Future<void> cacheContent(List<EducationalContent> content) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = content.map((c) => c.toMap()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Obtiene la metadata del caché local.
  /// Retorna null si no hay caché o si expiró.
  Future<List<EducationalContent>?> getCachedContent() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheDuration) {
      // Caché expirado
      return null;
    }

    final jsonString = prefs.getString(_cacheKey);
    if (jsonString == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((e) => EducationalContent.fromMap('', e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Limpia el caché.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }
}
