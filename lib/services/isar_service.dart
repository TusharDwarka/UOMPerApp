import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/class_session.dart';
import '../models/assessment.dart';
import '../models/attendance_record.dart';
import '../models/bus_route.dart';
import '../models/note.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [
          ClassSessionSchema,
          AssessmentSchema,
          AttendanceRecordSchema,
          BusRouteSchema,
          NoteSchema,
        ],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  // Example generic method to clear everything (useful for testing/resetting)
  Future<void> cleanDb() async {
    final isar = await db;
    await isar.writeTxn(() => isar.clear());
  }
}
