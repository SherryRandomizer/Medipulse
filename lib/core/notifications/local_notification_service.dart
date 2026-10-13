import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/logging/app_logger.dart';
import 'package:medipulse/core/notifications/pending_dose_action_store.dart';
import 'package:medipulse/core/notifications/reminder_alarm_registry.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

typedef NotificationActionCallback =
    Future<void> Function(String actionId, String doseId);

@pragma('vm:entry-point')
void medipulseNotificationTapBackground(NotificationResponse response) {
  final doseId = response.payload;
  if (doseId == null || doseId.isEmpty) return;
  unawaited(
    PendingDoseActionStore().save(
      actionId: response.actionId ?? 'open',
      doseId: doseId,
    ),
  );
}

/// Test seam for zoned scheduling and integer cancel without a real OS plugin.
abstract class NotificationAlarmGateway {
  Future<void> cancel(int id);

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });

  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode androidScheduleMode,
    required String payload,
  });
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    ReminderAlarmRegistry? registry,
    AppLogger logger = const AppLogger(),
    NotificationActionCallback? onAction,
    NotificationAlarmGateway? alarms,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _registry = registry ?? ReminderAlarmRegistry(),
       _logger = logger,
       _alarms = alarms,
       onAction = onAction;

  static const channelId = 'medipulse_doses';
  static const takenAction = 'taken';
  static const snoozeAction = 'snooze';
  static const skipAction = 'skip';
  static const doseCategoryId = 'DOSE_CATEGORY';

  /// Integer AlarmManager / plugin ID used before [ReminderAlarmRegistry].
  static int legacyAlarmId(String doseId) => doseId.hashCode & 0x7fffffff;

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderAlarmRegistry _registry;
  final AppLogger _logger;
  final NotificationAlarmGateway? _alarms;
  NotificationActionCallback? onAction;

  @override
  Future<bool> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          doseCategoryId,
          actions: [
            DarwinNotificationAction.plain(takenAction, 'Taken'),
            DarwinNotificationAction.plain(snoozeAction, 'Snooze'),
            DarwinNotificationAction.plain(skipAction, 'Skip'),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) async {
        final doseId = response.payload;
        if (doseId == null || onAction == null) return;
        final action = response.actionId ?? 'open';
        await onAction!(action, doseId);
      },
      onDidReceiveBackgroundNotificationResponse:
          medipulseNotificationTapBackground,
    );
    const channel = AndroidNotificationChannel(
      channelId,
      'Medication reminders',
      description: 'Time-sensitive reminders to take your medication',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response?.payload != null) {
      await PendingDoseActionStore().save(
        actionId: response!.actionId ?? 'open',
        doseId: response.payload!,
      );
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidOk = await android?.requestNotificationsPermission() ?? true;
    final iosOk =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    return androidOk && iosOk;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<bool> requestExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? true;
  }

  @override
  Future<void> openSystemNotificationSettings() => openAppSettings();

  @override
  Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<void> scheduleDoseReminder({
    required MedicationDose dose,
    required Medication medication,
  }) async {
    if (dose.remindAt.isBefore(
      DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    )) {
      return;
    }
    final when = tz.TZDateTime.from(dose.remindAt.toLocal(), tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Medication reminders',
        channelDescription: 'Time-sensitive reminders to take your medication',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        actions: const [
          AndroidNotificationAction(
            takenAction,
            'Taken',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            snoozeAction,
            'Snooze',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            skipAction,
            'Skip',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: LocalNotificationService.doseCategoryId,
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
    final id = await _registry.allocate(
      medicationId: medication.id,
      doseId: dose.id,
    );
    await _cancelPluginId(id);
    final title = 'Time for ${medication.name}';
    final body = _body(medication);
    try {
      await _zonedSchedule(
        id: id,
        title: title,
        body: body,
        when: when,
        details: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: dose.id,
      );
    } catch (error) {
      _logger.error('Unable to schedule reminder', error);
      try {
        await _zonedSchedule(
          id: id,
          title: title,
          body: body,
          when: when,
          details: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: dose.id,
        );
      } catch (inexactError, stack) {
        _logger.error('Unable to schedule reminder', inexactError);
        try {
          await _cancelPluginId(id);
        } catch (cancelError) {
          _logger.error('Unable to cancel failed reminder', cancelError);
        } finally {
          try {
            await _registry.releaseDose(dose.id);
          } catch (releaseError) {
            _logger.error('Unable to release failed reminder id', releaseError);
          }
        }
        Error.throwWithStackTrace(inexactError, stack);
      }
    }
  }

  @override
  Future<void> cancelDose(String doseId) async {
    await _cancelPluginId(legacyAlarmId(doseId));
    final id = await _registry.idForDose(doseId);
    if (id == null) return;
    try {
      await _cancelPluginId(id);
    } catch (error, stack) {
      _logger.error('Unable to cancel reminder', error);
      try {
        await _registry.releaseDose(doseId);
      } catch (releaseError) {
        _logger.error('Unable to release reminder id', releaseError);
      }
      Error.throwWithStackTrace(error, stack);
    }
    await _registry.releaseDose(doseId);
  }

  @override
  Future<void> cancelMedication(
    String medicationId, {
    Set<String> priorDoseIds = const {},
  }) async {
    for (final doseId in priorDoseIds) {
      await _plugin.cancel(legacyAlarmId(doseId));
    }
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload != null && priorDoseIds.contains(request.payload)) {
          await _plugin.cancel(request.id);
        }
      }
    } on Object {
      _logger.error('Unable to list pending reminders');
    }
    final doseIds = await _registry.doseIdsForMedication(medicationId);
    for (final doseId in doseIds) {
      final id = await _registry.idForDose(doseId);
      if (id == null) continue;
      await _plugin.cancel(id);
      await _registry.releaseDose(doseId);
    }
  }

  @override
  Future<List<String>> trackedMedicationIds() => _registry.medicationIds();

  @override
  Future<void> cancelAllReminders() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        await _plugin.cancel(request.id);
      }
    } on Object {
      _logger.error('Unable to cancel pending reminders; keeping alarm IDs tracked');
      return;
    }
    for (final medicationId in List<String>.from(
      await _registry.medicationIds(),
    )) {
      await _registry.releaseMedication(medicationId);
    }
  }

  @override
  Future<void> showImmediate({required String title, required String body}) async {
    final id = await _registry.allocateImmediate();
    final alarms = _alarms;
    if (alarms != null) {
      await alarms.show(id: id, title: title, body: body);
      return;
    }
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Medication reminders',
          importance: Importance.high,
        ),
      ),
    );
  }

  Future<void> _cancelPluginId(int id) {
    final alarms = _alarms;
    if (alarms != null) return alarms.cancel(id);
    return _plugin.cancel(id);
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode androidScheduleMode,
    required String payload,
  }) {
    final alarms = _alarms;
    if (alarms != null) {
      return alarms.zonedSchedule(
        id: id,
        title: title,
        body: body,
        when: when,
        details: details,
        androidScheduleMode: androidScheduleMode,
        payload: payload,
      );
    }
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: androidScheduleMode,
      payload: payload,
    );
  }

  String _body(Medication medication) {
    final food = medication.foodInstruction;
    final foodPart = (food == null || food.isEmpty) ? '' : ' $food.';
    return 'Take ${medication.doseLabel}.$foodPart';
  }
}
