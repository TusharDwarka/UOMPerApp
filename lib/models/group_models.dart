import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/time_utils.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// A cohort / study group, e.g. "Data Science · Year 2".
class StudyGroup {
  final String id;
  final String name;
  final String description;
  final String programme;
  final int year; // 1..5
  final int semester; // 1..2
  final bool isPublic;
  final String ownerId;
  final bool membersCanPost;
  final int? colorValue;

  const StudyGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.programme = '',
    this.year = 1,
    this.semester = 1,
    this.isPublic = true,
    required this.ownerId,
    this.membersCanPost = false,
    this.colorValue,
  });

  factory StudyGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return StudyGroup(
      id: doc.id,
      name: d['name'] ?? 'Group',
      description: d['description'] ?? '',
      programme: d['programme'] ?? '',
      year: (d['year'] as num?)?.toInt() ?? 1,
      semester: (d['semester'] as num?)?.toInt() ?? 1,
      isPublic: d['isPublic'] ?? true,
      ownerId: d['ownerId'] ?? '',
      membersCanPost: d['membersCanPost'] ?? false,
      colorValue: (d['colorValue'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'description': description,
        'programme': programme,
        'year': year,
        'semester': semester,
        'isPublic': isPublic,
        'ownerId': ownerId,
        'membersCanPost': membersCanPost,
        'colorValue': colorValue,
      };

  String get subtitle => [if (programme.isNotEmpty) programme, 'Y$year S$semester'].join(' · ');
}

class GroupMember {
  final String uid;
  final String displayName;
  final String role; // 'leader' | 'member'
  final DateTime? joinedAt;
  final int weeklyFocusMinutes;
  final String? statsWeek;
  final int tasksDone;
  final int streak;

  /// 'full' (name + progress), 'nameOnly', or 'hidden' from the ranking.
  final String rankVisibility;

  const GroupMember({
    required this.uid,
    required this.displayName,
    this.role = 'member',
    this.joinedAt,
    this.weeklyFocusMinutes = 0,
    this.statsWeek,
    this.tasksDone = 0,
    this.streak = 0,
    this.rankVisibility = 'full',
  });

  bool get isLeader => role == 'leader';

  factory GroupMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final stats = (d['stats'] as Map?) ?? const {};
    return GroupMember(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Student',
      role: d['role'] ?? 'member',
      joinedAt: _ts(d['joinedAt']),
      weeklyFocusMinutes: (stats['focusMinutes'] as num?)?.toInt() ?? 0,
      statsWeek: stats['week'] as String?,
      tasksDone: (stats['tasksDone'] as num?)?.toInt() ?? 0,
      streak: (stats['streak'] as num?)?.toInt() ?? 0,
      rankVisibility: d['rankVisibility'] ?? 'full',
    );
  }

  /// Leaderboard score: focus minutes this week + 20 per finished task +
  /// 10 per streak day. Stale stats from a previous week count as zero.
  int scoreFor(String currentWeek) {
    if (statsWeek != currentWeek || rankVisibility != 'full') return 0;
    return weeklyFocusMinutes + tasksDone * 20 + streak * 10;
  }
}

/// A recurring class on the group's shared timetable.
class GroupSession {
  final String id;
  final String subject;
  final String day; // Monday..Sunday
  final String startTime;
  final String endTime;
  final String room;
  final String? meetingLink;
  final String? createdByName;

  const GroupSession({
    required this.id,
    required this.subject,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room = '',
    this.meetingLink,
    this.createdByName,
  });

  int get startMinutes => parseMinutes(startTime) ?? 0;
  int get endMinutes => parseMinutes(endTime) ?? 0;

  factory GroupSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return GroupSession(
      id: doc.id,
      subject: d['subject'] ?? '',
      day: d['day'] ?? 'Monday',
      startTime: d['startTime'] ?? '09:00',
      endTime: d['endTime'] ?? '10:00',
      room: d['room'] ?? '',
      meetingLink: d['meetingLink'],
      createdByName: d['createdByName'],
    );
  }

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'day': day,
        'startTime': normalizeTime(startTime),
        'endTime': normalizeTime(endTime),
        'room': room,
        'meetingLink': meetingLink,
        'createdByName': createdByName,
      };
}

/// A dated shared item: deadline, exam, event, meetup.
class GroupEvent {
  final String id;
  final String title;
  final String type;
  final DateTime start;
  final DateTime? end;
  final String room;
  final String? meetingLink;
  final int? colorValue;
  final String? createdByName;
  final String? notes;

  const GroupEvent({
    required this.id,
    required this.title,
    this.type = 'Event',
    required this.start,
    this.end,
    this.room = '',
    this.meetingLink,
    this.colorValue,
    this.createdByName,
    this.notes,
  });

  factory GroupEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return GroupEvent(
      id: doc.id,
      title: d['title'] ?? '',
      type: d['type'] ?? 'Event',
      start: _ts(d['start']) ?? DateTime.now(),
      end: _ts(d['end']),
      room: d['room'] ?? '',
      meetingLink: d['meetingLink'],
      colorValue: (d['colorValue'] as num?)?.toInt(),
      createdByName: d['createdByName'],
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type,
        'start': Timestamp.fromDate(start),
        'end': end == null ? null : Timestamp.fromDate(end!),
        'room': room,
        'meetingLink': meetingLink,
        'colorValue': colorValue,
        'createdByName': createdByName,
        'notes': notes,
      };
}

class GroupMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? createdAt;
  final bool isAnnouncement;

  const GroupMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.createdAt,
    this.isAnnouncement = false,
  });

  factory GroupMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return GroupMessage(
      id: doc.id,
      text: d['text'] ?? '',
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? 'Student',
      createdAt: _ts(d['createdAt']),
      isAnnouncement: d['kind'] == 'announcement',
    );
  }
}
