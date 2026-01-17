import 'package:isar_community/isar.dart';

part 'academic_task.g.dart';

@collection
class AcademicTask {
  Id id = Isar.autoIncrement;

  late String title;
  late String description;
  late DateTime dueDate;
  late String subject; // e.g., "Mobile Computing"
  late bool isCompleted;
  late String type; // "Assignment", "Exam", "Note"

  AcademicTask({
    this.title = '',
    this.description = '',
    required this.dueDate,
    this.subject = 'General',
    this.isCompleted = false,
    this.type = 'Assignment',
  });
}
