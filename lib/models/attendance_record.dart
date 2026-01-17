
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
}
