import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment.dart';
import '../models/therapy_item.dart';
import '../utils/navigation.dart';
import 'error_handler.dart';
import 'health_service.dart';

/// Servizio centralizzato per la gestione delle Notifiche Locali su Android (e iOS).
///
/// Gestisce:
/// 1. Promemoria Terapie giornalieri con bottoni interattivi:
///    - 'Segna come già presa' (aggiorna subito il DB e la UI)
///    - 'Ricorda tra 30 min' (massimo 2 rinvii per dose)
/// 2. Promemoria Visite mediche a 24 ore e 2 ore dall'appuntamento,
///    con dettagli opzionali (medico, luogo, note) in formato BigTextStyle.
/// 3. Promemoria inattività del Diario (> 20 ore dall'ultimo utilizzo),
///    con rispetto automatico della fascia notturna (21:00 - 09:00).
/// 4. Deep-linking al tocco tramite `navigatorKey`.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _therapyChannelId = 'therapy_channel';
  static const String _therapyChannelName = 'Promemoria Terapie';
  static const String _therapyChannelDesc =
      'Avvisi giornalieri per l\'assunzione dei farmaci prescritti';

  static const String _appointmentsChannelId = 'appointments_channel';
  static const String _appointmentsChannelName = 'Promemoria Visite Mediche';
  static const String _appointmentsChannelDesc =
      'Avvisi 24 ore e 2 ore prima delle visite mediche in programma';

  static const String _inactivityChannelId = 'inactivity_channel';
  static const String _inactivityChannelName = 'Promemoria Diario Salute';
  static const String _inactivityChannelDesc =
      'Avvisi di incoraggiamento quando non aggiorni il diario da oltre 20 ore';

  static const String actionMarkTaken = 'MARK_TAKEN';
  static const String actionSnooze30 = 'SNOOZE_30';

  static const int _inactivityNotificationId = 999999;

  final Set<int> _scheduledTherapyIds = {};
  final Set<int> _scheduledAppointmentIds = {};

  String? _pendingRoute;
  bool _initialized = false;

  /// Callback invocato quando una terapia viene segnata come assunta direttamente
  /// dalla notifica (notifica a [HealthProvider] di eseguire un refresh).
  VoidCallback? onTherapyMarkedTaken;

  /// Restituisce l'eventuale rotta memorizzata al tocco di una notifica a freddo (cold start)
  /// e la azzera per evitare aperture duplicate.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  // ------------------------------------------------------------- ID Helpers

  static int _therapyNotificationId(String id) =>
      100000 + (id.hashCode.abs() % 800000);

  static int _therapySnoozeId(String id) =>
      300000 + (id.hashCode.abs() % 800000);

  static int _appointment24hNotificationId(String id) =>
      1000000 + (id.hashCode.abs() % 800000);

  static int _appointment2hNotificationId(String id) =>
      2000000 + (id.hashCode.abs() % 800000);

  // --------------------------------------------------------- Inizializzazione

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        } catch (_) {
          // Fallback alla timezone locale di sistema
        }
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Gestione cold-start: l'app è stata aperta cliccando su una notifica
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final resp = launchDetails.notificationResponse;
        if (resp != null) {
          await _handleNotificationAction(resp);
        }
      }

      _initialized = true;
    } on MissingPluginException catch (e, st) {
      ErrorHandler.logOnly(e, st, 'NotificationService.initialize.missingPlugin');
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'NotificationService.initialize');
    }
  }

  /// Richiede i permessi runtime per notifiche ed exact alarms su Android 13+ e iOS.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      return true;
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'NotificationService.requestPermissions');
      return false;
    }
  }

  // ------------------------------------------------------- Gestione Risposte

  @pragma('vm:entry-point')
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    await _handleNotificationAction(response);
  }

  Future<void> _handleNotificationAction(NotificationResponse response) async {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.trim().isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final actionId = response.actionId;

    // Caso 1: Click sul bottone "Segna come già presa"
    if (actionId == actionMarkTaken) {
      final therapyId = data['therapyId']?.toString();
      if (therapyId != null && therapyId.isNotEmpty) {
        try {
          // Cancella eventuale notifica snooze pendente per questa terapia
          await _plugin.cancel(_therapySnoozeId(therapyId));
          // Registra l'assunzione su Supabase
          await HealthService().insertTherapyLog(therapyId, DateTime.now());
          onTherapyMarkedTaken?.call();
        } catch (e, st) {
          ErrorHandler.logOnly(e, st, 'NotificationService.handleMarkTaken');
        }
      }
      return;
    }

    // Caso 2: Click sul bottone "Ricorda tra 30 min"
    if (actionId == actionSnooze30) {
      final therapyId = data['therapyId']?.toString();
      final therapyName = data['therapyName']?.toString() ?? 'Terapia';
      final therapyTime = data['therapyTime']?.toString() ?? '';
      final snoozeCount = (data['snoozeCount'] as num?)?.toInt() ?? 0;

      if (therapyId != null && therapyId.isNotEmpty && snoozeCount < 2) {
        await _scheduleTherapySnooze(
          therapyId: therapyId,
          therapyName: therapyName,
          therapyTime: therapyTime,
          snoozeCount: snoozeCount + 1,
        );
      }
      return;
    }

    // Caso 3: Tap generale sul corpo della notifica -> Deep Link
    final route = data['route']?.toString();
    if (route != null && route.isNotEmpty) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(route);
      } else {
        _pendingRoute = route;
      }
    }
  }

  // ----------------------------------------------------- Schedulazione Terapie

  List<AndroidNotificationAction> _buildTherapyActions(int snoozeCount) {
    return [
      const AndroidNotificationAction(
        actionMarkTaken,
        'Segna come già presa',
        showsUserInterface: true,
        cancelNotification: true,
      ),
      if (snoozeCount < 2)
        const AndroidNotificationAction(
          actionSnooze30,
          'Ricorda tra 30 min',
          showsUserInterface: true,
          cancelNotification: true,
        ),
    ];
  }

  Future<void> _scheduleTherapySnooze({
    required String therapyId,
    required String therapyName,
    required String therapyTime,
    required int snoozeCount,
  }) async {
    if (kIsWeb) return;

    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));
    final id = _therapySnoozeId(therapyId);

    final payload = jsonEncode({
      'type': 'therapy',
      'route': '/diary',
      'therapyId': therapyId,
      'therapyName': therapyName,
      'therapyTime': therapyTime,
      'snoozeCount': snoozeCount,
    });

    final details = AndroidNotificationDetails(
      _therapyChannelId,
      _therapyChannelName,
      channelDescription: _therapyChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      actions: _buildTherapyActions(snoozeCount),
      styleInformation: BigTextStyleInformation(
        'Ricordati di assumere $therapyName (orario previsto: $therapyTime). Tocca per aprire il Diario.',
        contentTitle: 'Promemoria Terapia ($snoozeCount° rinvio): $therapyName',
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'Promemoria Terapia ($snoozeCount° rinvio): $therapyName',
        'Ricordati di assumere $therapyName (prevista alle $therapyTime).',
        snoozeTime,
        NotificationDetails(android: details),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      // Fallback a inexact se exact alarm è disabilitato
      try {
        await _plugin.zonedSchedule(
          id,
          'Promemoria Terapia ($snoozeCount° rinvio): $therapyName',
          'Ricordati di assumere $therapyName (prevista alle $therapyTime).',
          snoozeTime,
          NotificationDetails(android: details),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (err, st) {
        ErrorHandler.logOnly(err, st, 'NotificationService.scheduleTherapySnooze');
      }
    }
  }

  /// Risincronizza tutti i promemoria delle terapie in modo deterministico.
  Future<void> syncTherapies({
    required List<TherapyItem> therapies,
    required bool enabled,
  }) async {
    if (kIsWeb) return;

    // Cancella le notifiche delle terapie schedulate in precedenza
    for (final id in _scheduledTherapyIds) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    _scheduledTherapyIds.clear();

    if (!enabled || therapies.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    for (final item in therapies) {
      // Se è già presa oggi, cancella anche eventuale snooze pendente
      if (item.taken) {
        try {
          await _plugin.cancel(_therapySnoozeId(item.id));
        } catch (_) {}
      }

      final parts = item.time.split(':');
      if (parts.isEmpty) continue;
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Smart Skip: se l'ora è già passata oggi o se l'utente ha già preso il farmaco,
      // la prima notifica scatterà a partire da domani.
      if (scheduledDate.isBefore(now) || item.taken) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final id = _therapyNotificationId(item.id);
      _scheduledTherapyIds.add(id);

      final payload = jsonEncode({
        'type': 'therapy',
        'route': '/diary',
        'therapyId': item.id,
        'therapyName': item.name,
        'therapyTime': item.time,
        'snoozeCount': 0,
      });

      final title = 'Promemoria Terapia: ${item.name}';
      final body = 'È l\'ora di assumere ${item.name} (${item.time}). Tocca per aprire il Diario.';

      final details = AndroidNotificationDetails(
        _therapyChannelId,
        _therapyChannelName,
        channelDescription: _therapyChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        actions: _buildTherapyActions(0),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          NotificationDetails(android: details),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (_) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            NotificationDetails(android: details),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        } catch (e, st) {
          ErrorHandler.logOnly(e, st, 'NotificationService.syncTherapies.single');
        }
      }
    }
  }

  // ---------------------------------------------------- Schedulazione Visite

  static String _buildAppointmentBody(Appointment appt, {required bool isDayBefore}) {
    final hh = appt.time.hour.toString().padLeft(2, '0');
    final mm = appt.time.minute.toString().padLeft(2, '0');
    final lines = <String>[
      isDayBefore
          ? 'Domani alle $hh:$mm hai in programma: ${appt.type}.'
          : 'Tra 2 ore (alle $hh:$mm) hai in programma: ${appt.type}.',
    ];

    if (appt.doctorName.trim().isNotEmpty) {
      lines.add('Medico: ${appt.doctorName.trim()}');
    }
    if (appt.location.trim().isNotEmpty) {
      lines.add('Luogo: ${appt.location.trim()}');
    }
    if (appt.notes.trim().isNotEmpty) {
      lines.add('Note: ${appt.notes.trim()}');
    }

    lines.add('Tocca per aprire i dettagli della visita.');
    return lines.join('\n');
  }

  /// Risincronizza i promemoria delle visite (-24h e -2h).
  Future<void> syncAppointments({
    required List<Appointment> appointments,
    required bool enabled,
  }) async {
    if (kIsWeb) return;

    for (final id in _scheduledAppointmentIds) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    _scheduledAppointmentIds.clear();

    if (!enabled || appointments.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    for (final appt in appointments) {
      final visitTime = tz.TZDateTime.from(appt.dateTime, tz.local);

      final payload = jsonEncode({
        'type': 'appointment',
        'route': '/appointments',
        'appointmentId': appt.id,
      });

      // 1. Promemoria giorno prima (-24h)
      final dayBeforeTime = visitTime.subtract(const Duration(hours: 24));
      if (dayBeforeTime.isAfter(now)) {
        final id24h = _appointment24hNotificationId(appt.id);
        _scheduledAppointmentIds.add(id24h);

        final title = 'Promemoria Visita Domani: ${appt.type}';
        final body = _buildAppointmentBody(appt, isDayBefore: true);

        final details = AndroidNotificationDetails(
          _appointmentsChannelId,
          _appointmentsChannelName,
          channelDescription: _appointmentsChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        );

        try {
          await _plugin.zonedSchedule(
            id24h,
            title,
            body,
            dayBeforeTime,
            NotificationDetails(android: details),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        } catch (_) {
          try {
            await _plugin.zonedSchedule(
              id24h,
              title,
              body,
              dayBeforeTime,
              NotificationDetails(android: details),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: payload,
            );
          } catch (e, st) {
            ErrorHandler.logOnly(e, st, 'NotificationService.syncAppointments.24h');
          }
        }
      }

      // 2. Promemoria giorno stesso (-2h)
      final twoHoursBeforeTime = visitTime.subtract(const Duration(hours: 2));
      if (twoHoursBeforeTime.isAfter(now)) {
        final id2h = _appointment2hNotificationId(appt.id);
        _scheduledAppointmentIds.add(id2h);

        final title = 'Visita tra 2 ore: ${appt.type}';
        final body = _buildAppointmentBody(appt, isDayBefore: false);

        final details = AndroidNotificationDetails(
          _appointmentsChannelId,
          _appointmentsChannelName,
          channelDescription: _appointmentsChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        );

        try {
          await _plugin.zonedSchedule(
            id2h,
            title,
            body,
            twoHoursBeforeTime,
            NotificationDetails(android: details),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        } catch (_) {
          try {
            await _plugin.zonedSchedule(
              id2h,
              title,
              body,
              twoHoursBeforeTime,
              NotificationDetails(android: details),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: payload,
            );
          } catch (e, st) {
            ErrorHandler.logOnly(e, st, 'NotificationService.syncAppointments.2h');
          }
        }
      }
    }
  }

  // ---------------------------------------------------- Inattività Diario > 20h

  /// Resetta il timer di inattività (Dead-Man's Switch) a +20 ore dall'istante corrente.
  /// Rispetta la fascia notturna: se il timer scade tra le 21:00 e le 08:59,
  /// viene posticipato alle ore 09:00 del mattino.
  Future<void> resetInactivityTimer({required bool enabled}) async {
    if (kIsWeb) return;

    try {
      await _plugin.cancel(_inactivityNotificationId);
    } catch (_) {}

    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var target = now.add(const Duration(hours: 20));

    // Quiet Hours: dalle 21:00 alle 08:59 non inviare notifiche
    if (target.hour >= 21) {
      // Slitta alle 09:00 del giorno successivo
      final nextDay = target.add(const Duration(days: 1));
      target = tz.TZDateTime(tz.local, nextDay.year, nextDay.month, nextDay.day, 9, 0);
    } else if (target.hour < 9) {
      // Slitta alle 09:00 dello stesso giorno
      target = tz.TZDateTime(tz.local, target.year, target.month, target.day, 9, 0);
    }

    final payload = jsonEncode({
      'type': 'inactivity',
      'route': '/diary',
    });

    const title = 'Come stai oggi?';
    const body =
        'Non aggiorni il tuo Diario da più di 20 ore. Tocca qui per registrare i tuoi parametri o le attività di oggi.';

    const details = AndroidNotificationDetails(
      _inactivityChannelId,
      _inactivityChannelName,
      channelDescription: _inactivityChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        _inactivityNotificationId,
        title,
        body,
        target,
        const NotificationDetails(android: details),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'NotificationService.resetInactivityTimer');
    }
  }

  // ----------------------------------------------------------------- Cleanup

  /// Cancella tutte le notifiche schedulate (invocato al logout per GDPR).
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
      _scheduledTherapyIds.clear();
      _scheduledAppointmentIds.clear();
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'NotificationService.cancelAll');
    }
  }
}
