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

  Note({
    this.title = '',
    this.content = '',
    this.subject = 'General',
    this.colorIndex = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'subject': subject,
        'colorIndex': colorIndex,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final note = Note(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      subject: json['subject'] ?? 'General',
      colorIndex: json['colorIndex'] ?? 0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
    if (json['id'] != null) {
      note.id = json['id'];
    }
    return note;
  }
}
