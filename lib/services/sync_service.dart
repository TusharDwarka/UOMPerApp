import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academic_task.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../models/note.dart';
import '../utils/ids.dart';
import 'isar_service.dart';

/// Keeps the local Isar database and Firestore in sync for the signed-in
/// user, so the phone and the Windows app show the same data.
///
/// Cloud layout (all private to the user, see `firestore.rules`):
///   users/{uid}                       profile (displayName, groupIds)
///   users/{uid}/class_sessions/{id}   one doc per record, id = syncId
///   users/{uid}/academic_tasks/{id}
///   users/{uid}/notes/{id}
///   users/{uid}/attendance/{id}
///   users/{uid}/settings/app_settings course, semester dates, folders
///   users/{uid}/settings/bus_timetable
///
/// Rules of the merge:
///  * every record has a random `syncId` and an `updatedAt` stamp;
///  * the newest `updatedAt` wins;
///  * deletes are written as tombstones (`deleted: true`) so other devices
///    delete their copy instead of re-uploading it;
///  * local records the cloud has never seen are uploaded, never discarded.
///    (The old implementation cleared the local DB before every pull, which
///    wiped the timetable whenever the cloud was empty.)
class SyncService {
  final IsarService _isarService;
  SyncService(this._isarService);

  static const sessionsCol = 'class_sessions';
  static const tasksCol = 'academic_tasks';
  static const notesCol = 'notes';
  static const attendanceCol = 'attendance';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  final _changes = StreamController<Set<String>>.broadcast();

  /// Emits the names of collections (or 'settings' / 'bus') changed remotely.
  Stream<Set<String>> get changes => _changes.stream;

  final List<StreamSubscription> _subs = [];
  String? _listeningUid;

  final ValueNotifier<DateTime?> lastSynced = ValueNotifier(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  DocumentReference<Map<String, dynamic>>? get userDoc {
    final u = uid;
    return u == null ? null : _db.collection('users').doc(u);
  }

  // ───────────────────────── Stamping ─────────────────────────

  /// Gives a record a syncId (if new) and bumps its updatedAt. Call before
  /// every local write of a synced model.
  static void stamp(Object record) {
    final now = DateTime.now();
    if (record is ClassSession) {
      record.syncId ??= newSyncId();
      record.updatedAt = now;
    } else if (record is AcademicTask) {
      record.syncId ??= newSyncId();
      record.updatedAt = now;
    } else if (record is Note) {
      record.syncId ??= newSyncId();
      record.updatedAt = now;
    } else if (record is AttendanceRecord) {
      record.syncId ??= newSyncId();
      record.updatedAt = now;
    }
  }

  // ───────────────────────── Push (single records) ─────────────────────────

  Future<void> pushSession(ClassSession s) => _pushDoc(sessionsCol, s.syncId, s.toSyncJson());
  Future<void> pushTask(AcademicTask t) => _pushDoc(tasksCol, t.syncId, t.toJson());
  Future<void> pushNote(Note n) => _pushDoc(notesCol, n.syncId, n.toJson());
  Future<void> pushAttendance(AttendanceRecord a) => _pushDoc(attendanceCol, a.syncId, a.toJson());

  Future<void> pushMany(String collection, List<Map<String, dynamic>> docs) async {
    final ref = userDoc;
    if (ref == null || docs.isEmpty) return;
    try {
      for (var i = 0; i < docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(400)) {
          final id = d['syncId'] as String?;
          if (id == null) continue;
          batch.set(ref.collection(collection).doc(id), d);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Sync pushMany($collection) failed: $e');
    }
  }

  /// Writes a tombstone so other devices remove their copy too.
  Future<void> pushDelete(String collection, String? syncId) async {
    if (syncId == null) return;
    await _pushDoc(collection, syncId, {
      'syncId': syncId,
      'deleted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> pushDeleteMany(String collection, Iterable<String?> ids) async {
    final now = DateTime.now().toIso8601String();
    await pushMany(collection, [
      for (final id in ids)
        if (id != null) {'syncId': id, 'deleted': true, 'updatedAt': now}
    ]);
  }

  Future<void> _pushDoc(String collection, String? syncId, Map<String, dynamic> data) async {
    final ref = userDoc;
    if (ref == null || syncId == null) return;
    try {
      // Not awaited on the server round-trip when offline: Firestore queues
      // the write in its local cache and sends it when back online.
      await ref.collection(collection).doc(syncId).set(data).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Offline: the write stays queued in Firestore's cache.
    } catch (e) {
      debugPrint('Sync push($collection) failed: $e');
    }
  }

  // ───────────────────────── Settings / bus ─────────────────────────

  static const _settingsUpdatedKey = 'settings_updated_at';

  Future<void> pushSettings(Map<String, dynamic> settings) async {
    final now = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsUpdatedKey, now);
    final ref = userDoc;
    if (ref == null) return;
    try {
      await ref
          .collection('settings')
          .doc('app_settings')
          .set({...settings, 'updatedAt': now}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Sync pushSettings failed: $e');
    }
  }

  /// Cloud settings, but only when they are newer than this device's last
  /// settings change (so an offline edit isn't overwritten on start-up).
  Future<Map<String, dynamic>?> fetchSettingsIfNewer() async {
    final remote = await fetchSettings();
    if (remote == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final local = DateTime.tryParse(prefs.getString(_settingsUpdatedKey) ?? '');
    final cloud = DateTime.tryParse(remote['updatedAt']?.toString() ?? '');
    if (local != null && (cloud == null || !cloud.isAfter(local))) return null;
    if (cloud != null) await prefs.setString(_settingsUpdatedKey, cloud.toIso8601String());
    return remote;
  }

  Future<Map<String, dynamic>?> fetchSettings() async {
    final ref = userDoc;
    if (ref == null) return null;
    try {
      final snap = await ref.collection('settings').doc('app_settings').get().timeout(const Duration(seconds: 8));
      return snap.data();
    } catch (e) {
      debugPrint('Sync fetchSettings failed: $e');
      return null;
    }
  }

  static const busPrefsKey = 'bus_locations_json';
  static const busUpdatedKey = 'bus_updated_at';

  Future<void> pushBus(List<Map<String, dynamic>> locations) async {
    final now = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(busUpdatedKey, now);
    final ref = userDoc;
    if (ref == null) return;
    try {
      await ref
          .collection('settings')
          .doc('bus_timetable')
          .set({'locations': locations, 'updatedAt': now})
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Sync pushBus failed: $e');
    }
  }

  Future<bool> _applyBus(Map<String, dynamic>? data) async {
    if (data == null || data['locations'] is! List) return false;
    final prefs = await SharedPreferences.getInstance();
    final remote = DateTime.tryParse(data['updatedAt']?.toString() ?? '');
    final local = DateTime.tryParse(prefs.getString(busUpdatedKey) ?? '');
    if (local != null && remote != null && !remote.isAfter(local)) return false;
    await prefs.setString(busPrefsKey, jsonEncode(data['locations']));
    await prefs.setString(busUpdatedKey, (remote ?? DateTime.now()).toIso8601String());
    return true;
  }

  // ───────────────────────── Account switching ─────────────────────────

  static const _ownerKey = 'sync_owner_uid';

  /// Local data belongs to whoever was signed in last. If a *different*
  /// account signs in on this device, clear the previous user's data first
  /// so it is not uploaded into the new account.
  /// Returns true when local data was wiped.
  Future<bool> prepareForUser(String newUid) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    var wiped = false;
    if (owner != null && owner != newUid) {
      final isar = await _isarService.db;
      await isar.writeTxn(() async {
        await isar.classSessions.clear();
        await isar.academicTasks.clear();
        await isar.notes.clear();
        await isar.attendanceRecords.clear();
      });
      for (final k in const [
        'courseName', 'hasCompletedSetup', 'semesterStartMs', 'semesterEndMs',
        busPrefsKey, busUpdatedKey, 'isSwapped', 'resource_sections', 'custom_folders', _settingsUpdatedKey,
      ]) {
        await prefs.remove(k);
      }
      wiped = true;
    }
    await prefs.setString(_ownerKey, newUid);
    return wiped;
  }

  // ───────────────────────── Full sync + realtime ─────────────────────────

  /// Pulls everything once (merging, never clearing) and uploads any local
  /// records the cloud doesn't have. Safe to call repeatedly.
  Future<void> syncAll() async {
    final ref = userDoc;
    if (ref == null) return;
    isSyncing.value = true;
    try {
      final changed = <String>{};
      for (final col in const [sessionsCol, tasksCol, notesCol, attendanceCol]) {
        final snap = await ref.collection(col).get().timeout(const Duration(seconds: 12));
        if (await _mergeDocs(col, snap.docs)) changed.add(col);
        await _uploadLocalOnly(col, snap.docs.map((d) => (d.data()['syncId'] as String?) ?? d.id).toSet());
      }
      final bus = await ref.collection('settings').doc('bus_timetable').get().timeout(const Duration(seconds: 8));
      if (await _applyBus(bus.data())) changed.add('bus');
      lastSynced.value = DateTime.now();
      if (changed.isNotEmpty) _changes.add(changed);
    } catch (e) {
      debugPrint('Sync syncAll failed (probably offline): $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Live updates: an edit on Windows shows up on the phone within seconds.
  void startRealtime() {
    final ref = userDoc;
    final u = uid;
    if (ref == null || u == null || _listeningUid == u) return;
    stopRealtime();
    _listeningUid = u;

    for (final col in const [sessionsCol, tasksCol, notesCol, attendanceCol]) {
      _subs.add(ref.collection(col).snapshots().listen((snap) async {
        final remoteDocs = snap.docChanges
            .where((c) => c.type != DocumentChangeType.removed && !c.doc.metadata.hasPendingWrites)
            .map((c) => c.doc)
            .toList();
        if (remoteDocs.isEmpty) return;
        if (await _mergeDocs(col, remoteDocs)) _changes.add({col});
        lastSynced.value = DateTime.now();
      }, onError: (e) => debugPrint('Realtime $col error: $e')));
    }
    _subs.add(ref.collection('settings').doc('bus_timetable').snapshots().listen((snap) async {
      if (snap.metadata.hasPendingWrites) return;
      if (await _applyBus(snap.data())) _changes.add({'bus'});
    }, onError: (e) => debugPrint('Realtime bus error: $e')));
    _subs.add(ref.collection('settings').doc('app_settings').snapshots().listen((snap) {
      if (snap.metadata.hasPendingWrites || snap.data() == null) return;
      _changes.add({'settings'});
    }, onError: (e) => debugPrint('Realtime settings error: $e')));
  }

  void stopRealtime() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _listeningUid = null;
  }

  // ───────────────────────── Merge internals ─────────────────────────

  /// Last-write-wins rule used by the merge.
  @visibleForTesting
  static bool remoteWins(DateTime? remote, DateTime? local) => _remoteWins(remote, local);

  static bool _remoteWins(DateTime? remote, DateTime? local) {
    if (local == null) return true;
    if (remote == null) return false;
    return remote.isAfter(local);
  }

  Future<bool> _mergeDocs(String col, List<DocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (docs.isEmpty) return false;
    final isar = await _isarService.db;
    var changed = false;
    await isar.writeTxn(() async {
      for (final doc in docs) {
        final data = doc.data();
        if (data == null) continue;
        final syncId = (data['syncId'] as String?) ?? doc.id;
        final remoteUpdated = DateTime.tryParse(data['updatedAt']?.toString() ?? '');
        final deleted = data['deleted'] == true;

        switch (col) {
          case sessionsCol:
            final local = await isar.classSessions.filter().syncIdEqualTo(syncId).findFirst();
            if (deleted) {
              if (local != null && _remoteWins(remoteUpdated, local.updatedAt)) {
                await isar.classSessions.delete(local.id);
                changed = true;
              }
            } else if (local == null || _remoteWins(remoteUpdated, local.updatedAt)) {
              final obj = ClassSession.fromSyncJson(data)..syncId = syncId;
              if (local != null) obj.id = local.id;
              await isar.classSessions.put(obj);
              changed = true;
            }
          case tasksCol:
            final local = await isar.academicTasks.filter().syncIdEqualTo(syncId).findFirst();
            if (deleted) {
              if (local != null && _remoteWins(remoteUpdated, local.updatedAt)) {
                await isar.academicTasks.delete(local.id);
                changed = true;
              }
            } else if (local == null || _remoteWins(remoteUpdated, local.updatedAt)) {
              final obj = AcademicTask.fromJson(data)..syncId = syncId;
              if (local != null) obj.id = local.id;
              await isar.academicTasks.put(obj);
              changed = true;
            }
          case notesCol:
            final local = await isar.notes.filter().syncIdEqualTo(syncId).findFirst();
            if (deleted) {
              if (local != null && _remoteWins(remoteUpdated, local.updatedAt)) {
                await isar.notes.delete(local.id);
                changed = true;
              }
            } else if (local == null || _remoteWins(remoteUpdated, local.updatedAt)) {
              final obj = Note.fromJson(data)..syncId = syncId;
              if (local != null) obj.id = local.id;
              await isar.notes.put(obj);
              changed = true;
            }
          case attendanceCol:
            final local = await isar.attendanceRecords.filter().syncIdEqualTo(syncId).findFirst();
            if (deleted) {
              if (local != null && _remoteWins(remoteUpdated, local.updatedAt)) {
                await isar.attendanceRecords.delete(local.id);
                changed = true;
              }
            } else if (local == null || _remoteWins(remoteUpdated, local.updatedAt)) {
              final obj = AttendanceRecord.fromJson(data)..syncId = syncId;
              if (local != null) obj.id = local.id;
              await isar.attendanceRecords.put(obj);
              changed = true;
            }
        }
      }
    });
    return changed;
  }

  /// Uploads records that exist only on this device (created offline, or
  /// created before the user ever signed in).
  Future<void> _uploadLocalOnly(String col, Set<String> remoteIds) async {
    final isar = await _isarService.db;
    final toUpload = <Map<String, dynamic>>[];

    Future<void> handle<T extends Object>(List<T> items, Future<void> Function(T) save, Map<String, dynamic> Function(T) json,
        String? Function(T) idOf) async {
      final needsStamp = items.where((i) => idOf(i) == null).toList();
      if (needsStamp.isNotEmpty) {
        await isar.writeTxn(() async {
          for (final i in needsStamp) {
            stamp(i);
            await save(i);
          }
        });
      }
      for (final i in items) {
        if (!remoteIds.contains(idOf(i))) toUpload.add(json(i));
      }
    }

    switch (col) {
      case sessionsCol:
        await handle<ClassSession>(await isar.classSessions.where().findAll(), (s) => isar.classSessions.put(s),
            (s) => s.toSyncJson(), (s) => s.syncId);
      case tasksCol:
        await handle<AcademicTask>(await isar.academicTasks.where().findAll(), (t) => isar.academicTasks.put(t),
            (t) => t.toJson(), (t) => t.syncId);
      case notesCol:
        await handle<Note>(await isar.notes.where().findAll(), (n) => isar.notes.put(n), (n) => n.toJson(), (n) => n.syncId);
      case attendanceCol:
        await handle<AttendanceRecord>(await isar.attendanceRecords.where().findAll(),
            (a) => isar.attendanceRecords.put(a), (a) => a.toJson(), (a) => a.syncId);
    }
    await pushMany(col, toUpload);
  }
}
