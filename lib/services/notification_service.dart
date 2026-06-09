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

    // v22 API: requires settings named parameter
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap here if needed
      },
    );

    _isInitialized = true;
  }

  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('class_reminders_enabled') ?? false;
  }

  /// Request notification permissions from the OS.
  /// This does NOT check SharedPreferences — it's meant to be called
  /// both during onboarding and from settings.
  Future<bool> requestPermissions() async {
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
    bool force = false,
  }) async {
    if (force) {
      await requestPermissions();
    } else {
      final enabled = await areRemindersEnabled();
      if (!enabled) return;
    }

    final reminderTime = classStartTime.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if it's already in the past
    if (reminderTime.isBefore(DateTime.now())) return;

    // v22 API: androidScheduleMode is required, uiLocalNotificationDateInterpretation is REMOVED
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: 'Upcoming Class: $subject',
      body: 'Starts in $minutesBefore mins at $room',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Notifications for upcoming classes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // v22 API: requires id named parameter
  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
