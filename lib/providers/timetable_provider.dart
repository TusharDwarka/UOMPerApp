import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Added for DateFormat
import 'package:isar_community/isar.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';
import '../models/attendance_record.dart'; // Added
import '../services/isar_service.dart';

class TimetableProvider extends ChangeNotifier {
  final IsarService isarService;
  
  // Restored Fields
  List<ClassSession> _userSessions = [];
  List<ClassSession> _friendSessions = [];
  Map<String, List<CommonFreeSlot>> _commonFreeTime = {};
  
  // Attendance
  List<AttendanceRecord> _attendanceRecords = [];
  
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

  // "Creative" Stats Calculation
  // Returns { 'lives': int, 'maxLives': int, 'status': String }
  Map<String, dynamic> getAttendanceStats(String subject) {
    // 1. Calculate Frequency per week from timetable
    final weeklyFrequency = _userSessions.where((s) => s.subject == subject).length;
    if (weeklyFrequency == 0) return {'lives': 0, 'maxLives': 0, 'status': 'No Data'};

    // 2. Estimate Total Semester Classes (approx 15 weeks)
    const int totalWeeks = 15;
    final int totalClasses = totalWeeks * weeklyFrequency;
    
    // 3. Max allowable skips (25%)
    final int maxSkips = (totalClasses * 0.25).floor();

    // 4. Count current absences
    final absences = _attendanceRecords
        .where((r) => r.subjectName == subject && !r.isPresent)
        .length;

    // Lives left
    int lives = maxSkips - absences;
    
    String status = "Safe";
    if (lives <= 0) status = "CRITICAL";
    else if (lives <= 2) status = "Warning";

    return {
      'lives': lives,
      'maxLives': maxSkips, // Initial hearts
      'absences': absences,
      'status': status
    };
  }

  Future<void> loadSessions() async {
    final isar = await isarService.db;
    _userSessions = await isar.classSessions.filter().isUserEqualTo(true).findAll();
    _friendSessions = await isar.classSessions.filter().isUserEqualTo(false).findAll();
    
    // Auto-Repair / Seed Data if empty OR if schema was broken (weeks is null)
    if ((_userSessions.isEmpty && _friendSessions.isEmpty) || 
        (_userSessions.isNotEmpty && _userSessions.first.weeks == null)) {
       print("Data missing or incomplete. Re-seeding database...");
       await loadFriendTimetable(); // This will clear and re-import
       return; // loadFriendTimetable calls loadSessions again, so we return to avoid double notify
    }

    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    
    // Load Attendance too
    await loadAttendance();
    
    // _calculateCommonFreeTime();
    notifyListeners();
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
    notifyListeners();
  }

  void setPerspective(bool isSwapped) {
    if (_isSwapped != isSwapped) {
      _isSwapped = isSwapped;
      notifyListeners();
    }
  }

  List<AcademicTask> _tasks = [];
  List<AcademicTask> get tasks => _tasks;
  
  // Computed properties for Dashboard
  List<AcademicTask> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<AcademicTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  TimetableProvider(this.isarService);



  // Helpers
  final DateTime _semesterStart = DateTime(2026, 1, 19);
  DateTime get semesterStart => _semesterStart;

  int getWeekNumber(DateTime date) {
    // Normalize dates to midnight to avoid time discrepancies
    final start = DateTime(_semesterStart.year, _semesterStart.month, _semesterStart.day);
    final current = DateTime(date.year, date.month, date.day);
    
    if (current.isBefore(start)) return 0;
    final diff = current.difference(start).inDays;
    return (diff / 7).floor() + 1;
  }

  bool _shouldShowSession(ClassSession session, DateTime date) {
    // If no weeks specified, assume it runs every week
    if (session.weeks == null || session.weeks!.isEmpty) return true;
    
    final week = getWeekNumber(date);
    return session.weeks!.contains(week);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ClassSession> getEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    // Filter sessions by Day AND Week
    return userSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
  }
  
  // New: Get specific classes for today (or specific date) to aid UI
  List<ClassSession> getClassesForDate(DateTime date) {
    return getEventsForDay(date);
  }

  // New: Generate past dates for a subject to allow marking retroactive attendance
  // We assume a semester length of ~15 weeks, scanning back from today.
  List<DateTime> getPastClassDates(String subject) {
    // Find missing logic: We need to know WHICH days of the week this subject occurs.
    final sessions = _userSessions.where((s) => s.subject == subject).toList();
    if (sessions.isEmpty) return [];
    
    final validDays = sessions.map((s) => s.day).toSet(); // e.g. {"Monday", "Wednesday"}
    
    List<DateTime> dates = [];
    // Scan back 15 weeks
    DateTime current = DateTime.now();
    // Normalize to start of today to avoid time issues
    current = DateTime(current.year, current.month, current.day);

    for (int i = 0; i < 15 * 7; i++) {
       final d = current.subtract(Duration(days: i));
       final dayName = DateFormat('EEEE').format(d);
       
       if (validDays.contains(dayName)) {
         // Also check if the session was active that week!
         // We need at least one session on that day that was active.
         bool isActive = sessions.any((s) => s.day == dayName && _shouldShowSession(s, d));
         if (isActive) {
           dates.add(d);
         }
       }
    }
    return dates;
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

  // Friend Helpers
  List<ClassSession> getFriendEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return _friendSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
  }

  List<CommonFreeSlot> getFreeSlotsForDay(DateTime date) {
    if (isOnlineWeek(getWeekNumber(date))) {
      return []; // No physical meetings on Online weeks
    }

    final dayName = DateFormat('EEEE').format(date);
    
    // 1. Get User and Friend Sessions active for THIS specific date (checking weeks)
    final dailyUser = _userSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();

    final dailyFriend = _friendSessions.where((s) => 
      s.day == dayName && _shouldShowSession(s, date)
    ).toList();
    
    // Bounds: 8:00 (480) to 16:00 (960)
    final timeBounds = _TimeInterval(start: 480, end: 960);
    
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
    // Campus Weeks: 1, 2, 3, 6, 10
    const campusWeeks = [1, 2, 3, 6, 10];
    // If it's not a campus week, it's online
    return !campusWeeks.contains(week);
  }

  // Task Management
  Future<void> addTask(String title, String subject, String type, DateTime due) async {
     final isar = await isarService.db;
     final newTask = AcademicTask(
       title: title, 
       subject: subject, 
       type: type, 
       dueDate: due, 
       isCompleted: false
     );
     await isar.writeTxn(() async => await isar.academicTasks.put(newTask));
     await loadSessions(); 
  }

  Future<void> updateTask(int id, String title, String subject, DateTime dueDate, bool isCompleted) async {
     final isar = await isarService.db;
     await isar.writeTxn(() async {
       final task = await isar.academicTasks.get(id);
       if (task != null) {
         task.title = title;
         task.subject = subject;
         task.dueDate = dueDate;
         task.isCompleted = isCompleted;
         await isar.academicTasks.put(task);
       }
     });
     await loadSessions();
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

  // Friend Load - Now Supercharged to Reset & Seed Data
  Future<void> loadFriendTimetable() async {
     
     // DS2Y1 (Data Science - User)
     final dssJson = {
      "timetable": {
        "Monday": [{"day": "Monday", "startTime": "09:00", "endTime": "12:00", "moduleCode": "SIS 1067(1)", "moduleName": "Graphs", "location": "Room (NAC 2.12)", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Monday", "startTime": "09:00", "endTime": "12:00", "moduleCode": "SIS 1067(1)", "moduleName": "Graphs", "location": "ONLINE", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
        "Tuesday": [{"day": "Tuesday", "startTime": "08:30", "endTime": "11:30", "moduleCode": "SIS 1066", "moduleName": "Programming Lecture", "location": "ONLINE", "mode": "ONLINE", "weeks": []}, {"day": "Tuesday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "MA 1024(1)", "moduleName": "Mathematical Analysis II", "location": "ONLINE", "mode": "ONLINE", "weeks": []}, {"day": "Tuesday", "startTime": "16:00", "endTime": "17:30", "moduleCode": "STAT 1244", "moduleName": "Probability and Statistics", "location": "ONLINE", "mode": "ONLINE", "weeks": []}],
        "Wednesday": [{"day": "Wednesday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "MA 1023(1)", "moduleName": "Differential Equations", "location": "Room 2.7 - NAC Reduit", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Wednesday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "MA 1023(1)", "moduleName": "Differential Equations", "location": "ONLINE", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
        "Thursday": [{"day": "Thursday", "startTime": "09:00", "endTime": "12:00", "moduleCode": "MA 1022(1)", "moduleName": "Matric Computation", "location": "Room 2.37 FLM", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Thursday", "startTime": "09:00", "endTime": "12:00", "moduleCode": "MA 1022(1)", "moduleName": "Matric Computation", "location": "ONLINE", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Thursday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "MA 1024(1)", "moduleName": "Mathematical Analysis II", "location": "Room 2.37 FLM", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Thursday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "MA 1024(1)", "moduleName": "Mathematical Analysis II", "location": "ONLINE", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Thursday", "startTime": "16:00", "endTime": "17:30", "moduleCode": "STAT 1244", "moduleName": "Probability and Statistics", "location": "Room 1.14 Phase II Building", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Thursday", "startTime": "16:00", "endTime": "17:30", "moduleCode": "STAT 1244", "moduleName": "Probability and Statistics", "location": "ONLINE", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
        "Friday": [{"day": "Friday", "startTime": "08:30", "endTime": "11:30", "moduleCode": "SIS 1066", "moduleName": "Programming Lab", "location": "SIS Lab - Second Floor Phase II Building", "mode": "CAMPUS", "weeks": []}],
        "Saturday": [{"day": "Saturday", "startTime": "09:00", "endTime": "12:00", "moduleCode": "ICT 1201", "moduleName": "Computer Architecture", "location": "ONLINE", "mode": "ONLINE", "weeks": []}, {"day": "Saturday", "startTime": "12:00", "endTime": "15:00", "moduleCode": "STAT 1244", "moduleName": "Probability and Statistics", "location": "ONLINE", "mode": "ONLINE", "weeks": []}]
      }
     };

     // CSS2Y1 (Computer Science - Friend)
     final cssJson = {
       "timetable": {
         "Monday": [{"day": "Monday", "startTime": "08:00", "endTime": "10:00", "moduleCode": "ICDT 1202Y(1)", "moduleName": "Database Systems Lecture", "location": "Room 1.16", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Monday", "startTime": "08:00", "endTime": "10:00", "moduleCode": "ICDT 1202Y(1)", "moduleName": "Database Systems Lecture", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Monday", "startTime": "13:00", "endTime": "15:00", "moduleCode": "ICDT 1016Y", "moduleName": "Communication and Business Skills for IT (Lecture)", "location": "ELT1", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Monday", "startTime": "13:00", "endTime": "15:00", "moduleCode": "ICDT 1016Y", "moduleName": "Communication and Business Skills for IT (Lecture)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
         "Tuesday": [{"day": "Tuesday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICDT 1201Y(1)", "moduleName": "Computer Programming", "location": "ELT1", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Tuesday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICDT 1201Y(1)", "moduleName": "Computer Programming", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Tuesday", "startTime": "11:00", "endTime": "12:00", "moduleCode": "ICDT 1016Y(1)", "moduleName": "Communication and Business Skills for IT (Tutorial)", "location": "Room 1.14", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Tuesday", "startTime": "11:00", "endTime": "12:00", "moduleCode": "ICDT 1016Y(1)", "moduleName": "Communication and Business Skills for IT (Tutorial)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
         "Wednesday": [{"day": "Wednesday", "startTime": "08:30", "endTime": "09:30", "moduleCode": "ICDT 1201Y(1)", "moduleName": "Computer Programming (Lab)", "location": "CITS Lab 1A", "group": "A1", "mode": "CAMPUS", "weeks": []}, {"day": "Wednesday", "startTime": "09:30", "endTime": "10:30", "moduleCode": "ICDT 1208Y", "moduleName": "Software Engineering Principles (Tutorial)", "location": "Tech Avenue", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Wednesday", "startTime": "09:30", "endTime": "10:30", "moduleCode": "ICDT 1208Y", "moduleName": "Software Engineering Principles (Tutorial)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Wednesday", "startTime": "10:30", "endTime": "11:30", "moduleCode": "ICDT 1207Y", "moduleName": "Computational Mathematics(Tutorial)", "location": "Room 1.15", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Wednesday", "startTime": "10:30", "endTime": "11:30", "moduleCode": "ICDT 1207Y", "moduleName": "Computational Mathematics(Tutorial)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
         "Thursday": [{"day": "Thursday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1207(1)", "moduleName": "Computational Mathematics", "location": "ELT1", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Thursday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1207(1)", "moduleName": "Computational Mathematics", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Thursday", "startTime": "10:30", "endTime": "12:30", "moduleCode": "ICDT 1208Y", "moduleName": "Software Engineering Principles (Lecture)", "location": "ELT1", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Thursday", "startTime": "10:30", "endTime": "12:30", "moduleCode": "ICDT 1208Y", "moduleName": "Software Engineering Principles (Lecture)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}],
         "Friday": [{"day": "Friday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1206Y(1)", "moduleName": "Computer Organisation and Architecture(Lecture)", "location": "ELT1", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Friday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1206Y(1)", "moduleName": "Computer Organisation and Architecture(Lecture)", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}, {"day": "Friday", "startTime": "12:30", "endTime": "13:30", "moduleCode": "ICT 1206Y(1)", "moduleName": "Computer Organisation and Architecture(Lecture)", "location": "CITS Lab 1A", "group": "A1", "mode": "CAMPUS", "weeks": []}],
         "Saturday": [{"day": "Saturday", "startTime": "08:00", "endTime": "09:00", "moduleCode": "ICDT 1202Y(1)", "moduleName": "Database Systems Lecture", "location": "ICT Lab", "group": "A1", "mode": "CAMPUS", "weeks": [1, 2, 3, 6, 10]}, {"day": "Saturday", "startTime": "08:00", "endTime": "09:00", "moduleCode": "ICDT 1202Y(1)", "moduleName": "Database Systems Lecture", "location": "ONLINE", "group": "A1", "mode": "ONLINE", "weeks": [4, 5, 7, 8, 9]}]
       }
     };

     final isar = await isarService.db;
     await isar.writeTxn(() async {
       // Clear ALL existing sessions to ensure fresh start
       await isar.classSessions.clear(); // Safest
       
       // Import DSS (User = true)
       _importSessions(isar, dssJson['timetable'] as Map<String, dynamic>, true);
       
       // Import CSS (Friend = false)
       _importSessions(isar, cssJson['timetable'] as Map<String, dynamic>, false);
     });
     
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
