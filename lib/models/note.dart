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
}
