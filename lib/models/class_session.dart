import 'package:isar_community/isar.dart';

part 'class_session.g.dart';

@collection
class ClassSession {
  Id id = Isar.autoIncrement;

  late String subject;
  late String startTime; // Format: "HH:mm"
  late String endTime;   // Format: "HH:mm"
  late String day;       // e.g., "Monday"
  late String room;
  late String moduleCode;
  
  // To distinguish between the user's timetable and a friend's
  late bool isUser; 

  // Specific Date support (Optional)
  // If set, this session applies ONLY to this specific date.
  // If null, it applies to every week (generic).
  DateTime? specificDate;
  
  // Weeks this session is active (e.g. [1, 2, 3, 6, 10])
  List<int>? weeks;

  ClassSession({
    this.subject = '',
    this.startTime = '',
    this.endTime = '',
    this.day = '',
    this.room = '',
    this.moduleCode = '',
    this.isUser = true,
    this.specificDate,
    this.weeks,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json, {bool isUser = true}) {
    return ClassSession(
      subject: json['moduleName'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      day: json['day'] ?? '',
      room: json['location'] ?? '',
      moduleCode: json['moduleCode'] ?? '',
      isUser: isUser,
    );
  }
}
