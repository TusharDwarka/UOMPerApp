import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'isar_service.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';
import '../models/note.dart';
import '../models/attendance_record.dart';
import '../models/bus_route.dart';
import 'package:isar_community/isar.dart';

class SyncService {
  final IsarService _isarService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  SyncService(this._isarService);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Pulls all data from Firestore and overwrites local Isar data
  Future<void> pullFromCloud() async {
    final uid = _uid;
    if (uid == null) return;
    
    try {
      final userRef = _db.collection('users').doc(uid);
      
      // Fetch all collections
      final sessionsSnap = await userRef.collection('class_sessions').get();
      final tasksSnap = await userRef.collection('academic_tasks').get();
      final notesSnap = await userRef.collection('notes').get();
      final attendanceSnap = await userRef.collection('attendance').get();
      final busDoc = await userRef.collection('settings').doc('bus_timetable').get();

      // Convert to Isar models
      final sessions = sessionsSnap.docs.map((doc) => ClassSession.fromSyncJson(doc.data())).toList();
      final tasks = tasksSnap.docs.map((doc) => AcademicTask.fromJson(doc.data())).toList();
      final notes = notesSnap.docs.map((doc) => Note.fromJson(doc.data())).toList();
      final attendance = attendanceSnap.docs.map((doc) => AttendanceRecord.fromJson(doc.data())).toList();
      
      final isar = await _isarService.db;
      
      // Write to Isar
      await isar.writeTxn(() async {
        // Clear existing
        await isar.classSessions.clear();
        await isar.academicTasks.clear();
        await isar.notes.clear();
        await isar.attendanceRecords.clear();
        
        // Put new
        await isar.classSessions.putAll(sessions);
        await isar.academicTasks.putAll(tasks);
        await isar.notes.putAll(notes);
        await isar.attendanceRecords.putAll(attendance);
      });
      
      // Bus data is stored in SharedPreferences
      if (busDoc.exists) {
        final data = busDoc.data();
        if (data != null && data['locations'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bus_locations_json', jsonEncode(data['locations']));
        }
      }
    } catch (e) {
      print("Error pulling from cloud: $e");
    }
  }

  /// Pushes all local Isar data to Firestore, overwriting cloud data
  Future<void> pushToCloud() async {
    final uid = _uid;
    if (uid == null) return;
    
    try {
      final isar = await _isarService.db;
      
      final sessions = await isar.classSessions.where().findAll();
      final tasks = await isar.academicTasks.where().findAll();
      final notes = await isar.notes.where().findAll();
      final attendance = await isar.attendanceRecords.where().findAll();
      
      final batch = _db.batch();
      final userRef = _db.collection('users').doc(uid);
      
      // Delete existing data in cloud to avoid duplicates
      // NOTE: For a massive scale app, deleting everything in a batch might hit limits.
      // But for a single user's timetable app, it's well under the 500 operation limit.
      
      // We'll just overwrite using set() with known IDs if possible, but Isar IDs are ints.
      // Best way: map Isar int ID to string document ID.
      for (final s in sessions) {
        batch.set(userRef.collection('class_sessions').doc(s.id.toString()), s.toSyncJson());
      }
      for (final t in tasks) {
        batch.set(userRef.collection('academic_tasks').doc(t.id.toString()), t.toJson());
      }
      for (final n in notes) {
        batch.set(userRef.collection('notes').doc(n.id.toString()), n.toJson());
      }
      for (final a in attendance) {
        batch.set(userRef.collection('attendance').doc(a.id.toString()), a.toJson());
      }
      
      // Push bus data
      final prefs = await SharedPreferences.getInstance();
      final busJson = prefs.getString('bus_locations_json');
      if (busJson != null) {
        final decoded = jsonDecode(busJson);
        batch.set(userRef.collection('settings').doc('bus_timetable'), {'locations': decoded});
      }
      
      await batch.commit();
    } catch (e) {
      print("Error pushing to cloud: $e");
    }
  }
}
