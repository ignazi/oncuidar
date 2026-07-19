import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../services/metadata_cache_service.dart';
import '../services/auto_download_service.dart';
import '../../data/faq_data.dart';
import '../../models/app_user.dart';
import '../../models/daily_record.dart';
import '../../models/educational_content.dart';
import '../../models/faq_item.dart';
import '../../models/orientation_rule.dart';
import '../../models/patient.dart';
import '../../models/reminder.dart';
import '../../models/user_checklist.dart';

const _kSelectedPatientKey = 'selected_patient_id';

// ── Service ──

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// ── Auth ──

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ── User ──

final userProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(firestoreServiceProvider).userStream();
});

// ── Patient List ──

final patientsListProvider = StreamProvider<List<Patient>>((ref) {
  return ref.watch(firestoreServiceProvider).patientsStream();
});

// ── Selected Patient ID (persisted in SharedPreferences) ──

/// Guarda el ID del paciente seleccionado, persistido entre sesiones
/// con SharedPreferences. Arranca en null (se carga async del prefs).
class SelectedPatientNotifier extends Notifier<String?> {
  @override
  String? build() {
    _loadFromPrefs();
    return null; // initial — will update once prefs loads
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSelectedPatientKey);
    if (saved != null) state = saved;
  }

  Future<void> select(String? patientId) async {
    state = patientId;
    final prefs = await SharedPreferences.getInstance();
    if (patientId == null) {
      await prefs.remove(_kSelectedPatientKey);
    } else {
      await prefs.setString(_kSelectedPatientKey, patientId);
    }
  }
}

final selectedPatientIdProvider =
    NotifierProvider<SelectedPatientNotifier, String?>(
  SelectedPatientNotifier.new,
);

// ── Current Patient (derived from selection + patient list) ──

/// Emite el paciente seleccionado actualmente.
/// Prioridad: ID guardado en SharedPreferences → primer paciente → null.
/// Se recalcula cuando cambia la lista de pacientes (por ej. si se borra uno)
/// o cuando el usuario cambia la selección.
final currentPatientProvider = StreamProvider<Patient?>((ref) {
  final selectedId = ref.watch(selectedPatientIdProvider);
  return ref.watch(firestoreServiceProvider).patientsStream().map((list) {
    if (list.isEmpty) return null;

    // Si hay selección guardada, tratamos de encontrarla en la lista
    if (selectedId != null) {
      final match = list.where((p) => p.id == selectedId);
      if (match.isNotEmpty) return match.first;
      // El paciente seleccionado fue borrado — usamos el primero
    }

    return list.first;
  });
});

// ── Patient-dependent providers ──

final dailyRecordsProvider = StreamProvider<List<DailyRecord>>((ref) {
  final patientAsync = ref.watch(currentPatientProvider);
  if (patientAsync is AsyncLoading) return const Stream.empty();
  final patient = patientAsync.value;
  if (patient == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).dailyRecordsStream(patient.id);
});

final remindersProvider = StreamProvider<List<Reminder>>((ref) {
  final patientAsync = ref.watch(currentPatientProvider);
  if (patientAsync is AsyncLoading) return const Stream.empty();
  final patient = patientAsync.value;
  if (patient == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).remindersStream(patient.id);
});

final userChecklistsProvider = StreamProvider<List<UserChecklist>>((ref) {
  final patientAsync = ref.watch(currentPatientProvider);
  if (patientAsync is AsyncLoading) return const Stream.empty();
  final patient = patientAsync.value;
  if (patient == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).userChecklistsStream(patient.id);
});

final favoriteArticlesProvider = StreamProvider<List<String>>((ref) {
  final patientAsync = ref.watch(currentPatientProvider);
  if (patientAsync is AsyncLoading) return const Stream.empty();
  final patient = patientAsync.value;
  if (patient == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).favoriteArticlesStream(patient.id);
});

// ── Shared content (not patient-dependent) ──

/// Provider que carga reglas de orientación.
///
/// Estrategia offline-first:
/// 1. Emite inmediatamente desde el JSON bundleado (asset local, siempre disponible)
/// 2. Después se suscribe a Firestore para recibir actualizaciones en tiempo real
/// 3. Si Firestore está vacío (primera vez sin seed), mantiene los datos del asset
/// 4. Una vez que Firestore cargó, su caché offline mantiene los datos actualizados
final orientationRulesProvider = StreamProvider<List<OrientationRule>>((ref) async* {
  // ── Paso 1: Emitir desde el asset bundle (instantáneo + offline) ──
  try {
    final assetJson = await rootBundle.loadString('assets/data/orientation_rules.json');
    final List<dynamic> decoded = jsonDecode(assetJson);
    yield decoded
        .map((e) => OrientationRule.fromMap('', e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Si falla el asset (no debería), continuamos sin él
  }

  // ── Paso 2: Suscribirse a Firestore (actualizaciones en tiempo real) ──
  await for (final firestoreRules
      in ref.watch(firestoreServiceProvider).orientationRulesStream()) {
    if (firestoreRules.isNotEmpty) {
      yield firestoreRules;
    }
    // Si Firestore está vacío, seguimos con los datos del asset ya emitidos
  }
});

/// Metadata cache service singleton.
final metadataCacheServiceProvider = Provider<MetadataCacheService>((ref) {
  return MetadataCacheService();
});

/// Provider de contenido educativo con soporte offline.
///
/// Estrategia:
/// 1. Cargar desde caché local inmediatamente (disponible offline)
/// 2. Si hay internet, sincronizar con Firestore y actualizar caché
/// 3. Si no hay internet, usar solo el caché
final educationalContentProvider =
    StreamProvider<List<EducationalContent>>((ref) async* {
  final cacheService = ref.read(metadataCacheServiceProvider);

  // Paso 1: Emitir desde caché local (instantáneo, offline-safe)
  try {
    final cached = await cacheService.getCachedContent();
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }
  } catch (_) {
    // Si falla el caché, continuamos
  }

  // Paso 2: Suscribirse a Firestore (actualizaciones en tiempo real)
  await for (final firestoreContent
      in ref.watch(firestoreServiceProvider).educationalContentStream()) {
    if (firestoreContent.isNotEmpty) {
      yield firestoreContent;
      // Actualizar caché local
      try {
        await cacheService.cacheContent(firestoreContent);
      } catch (_) {
        // Si falla el guardado del caché, no es crítico
      }
    }
    // Si Firestore está vacío, seguimos con los datos del caché ya emitidos
  }
});

/// FAQ provider: emite datos hardcodeados (basados en fuentes científicas)
/// y se actualiza con datos de Firestore cuando estén disponibles.
final faqsProvider = StreamProvider<List<FaqItem>>((ref) async* {
  // Emitir datos hardcodeados inmediatamente
  yield defaultFaqItems;

  // Suscribirse a Firestore para actualizaciones en tiempo real
  await for (final firestoreFaqs
      in ref.watch(firestoreServiceProvider).faqsStream()) {
    if (firestoreFaqs.isNotEmpty) {
      yield firestoreFaqs;
    }
  }
});

// ── Chats (conversaciones de orientación) ──

/// Provee la lista de conversaciones del usuario desde Firestore.
final conversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).chatsStream();
});

// ── Conectividad ──

/// Singleton del servicio de conectividad.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream del estado de conectividad (true = online, false = offline).
final isConnectedProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isConnected;
});

// ── Auto-descarga de contenido ──

/// Servicio de descarga automática.
final autoDownloadServiceProvider = Provider<AutoDownloadService>((ref) {
  final service = AutoDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});
