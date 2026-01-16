import 'package:isar_community/isar.dart';

part 'assessment.g.dart';

@collection
class Assessment {
  Id id = Isar.autoIncrement;

  late String title;
  late String module;
  late DateTime dueDate;
  late String roomName;
  late bool isTest;

  Assessment({
    this.title = '',
    this.module = '',
    required this.dueDate,
    this.roomName = '',
    this.isTest = false,
  });
}
