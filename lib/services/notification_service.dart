import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap here if needed
      },
    );

    _isInitialized = true;
  }

  Future<bool> _areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true unless explicitly disabled
    return prefs.getBool('class_reminders_enabled') ?? true;
  }

  Future<bool> requestPermissions() async {
    final enabled = await _areRemindersEnabled();
    if (!enabled) return false;

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
    return granted ?? false;
  }

  Future<void> scheduleClassReminder({
    required int id,
    required String subject,
    required String room,
    required DateTime classStartTime,
    int minutesBefore = 15,
  }) async {
    final enabled = await _areRemindersEnabled();
    if (!enabled) return;

    final reminderTime = classStartTime.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if it's already in the past
    if (reminderTime.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      'Upcoming Class: $subject',
      'Starts in $minutesBefore mins at $room',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Notifications for upcoming classes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
