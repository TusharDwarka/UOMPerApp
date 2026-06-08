import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../providers/timetable_provider.dart';

/// Service to update Android/iOS home screen widgets with
/// the latest class and task information.
class WidgetService {
  static const _androidWidgetName = 'UomperWidgetProvider';

  /// Call this whenever data changes — after loadSessions, addTask, etc.
  static Future<void> updateWidget(TimetableProvider timetable) async {
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      // ── Next Class ──
      String className = 'No upcoming classes';
      String classDetail = '';
      String nextLabel = 'NEXT CLASS';

      // Check today's classes
      final todaySessions = timetable.getEventsForDay(now);
      todaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Currently in class?
      for (var s in todaySessions) {
        final startParts = s.startTime.split(':');
        final endParts = s.endTime.split(':');
        final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        if (nowMinutes >= startMins && nowMinutes < endMins) {
          final remaining = endMins - nowMinutes;
          className = s.subject;
          classDetail = '${s.room} • ${remaining}m remaining';
          nextLabel = 'IN CLASS NOW';
          break;
        }
      }

      // If not in class, find next upcoming
      if (nextLabel == 'NEXT CLASS') {
        for (var s in todaySessions) {
          final parts = s.startTime.split(':');
          final startMins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          if (startMins > nowMinutes) {
            final diff = startMins - nowMinutes;
            className = s.subject;
            classDetail = '${s.room} • ${s.startTime} - ${s.endTime}';
            if (diff < 60) {
              nextLabel = 'IN ${diff}m';
            } else {
              nextLabel = 'IN ${diff ~/ 60}h ${diff % 60}m';
            }
            break;
          }
        }
      }

      // If no more today, check tomorrow
      if (nextLabel == 'NEXT CLASS') {
        for (int d = 1; d <= 7; d++) {
          final futureDate = now.add(Duration(days: d));
          final week = timetable.getWeekNumber(futureDate);
          if (week < 1 || timetable.isOnlineWeek(week)) continue;
          
          final classes = timetable.getEventsForDay(futureDate);
          if (classes.isNotEmpty) {
            classes.sort((a, b) => a.startTime.compareTo(b.startTime));
            final first = classes.first;
            className = first.subject;
            final dayLabel = d == 1 ? 'Tomorrow' : DateFormat('EEE').format(futureDate);
            classDetail = '${first.room} • ${first.startTime} - ${first.endTime}';
            nextLabel = dayLabel.toUpperCase();
            break;
          }
        }
      }

      // Check online week
      final currentWeek = timetable.getWeekNumber(now);
      if (currentWeek >= 1 && timetable.isOnlineWeek(currentWeek) && nextLabel == 'NEXT CLASS') {
        className = 'Online Week';
        classDetail = 'No campus classes this week';
        nextLabel = 'WEEK $currentWeek';
      }

      // ── Upcoming Task ──
      String taskName = 'No pending tasks';
      String taskDetail = '';
      
      final pending = timetable.pendingTasks;
      if (pending.isNotEmpty) {
        final sorted = List.from(pending)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final nearest = sorted.first;
        taskName = nearest.title;
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
      final todayClasses = todaySessions.map((s) => {
        'subject': s.subject,
        'room': s.room,
        'startTime': s.startTime,
        'endTime': s.endTime,
      }).toList();

      final pendingTasksJson = pending.map((t) => {
        'title': t.title,
        'subject': t.subject,
        'dueDate': t.dueDate.toIso8601String(),
        'type': t.type,
      }).toList();

      // ── Save to SharedPreferences for native widget ──
      await HomeWidget.saveWidgetData('className', className);
      await HomeWidget.saveWidgetData('classDetail', classDetail);
      await HomeWidget.saveWidgetData('nextLabel', nextLabel);
      await HomeWidget.saveWidgetData('taskName', taskName);
      await HomeWidget.saveWidgetData('taskDetail', taskDetail);
      await HomeWidget.saveWidgetData('weekBadge', weekBadge);
      
      // New JSON properties for the native timeline calculation
      await HomeWidget.saveWidgetData('widget_classes_json', jsonEncode(todayClasses));
      await HomeWidget.saveWidgetData('widget_tasks_json', jsonEncode(pendingTasksJson));

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: 'TaskWidgetProvider',
      );
    } catch (e) {
      // Silently fail — widget is optional
      print('Widget update failed: $e');
    }
  }
}
