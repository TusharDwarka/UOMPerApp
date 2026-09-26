import 'package:isar_community/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  late String title;
  late String content;
  late String subject;
  late int colorIndex;
  late DateTime timestamp;

  /// Pinned notes are shown first.
  bool? isPinned;

  /// Stable cross-device id (Firestore document id).
  @Index()
  String? syncId;
  DateTime? updatedAt;

  Note({
    this.title = '',
    this.content = '',
    this.subject = 'General',
    this.colorIndex = 0,
    required this.timestamp,
    this.isPinned,
  });

  Map<String, dynamic> toJson() => {
        'syncId': syncId,
        'title': title,
        'content': content,
        'subject': subject,
        'colorIndex': colorIndex,
        'timestamp': timestamp.toIso8601String(),
        'isPinned': isPinned,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      subject: json['subject'] ?? 'General',
      colorIndex: json['colorIndex'] ?? 0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      isPinned: json['isPinned'],
    )
      ..syncId = json['syncId']
      ..updatedAt = json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null;
  }
}
