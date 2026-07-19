import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Callback que se ejecuta cuando el usuario toca una notificación
  Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // lo pedimos manualmente después
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        log('Notification tapped: ${details.payload}');
        onNotificationTap?.call(details.payload);
      },
    );

    _initialized = true;
    log('NotificationService initialized');
  }

  /// Pide permiso de notificaciones al usuario (Android 13+ / iOS)
  /// Retorna true si se concedió el permiso.
  Future<bool> requestPermission() async {
    // Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      log('Android notification permission granted: $granted');
    }

    // iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      log('iOS notification permission granted: $granted');
      return granted ?? false;
    }

    return true; // Android pre-13 no necesita runtime permission
  }

  /// Convierte un hashCode a un entero positivo seguro para Android
  static int safeId(String docId) {
    return docId.hashCode & 0x7FFFFFFF;
  }

  tz.TZDateTime _nextMatchingDay(
      DateTime scheduledTime, List<String> repeatDays) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    const dayMap = {
      'lun': DateTime.monday,
      'mar': DateTime.tuesday,
      'mie': DateTime.wednesday,
      'jue': DateTime.thursday,
      'vie': DateTime.friday,
      'sab': DateTime.saturday,
      'dom': DateTime.sunday,
    };

    final targetWeekdays =
        repeatDays.map((d) => dayMap[d]).whereType<int>().toList()..sort();

    for (int i = 0; i < 7; i++) {
      final test = candidate.add(Duration(days: i));
      if (targetWeekdays.contains(test.weekday) && test.isAfter(now)) {
        return test;
      }
    }

    return candidate.add(const Duration(days: 1));
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    List<String>? repeatDays,
  }) async {
    if (!_initialized) {
      log('WARNING: NotificationService not initialized, initializing now');
      await initialize();
    }

    tz.TZDateTime tzDateTime;

    if (repeatDays != null && repeatDays.isNotEmpty) {
      tzDateTime = _nextMatchingDay(scheduledTime, repeatDays);
    } else {
      tzDateTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) {
        tzDateTime = tzDateTime.add(const Duration(days: 1));
      }
    }

    log('Scheduling notification $id for $tzDateTime');
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Recordatorios',
            channelDescription: 'Notificaciones de recordatorios de medicación y citas médicas',
            importance: Importance.high,
            priority: Priority.high,
            channelShowBadge: true,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      log('Notification $id scheduled successfully');
    } catch (e) {
      log('ERROR scheduling notification $id: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
    log('Cancelled notification $id');
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
    log('Cancelled all notifications');
  }
}
