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
    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    
    // Load Attendance too
    await loadAttendance();
    
    _calculateCommonFreeTime();
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
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ClassSession> getEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return userSessions.where((s) => s.day == dayName).toList();
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
         dates.add(d);
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
    return _friendSessions.where((s) => s.day == dayName).toList();
  }

  List<CommonFreeSlot> getFreeSlotsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return _commonFreeTime[dayName] ?? [];
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

  // Friend Load
  Future<void> loadFriendTimetable() async {
     // Hardcoded CSS1Y1 data as requested
     final json = {
        "timetable": {
          "Monday": [
            {"day": "Monday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICDT 1202Y(1)", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"},
            {"day": "Monday", "startTime": "10:30", "endTime": "12:30", "moduleCode": "ICDT 1016Y(1)", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"}
          ],
          "Tuesday": [
            {"day": "Tuesday", "startTime": "08:30", "endTime": "12:30", "moduleCode": "ICDT 1201Y(1)", "moduleName": "LAB", "location": "CITS FoA Lab 2B", "mode": "CAMPUS"},
            {"day": "Tuesday", "startTime": "12:30", "endTime": "16:30", "moduleCode": "ICDT 1206Y(1)", "moduleName": "LAB(A1)", "location": "CITS FoA Lab 2B", "mode": "CAMPUS"}
          ],
          "Wednesday": [
            {"day": "Wednesday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1207 Y", "moduleName": "TUTORIAL", "location": "Room 2.10", "mode": "CAMPUS"},
            {"day": "Wednesday", "startTime": "11:30", "endTime": "15:30", "moduleCode": "ICDT 1202Y(1)", "moduleName": "LAB", "location": "ETB Lab", "mode": "CAMPUS"}
          ],
          "Thursday": [
            {"day": "Thursday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICT 1207 Y", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"},
            {"day": "Thursday", "startTime": "10:30", "endTime": "12:30", "moduleCode": "ICT 1206Y", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"},
            {"day": "Thursday", "startTime": "12:30", "endTime": "15:00", "moduleCode": "ICT 1208Y(1)", "moduleName": "TUTORIAL", "location": "Room 1.16", "mode": "CAMPUS"}
          ],
          "Friday": [
            {"day": "Friday", "startTime": "08:30", "endTime": "10:30", "moduleCode": "ICDT 1201Y(1)", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"},
            {"day": "Friday", "startTime": "10:30", "endTime": "12:30", "moduleCode": "ICT 1208Y(1)", "moduleName": "LECTURE", "location": "Room 1.16", "mode": "CAMPUS"},
            {"day": "Friday", "startTime": "12:30", "endTime": "15:00", "moduleCode": "ICT 1208Y(1)", "moduleName": "TUTORIAL", "location": "Room 1.15", "mode": "CAMPUS"}
          ]
        }
     };

     final isar = await isarService.db;
     await isar.writeTxn(() async {
       // Clear old friend sessions
       await isar.classSessions.filter().isUserEqualTo(false).deleteAll();
       
       // Import new
       final timetable = json['timetable'] as Map<String, dynamic>;
       timetable.forEach((day, sessions) {
         for (var s in sessions as List<dynamic>) {
            final session = ClassSession(
               subject: s['moduleName'],
               startTime: s['startTime'],
               endTime: s['endTime'],
               day: day,
               room: s['location'],
               moduleCode: s['moduleCode'] ?? '',
               isUser: false, // Compares as Friend
            );
            isar.classSessions.put(session);
         }
       });
     });
     
     await loadSessions();
  }

  void _calculateCommonFreeTime() {
    _commonFreeTime.clear();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    
    // Bounds: 8:00 (480) to 16:00 (960)
    final timeBounds = _TimeInterval(start: 480, end: 960);
    
    for (var day in days) {
      final dailyUser = _userSessions.where((s) => s.day == day).toList();
      final dailyFriend = _friendSessions.where((s) => s.day == day).toList();
      
      final busy = <_TimeInterval>[];
      for (var s in [...dailyUser, ...dailyFriend]) {
        busy.add(_TimeInterval(start: _timeToMinutes(s.startTime), end: _timeToMinutes(s.endTime)));
      }
      busy.sort((a,b) => a.start.compareTo(b.start));
      
      // Merge
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
      final validSlots = freeSlots.where((s) => (s.end - s.start) >= 30).toList();
      
      if (validSlots.isNotEmpty) {
        _commonFreeTime[day] = validSlots;
      }
    }
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
