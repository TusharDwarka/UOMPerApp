import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/class_session.dart';

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

  /// Automatically schedule reminders for ALL upcoming classes over the next 7 days.
  /// Uses a stable notification ID derived from the class data so re-scheduling
  /// is idempotent (won't duplicate alarms).
  Future<void> scheduleAllUpcomingClasses(List<ClassSession> allSessions, {
    List<ClassSession> Function(DateTime)? getEventsForDay,
  }) async {
    final enabled = await areRemindersEnabled();
    if (!enabled) return;

    // Check if today is a "No Class" day — skip today if so
    final noClassToday = await isNoClassToday();

    final now = DateTime.now();
    for (int d = 0; d < 7; d++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: d));

      // Skip today if user declared "No Class Today"
      if (d == 0 && noClassToday) continue;

      final dayName = DateFormat('EEEE').format(date);

      // Get classes for this day
      List<ClassSession> dayClasses;
      if (getEventsForDay != null) {
        dayClasses = getEventsForDay(date);
      } else {
        dayClasses = allSessions.where((s) => s.day == dayName).toList();
      }

      for (var session in dayClasses) {
        // Parse the start time
        final parts = session.startTime.split(':');
        if (parts.length != 2) continue;

        final classStart = DateTime(
          date.year, date.month, date.day,
          int.parse(parts[0]), int.parse(parts[1]),
        );

        // Generate a stable ID from date + session data
        final stableId = (date.day * 10000 + int.parse(parts[0]) * 100 + int.parse(parts[1]) + session.subject.hashCode).abs() % 2000000000;

        await scheduleClassReminder(
          id: stableId,
          subject: session.subject,
          room: session.room,
          classStartTime: classStart,
        );
      }
    }
  }

  /// Cancel ALL class reminders for the rest of today.
  Future<void> cancelTodayReminders(List<ClassSession> todayClasses) async {
    final now = DateTime.now();
    for (var session in todayClasses) {
      final parts = session.startTime.split(':');
      if (parts.length != 2) continue;

      final stableId = (now.day * 10000 + int.parse(parts[0]) * 100 + int.parse(parts[1]) + session.subject.hashCode).abs() % 2000000000;
      await cancelReminder(stableId);
    }
  }

  /// Check if the user declared "No Class Today"
  Future<bool> isNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('no_class_date');
    if (savedDate == null) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return savedDate == today;
  }

  /// Set today as a "No Class" day
  Future<void> setNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('no_class_date', today);
  }

  /// Clear the "No Class Today" flag
  Future<void> clearNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('no_class_date');
  }
}
