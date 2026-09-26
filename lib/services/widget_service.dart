import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../providers/timetable_provider.dart';
import 'notification_service.dart';
import '../utils/time_utils.dart';

/// Service to update Android/iOS home screen widgets with
/// the latest class and task information.
class WidgetService {
  static const _androidWidgetName = 'UomperWidgetProvider';

  /// Call this whenever data changes — after loadSessions, addTask, etc.
  static Future<void> updateWidget(TimetableProvider timetable) async {
    try {
      final now = DateTime.now();

      // ── Next Class ──
      String className = 'No upcoming classes';
      String classDetail = '';
      String nextLabel = 'NEXT CLASS';

      final isNoClassToday = await NotificationService().isNoClassToday();

      final todaySessions = timetable.getClassesForDate(now);
      final currentWeek = timetable.getWeekNumber(now);

      if (isNoClassToday) {
        className = 'No Classes Today 🌴';
        classDetail = 'You declared a day off! Enjoy your freedom.';
        nextLabel = 'FREE DAY';
      } else {
        final next = timetable.findNextClass(now);
        if (next != null) {
          final s = next.session;
          className = s.subject;
          if (next.inProgress) {
            classDetail = '${s.room} • ${next.minutesUntilEnd(now)}m remaining';
            nextLabel = 'IN CLASS NOW';
          } else if (isSameDate(next.date, now)) {
            classDetail = '${s.room} • ${s.startTime} - ${s.endTime}';
            nextLabel = 'IN ${formatCountdown(next.minutesUntilStart(now)).toUpperCase()}';
          } else {
            final days = next.date.difference(dateOnly(now)).inDays;
            classDetail = '${s.room} • ${s.startTime} - ${s.endTime}';
            nextLabel = (days == 1 ? 'Tomorrow' : DateFormat('EEE').format(next.date)).toUpperCase();
          }
        }
      }

      // ── Upcoming Task ──
      String taskName = 'No pending tasks';
      String taskDetail = '';
      
      final pending = timetable.pendingTasks;
      if (pending.isNotEmpty) {
        final sorted = List.from(pending)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final nearest = sorted.first;
        taskName = nearest.title;
        final today = DateTime(now.year, now.month, now.day);
        final taskDate = DateTime(nearest.dueDate.year, nearest.dueDate.month, nearest.dueDate.day);
        final daysLeft = taskDate.difference(today).inDays;
        final typeEmoji = {
          'Exam': '🔴',
          'Test': '🟠',
          'Assignment': '🔵',
          'Homework': '📗',
          'Project': '🟣',
        }[nearest.type] ?? '⚪';
        
        if (daysLeft < 0) {
          taskDetail = '$typeEmoji ${nearest.subject} • OVERDUE';
        } else if (daysLeft == 0) {
          taskDetail = '$typeEmoji ${nearest.subject} • Due TODAY';
        } else if (daysLeft == 1) {
          taskDetail = '$typeEmoji ${nearest.subject} • Due TOMORROW';
        } else {
          taskDetail = '$typeEmoji ${nearest.subject} • ${daysLeft}d left';
        }
      }

      // ── Week Badge ──
      String weekBadge = currentWeek >= 1 
          ? 'Week $currentWeek${timetable.isOnlineWeek(currentWeek) ? " • Online" : ""}'
          : 'Pre-Semester';

      // ── Native Widget JSON Serialization ──
      final todayClassesJson = isNoClassToday ? [] : todaySessions.map((s) => ({
        'subject': s.subject,
        'room': s.room,
        'startTime': s.startTime,
        'endTime': s.endTime,
      })).toList();

      final pendingTasksJson = pending.map((t) => ({
        'title': t.title,
        'subject': t.subject,
        'dueDate': t.dueDate.toIso8601String(),
        'type': t.type,
      })).toList();

      // ── Save to SharedPreferences for native widget ──
      await HomeWidget.saveWidgetData('className', className);
      await HomeWidget.saveWidgetData('classDetail', classDetail);
      await HomeWidget.saveWidgetData('nextLabel', nextLabel);
      await HomeWidget.saveWidgetData('taskName', taskName);
      await HomeWidget.saveWidgetData('taskDetail', taskDetail);
      await HomeWidget.saveWidgetData('weekBadge', weekBadge);
      
      // New JSON properties for the native timeline calculation
      await HomeWidget.saveWidgetData('widget_classes_json', jsonEncode(todayClassesJson));
      await HomeWidget.saveWidgetData('widget_tasks_json', jsonEncode(pendingTasksJson));

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.example.uom_per_app.UomperWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: 'TaskWidgetProvider',
        qualifiedAndroidName: 'com.example.uom_per_app.TaskWidgetProvider',
      );
    } catch (e) {
      // Silently fail — widget is optional
      debugPrint('Widget update failed: $e');
    }
  }
}
