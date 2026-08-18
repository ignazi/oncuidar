import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/providers/providers.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  await NotificationService().initialize();
  await NotificationService().requestPermission();
  runApp(const ProviderScope(child: OncuidarApp()));
}

class OncuidarApp extends ConsumerStatefulWidget {
  const OncuidarApp({super.key});
  @override ConsumerState<OncuidarApp> createState() => _OncuidarAppState();
}

class _OncuidarAppState extends ConsumerState<OncuidarApp> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        ref.read(encryptionServiceProvider).lock();
        ref.read(encryptionUnlockedProvider.notifier).setUnlocked(false);
        NotificationService().cancelAllReminders();
      } else {
        _rescheduleReminders();
      }
    });
  }

  Future<void> _rescheduleReminders() async {
    try {
      final service = ref.read(firestoreServiceProvider);
      await NotificationService().cancelAllReminders();
      final patients = await service.patientsStream().first;
      for (final patient in patients) {
        if (!patient.notificationsEnabled) continue;
        final reminders = await service.remindersStream(patient.id).first;
        for (final reminder in reminders.where((r) => r.isActive)) {
          await NotificationService().scheduleReminder(
            id: NotificationService.safeId(reminder.id),
            title: '${patient.fullName}: ${reminder.title}',
            body: reminder.description ?? reminder.title,
            scheduledTime: reminder.dateTime,
            repeatDays: reminder.repeatDays,
            payload: patient.id,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final unlocked = ref.watch(encryptionUnlockedProvider);
    return MaterialApp.router(
      title: 'Oncuidar', debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, routerConfig: router,
      builder: (context, child) => user != null && !unlocked
          ? const _DataKeyGate()
          : child ?? const SizedBox.shrink(),
    );
  }
}

class _DataKeyGate extends ConsumerStatefulWidget {
  const _DataKeyGate();
  @override ConsumerState<_DataKeyGate> createState() => _DataKeyGateState();
}

class _DataKeyGateState extends ConsumerState<_DataKeyGate> {
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _restore(); }

  Future<void> _restore() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final encryption = ref.read(encryptionServiceProvider);
      final local = await encryption.restoreLocalKey(uid);
      if (!local) {
        final result = await FirebaseFunctions.instanceFor(region: 'southamerica-west1')
            .httpsCallable('getOrCreateDataKey')
            .call();
        await encryption.setKey(
          uid,
          (result.data as Map)['dataKey'] as String,
        );
      }
      await ref.read(firestoreServiceProvider).migrateLegacySensitiveData();
      ref.read(encryptionUnlockedProvider.notifier).setUnlocked(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'No se pudieron restaurar tus datos.\n\n'
              'Posibles causas:\n'
              '• La función del servidor no está desplegada\n'
              '• Error de conexión a internet\n\n'
              'Intenta cerrar sesión y volver a entrar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _loading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restaurando clave de datos...'),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Restauración pendiente',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
    ),
  );
}
