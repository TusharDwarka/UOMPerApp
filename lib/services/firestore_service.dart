import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central Firestore service that syncs all app data to the cloud.
/// Data is stored under: users/{userId}/{collection}
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Returns the user's document reference, or null if not logged in.
  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ─── CLASS SESSIONS (Timetable) ───────────────────────────────

  CollectionReference? get _sessionsCol => _userDoc?.collection('class_sessions');

  Future<void> saveSession(Map<String, dynamic> data, {String? docId}) async {
    final col = _sessionsCol;
    if (col == null) return;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
    } else {
      await col.add(data);
    }
  }

  Future<void> deleteSession(String docId) async {
    await _sessionsCol?.doc(docId).delete();
  }

  Future<void> clearUserSessions() async {
    final col = _sessionsCol;
    if (col == null) return;
    final snap = await col.where('isUser', isEqualTo: true).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<QuerySnapshot>? sessionsStream() {
    return _sessionsCol?.snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getAllSessions() async {
    final col = _sessionsCol;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs;
  }

  // ─── ACADEMIC TASKS (Todo Board) ──────────────────────────────

  CollectionReference? get _tasksCol => _userDoc?.collection('academic_tasks');

  Future<String?> saveTask(Map<String, dynamic> data, {String? docId}) async {
    final col = _tasksCol;
    if (col == null) return null;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
      return docId;
    } else {
      final ref = await col.add(data);
      return ref.id;
    }
  }

  Future<void> deleteTask(String docId) async {
    await _tasksCol?.doc(docId).delete();
  }

  Stream<QuerySnapshot>? tasksStream() {
    return _tasksCol?.orderBy('dueDate', descending: true).snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getAllTasks() async {
    final col = _tasksCol;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs;
  }

  // ─── NOTES ────────────────────────────────────────────────────

  CollectionReference? get _notesCol => _userDoc?.collection('notes');

  Future<String?> saveNote(Map<String, dynamic> data, {String? docId}) async {
    final col = _notesCol;
    if (col == null) return null;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
      return docId;
    } else {
      final ref = await col.add(data);
      return ref.id;
    }
  }

  Future<void> deleteNote(String docId) async {
    await _notesCol?.doc(docId).delete();
  }

  Stream<QuerySnapshot>? notesStream() {
    return _notesCol?.orderBy('timestamp', descending: true).snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getAllNotes() async {
    final col = _notesCol;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs;
  }

  // ─── ATTENDANCE ───────────────────────────────────────────────

  CollectionReference? get _attendanceCol => _userDoc?.collection('attendance');

  Future<void> saveAttendance(Map<String, dynamic> data, {String? docId}) async {
    final col = _attendanceCol;
    if (col == null) return;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
    } else {
      await col.add(data);
    }
  }

  Future<void> deleteAttendance(String docId) async {
    await _attendanceCol?.doc(docId).delete();
  }

  Future<void> clearAttendance() async {
    final col = _attendanceCol;
    if (col == null) return;
    final snap = await col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<QuerySnapshot>? attendanceStream() {
    return _attendanceCol?.snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getAllAttendance() async {
    final col = _attendanceCol;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs;
  }

  // ─── BUS TIMETABLE ────────────────────────────────────────────

  /// Bus data is stored as a single document with a 'locations' array field,
  /// mirroring the SharedPreferences JSON structure.
  DocumentReference? get _busDoc => _userDoc?.collection('settings').doc('bus_timetable');

  Future<void> saveBusData(List<Map<String, dynamic>> locations) async {
    final doc = _busDoc;
    if (doc == null) return;
    await doc.set({'locations': locations, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<List<Map<String, dynamic>>?> loadBusData() async {
    final doc = _busDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null || data['locations'] == null) return null;
    return (data['locations'] as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }

  Stream<DocumentSnapshot>? busDataStream() {
    return _busDoc?.snapshots();
  }

  // ─── MODULE RESOURCES (metadata only, not actual files) ───────

  CollectionReference? get _resourcesCol => _userDoc?.collection('module_resources');

  Future<String?> saveResource(Map<String, dynamic> data, {String? docId}) async {
    final col = _resourcesCol;
    if (col == null) return null;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
      return docId;
    } else {
      final ref = await col.add(data);
      return ref.id;
    }
  }

  Future<void> deleteResource(String docId) async {
    await _resourcesCol?.doc(docId).delete();
  }

  Stream<QuerySnapshot>? resourcesStream() {
    return _resourcesCol?.orderBy('addedAt', descending: true).snapshots();
  }

  // ─── USER SETTINGS / PREFERENCES ─────────────────────────────

  DocumentReference? get _settingsDoc => _userDoc?.collection('settings').doc('app_settings');

  Future<void> saveSettings(Map<String, dynamic> data) async {
    final doc = _settingsDoc;
    if (doc == null) return;
    await doc.set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadSettings() async {
    final doc = _settingsDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>?;
  }

  Stream<DocumentSnapshot>? settingsStream() {
    return _settingsDoc?.snapshots();
  }

  // ─── ASSESSMENTS ──────────────────────────────────────────────

  CollectionReference? get _assessmentsCol => _userDoc?.collection('assessments');

  Future<String?> saveAssessment(Map<String, dynamic> data, {String? docId}) async {
    final col = _assessmentsCol;
    if (col == null) return null;
    if (docId != null) {
      await col.doc(docId).set(data, SetOptions(merge: true));
      return docId;
    } else {
      final ref = await col.add(data);
      return ref.id;
    }
  }

  Future<void> deleteAssessment(String docId) async {
    await _assessmentsCol?.doc(docId).delete();
  }

  Stream<QuerySnapshot>? assessmentsStream() {
    return _assessmentsCol?.snapshots();
  }

  // ─── BULK UPLOAD (Initial Migration) ──────────────────────────

  /// Upload all local data to Firestore in one go.
  /// This is called once when a user first signs in to seed the cloud.
  Future<void> uploadAllData({
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> busLocations,
    required Map<String, dynamic> settings,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);

    // Sessions
    for (final s in sessions) {
      batch.set(userRef.collection('class_sessions').doc(), s);
    }

    // Tasks
    for (final t in tasks) {
      batch.set(userRef.collection('academic_tasks').doc(), t);
    }

    // Notes
    for (final n in notes) {
      batch.set(userRef.collection('notes').doc(), n);
    }

    // Attendance
    for (final a in attendance) {
      batch.set(userRef.collection('attendance').doc(), a);
    }

    // Bus data
    batch.set(
      userRef.collection('settings').doc('bus_timetable'),
      {'locations': busLocations, 'updatedAt': FieldValue.serverTimestamp()},
    );

    // Settings
    batch.set(
      userRef.collection('settings').doc('app_settings'),
      settings,
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
