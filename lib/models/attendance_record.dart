import 'package:isar_community/isar.dart';

part 'attendance_record.g.dart';

@collection
class AttendanceRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String moduleCode;
  
  int attendedSessions;
  int totalSessions;

  AttendanceRecord({
    this.moduleCode = '',
    this.attendedSessions = 0,
    this.totalSessions = 0,
  });

  double get percentage => totalSessions == 0 ? 0.0 : (attendedSessions / totalSessions) * 100;
  
  bool get isBelowThreshold => percentage < 75.0;
  
  int get classesToSkip {
    // If we have attended A out of T. 
    // We want to know how many future classes (X) we can miss such that A / (T + X) >= 0.75
    // A / 0.75 >= T + X
    // X <= (A / 0.75) - T
    if (totalSessions == 0) return 0;
    
    double maxTotal = attendedSessions / 0.75;
    int maxSkippableTotal = maxTotal.floor();
    int skippable = maxSkippableTotal - totalSessions;
    return skippable > 0 ? skippable : 0;
  }
}
