import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/class_session.dart';
import '../services/isar_service.dart';

class TimetableProvider extends ChangeNotifier {
  final IsarService isarService;
  
  List<ClassSession> _userSessions = [];
  List<ClassSession> _friendSessions = [];
  
  // A map of day -> list of free time strings (e.g., "Monday" -> ["08:00 - 09:30", "12:30 - 13:00"])
  Map<String, List<String>> _commonFreeTime = {};

  TimetableProvider(this.isarService);

  List<ClassSession> get userSessions => _userSessions;
  List<ClassSession> get friendSessions => _friendSessions;
  Map<String, List<String>> get commonFreeTime => _commonFreeTime;

  Future<void> loadSessions() async {
    final isar = await isarService.db;
    _userSessions = await isar.classSessions.filter().isUserEqualTo(true).findAll();
    _friendSessions = await isar.classSessions.filter().isUserEqualTo(false).findAll();
    
    _calculateCommonFreeTime();
    notifyListeners();
  }

  Future<void> addSession(ClassSession session) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.classSessions.put(session);
    });
    await loadSessions();
  }

  // --- Logic for Free Time Comparison ---

  void _calculateCommonFreeTime() {
    _commonFreeTime.clear();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    
    for (var day in days) {
      // Get all intervals for this day
      final dailyUserSessions = _userSessions.where((s) => s.day == day).toList();
      final dailyFriendSessions = _friendSessions.where((s) => s.day == day).toList();
      
      final busyIntervals = <_TimeInterval>[];
      
      for (var s in [...dailyUserSessions, ...dailyFriendSessions]) {
        busyIntervals.add(_TimeInterval(
          start: _timeToMinutes(s.startTime),
          end: _timeToMinutes(s.endTime),
        ));
      }

      // Sort by start time
      busyIntervals.sort((a, b) => a.start.compareTo(b.start));

      // Merge overlapping intervals
      final mergedIntervals = <_TimeInterval>[];
      if (busyIntervals.isNotEmpty) {
        var current = busyIntervals.first;
        for (var i = 1; i < busyIntervals.length; i++) {
          if (busyIntervals[i].start < current.end) {
            // Overlop or adjacent
            current.end = busyIntervals[i].end > current.end ? busyIntervals[i].end : current.end;
          } else {
            mergedIntervals.add(current);
            current = busyIntervals[i];
          }
        }
        mergedIntervals.add(current);
      }

      // Find gaps between 08:00 (480) and 16:00 (960)
      final freeSlots = <String>[];
      int currentPointer = 480; // 8:00 AM
      const endOfDay = 960;     // 4:00 PM

      for (var interval in mergedIntervals) {
        if (interval.start > currentPointer) {
          // Found a gap
          freeSlots.add("${_minutesToTime(currentPointer)} - ${_minutesToTime(interval.start)}");
        }
        currentPointer = interval.end > currentPointer ? interval.end : currentPointer;
      }

      if (currentPointer < endOfDay) {
        freeSlots.add("${_minutesToTime(currentPointer)} - ${_minutesToTime(endOfDay)}");
      }

      if (freeSlots.isNotEmpty) {
        _commonFreeTime[day] = freeSlots;
      }
    }
  }

  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  String _minutesToTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }
}

class _TimeInterval {
  int start;
  int end;
  _TimeInterval({required this.start, required this.end});
}
