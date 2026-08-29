import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/logging/app_logger.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

typedef NotificationActionCallback = Future<void> Function(String actionId, String doseId);

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    AppLogger logger = const AppLogger(),
    NotificationActionCallback? onAction,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _logger = logger,
       onAction = onAction;

  static const channelId = 'medipulse_doses';
  static const takenAction = 'taken';
  static const snoozeAction = 'snooze';
  static const skipAction = 'skip';

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLogger _logger;
  NotificationActionCallback? onAction;

  @override
  Future<bool> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) async {
        final doseId = response.payload;
        if (doseId == null || onAction == null) return;
        final action = response.actionId ?? 'open';
        await onAction!(action, doseId);
      },
    );
    const channel = AndroidNotificationChannel(
      channelId,
      'Medication reminders',
      description: 'Time-sensitive reminders to take your medication',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final androidOk = await android?.requestNotificationsPermission() ?? true;
    final iosOk =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? true;
    return androidOk && iosOk;
  }

  @override
  Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<void> scheduleDoseReminder({
    required MedicationDose dose,
    required Medication medication,
  }) async {
    if (dose.remindAt.isBefore(DateTime.now().toUtc().subtract(const Duration(minutes: 1)))) {
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
          AndroidNotificationAction(takenAction, 'Taken', showsUserInterface: true),
          AndroidNotificationAction(snoozeAction, 'Snooze', showsUserInterface: true),
          AndroidNotificationAction(skipAction, 'Skip', showsUserInterface: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'DOSE_CATEGORY',
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        _id(dose.id),
        'Time for ${medication.name}',
        _body(medication),
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: dose.id,
      );
    } catch (error) {
      _logger.error('Unable to schedule reminder');
      await _plugin.zonedSchedule(
        _id(dose.id),
        'Time for ${medication.name}',
        _body(medication),
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: dose.id,
      );
    }
  }

  @override
  Future<void> cancelDose(String doseId) => _plugin.cancel(_id(doseId));

  @override
  Future<void> cancelMedication(String medicationId) async {
    // Individual dose ids are cancelled by the reminder coordinator.
  }

  @override
  Future<void> showImmediate({required String title, required String body}) {
    return _plugin.show(
      title.hashCode & 0x7fffffff,
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

  String _body(Medication medication) {
    final food = medication.foodInstruction;
    final foodPart = (food == null || food.isEmpty) ? '' : ' $food.';
    return 'Take ${medication.doseLabel}.$foodPart';
  }

  int _id(String doseId) => doseId.hashCode & 0x7fffffff;
}
