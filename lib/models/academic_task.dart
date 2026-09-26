import 'package:isar_community/isar.dart';

part 'academic_task.g.dart';

/// Kanban columns for the To-Do board.
class TaskStatus {
  static const todo = 'todo';
  static const doing = 'doing';
  static const done = 'done';
  static const all = [todo, doing, done];

  static String label(String status) {
    switch (status) {
      case doing:
        return 'In Progress';
      case done:
        return 'Done';
      default:
        return 'To Do';
    }
  }
}

@collection
class AcademicTask {
  Id id = Isar.autoIncrement;

  late String title;
  late String description;
  late DateTime dueDate;
  late String subject; // e.g., "Mobile Computing"
  late bool isCompleted;
  late String type; // "Assignment", "Exam", "Event", ...

  /// Optional start for events that span several days (e.g. a field trip
  /// or an exam week). When null the item only occupies [dueDate].
  DateTime? startDate;

  /// ARGB colour chosen by the user; null means "use the type's colour".
  int? colorValue;

  /// Google Meet / Microsoft Teams / Zoom link.
  String? meetingLink;

  /// Kanban column, see [TaskStatus]. Null on records created before the
  /// board existed, which is why callers should use [effectiveStatus].
  String? status;

  /// 0 = low, 1 = normal, 2 = high.
  int? priority;

  /// Stable cross-device id (Firestore document id).
  @Index()
  String? syncId;
  DateTime? updatedAt;

  AcademicTask({
    this.title = '',
    this.description = '',
    required this.dueDate,
    this.subject = 'General',
    this.isCompleted = false,
    this.type = 'Assignment',
    this.startDate,
    this.colorValue,
    this.meetingLink,
    this.status,
    this.priority,
  });

  @ignore
  String get effectiveStatus {
    if (isCompleted) return TaskStatus.done;
    final s = status;
    if (s == null || s == TaskStatus.done) return TaskStatus.todo;
    return s;
  }

  /// True when the item covers more than one calendar day.
  @ignore
  bool get isSpanning {
    final s = startDate;
    if (s == null) return false;
    final start = DateTime(s.year, s.month, s.day);
    final end = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return start.isBefore(end);
  }

  /// Whether this item should appear on [day] in a calendar.
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final end = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final s = startDate;
    final start = s == null ? end : DateTime(s.year, s.month, s.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  Map<String, dynamic> toJson() => {
        'syncId': syncId,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'subject': subject,
        'isCompleted': isCompleted,
        'type': type,
        'startDate': startDate?.toIso8601String(),
        'colorValue': colorValue,
        'meetingLink': meetingLink,
        'status': status,
        'priority': priority,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AcademicTask.fromJson(Map<String, dynamic> json) {
    return AcademicTask(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : DateTime.now(),
      subject: json['subject'] ?? 'General',
      isCompleted: json['isCompleted'] ?? false,
      type: json['type'] ?? 'Assignment',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      colorValue: json['colorValue'],
      meetingLink: json['meetingLink'],
      status: json['status'],
      priority: json['priority'],
    )
      ..syncId = json['syncId']
      ..updatedAt = json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null;
  }
}
