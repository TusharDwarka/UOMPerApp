import 'package:isar_community/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  late String title;
  late String content;
  late DateTime timestamp;

  Note({
    this.title = '',
    this.content = '',
    required this.timestamp,
  });
}
