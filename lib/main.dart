import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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
  }

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
