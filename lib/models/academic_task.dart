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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'subject': subject,
        'isCompleted': isCompleted,
        'type': type,
      };

  factory AcademicTask.fromJson(Map<String, dynamic> json) {
    final task = AcademicTask(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : DateTime.now(),
      subject: json['subject'] ?? 'General',
      isCompleted: json['isCompleted'] ?? false,
      type: json['type'] ?? 'Assignment',
    );
    if (json['id'] != null) {
      task.id = json['id'];
    }
    return task;
  }
}
