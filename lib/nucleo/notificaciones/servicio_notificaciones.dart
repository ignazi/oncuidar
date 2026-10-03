import 'dart:developer';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:oncuidar/nucleo/notificaciones/calendario_avisos.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Programa notificaciones locales de recordatorios. En tests se reemplaza
/// con un fake vía [servicioNotificacionesProvider].
class ServicioNotificaciones {
  ServicioNotificaciones._();
  static final ServicioNotificaciones _instancia = ServicioNotificaciones._();
  factory ServicioNotificaciones() => _instancia;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  /// Ruta interna que abre el toque de un aviso de recordatorio.
  static const rutaAviso = '/recordatorios';

  /// Se invoca con el payload cuando el usuario toca un aviso con la app viva.
  void Function(String? payload)? alTocar;

  String? _payloadLanzamiento;

  /// Payload del aviso que abrió la app desde cerrada (una sola lectura).
  Future<String?> consumirPayloadLanzamiento() async {
    if (!_inicializado) await inicializar();
    final payload = _payloadLanzamiento;
    _payloadLanzamiento = null;
    return payload;
  }

  Future<void> inicializar() async {
    if (_inicializado) return;
    tz.initializeTimeZones();
    await _configurarZonaHoraria();

    const ajustesAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ajustesIos = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const ajustes = InitializationSettings(
      android: ajustesAndroid,
      iOS: ajustesIos,
    );

    await _plugin.initialize(
      settings: ajustes,
      onDidReceiveNotificationResponse: (respuesta) =>
          alTocar?.call(respuesta.payload),
    );
    try {
      final detalles = await _plugin.getNotificationAppLaunchDetails();
      if (detalles?.didNotificationLaunchApp ?? false) {
        _payloadLanzamiento = detalles?.notificationResponse?.payload;
      }
    } catch (e) {
      log('No se pudo leer el lanzamiento por notificación: $e');
    }

    _inicializado = true;
    log('ServicioNotificaciones inicializado');
  }

  Future<void> _configurarZonaHoraria() async {
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
      log('Zona horaria configurada: ${zona.identifier}');
    } catch (e) {
      log('No se pudo configurar la zona horaria: $e');
    }
  }

  /// Pide permisos (Android 13+ y exact alarms; iOS alert/badge/sound).
  /// Devuelve true si se concedieron (Android 11 o menor: siempre true).
  Future<bool> solicitarPermiso() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final concedido = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return concedido ?? false;
    }
    return true;
  }

  /// Convierte un docId en un id positivo seguro para Android.
  static int idSeguro(String docId) => docId.hashCode & 0x7FFFFFFF;

  int _idRepetido(int idBase, int diaSemana) =>
      (idBase + diaSemana) & 0x7FFFFFFF;

  /// ¿El cuidador silenció globalmente las notificaciones? Se lee de
  /// SharedPreferences; ante cualquier fallo se asume no silenciado.
  Future<bool> _notificacionesSilenciadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notificaciones_silenciadas') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Programa el recordatorio. Con [diasRepeticion] agenda UNA notificación
  /// por día (weekday) con repetición semanal; sin días, agenda una sola vez
  /// (pasada la hora, se desplaza a mañana). Con [mensual] agenda una
  /// notificación que repite el mismo día del mes.
  Future<void> programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaHora,
    List<String>? diasRepeticion,
    bool mensual = false,
  }) async {
    if (await _notificacionesSilenciadas()) {
      await cancelar(id);
      return;
    }

    if (!_inicializado) await inicializar();

    if (mensual) {
      await cancelar(id);
      final momento = proximaMensual(tz.TZDateTime.now(tz.local), fechaHora);
      await _programarUna(
        id: id,
        titulo: titulo,
        cuerpo: cuerpo,
        momento: momento,
        repetir: DateTimeComponents.dayOfMonthAndTime,
      );
      return;
    }

    if (diasRepeticion != null && diasRepeticion.isNotEmpty) {
      await cancelar(id);
      for (final dia in diasRepeticion) {
        final diaSemana = diasPorSemana[dia];
        if (diaSemana == null) continue;
        final momento = proximaCoincidenciaSemanal(
          tz.TZDateTime.now(tz.local),
          fechaHora,
          diasPorSemana.entries
              .where((e) => e.value == diaSemana)
              .map((e) => e.key)
              .toList(),
        );
        await _programarUna(
          id: _idRepetido(id, diaSemana),
          titulo: titulo,
          cuerpo: cuerpo,
          momento: momento,
          repetir: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    final momento = momentoUnaVez(tz.TZDateTime.now(tz.local), fechaHora);
    await _programarUna(
      id: id,
      titulo: titulo,
      cuerpo: cuerpo,
      momento: momento,
    );
  }

  Future<void> _programarUna({
    required int id,
    required String titulo,
    required String cuerpo,
    required tz.TZDateTime momento,
    DateTimeComponents? repetir,
  }) async {
    log('Programando notificación $id para $momento');
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        scheduledDate: momento,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'recordatorios_channel',
            'Recordatorios',
            channelDescription:
                'Avisos de medicación, mediciones y citas médicas',
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
        matchDateTimeComponents: repetir,
        payload: rutaAviso,
      );
    } catch (e) {
      log('Error programando notificación $id: $e');
    }
  }

  /// Cancela la notificación base y todas sus variantes por día de semana.
  Future<void> cancelar(int id) async {
    await _plugin.cancel(id: id);
    for (final diaSemana in diasPorSemana.values) {
      await _plugin.cancel(id: _idRepetido(id, diaSemana));
    }
    log('Cancelada notificación $id');
  }

  Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }
}
