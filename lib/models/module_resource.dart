import 'package:isar_community/isar.dart';

part 'module_resource.g.dart';

@collection
class ModuleResource {
  Id id = Isar.autoIncrement;

  /// Display name of the file, e.g. "Week3_Slides.pdf"
  late String fileName;

  /// Module this file belongs to, e.g. "CSE 1010" or "Unsorted"
  late String moduleName;

  /// One of: "Lectures", "Tutorials", "Past Papers", "Assignments"
  late String category;

  /// Absolute local path to the copied file on device
  late String filePath;

  /// When the file was added to the app
  late DateTime addedAt;

  /// Where the file came from: "whatsapp", "classroom", "manual"
  String? sourceApp;

  /// File size in bytes (for display)
  int fileSizeBytes = 0;

  ModuleResource({
    this.fileName = '',
    this.moduleName = 'Unsorted',
    this.category = 'Lectures',
    this.filePath = '',
    required this.addedAt,
    this.sourceApp,
    this.fileSizeBytes = 0,
  });
}
