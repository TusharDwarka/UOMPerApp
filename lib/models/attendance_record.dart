
import 'package:isar_community/isar.dart';

part 'attendance_record.g.dart';

@Collection()
class AttendanceRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String subjectName;

  late DateTime date;

  // true = Present, false = Absent
  late bool isPresent; 

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'date': date.toIso8601String(),
        'isPresent': isPresent,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final record = AttendanceRecord()
      ..subjectName = json['subjectName'] ?? ''
      ..date = json['date'] != null ? DateTime.parse(json['date']) : DateTime.now()
      ..isPresent = json['isPresent'] ?? false;
      
    if (json['id'] != null) {
      record.id = json['id'];
    }
    return record;
  }
}
