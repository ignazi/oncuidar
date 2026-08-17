import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/providers/providers.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activamos caché offline en Firestore — los datos se guardan localmente
  // y los streams emiten snapshots cacheados cuando no hay internet.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService().initialize();
  // Pedir permiso de notificaciones (Android 13+ / iOS)
  await NotificationService().requestPermission();

  runApp(const ProviderScope(child: OncuidarApp()));
}

class OncuidarApp extends ConsumerStatefulWidget {
  const OncuidarApp({super.key});

  @override
  ConsumerState<OncuidarApp> createState() => _OncuidarAppState();
}

class _OncuidarAppState extends ConsumerState<OncuidarApp> {
  @override
  void initState() {
    super.initState();

    NotificationService().onNotificationTap = (payload) {
      if (payload == null || payload.isEmpty) return;

      // Cambiar al paciente que viene en la notificación
      ref.read(selectedPatientIdProvider.notifier).select(payload);

      // Navegar a la pantalla de recordatorios
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go('/reminders');
      });
    };

    // Al autenticarse: reprogramar recordatorios activos desde Firestore.
    // Al cerrar sesión: cancelar todas las notificaciones del OS.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _rescheduleReminders();
      } else {
        NotificationService().cancelAllReminders();
      }
    });
  }

  /// Reprograma localmente todos los recordatorios activos del usuario
  /// autenticado. Se llama al login y al reabrir la app con sesión activa.
  Future<void> _rescheduleReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = ref.read(firestoreServiceProvider);

      // Limpiar alarmas previas para evitar duplicados
      await NotificationService().cancelAllReminders();

      // Obtener todos los pacientes del usuario
      final patients = await firestore.patientsStream().first;

      for (final patient in patients) {
        if (!patient.notificationsEnabled) continue;

        final reminders = await firestore.remindersStream(patient.id).first;

        for (final reminder in reminders) {
          if (!reminder.isActive) continue;

          await NotificationService().scheduleReminder(
            id: NotificationService.safeId(reminder.id),
            title: '${patient.fullName}: ${_typeLabel(reminder.type)}',
            body:
                '${reminder.title}${reminder.description != null ? ' · ${reminder.description}' : ''}',
            scheduledTime: reminder.dateTime,
            repeatDays: reminder.repeatDays,
            payload: patient.id,
          );
        }
      }
    } catch (e) {
      // Best-effort: si falla la reprogramación no bloquear el arranque
    }
  }

  static String _typeLabel(String type) => switch (type) {
        'medicamento' => 'Medicamento',
        'medicion' => 'Medición',
        'cita' => 'Cita médica',
        _ => 'Recordatorio',
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oncuidar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
