import 'dart:async';

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
import '../services/sync_service.dart';
import '../utils/time_utils.dart';

/// What the dashboard, widget and groups show as "next class".
class UpcomingClass {
  final ClassSession session;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final bool inProgress;
  const UpcomingClass({required this.session, required this.date, required this.start, required this.end, required this.inProgress});

  int minutesUntilStart(DateTime now) => start.difference(now).inMinutes;
  int minutesUntilEnd(DateTime now) => end.difference(now).inMinutes;
}

class TimetableProvider extends ChangeNotifier {
  final IsarService isarService;
  final SyncService _syncService;
  StreamSubscription<Set<String>>? _syncSub;

  List<ClassSession> _userSessions = [];
  List<ClassSession> _friendSessions = [];
  List<AttendanceRecord> _attendanceRecords = [];
  List<AcademicTask> _tasks = [];

  // Adaptive Timetable Fields
  String _courseName = '';
  bool _hasCompletedSetup = false;
  bool _isSetupLoaded = false;
  int _reminderMinutes = 15;
  int _studyYear = 1; // 1..5
  int _semester = 1; // 1..2
  int _clearDoneAfterDays = 14; // 0 = never
  DateTime? _lastPurge;

  String get courseName => _courseName;
  bool get hasCompletedSetup => _hasCompletedSetup;
  bool get isSetupLoaded => _isSetupLoaded;
  int get reminderMinutes => _reminderMinutes;
  int get studyYear => _studyYear;
  int get semester => _semester;
  int get clearDoneAfterDays => _clearDoneAfterDays;

  TimetableProvider(this.isarService, this._syncService) {
    // Remote 'settings' changes are applied by SignedInGate (main.dart),
    // which updates this provider and ResourceProvider together.
    _syncSub = _syncService.changes.listen((cols) async {
      if (cols.any((c) => c != 'bus' && c != 'settings' && c != SyncService.notesCol)) {
        await loadSessions();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  /// Load setup state from SharedPreferences (called early in app init)
  Future<void> loadSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    _courseName = prefs.getString('courseName') ?? '';
    _hasCompletedSetup = prefs.getBool('hasCompletedSetup') ?? false;
    _reminderMinutes = prefs.getInt('reminder_minutes') ?? 15;
    _studyYear = prefs.getInt('study_year') ?? 1;
    _semester = prefs.getInt('semester') ?? 1;
    _clearDoneAfterDays = prefs.getInt('clear_done_days') ?? 14;

    final semesterStartMs = prefs.getInt('semesterStartMs');
    if (semesterStartMs != null) {
      _semesterStart = DateTime.fromMillisecondsSinceEpoch(semesterStartMs);
    }
    final semesterEndMs = prefs.getInt('semesterEndMs');
    _semesterEnd = semesterEndMs != null ? DateTime.fromMillisecondsSinceEpoch(semesterEndMs) : null;

    _isSetupLoaded = true;
    notifyListeners();
  }

  // ───────────── Cloud settings (course, semester, setup flag) ─────────────

  Map<String, dynamic> settingsSnapshot() => {
        'courseName': _courseName,
        'hasCompletedSetup': _hasCompletedSetup,
        'semesterStartMs': _semesterStart.millisecondsSinceEpoch,
        'semesterEndMs': _semesterEnd?.millisecondsSinceEpoch,
        'reminderMinutes': _reminderMinutes,
        'studyYear': _studyYear,
        'semester': _semester,
        'clearDoneAfterDays': _clearDoneAfterDays,
      };

  /// Applies settings pulled from the cloud. This is what lets a second
  /// device (e.g. the Windows app) skip onboarding after signing in.
  Future<void> applyCloudSettings(Map<String, dynamic> s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s['courseName'] is String && (s['courseName'] as String).isNotEmpty) {
      _courseName = s['courseName'];
      await prefs.setString('courseName', _courseName);
    }
    if (s['hasCompletedSetup'] == true && !_hasCompletedSetup) {
      _hasCompletedSetup = true;
      await prefs.setBool('hasCompletedSetup', true);
    }
    if (s['semesterStartMs'] is int) {
      _semesterStart = DateTime.fromMillisecondsSinceEpoch(s['semesterStartMs']);
      await prefs.setInt('semesterStartMs', s['semesterStartMs']);
    }
    if (s.containsKey('semesterEndMs')) {
      final end = s['semesterEndMs'];
      _semesterEnd = end is int ? DateTime.fromMillisecondsSinceEpoch(end) : null;
      if (end is int) {
        await prefs.setInt('semesterEndMs', end);
      } else {
        await prefs.remove('semesterEndMs');
      }
    }
    if (s['studyYear'] is int) {
      _studyYear = s['studyYear'];
      await prefs.setInt('study_year', _studyYear);
    }
    if (s['semester'] is int) {
      _semester = s['semester'];
      await prefs.setInt('semester', _semester);
    }
    if (s['clearDoneAfterDays'] is int) {
      _clearDoneAfterDays = s['clearDoneAfterDays'];
      await prefs.setInt('clear_done_days', _clearDoneAfterDays);
    }
    if (s['reminderMinutes'] is int) {
      _reminderMinutes = s['reminderMinutes'];
      await prefs.setInt('reminder_minutes', _reminderMinutes);
    }
    notifyListeners();
  }

  void _pushSettings() => _syncService.pushSettings(settingsSnapshot());

  Future<void> setCourseName(String name) async {
    _courseName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courseName', name);
    _pushSettings();
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
    _pushSettings();
    notifyListeners();
  }

  Future<void> setSetupCompleted(bool completed) async {
    _hasCompletedSetup = completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedSetup', completed);
    _pushSettings();
    notifyListeners();
  }

  Future<void> setStudyPeriod({int? year, int? semester}) async {
    final prefs = await SharedPreferences.getInstance();
    if (year != null) {
      _studyYear = year.clamp(1, 5);
      await prefs.setInt('study_year', _studyYear);
    }
    if (semester != null) {
      _semester = semester.clamp(1, 2);
      await prefs.setInt('semester', _semester);
    }
    _pushSettings();
    notifyListeners();
  }

  Future<void> setClearDoneAfterDays(int days) async {
    _clearDoneAfterDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clear_done_days', days);
    _pushSettings();
    notifyListeners();
    await purgeOldDoneTasks();
  }

  /// Deletes board items finished more than [clearDoneAfterDays] days ago.
  Future<int> purgeOldDoneTasks() async {
    if (_clearDoneAfterDays <= 0) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: _clearDoneAfterDays));
    final old = _tasks.where((t) => t.isCompleted && (t.updatedAt ?? t.dueDate).isBefore(cutoff)).toList();
    if (old.isEmpty) return 0;
    final isar = await isarService.db;
    await isar.writeTxn(() => isar.academicTasks.deleteAll(old.map((t) => t.id).toList()));
    await _syncService.pushDeleteMany(SyncService.tasksCol, old.map((t) => t.syncId));
    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    notifyListeners();
    return old.length;
  }

  Future<void> setReminderMinutes(int minutes) async {
    _reminderMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_minutes', minutes);
    _pushSettings();
    notifyListeners();
    await rescheduleReminders();
  }

  Future<void> rescheduleReminders() => NotificationService().scheduleAllUpcomingClasses(
        _userSessions,
        getEventsForDay: getClassesForDate,
        minutesBefore: _reminderMinutes,
      );

  /// Import sessions parsed by AI. Replaces the user's sessions.
  Future<void> importAiSessions(List<ClassSession> sessions) async {
    final isar = await isarService.db;
    final removed = await isar.classSessions.filter().isUserEqualTo(true).findAll();
    for (final s in sessions) {
      s.startTime = normalizeTime(s.startTime);
      s.endTime = normalizeTime(s.endTime);
      SyncService.stamp(s);
    }
    await isar.writeTxn(() async {
      await isar.classSessions.deleteAll(removed.map((s) => s.id).toList());
      await isar.classSessions.putAll(sessions);
    });
    await _syncService.pushDeleteMany(SyncService.sessionsCol, removed.map((s) => s.syncId));
    await _syncService.pushMany(SyncService.sessionsCol, sessions.map((s) => s.toSyncJson()).toList());
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
    final removed = await isar.classSessions.where().findAll();
    await isar.writeTxn(() async {
      await isar.classSessions.clear();
    });
    await _syncService.pushDeleteMany(SyncService.sessionsCol, removed.map((s) => s.syncId));
    await _syncService.pushSettings({
      'courseName': '',
      'hasCompletedSetup': false,
      'semesterStartMs': _semesterStart.millisecondsSinceEpoch,
      'semesterEndMs': null,
    });
    await loadSessions();
  }

  // ───────────────────────── Attendance ─────────────────────────

  Future<void> loadAttendance() async {
    final isar = await isarService.db;
    _attendanceRecords = await isar.attendanceRecords.where().findAll();
    notifyListeners();
  }

  bool isPresent(String subject, DateTime date) => getAttendanceRecord(subject, date)?.isPresent ?? true;

  Future<void> toggleAttendance(String subject, DateTime date) async {
    await setAttendance(subject, date, !isPresent(subject, date));
  }

  Future<void> setAttendance(String subject, DateTime date, bool isPresent) async {
    final isar = await isarService.db;
    final day = dateOnly(date);
    final existing = getAttendanceRecord(subject, day);
    final record = existing ??
        (AttendanceRecord()
          ..subjectName = subject
          ..date = day);
    record.isPresent = isPresent;
    SyncService.stamp(record);
    await isar.writeTxn(() => isar.attendanceRecords.put(record));
    _syncService.pushAttendance(record);
    await loadAttendance();
  }

  // Stats: 10 Skips Allowed PER MODULE
  Map<String, dynamic> getAttendanceStats(String subject) {
    const int maxSkips = 10;
    final absences = _attendanceRecords.where((r) => r.subjectName == subject && !r.isPresent).length;
    final presents = _attendanceRecords.where((r) => r.subjectName == subject && r.isPresent).length;
    final lives = maxSkips - absences;

    String status = "Safe";
    if (lives <= 0) {
      status = "ELIMINATED";
    } else if (lives <= 3) {
      status = "Warning";
    }

    final total = absences + presents;
    return {
      'lives': lives > 0 ? lives : 0,
      'maxLives': maxSkips,
      'absences': absences,
      'presents': presents,
      'rate': total == 0 ? 1.0 : presents / total,
      'status': status
    };
  }

  Future<void> loadSessions() async {
    final isar = await isarService.db;
    int byStart(ClassSession a, ClassSession b) => a.startMinutes.compareTo(b.startMinutes);
    _userSessions = (await isar.classSessions.filter().isUserEqualTo(true).findAll())..sort(byStart);
    _friendSessions = (await isar.classSessions.filter().isUserEqualTo(false).findAll())..sort(byStart);

    final prefs = await SharedPreferences.getInstance();
    _isSwapped = prefs.getBool('isSwapped') ?? false;

    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    _attendanceRecords = await isar.attendanceRecords.where().findAll();

    notifyListeners();

    // Tidy the Done column (at most hourly).
    final now = DateTime.now();
    if (_lastPurge == null || now.difference(_lastPurge!) > const Duration(hours: 1)) {
      _lastPurge = now;
      unawaited(purgeOldDoneTasks());
    }

    WidgetService.updateWidget(this);
    rescheduleReminders();
    NotificationService().scheduleWeeklySummary([
      for (final t in _tasks)
        if (!t.isCompleted) (title: t.title, type: t.type, due: t.dueDate)
    ]);
  }

  Future<void> resetAttendance() async {
    final isar = await isarService.db;
    final removed = List<AttendanceRecord>.from(_attendanceRecords);
    await isar.writeTxn(() async {
      await isar.attendanceRecords.clear();
    });
    await _syncService.pushDeleteMany(SyncService.attendanceCol, removed.map((r) => r.syncId));
    await loadAttendance();
  }

  // Global Survival Stats: 10 Lives Total Rule
  Map<String, dynamic> getGlobalSurvivalStats() {
    const int maxLives = 10;
    final totalAbsences = _attendanceRecords.where((r) => !r.isPresent).length;
    final livesLeft = maxLives - totalAbsences;

    String status = "Safe";
    if (livesLeft <= 0) {
      status = "Eliminated";
    } else if (livesLeft <= 3) {
      status = "Danger";
    } else if (livesLeft <= 6) {
      status = "Warning";
    }

    return {'lives': livesLeft > 0 ? livesLeft : 0, 'maxLives': maxLives, 'absences': totalAbsences, 'status': status};
  }

  List<ClassSession> getUnmarkedClasses(DateTime date) {
    return getClassesForDate(date).where((s) => getAttendanceRecord(s.subject, date) == null).toList();
  }

  Map<String, dynamic> getSubjectStats(String subject) {
    final absences = _attendanceRecords.where((r) => r.subjectName == subject && !r.isPresent).length;
    return {'absences': absences};
  }

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

  List<AcademicTask> get tasks => _tasks;
  List<AcademicTask> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<AcademicTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();
  List<AcademicTask> tasksWithStatus(String status) => _tasks.where((t) => t.effectiveStatus == status).toList();

  // Configurable semester start — loaded from SharedPreferences
  DateTime _semesterStart = DateTime(2026, 1, 19);
  DateTime? _semesterEnd;
  DateTime get semesterStart => _semesterStart;
  DateTime? get semesterEnd => _semesterEnd;

  int getWeekNumber(DateTime date) {
    final start = dateOnly(_semesterStart);
    final current = dateOnly(date);
    if (current.isBefore(start)) return 0;
    return (current.difference(start).inDays / 7).floor() + 1;
  }

  bool _shouldShowSession(ClassSession session, DateTime date) {
    if (session.specificDate != null) {
      return isSameDay(date, session.specificDate!);
    }
    final normalizedDate = dateOnly(date);
    if (normalizedDate.isBefore(dateOnly(_semesterStart))) return false;
    if (_semesterEnd != null && normalizedDate.isAfter(dateOnly(_semesterEnd!))) return false;

    if (session.weeks == null || session.weeks!.isEmpty) return true;
    return session.weeks!.contains(getWeekNumber(date));
  }

  bool isSameDay(DateTime a, DateTime b) => isSameDate(a, b);

  String getWeekLabel(DateTime date) {
    final normalizedDate = dateOnly(date);
    if (normalizedDate.isBefore(dateOnly(_semesterStart))) return "Pre-Sem";
    if (_semesterEnd != null && normalizedDate.isAfter(dateOnly(_semesterEnd!))) return "Break";

    final w = getWeekNumber(date);
    if (_semesterEnd == null && w > 15) return "Break";
    final online = isOnlineWeek(w);
    return "Week $w${online ? ' (Online)' : ''}";
  }

  List<ClassSession> _sessionsFor(List<ClassSession> source, DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return source.where((s) {
      // One-off classes match on their date even if `day` disagrees.
      if (s.specificDate != null) return isSameDay(date, s.specificDate!);
      return s.day == dayName && _shouldShowSession(s, date);
    }).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  /// Classes for [date] in the current perspective, sorted by start time.
  List<ClassSession> getEventsForDay(DateTime date) => _sessionsFor(userSessions, date);

  /// The signed-in user's own classes for [date] (ignores the friend swap).
  List<ClassSession> getClassesForDate(DateTime date) => _sessionsFor(_userSessions, date);

  /// Finds the class in progress, or the next one within [lookaheadDays].
  UpcomingClass? findNextClass(DateTime now, {int lookaheadDays = 7, bool skipToday = false}) {
    for (var d = skipToday ? 1 : 0; d <= lookaheadDays; d++) {
      final date = dateOnly(now).add(Duration(days: d));
      for (final s in getClassesForDate(date)) {
        final start = date.add(Duration(minutes: s.startMinutes));
        var end = date.add(Duration(minutes: s.endMinutes));
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
        if (end.isAfter(now)) {
          return UpcomingClass(session: s, date: date, start: start, end: end, inProgress: !start.isAfter(now));
        }
      }
    }
    return null;
  }

  // Past dates a subject was held, most recent first.
  List<DateTime> getPastClassDates(String subject) {
    final sessions = userSessions.where((s) => s.subject == subject).toList();
    if (sessions.isEmpty) return [];

    final dates = <DateTime>[];
    var iterator = dateOnly(_semesterStart);
    final today = dateOnly(DateTime.now());
    while (!iterator.isAfter(today)) {
      final dayName = DateFormat('EEEE').format(iterator);
      final active = sessions.any((s) => s.specificDate != null
          ? isSameDay(iterator, s.specificDate!)
          : s.day == dayName && _shouldShowSession(s, iterator));
      if (active) dates.add(iterator);
      iterator = DateTime(iterator.year, iterator.month, iterator.day + 1);
    }
    return dates.reversed.toList();
  }

  AttendanceRecord? getAttendanceRecord(String subject, DateTime date) {
    for (final r in _attendanceRecords) {
      if (r.subjectName == subject && isSameDay(r.date, date)) return r;
    }
    return null;
  }

  /// Tasks/events on [date], including multi-day events that span it.
  List<AcademicTask> getTasksForDay(DateTime date) => _tasks.where((t) => t.occursOn(date)).toList();

  List<ClassSession> getFriendEventsForDay(DateTime date) => _sessionsFor(friendSessions, date);

  List<CommonFreeSlot> getFreeSlotsForDay(DateTime date) {
    if (isOnlineWeek(getWeekNumber(date))) return [];

    final dailyUser = getEventsForDay(date);
    final dailyFriend = getFriendEventsForDay(date);

    // Both must be on campus (at least one non-online class)
    final userOnCampus = dailyUser.any((s) => !s.room.toUpperCase().contains('ONLINE'));
    final friendOnCampus = dailyFriend.any((s) => !s.room.toUpperCase().contains('ONLINE'));
    if (!userOnCampus || !friendOnCampus) return [];

    const boundsStart = 480, boundsEnd = 1050; // 08:00 – 17:30
    final busy = [for (final s in [...dailyUser, ...dailyFriend]) _TimeInterval(start: s.startMinutes, end: s.endMinutes)]
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <_TimeInterval>[];
    for (final b in busy) {
      if (merged.isNotEmpty && b.start < merged.last.end) {
        if (b.end > merged.last.end) merged.last.end = b.end;
      } else {
        merged.add(_TimeInterval(start: b.start, end: b.end));
      }
    }

    final freeSlots = <CommonFreeSlot>[];
    var pointer = boundsStart;
    for (final block in merged) {
      if (block.start > pointer) freeSlots.add(CommonFreeSlot(start: pointer, end: block.start));
      if (block.end > pointer) pointer = block.end;
    }
    if (pointer < boundsEnd) freeSlots.add(CommonFreeSlot(start: pointer, end: boundsEnd));
    return freeSlots.where((s) => (s.end - s.start) >= 30).toList();
  }

  bool isOnlineWeek(int week) {
    // In the adaptive system every week is a campus week unless configured.
    return false;
  }

  // ───────────────────────── Tasks / events ─────────────────────────

  /// Inserts or updates a task. Keeps `isCompleted` and the board column
  /// consistent.
  Future<void> saveTask(AcademicTask task) async {
    final status = task.status;
    if (status == TaskStatus.done) {
      task.isCompleted = true;
    } else if (status != null) {
      task.isCompleted = false;
    }
    SyncService.stamp(task);
    final isar = await isarService.db;
    await isar.writeTxn(() => isar.academicTasks.put(task));
    _syncService.pushTask(task);
    await loadSessions();
  }

  Future<void> addTask(String title, String subject, String type, DateTime due, {String description = ''}) {
    return saveTask(AcademicTask(title: title, subject: subject, type: type, dueDate: due, description: description));
  }

  Future<void> setTaskStatus(AcademicTask task, String status) async {
    task.status = status;
    task.isCompleted = status == TaskStatus.done;
    await saveTask(task);
  }

  Future<void> toggleTaskDone(AcademicTask task) =>
      setTaskStatus(task, task.isCompleted ? TaskStatus.todo : TaskStatus.done);

  /// Modules on the user's timetable (the source for subject pickers).
  List<String> get scheduleSubjects {
    final seen = <String>{};
    final list = <String>[];
    for (final s in _userSessions) {
      final name = s.subject.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) list.add(name);
    }
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  // Unique subjects from tasks and classes for autocomplete
  List<String> get savedSubjects {
    final subjects = {
      ..._tasks.map((t) => t.subject),
      ..._userSessions.map((s) => s.subject),
    }.where((s) => s.isNotEmpty && s != 'General').toList();
    subjects.sort();
    return subjects;
  }

  /// Deletes a task and returns it so the caller can offer "Undo".
  Future<AcademicTask?> deleteTask(int id) async {
    final isar = await isarService.db;
    final task = await isar.academicTasks.get(id);
    if (task == null) return null;
    await isar.writeTxn(() => isar.academicTasks.delete(id));
    _syncService.pushDelete(SyncService.tasksCol, task.syncId);
    await loadSessions();
    return task;
  }

  /// Re-inserts a task removed by [deleteTask].
  Future<void> restoreTask(AcademicTask task) async {
    task.id = Isar.autoIncrement;
    await saveTask(task);
  }

  // ───────────────────────── Sessions ─────────────────────────

  Future<void> addSession(ClassSession session) async {
    session.startTime = normalizeTime(session.startTime);
    session.endTime = normalizeTime(session.endTime);
    SyncService.stamp(session);
    final isar = await isarService.db;
    await isar.writeTxn(() => isar.classSessions.put(session));
    _syncService.pushSession(session);
    await loadSessions();
  }

  Future<void> deleteSession(int id) async {
    final isar = await isarService.db;
    final session = await isar.classSessions.get(id);
    await isar.writeTxn(() => isar.classSessions.delete(id));
    _syncService.pushDelete(SyncService.sessionsCol, session?.syncId);
    await loadSessions();
  }

  /// Seeds in-memory data without touching Isar (widget tests only).
  @visibleForTesting
  void debugSetData({
    List<ClassSession> sessions = const [],
    List<AcademicTask> tasks = const [],
    List<AttendanceRecord> attendance = const [],
    String? courseName,
    DateTime? semesterStart,
  }) {
    _userSessions = [...sessions]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    _tasks = [...tasks];
    _attendanceRecords = [...attendance];
    if (courseName != null) _courseName = courseName;
    if (semesterStart != null) _semesterStart = semesterStart;
    _hasCompletedSetup = true;
    _isSetupLoaded = true;
    notifyListeners();
  }

  // Legacy: kept for code that still calls it.
  Future<void> loadFriendTimetable() => loadSessions();
}

class CommonFreeSlot {
  final int start; // minutes from midnight
  final int end; // minutes from midnight
  CommonFreeSlot({required this.start, required this.end});

  String get label => "${formatMinutes(start)} - ${formatMinutes(end)}";
}

class _TimeInterval {
  int start;
  int end;
  _TimeInterval({required this.start, required this.end});
}
