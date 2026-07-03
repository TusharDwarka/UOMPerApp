import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';
import '../models/attendance_record.dart';
import '../services/isar_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';

class TimetableProvider extends ChangeNotifier {
  final IsarService isarService;
  
  // Restored Fields
  List<ClassSession> _userSessions = [];
  List<ClassSession> _friendSessions = [];
  Map<String, List<CommonFreeSlot>> _commonFreeTime = {};
  
  // Attendance
  List<AttendanceRecord> _attendanceRecords = [];

  // Adaptive Timetable Fields
  String _courseName = '';
  bool _hasCompletedSetup = false;
  
  String get courseName => _courseName;
  bool get hasCompletedSetup => _hasCompletedSetup;
  
  TimetableProvider(this.isarService);

  /// Load setup state from SharedPreferences (called early in app init)
  Future<void> loadSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    _courseName = prefs.getString('courseName') ?? '';
    _hasCompletedSetup = prefs.getBool('hasCompletedSetup') ?? false;
    
    // Load configurable semester start
    final semesterStartMs = prefs.getInt('semesterStartMs');
    if (semesterStartMs != null) {
      _semesterStart = DateTime.fromMillisecondsSinceEpoch(semesterStartMs);
    }

    final semesterEndMs = prefs.getInt('semesterEndMs');
    if (semesterEndMs != null) {
      _semesterEnd = DateTime.fromMillisecondsSinceEpoch(semesterEndMs);
    }
    notifyListeners();
  }

  Future<void> setCourseName(String name) async {
    _courseName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courseName', name);
    notifyListeners();
  }

  Future<void> setSemesterDates(DateTime start, DateTime? end) async {
    _semesterStart = start;
    _semesterEnd = end;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('semesterStartMs', start.millisecondsSinceEpoch);
    if (end != null) {
      await prefs.setInt('semesterEndMs', end.millisecondsSinceEpoch);
    } else {
      await prefs.remove('semesterEndMs');
    }
    notifyListeners();
  }

  Future<void> setSetupCompleted(bool completed) async {
    _hasCompletedSetup = completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedSetup', completed);
    notifyListeners();
  }

  /// Import sessions parsed by AI. Clears existing user sessions and saves new ones.
  Future<void> importAiSessions(List<ClassSession> sessions) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      // Clear only user sessions (keep friend sessions if any)
      final existingUser = await isar.classSessions.filter().isUserEqualTo(true).findAll();
      for (final s in existingUser) {
        await isar.classSessions.delete(s.id);
      }
      // Save new AI-parsed sessions
      for (final session in sessions) {
        await isar.classSessions.put(session);
      }
    });
    await loadSessions();
  }

  /// Reset everything for a fresh setup (re-onboarding)
  Future<void> resetForNewSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('courseName');
    await prefs.remove('hasCompletedSetup');
    await prefs.remove('semesterStartMs');
    await prefs.remove('semesterEndMs');
    _courseName = '';
    _hasCompletedSetup = false;
    _semesterStart = DateTime.now();
    _semesterEnd = null;
    
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.classSessions.clear();
    });
    await loadSessions();
  }

  Future<void> loadAttendance() async {
    final isar = await isarService.db;
    _attendanceRecords = await isar.attendanceRecords.where().findAll();
    notifyListeners();
  }

  bool isPresent(String subject, DateTime date) {
    // If no record exists, assume present by default (or we can assume 'unknown')
    // For this tracker, let's assume 'unknown' but visually default to green?
    // Actually, distinct records are better.
    final record = _attendanceRecords.firstWhere(
      (r) => r.subjectName == subject && isSameDay(r.date, date),
      orElse: () => AttendanceRecord()..isPresent = true // Default to Present
    );
    return record.isPresent;
  }

  Future<void> toggleAttendance(String subject, DateTime date) async {
    final isar = await isarService.db;
    
    // Find existing - filter by subject and date
    final existing = await isar.attendanceRecords.filter()
        .subjectNameEqualTo(subject)
        .and()
        .dateEqualTo(date)
        .findFirst();

    if (existing != null) {
       existing.isPresent = !existing.isPresent;
       await isar.writeTxn(() async => await isar.attendanceRecords.put(existing));
    } else {
      // Create new "Absent" record (since default was Present)
      // Actually, if we toggle from "Default Present" -> "Absent"
      final newRecord = AttendanceRecord()
        ..subjectName = subject
        ..date = date
        ..isPresent = false;
      await isar.writeTxn(() async => await isar.attendanceRecords.put(newRecord));
    }
    
    await loadAttendance();
  }

  Future<void> setAttendance(String subject, DateTime date, bool isPresent) async {
    final isar = await isarService.db;
    
    // Find existing
    final existing = await isar.attendanceRecords.filter()
        .subjectNameEqualTo(subject)
        .and()
        .dateEqualTo(date)
        .findFirst();

    await isar.writeTxn(() async {
      if (existing != null) {
        existing.isPresent = isPresent;
        await isar.attendanceRecords.put(existing);
      } else {
        final newRecord = AttendanceRecord()
          ..subjectName = subject
          ..date = date
          ..isPresent = isPresent;
        await isar.attendanceRecords.put(newRecord);
      }
    });
    
    await loadAttendance();
    notifyListeners();
  }

  // Stats: 10 Skips Allowed PER MODULE
  Map<String, dynamic> getAttendanceStats(String subject) {
    const int maxSkips = 10;

    // Count current absences
    final absences = _attendanceRecords
        .where((r) => r.subjectName == subject && !r.isPresent)
        .length;

    // Lives left
    int lives = maxSkips - absences;
    
    String status = "Safe";
    if (lives <= 0) status = "CRITICAL"; // 0 lives means you used all 10 allowed skips? Or 0 means you have 0 skips left? 
    // "10 class missed in total not more" -> 10 lives. 
    // 0 absences = 10 lives. 10 absences = 0 lives. 
    // If lives < 0 ... technically eliminated?
    
    if (lives <= 0) status = "ELIMINATED";
    else if (lives <= 3) status = "Warning";

    return {
      'lives': lives > 0 ? lives : 0,
      'maxLives': maxSkips, // 10
      'absences': absences,
      'status': status
    };
  }
  
  Future<void> loadSessions() async {
    final isar = await isarService.db;
    _userSessions = await isar.classSessions.filter().isUserEqualTo(true).findAll();
    _friendSessions = await isar.classSessions.filter().isUserEqualTo(false).findAll();
    
    // Load persisted perspective
    final prefs = await SharedPreferences.getInstance();
    _isSwapped = prefs.getBool('isSwapped') ?? false;

    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    
    // Load Attendance too
    await loadAttendance();
    
    notifyListeners();
    
    // Update home screen widget
    WidgetService.updateWidget(this);
    
    // Auto-schedule class reminders for the next 7 days
    NotificationService().scheduleAllUpcomingClasses(
      _userSessions,
      getEventsForDay: (date) => getEventsForDay(date),
    );
  }
  
  // --- Attendance Logic ---

  Future<void> resetAttendance() async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.attendanceRecords.clear();
    });
    await loadAttendance();
  }

  // Global Survival Stats: 10 Lives Total Rule
  Map<String, dynamic> getGlobalSurvivalStats() {
    const int maxLives = 10;
    
    // Count total absences (where isPresent == false)
    final totalAbsences = _attendanceRecords.where((r) => !r.isPresent).length;
    
    final livesLeft = maxLives - totalAbsences;
    
    String status = "Safe";
    if (livesLeft <= 0) status = "Eliminated";
    else if (livesLeft <= 3) status = "Danger";
    else if (livesLeft <= 6) status = "Warning";
    
    return {
      'lives': livesLeft > 0 ? livesLeft : 0,
      'maxLives': maxLives,
      'absences': totalAbsences,
      'status': status
    };
  }

  // Check for unmarked past/today classes
  List<ClassSession> getUnmarkedClasses(DateTime date) {
    // Get all user sessions for this day
    final sessions = getEventsForDay(date);
    
    // Filter those that don't have a record
    return sessions.where((s) {
       final record = getAttendanceRecord(s.subject, date);
       return record == null;
    }).toList();
  }
  
  // Per-Subject Stats (Secondary)
  Map<String, dynamic> getSubjectStats(String subject) {
    // Just count absences for this subject
    final absences = _attendanceRecords
        .where((r) => r.subjectName == subject && !r.isPresent)
        .length;
        
    return {
      'absences': absences
    };
  }

  // Getters
  // If swapped, return Friend sessions as "User" sessions (Main view)
  List<ClassSession> get userSessions => _isSwapped ? _friendSessions : _userSessions;
  
  // If swapped, return User sessions as "Friend" sessions (Ghost view)
  List<ClassSession> get friendSessions => _isSwapped ? _userSessions : _friendSessions;
  
  bool _isSwapped = false;
  bool get isSwapped => _isSwapped;

  void togglePerspective() {
    _isSwapped = !_isSwapped;
    _persistPerspective();
    notifyListeners();
  }

  void setPerspective(bool isSwapped) {
    if (_isSwapped != isSwapped) {
      _isSwapped = isSwapped;
      _persistPerspective();
      notifyListeners();
    }
  }

  Future<void> _persistPerspective() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSwapped', _isSwapped);
  }

  List<AcademicTask> _tasks = [];
  List<AcademicTask> get tasks => _tasks;
  
  // Computed properties for Dashboard
  List<AcademicTask> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<AcademicTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  // Helpers
  // Configurable semester start — loaded from SharedPreferences, fallback to Jan 19 2026
  DateTime _semesterStart = DateTime(2026, 1, 19);
  DateTime? _semesterEnd;
  DateTime get semesterStart => _semesterStart;
  DateTime? get semesterEnd => _semesterEnd;

  int getWeekNumber(DateTime date) {
    // Normalize dates to midnight to avoid time discrepancies
    final start = DateTime(_semesterStart.year, _semesterStart.month, _semesterStart.day);
    final current = DateTime(date.year, date.month, date.day);
    
    if (current.isBefore(start)) return 0;
    final diff = current.difference(start).inDays;
    return (diff / 7).floor() + 1;
  }

  bool _shouldShowSession(ClassSession session, DateTime date) {
    if (session.specificDate != null) {
      return isSameDay(date, session.specificDate!);
    }

    // Check semester bounds
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(_semesterStart.year, _semesterStart.month, _semesterStart.day);
    if (normalizedDate.isBefore(normalizedStart)) return false;
    
    if (_semesterEnd != null) {
      final normalizedEnd = DateTime(_semesterEnd!.year, _semesterEnd!.month, _semesterEnd!.day);
      if (normalizedDate.isAfter(normalizedEnd)) return false;
    }

    // If no weeks specified, assume it runs every week
    if (session.weeks == null || session.weeks!.isEmpty) return true;
    
    final week = getWeekNumber(date);
    return session.weeks!.contains(week);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String getWeekLabel(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(_semesterStart.year, _semesterStart.month, _semesterStart.day);
    if (normalizedDate.isBefore(normalizedStart)) return "Pre-Sem";
    
    if (_semesterEnd != null) {
      final normalizedEnd = DateTime(_semesterEnd!.year, _semesterEnd!.month, _semesterEnd!.day);
      if (normalizedDate.isAfter(normalizedEnd)) return "Break";
    }

    final w = getWeekNumber(date);
    if (w > 15) return "Break";
    
    final online = isOnlineWeek(w);
    return "Week $w${online ? ' (Online)' : ''}";
  }

  List<ClassSession> getEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    // Filter sessions by Day AND Week
    return userSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
  }
  
  // Get all classes for a specific date — always uses _userSessions directly
  // and also catches one-off classes whose specificDate matches even if day name doesn't
  List<ClassSession> getClassesForDate(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return _userSessions.where((s) {
      // One-off class: match by specificDate only
      if (s.specificDate != null) {
        return isSameDay(date, s.specificDate!);
      }
      // Regular class: match by day name + semester/week bounds
      return s.day == dayName && _shouldShowSession(s, date);
    }).toList();
  }

  // Calculate past/valid dates from Semester Start (Jan 19, 2026) going forward
  List<DateTime> getPastClassDates(String subject) {
    final sessions = userSessions.where((s) => s.subject == subject).toList(); // Use userSessions getter to respect View
    if (sessions.isEmpty) return [];
    
    final validDays = sessions.map((s) => s.day).toSet(); 
    
    List<DateTime> dates = [];
    DateTime iterator = _semesterStart; // Jan 19
    DateTime today = DateTime.now();
    // Normalize today to Midnight
    today = DateTime(today.year, today.month, today.day);
    
    // Iterate forward until Today
    while (iterator.isBefore(today) || isSameDay(iterator, today)) {
       final dayName = DateFormat('EEEE').format(iterator);
       
       if (validDays.contains(dayName)) {
         // Check if session active this week
         // We must find IF there is a session for this subject on this day that is active
         bool isActive = sessions.any((s) => s.day == dayName && _shouldShowSession(s, iterator));
         if (isActive) {
           dates.add(iterator);
         }
       }
       iterator = iterator.add(const Duration(days: 1));
    }
    
    // Sort recent first
    return dates.reversed.toList();
  }
  
  // Check if attendance is marked for a specific date/subject
  AttendanceRecord? getAttendanceRecord(String subject, DateTime date) {
    // We need exact date matching at 00:00:00 usually. 
    // The date passed in should be normalized.
    final normalized = DateTime(date.year, date.month, date.day);
    
    try {
      return _attendanceRecords.firstWhere(
        (r) => r.subjectName == subject && 
               r.date.year == normalized.year && 
               r.date.month == normalized.month && 
               r.date.day == normalized.day
      );
    } catch (e) {
      return null;
    }
  }

  
  List<AcademicTask> getTasksForDay(DateTime date) {
    return _tasks.where((t) => isSameDay(t.dueDate, date)).toList();
  }

  // Friend Helpers — uses the swapped getter so it always returns the "other" course
  List<ClassSession> getFriendEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return friendSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
  }

  List<CommonFreeSlot> getFreeSlotsForDay(DateTime date) {
    if (isOnlineWeek(getWeekNumber(date))) {
      return []; // No physical meetings on Online weeks
    }

    final dayName = DateFormat('EEEE').format(date);
    
    // Use SWAPPED getters so comparison works from both perspectives
    // userSessions = current user's timetable (respects swap)
    // friendSessions = the other course's timetable (respects swap)
    final dailyUser = userSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();

    final dailyFriend = friendSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
    
    // 2. Check Campus Presence: Both must have at least one NON-ONLINE class
    // If list is empty or all classes are ONLINE, assume not on campus.
    final userOnCampus = dailyUser.isNotEmpty && dailyUser.any((s) => !s.room.toUpperCase().contains('ONLINE'));
    final friendOnCampus = dailyFriend.isNotEmpty && dailyFriend.any((s) => !s.room.toUpperCase().contains('ONLINE'));

    if (!userOnCampus || !friendOnCampus) {
      return []; 
    }

    // Bounds: 8:00 (480) to 17:30 (1050)
    final timeBounds = _TimeInterval(start: 480, end: 1050);
    
    final busy = <_TimeInterval>[];
    for (var s in [...dailyUser, ...dailyFriend]) {
      busy.add(_TimeInterval(start: _timeToMinutes(s.startTime), end: _timeToMinutes(s.endTime)));
    }
    busy.sort((a,b) => a.start.compareTo(b.start));
    
    // Merge Overlapping Busy Slots
    final merged = <_TimeInterval>[];
    if (busy.isNotEmpty) {
      var current = busy.first;
      for (var i = 1; i < busy.length; i++) {
         if (busy[i].start < current.end) {
           current.end = busy[i].end > current.end ? busy[i].end : current.end;
         } else {
           merged.add(current);
           current = busy[i];
         }
      }
      merged.add(current);
    }
    
    // Invert for Free Time
    final freeSlots = <CommonFreeSlot>[];
    int pointer = timeBounds.start;
    
    for (var block in merged) {
       if (block.start > pointer) {
         // Gap found
         freeSlots.add(CommonFreeSlot(start: pointer, end: block.start));
       }
       pointer = block.end > pointer ? block.end : pointer;
    }
    
    if (pointer < timeBounds.end) {
      freeSlots.add(CommonFreeSlot(start: pointer, end: timeBounds.end));
    }
    
    // Filter out tiny slots (< 30 mins)
    return freeSlots.where((s) => (s.end - s.start) >= 30).toList();
  }

  bool isOnlineWeek(int week) {
    // For generic/adaptive courses, all weeks are campus by default.
    // The old DS/CS hardcoded campus weeks were [1, 2, 3, 6, 10].
    // In the adaptive system, we treat every week as campus unless configured otherwise.
    return false;
  }

  // Task Management
  Future<void> addTask(String title, String subject, String type, DateTime due, {String description = ''}) async {
     final isar = await isarService.db;
     final newTask = AcademicTask(
       title: title, 
       subject: subject, 
       type: type, 
       dueDate: due, 
       description: description,
       isCompleted: false
     );
     await isar.writeTxn(() async => await isar.academicTasks.put(newTask));
     await loadSessions(); 
  }

  Future<void> updateTask(int id, String title, String subject, String type, DateTime dueDate, bool isCompleted, {String description = ''}) async {
     final isar = await isarService.db;
     await isar.writeTxn(() async {
       final task = await isar.academicTasks.get(id);
       if (task != null) {
         task.title = title;
         task.subject = subject;
         task.type = type;
         task.dueDate = dueDate;
         task.isCompleted = isCompleted;
         task.description = description;
         await isar.academicTasks.put(task);
       }
     });
     await loadSessions();
  }

  // Unique subjects from existing tasks for autocomplete
  List<String> get savedSubjects {
    final subjects = _tasks.map((t) => t.subject).where((s) => s.isNotEmpty && s != 'General').toSet().toList();
    subjects.sort();
    return subjects;
  }

  Future<void> deleteTask(int id) async {
     final isar = await isarService.db;
     await isar.writeTxn(() async => await isar.academicTasks.delete(id));
     await loadSessions();
  }

  // Session Management
  Future<void> addSession(ClassSession session) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.classSessions.put(session);
    });
    await loadSessions();
  }
  
  Future<void> deleteSession(int id) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.classSessions.delete(id);
    });
    await loadSessions();
  }

  /* ================================================================
   * OMITTED — Old Semester Data (Y1 S2 - Data Science & Computer Science)
   * 
   * The hardcoded DS/CS timetable JSON that was here has been omitted
   * in favor of the new adaptive AI-powered timetable import system.
   * The original data is preserved in the json/ directory as:
   *   - json/DSS2Y1.json (Data Science)
   *   - json/CSS2Y1.json (Computer Science)
   * 
   * To restore the old behavior, see git history.
   * ================================================================ */

  // Legacy: Seed data loader — now a no-op in the adaptive system.
  // Kept for backward compatibility with code that calls it.
  Future<void> loadFriendTimetable() async {
     // In the adaptive system, this is replaced by importAiSessions().
     // If called, just reload whatever sessions exist in the DB.
     await loadSessions();
  }

  void _importSessions(Isar isar, Map<String, dynamic> timetable, bool isUser) {
    timetable.forEach((day, sessions) {
      for (var s in sessions as List<dynamic>) {
         // Parse weeks
         List<int>? weeksList;
         if (s['weeks'] != null) {
            weeksList = (s['weeks'] as List).map((e) => e as int).toList();
         }

         final session = ClassSession(
            subject: s['moduleName'],
            startTime: s['startTime'],
            endTime: s['endTime'],
            day: day,
            room: s['location'] ?? 'Unknown',
            moduleCode: s['moduleCode'] ?? '',
            isUser: isUser,
            weeks: weeksList
         );
         isar.classSessions.put(session);
      }
    });
  }

  void _calculateCommonFreeTime() {
    // Deprecated: Now we calculate strictly per day in getFreeSlotsForDay
    _commonFreeTime.clear();
  }

  // Time Utility
  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }
} // End of Class

class CommonFreeSlot {
  final int start; // minutes from midnight
  final int end;   // minutes from midnight
  CommonFreeSlot({required this.start, required this.end});
  
  String get label => "${_minToTime(start)} - ${_minToTime(end)}";
  
  static String _minToTime(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final min = (m % 60).toString().padLeft(2, '0');
    return "$h:$min";
  }
}

class _TimeInterval {
  int start;
  int end;
  _TimeInterval({required this.start, required this.end});
}
