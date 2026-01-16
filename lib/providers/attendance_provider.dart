import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../services/isar_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final IsarService isarService;
  List<AttendanceRecord> _records = [];

  AttendanceProvider(this.isarService);

  List<AttendanceRecord> get records => _records;

  Future<void> loadRecords() async {
    final isar = await isarService.db;
    _records = await isar.attendanceRecords.where().findAll();
    notifyListeners();
  }

  AttendanceRecord? getRecordForModule(String moduleCode) {
    try {
      return _records.firstWhere((r) => r.moduleCode == moduleCode);
    } catch (e) {
      return null;
    }
  }

  Future<void> markAttendance(String moduleCode, bool present) async {
    final isar = await isarService.db;
    
    await isar.writeTxn(() async {
      // Find existing record or create new
      var record = await isar.attendanceRecords
          .filter()
          .moduleCodeEqualTo(moduleCode)
          .findFirst();

      if (record == null) {
        record = AttendanceRecord(
          moduleCode: moduleCode,
          attendedSessions: 0,
          totalSessions: 0,
        );
      }

      // Update stats
      // Logic: This function is called for a specific session.
      // We assume this is a NEW marking action for a generic "next class".
      // or we need to track if THIS specific session was already marked?
      // For simplicity, we just increment counters.
      
      record.totalSessions += 1;
      if (present) {
        record.attendedSessions += 1;
      }
      
      await isar.attendanceRecords.put(record);
    });
    
    await loadRecords();
  }
  
  // Method to get skippable classes for a module
  int getSkippable(String moduleCode) {
    final record = getRecordForModule(moduleCode);
    return record?.classesToSkip ?? 0;
  }
}
