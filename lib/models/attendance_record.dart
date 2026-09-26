
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

  /// Stable cross-device id (Firestore document id).
  @Index()
  String? syncId;
  DateTime? updatedAt;

  AttendanceRecord();

  Map<String, dynamic> toJson() => {
        'syncId': syncId,
        'subjectName': subjectName,
        'date': date.toIso8601String(),
        'isPresent': isPresent,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord()
      ..subjectName = json['subjectName'] ?? ''
      ..date = json['date'] != null ? DateTime.parse(json['date']) : DateTime.now()
      ..isPresent = json['isPresent'] ?? false
      ..syncId = json['syncId']
      ..updatedAt = json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null;
  }
}
