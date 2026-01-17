import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Added for DateFormat
import 'package:isar_community/isar.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';
import '../services/isar_service.dart';

class TimetableProvider extends ChangeNotifier {
  final IsarService isarService;
  
  List<ClassSession> _userSessions = [];
  List<ClassSession> _friendSessions = [];
  
  Map<String, List<CommonFreeSlot>> _commonFreeTime = {};
  Map<String, List<CommonFreeSlot>> get commonFreeTime => _commonFreeTime;

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

  List<AcademicTask> _tasks = [];
  List<AcademicTask> get tasks => _tasks;
  
  // Computed properties for Dashboard
  List<AcademicTask> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<AcademicTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  TimetableProvider(this.isarService);

  Future<void> loadSessions() async {
    final isar = await isarService.db;
    _userSessions = await isar.classSessions.filter().isUserEqualTo(true).findAll();
    _friendSessions = await isar.classSessions.filter().isUserEqualTo(false).findAll();
    _tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    _calculateCommonFreeTime();
    notifyListeners();
  }

  // Helpers
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ClassSession> getEventsForDay(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    return _userSessions.where((s) {
       if (s.specificDate != null) {
         return isSameDay(s.specificDate!, date);
       } else {
         return s.day == dayName;
       }
    }).toList();
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
