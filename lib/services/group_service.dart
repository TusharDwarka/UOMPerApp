import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_models.dart';
import '../utils/ids.dart';
import '../utils/time_utils.dart';
import 'notification_service.dart';

/// Firestore-backed study groups ("cohorts").
///
///   groups/{gid}                     StudyGroup
///   groups/{gid}/members/{uid}       role, displayName, weekly stats
///   groups/{gid}/sessions/{id}       shared weekly timetable
///   groups/{gid}/events/{id}         shared deadlines / exams / events
///   groups/{gid}/messages/{id}       chat + leader announcements
///   joinCodes/{CODE}                 { groupId } for private groups
///   users/{uid}.groupIds             the groups this user belongs to
///
/// Access control lives in `firestore.rules`; this class only issues the
/// writes the rules allow (e.g. only leaders edit the shared timetable).
class GroupService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String? get uid => _user?.uid;

  bool get canUseGroups => _user != null && !_user!.isAnonymous;

  String get displayName {
    final u = _user;
    if (u == null) return 'Student';
    final n = u.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final email = u.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Student';
  }

  static String weekKey([DateTime? d]) {
    final date = d ?? DateTime.now();
    final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  DocumentReference<Map<String, dynamic>> _group(String gid) => _db.collection('groups').doc(gid);
  DocumentReference<Map<String, dynamic>>? get _userDoc => uid == null ? null : _db.collection('users').doc(uid);

  /// Creates/updates users/{uid} with the display name.
  Future<void> ensureProfile() async {
    final ref = _userDoc;
    if (ref == null || !canUseGroups) return;
    try {
      await ref.set({
        'displayName': displayName,
        'email': _user?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ensureProfile failed: $e');
    }
  }

  // ───────────── Listing ─────────────

  Stream<List<StudyGroup>> myGroups() {
    final ref = _userDoc;
    if (ref == null) return Stream.value(const []);
    return ref.snapshots().asyncMap((snap) async {
      final ids = List<String>.from(snap.data()?['groupIds'] ?? const []);
      final groups = <StudyGroup>[];
      for (final id in ids) {
        try {
          final g = await _group(id).get();
          if (g.exists) groups.add(StudyGroup.fromDoc(g));
        } catch (e) {
          debugPrint('Could not load group $id: $e');
        }
      }
      return groups;
    });
  }

  /// Public groups, optionally filtered by programme/year on the client.
  Stream<List<StudyGroup>> discover() {
    return _db
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(StudyGroup.fromDoc).toList());
  }

  Stream<StudyGroup?> watchGroup(String gid) =>
      _group(gid).snapshots().map((d) => d.exists ? StudyGroup.fromDoc(d) : null);

  // ───────────── Create / join / leave ─────────────

  Future<(StudyGroup, String)> createGroup({
    required String name,
    String description = '',
    String programme = '',
    int year = 1,
    int semester = 1,
    bool isPublic = true,
    bool membersCanPost = false,
    int? colorValue,
  }) async {
    final me = uid;
    if (me == null) throw StateError('Sign in first');
    final ref = _db.collection('groups').doc();
    final code = newJoinCode();
    final group = StudyGroup(
      id: ref.id,
      name: name.trim(),
      description: description.trim(),
      programme: programme.trim(),
      year: year,
      semester: semester,
      isPublic: isPublic,
      ownerId: me,
      membersCanPost: membersCanPost,
      colorValue: colorValue,
    );

    // Sequential (not a batch): the member/joinCode rules read the group doc.
    await ref.set({...group.toMap(), 'joinCode': code, 'createdAt': FieldValue.serverTimestamp()});
    await ref.collection('members').doc(me).set({
      'displayName': displayName,
      'role': 'leader',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('joinCodes').doc(code).set({'groupId': ref.id, 'ownerId': me});
    await _userDoc!.set({'groupIds': FieldValue.arrayUnion([ref.id])}, SetOptions(merge: true));
    return (group, code);
  }

  /// Returns the join code. Anyone who can read the group can share it.
  Future<String?> joinCodeFor(String gid) async {
    final d = await _group(gid).get();
    return d.data()?['joinCode'] as String?;
  }

  Future<StudyGroup> joinByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final codeDoc = await _db.collection('joinCodes').doc(code).get();
    final gid = codeDoc.data()?['groupId'] as String?;
    if (gid == null) throw StateError('No group found for code $code');
    await _join(gid, code: code);
    final g = await _group(gid).get();
    return StudyGroup.fromDoc(g);
  }

  Future<void> joinPublic(StudyGroup g) => _join(g.id);

  Future<void> _join(String gid, {String? code}) async {
    final me = uid;
    if (me == null) throw StateError('Sign in first');
    await _group(gid).collection('members').doc(me).set({
      'displayName': displayName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      if (code != null) 'code': code,
    });
    await _userDoc!.set({'groupIds': FieldValue.arrayUnion([gid])}, SetOptions(merge: true));
  }

  Future<void> leave(String gid) async {
    final me = uid;
    if (me == null) return;
    await _group(gid).collection('members').doc(me).delete();
    await _userDoc!.set({'groupIds': FieldValue.arrayRemove([gid])}, SetOptions(merge: true));
    await cancelGroupReminders(gid);
  }

  Future<void> updateGroup(StudyGroup g) => _group(g.id).update(g.toMap());

  /// Owner only. Removes the group and its join code; members' groupIds
  /// entries are dropped lazily (missing groups are skipped when listing).
  Future<void> deleteGroup(String gid) async {
    final code = await joinCodeFor(gid);
    if (code != null) await _db.collection('joinCodes').doc(code).delete();
    await _group(gid).delete();
    await _userDoc?.set({'groupIds': FieldValue.arrayRemove([gid])}, SetOptions(merge: true));
    await cancelGroupReminders(gid);
  }

  // ───────────── Members ─────────────

  Stream<List<GroupMember>> members(String gid) => _group(gid).collection('members').snapshots().map((s) {
        final list = s.docs.map(GroupMember.fromDoc).toList();
        list.sort((a, b) {
          if (a.isLeader != b.isLeader) return a.isLeader ? -1 : 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
        return list;
      });

  Future<void> setRole(String gid, String memberUid, String role) =>
      _group(gid).collection('members').doc(memberUid).update({'role': role});

  Future<void> removeMember(String gid, String memberUid) => _group(gid).collection('members').doc(memberUid).delete();

  /// Publishes this user's weekly productivity for the leaderboard (unless
  /// they chose to keep their progress private).
  Future<void> publishStats(String gid,
      {required int focusMinutes, required int tasksDone, required int streak, String visibility = 'full'}) async {
    final me = uid;
    if (me == null) return;
    try {
      await _group(gid).collection('members').doc(me).update({
        'displayName': displayName,
        'stats': visibility == 'full'
            ? {'week': weekKey(), 'focusMinutes': focusMinutes, 'tasksDone': tasksDone, 'streak': streak}
            : FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('publishStats failed: $e');
    }
  }

  /// Ranking privacy: 'full', 'nameOnly' or 'hidden'. Progress is removed
  /// from the member doc when not 'full'.
  Future<void> setRankVisibility(String gid, String visibility) async {
    final me = uid;
    if (me == null) return;
    await _group(gid).collection('members').doc(me).update({
      'rankVisibility': visibility,
      if (visibility != 'full') 'stats': FieldValue.delete(),
    });
  }

  // ───────────── "I'm done" on shared events ─────────────

  /// Who has marked a shared event as done (uid -> display name).
  Stream<Map<String, String>> eventDone(String gid, String eventId) => _group(gid)
      .collection('events')
      .doc(eventId)
      .collection('done')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: (d.data()['name'] as String?) ?? 'Student'});

  Future<void> setEventDone(String gid, String eventId, bool done) async {
    final me = uid;
    if (me == null) return;
    final ref = _group(gid).collection('events').doc(eventId).collection('done').doc(me);
    if (done) {
      await ref.set({'name': displayName, 'at': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  // ───────────── Shared timetable ─────────────

  Stream<List<GroupSession>> sessions(String gid) => _group(gid).collection('sessions').snapshots().map((s) {
        final list = s.docs.map(GroupSession.fromDoc).toList();
        list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        return list;
      });

  Future<void> saveSession(String gid, GroupSession s) {
    final col = _group(gid).collection('sessions');
    final data = {...s.toMap(), 'createdBy': uid, 'createdByName': s.createdByName ?? displayName};
    return s.id.isEmpty ? col.add(data) : col.doc(s.id).set(data);
  }

  Future<void> deleteSession(String gid, String id) => _group(gid).collection('sessions').doc(id).delete();

  // ───────────── Shared events ─────────────

  Stream<List<GroupEvent>> events(String gid) => _group(gid)
      .collection('events')
      .orderBy('start')
      .snapshots()
      .map((s) => s.docs.map(GroupEvent.fromDoc).toList());

  Future<void> saveEvent(String gid, GroupEvent e) {
    final col = _group(gid).collection('events');
    final data = {...e.toMap(), 'createdBy': uid, 'createdByName': e.createdByName ?? displayName};
    return e.id.isEmpty ? col.add(data) : col.doc(e.id).set(data);
  }

  Future<void> deleteEvent(String gid, String id) => _group(gid).collection('events').doc(id).delete();

  // ───────────── Chat ─────────────

  Stream<List<GroupMessage>> messages(String gid, {int limit = 150}) => _group(gid)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(GroupMessage.fromDoc).toList());

  Future<void> sendMessage(String gid, String text, {bool announcement = false}) async {
    final t = text.trim();
    if (t.isEmpty || uid == null) return;
    await _group(gid).collection('messages').add({
      'text': t.length > 2000 ? t.substring(0, 2000) : t,
      'senderId': uid,
      'senderName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'kind': announcement ? 'announcement' : 'text',
    });
  }

  Future<void> deleteMessage(String gid, String id) => _group(gid).collection('messages').doc(id).delete();

  // ───────────── Next class & reminders ─────────────

  /// Next occurrence of any shared class from [now] (in progress counts).
  static ({GroupSession session, DateTime start, DateTime end, bool inProgress})? nextSession(
      List<GroupSession> sessions, DateTime now) {
    for (var d = 0; d < 8; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final dayName = DateFormat('EEEE').format(date);
      final today = sessions.where((s) => s.day == dayName).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      for (final s in today) {
        final start = date.add(Duration(minutes: s.startMinutes));
        var end = date.add(Duration(minutes: s.endMinutes));
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
        if (end.isAfter(now)) return (session: s, start: start, end: end, inProgress: !start.isAfter(now));
      }
    }
    return null;
  }

  // ───────────── Announcement notifications ─────────────
  // While the app is alive (open or in the background) new leader
  // announcements in any of the user's groups show as local notifications.
  // Notifications while the app is fully closed would need FCM + a Cloud
  // Function (Blaze plan).

  StreamSubscription? _userSub;
  final List<StreamSubscription> _announcementSubs = [];

  void startAnnouncementWatcher() {
    stopAnnouncementWatcher();
    final ref = _userDoc;
    if (ref == null || !canUseGroups) return;
    _userSub = ref.snapshots().listen((snap) {
      for (final s in _announcementSubs) {
        s.cancel();
      }
      _announcementSubs.clear();
      final ids = List<String>.from(snap.data()?['groupIds'] ?? const []);
      for (final gid in ids) {
        _announcementSubs.add(_group(gid)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots()
            .listen((ms) => _onMessages(gid, ms), onError: (_) {}));
      }
    }, onError: (_) {});
  }

  void stopAnnouncementWatcher() {
    _userSub?.cancel();
    _userSub = null;
    for (final s in _announcementSubs) {
      s.cancel();
    }
    _announcementSubs.clear();
  }

  Future<void> _onMessages(String gid, QuerySnapshot<Map<String, dynamic>> ms) async {
    if (ms.metadata.hasPendingWrites) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'announcement_seen_$gid';
    final seen = prefs.getInt(key);
    final anns = ms.docs
        .map(GroupMessage.fromDoc)
        .where((m) => m.isAnnouncement && m.createdAt != null && m.senderId != uid)
        .toList();
    final newest = anns.isEmpty ? null : anns.map((m) => m.createdAt!.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b);
    if (seen == null) {
      // First run: don't replay old announcements.
      await prefs.setInt(key, newest ?? DateTime.now().millisecondsSinceEpoch);
      return;
    }
    final fresh = anns.where((m) => m.createdAt!.millisecondsSinceEpoch > seen).toList();
    if (fresh.isEmpty) return;
    await prefs.setInt(key, newest!);
    String groupName = 'Your group';
    try {
      groupName = ((await _group(gid).get()).data()?['name'] as String?) ?? groupName;
    } catch (_) {}
    for (final m in fresh) {
      await NotificationService().scheduleOneOff(
        key: 'announcement|$gid|${m.id}',
        title: '📣 $groupName',
        body: '${m.senderName}: ${m.text}',
        at: DateTime.now().add(const Duration(seconds: 2)),
      );
    }
  }

  static String _remindKey(String gid) => 'group_remind_$gid';

  /// Minutes before a group class/event to notify this user (null = off).
  Future<int?> reminderMinutesFor(String gid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_remindKey(gid));
  }

  Future<void> setReminderMinutes(String gid, int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null) {
      await prefs.remove(_remindKey(gid));
      await cancelGroupReminders(gid);
    } else {
      await prefs.setInt(_remindKey(gid), minutes);
    }
  }

  /// Schedules local notifications for the next 7 days of shared classes and
  /// upcoming shared events. Each member chooses their own lead time.
  Future<void> scheduleGroupReminders(String gid, String groupName, List<GroupSession> sessions, List<GroupEvent> events) async {
    final minutes = await reminderMinutesFor(gid);
    await cancelGroupReminders(gid);
    if (minutes == null) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = <String>[];
    final now = DateTime.now();
    for (var d = 0; d < 7; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final dayName = DateFormat('EEEE').format(date);
      for (final s in sessions.where((s) => s.day == dayName)) {
        final start = date.add(Duration(minutes: s.startMinutes));
        final key = 'g|$gid|${DateFormat('yyyyMMdd').format(date)}|${s.id}';
        await NotificationService().scheduleOneOff(
          key: key,
          title: '$groupName: ${s.subject}',
          body: 'Starts at ${s.startTime}${s.room.isNotEmpty ? ' • ${s.room}' : ''}',
          at: start.subtract(Duration(minutes: minutes)),
        );
        keys.add(key);
      }
    }
    for (final e in events.where((e) => e.start.isAfter(now) && e.start.difference(now).inDays < 14)) {
      final key = 'g|$gid|event|${e.id}';
      await NotificationService().scheduleOneOff(
        key: key,
        title: '$groupName: ${e.title}',
        body: '${e.type} • ${DateFormat('EEE d MMM, HH:mm').format(e.start)}',
        at: e.start.subtract(Duration(minutes: minutes)),
      );
      keys.add(key);
    }
    await prefs.setStringList('${_remindKey(gid)}_keys', keys);
  }

  Future<void> cancelGroupReminders(String gid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getStringList('${_remindKey(gid)}_keys') ?? const <String>[]) {
      await NotificationService().cancelOneOff(k);
    }
    await prefs.remove('${_remindKey(gid)}_keys');
  }

  static String describeCountdown(DateTime start, DateTime now) {
    final mins = start.difference(now).inMinutes;
    if (isSameDate(start, now)) return 'in ${formatCountdown(mins)}';
    final days = dateOnly(start).difference(dateOnly(now)).inDays;
    return days == 1 ? 'tomorrow ${DateFormat('HH:mm').format(start)}' : DateFormat('EEE HH:mm').format(start);
  }
}
