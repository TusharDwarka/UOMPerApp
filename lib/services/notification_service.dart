import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/class_session.dart';
import '../utils/ids.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Scheduled reminders are only supported on Android/iOS. On Windows the
  /// plugin would throw during init (it requires Windows-specific settings),
  /// which used to crash the desktop app at startup.
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _prefsEnabled = 'class_reminders_enabled';
  static const _prefsScheduledIds = 'scheduled_reminder_ids';

  Future<void> init() async {
    if (_isInitialized || !isSupported) return;

    try {
      tz.initializeTimeZones();

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Reminders default to ON (the Settings switch already showed ON by
  /// default, but this used to default to OFF, so nothing was scheduled).
  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabled) ?? true;
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      return granted ?? false;
    }
    final ios = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<void> scheduleClassReminder({
    required int id,
    required String subject,
    required String room,
    required DateTime classStartTime,
    int minutesBefore = 15,
    bool force = false,
  }) async {
    if (!_isInitialized) return;
    if (force) {
      await requestPermissions();
    } else if (!await areRemindersEnabled()) {
      return;
    }

    final reminderTime = classStartTime.subtract(Duration(minutes: minutesBefore));
    if (reminderTime.isBefore(DateTime.now())) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Upcoming: $subject',
        body: minutesBefore == 0 ? 'Starting now at $room' : 'Starts in $minutesBefore min at $room',
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_reminders',
            'Class Reminders',
            channelDescription: 'Notifications for upcoming classes',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // Exact alarms can be denied on Android 14+; fall back to inexact.
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: 'Upcoming: $subject',
          body: 'Starts in $minutesBefore min at $room',
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('class_reminders', 'Class Reminders'),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('Could not schedule reminder: $e2');
      }
    }
  }

  Future<void> cancelReminder(int id) async {
    if (!_isInitialized) return;
    await _notificationsPlugin.cancel(id: id);
  }

  static int reminderIdFor(DateTime date, ClassSession session) {
    final key = '${DateFormat('yyyyMMdd').format(date)}|${session.startTime}|${session.subject}';
    return stableHash(key) % 2000000000;
  }

  /// Schedules reminders for all classes in the next 7 days.
  ///
  /// Previously-scheduled class reminders are cancelled first, so deleting
  /// or moving a class no longer leaves a stale notification behind.
  Future<void> scheduleAllUpcomingClasses(
    List<ClassSession> allSessions, {
    List<ClassSession> Function(DateTime)? getEventsForDay,
    int minutesBefore = 15,
  }) async {
    if (!_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    for (final old in prefs.getStringList(_prefsScheduledIds) ?? const <String>[]) {
      final id = int.tryParse(old);
      if (id != null) await cancelReminder(id);
    }
    await prefs.setStringList(_prefsScheduledIds, []);

    if (!await areRemindersEnabled()) return;

    final noClassToday = await isNoClassToday();
    final scheduled = <String>[];
    final now = DateTime.now();
    for (int d = 0; d < 7; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      if (d == 0 && noClassToday) continue;

      final dayName = DateFormat('EEEE').format(date);
      final dayClasses = getEventsForDay != null ? getEventsForDay(date) : allSessions.where((s) => s.day == dayName).toList();

      for (final session in dayClasses) {
        final start = date.add(Duration(minutes: session.startMinutes));
        final id = reminderIdFor(date, session);
        await scheduleClassReminder(
          id: id,
          subject: session.subject,
          room: session.room,
          classStartTime: start,
          minutesBefore: minutesBefore,
        );
        scheduled.add('$id');
      }
    }
    await prefs.setStringList(_prefsScheduledIds, scheduled);
  }

  /// Cancel all class reminders for today.
  Future<void> cancelTodayReminders(List<ClassSession> todayClasses) async {
    final today = DateTime.now();
    for (final session in todayClasses) {
      await cancelReminder(reminderIdFor(DateTime(today.year, today.month, today.day), session));
    }
  }

  Future<bool> isNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('no_class_date');
    if (savedDate == null) return false;
    return savedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> setNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('no_class_date', DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  Future<void> clearNoClassToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('no_class_date');
  }

  // ───────────── Sunday summary ─────────────

  static const _summaryKey = 'weekly_summary';
  static const _prefsSummary = 'weekly_summary_enabled';

  Future<bool> isWeeklySummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsSummary) ?? true;
  }

  Future<void> setWeeklySummaryEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsSummary, on);
    if (!on) await cancelOneOff(_summaryKey);
  }

  /// Schedules next Sunday 18:00 with the coming Mon–Sun's deadlines and
  /// exams. Re-run whenever tasks change so the summary stays current.
  Future<void> scheduleWeeklySummary(List<({String title, String type, DateTime due})> tasks) async {
    if (!_isInitialized) return;
    await cancelOneOff(_summaryKey);
    if (!await isWeeklySummaryEnabled()) return;

    final now = DateTime.now();
    var sunday = DateTime(now.year, now.month, now.day + (DateTime.sunday - now.weekday) % 7, 18);
    if (!sunday.isAfter(now)) sunday = sunday.add(const Duration(days: 7));
    final weekStart = DateTime(sunday.year, sunday.month, sunday.day + 1);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final upcoming = tasks.where((t) => !t.due.isBefore(weekStart) && t.due.isBefore(weekEnd)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));

    final exams = upcoming.where((t) => t.type == 'Exam' || t.type == 'Test').length;
    final String body;
    if (upcoming.isEmpty) {
      body = 'Nothing due next week — a good time to get ahead.';
    } else {
      final list = upcoming.take(4).map((t) => '${t.title} (${DateFormat('EEE').format(t.due)})').join(', ');
      body = '${upcoming.length} due${exams > 0 ? ', $exams exam${exams == 1 ? '' : 's'}/test${exams == 1 ? '' : 's'}' : ''}: '
          '$list${upcoming.length > 4 ? '…' : ''}';
    }
    await scheduleOneOff(key: _summaryKey, title: 'Your week ahead 🗓', body: body, at: sunday);
  }

  // ───────────── Group "class coming up" nudges (local only) ─────────────

  /// Schedules a one-off local notification (used for group events and the
  /// focus timer). Ids are derived from [key] so re-scheduling is idempotent.
  Future<void> scheduleOneOff({
    required String key,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_isInitialized || at.isBefore(DateTime.now())) return;
    try {
      await _notificationsPlugin.zonedSchedule(
        id: stableHash(key) % 2000000000,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('general', 'General', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('scheduleOneOff failed: $e');
    }
  }

  Future<void> cancelOneOff(String key) => cancelReminder(stableHash(key) % 2000000000);
}
