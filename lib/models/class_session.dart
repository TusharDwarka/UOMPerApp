import 'package:isar_community/isar.dart';
import '../utils/time_utils.dart';

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

  /// Google Meet / Microsoft Teams / Zoom link for online sessions.
  String? meetingLink;

  /// Stable cross-device id (Firestore document id).
  @Index()
  String? syncId;
  DateTime? updatedAt;

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
    this.meetingLink,
  });

  @ignore
  int get startMinutes => parseMinutes(startTime) ?? 0;

  @ignore
  int get endMinutes => parseMinutes(endTime) ?? 0;

  factory ClassSession.fromJson(Map<String, dynamic> json, {bool isUser = true}) {
    return ClassSession(
      subject: json['moduleName'] ?? '',
      startTime: normalizeTime(json['startTime'] ?? ''),
      endTime: normalizeTime(json['endTime'] ?? ''),
      day: json['day'] ?? '',
      room: json['location'] ?? '',
      moduleCode: json['moduleCode'] ?? '',
      isUser: isUser,
    );
  }

  Map<String, dynamic> toSyncJson() => {
        'syncId': syncId,
        'subject': subject,
        'startTime': startTime,
        'endTime': endTime,
        'day': day,
        'room': room,
        'moduleCode': moduleCode,
        'isUser': isUser,
        'specificDate': specificDate?.toIso8601String(),
        'weeks': weeks,
        'meetingLink': meetingLink,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ClassSession.fromSyncJson(Map<String, dynamic> json) {
    return ClassSession(
      subject: json['subject'] ?? '',
      startTime: normalizeTime(json['startTime'] ?? ''),
      endTime: normalizeTime(json['endTime'] ?? ''),
      day: json['day'] ?? '',
      room: json['room'] ?? '',
      moduleCode: json['moduleCode'] ?? '',
      isUser: json['isUser'] ?? true,
      specificDate: json['specificDate'] != null ? DateTime.tryParse(json['specificDate']) : null,
      weeks: json['weeks'] != null ? List<int>.from(json['weeks']) : null,
      meetingLink: json['meetingLink'],
    )
      ..syncId = json['syncId']
      ..updatedAt = json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null;
  }
}
