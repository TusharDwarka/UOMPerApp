import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/module_record.dart';
import '../services/activity_log.dart';
import '../services/sync_service.dart';
import '../utils/time_utils.dart';

/// Grades, module life-cycle (ongoing → ended → resit) and holiday mode.
///
/// Everything lives in SharedPreferences and is mirrored into the cloud
/// settings document, so it follows the account between phone and PC.
class RecordProvider extends ChangeNotifier {
  final SyncService? _syncService;

  /// Told which modules have ended (lower-cased name → end date), so the
  /// timetable can stop showing their classes.
  final void Function(Map<String, DateTime> ended)? onEndedModulesChanged;

  static const _recordsKey = 'module_records';
  static const _holidayKey = 'holiday_mode';
  static const _holidaySinceKey = 'holiday_since';
  static const _capResitKey = 'cap_resit_marks';

  /// Prefs keys owned by this provider (cleared when another account signs in).
  static const prefsKeys = [_recordsKey, _holidayKey, _holidaySinceKey, _capResitKey, ActivityLog.prefsKey];

  List<ModuleRecord> _records = [];
  bool _holidayMode = false;
  DateTime? _holidaySince;
  bool _capResit = false;
  bool _loaded = false;
  bool _seeded = false;
  Timer? _activityPush;

  RecordProvider([this._syncService, this.onEndedModulesChanged]) {
    ActivityLog.instance.addListener(_onActivity);
    load();
  }

  @override
  void dispose() {
    ActivityLog.instance.removeListener(_onActivity);
    _activityPush?.cancel();
    super.dispose();
  }

  List<ModuleRecord> get records => List.unmodifiable(_records);
  bool get holidayMode => _holidayMode;
  DateTime? get holidaySince => _holidaySince;
  bool get capResit => _capResit;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_seeded) return; // widget tests: keep the seeded data
    _records = _decode(prefs.getString(_recordsKey));
    _holidayMode = prefs.getBool(_holidayKey) ?? false;
    final since = prefs.getInt(_holidaySinceKey);
    _holidaySince = since == null ? null : DateTime.fromMillisecondsSinceEpoch(since);
    _capResit = prefs.getBool(_capResitKey) ?? false;
    await ActivityLog.instance.load();
    _loaded = true;
    _announceEnded();
    notifyListeners();
  }

  static List<ModuleRecord> _decode(Object? raw) {
    Object? data = raw;
    if (raw is String) {
      try {
        data = jsonDecode(raw);
      } catch (_) {
        return [];
      }
    }
    if (data is! List) return [];
    return [
      for (final e in data)
        if (e is Map) ModuleRecord.fromJson(Map<String, dynamic>.from(e))
    ];
  }

  // ───────────── Cloud settings ─────────────

  Map<String, dynamic> settingsSnapshot() => {
        'moduleRecords': [for (final r in _records) r.toJson()],
        'holidayMode': _holidayMode,
        'holidaySinceMs': _holidaySince?.millisecondsSinceEpoch,
        'capResitMarks': _capResit,
        'activityLog': ActivityLog.instance.days,
      };

  Future<void> applyCloudSettings(Map<String, dynamic> s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s['moduleRecords'] is List) {
      _records = _decode(s['moduleRecords']);
      await prefs.setString(_recordsKey, jsonEncode([for (final r in _records) r.toJson()]));
    }
    if (s['holidayMode'] is bool) {
      _holidayMode = s['holidayMode'];
      await prefs.setBool(_holidayKey, _holidayMode);
    }
    if (s.containsKey('holidaySinceMs')) {
      final ms = s['holidaySinceMs'];
      _holidaySince = ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      ms is int ? await prefs.setInt(_holidaySinceKey, ms) : await prefs.remove(_holidaySinceKey);
    }
    if (s['capResitMarks'] is bool) {
      _capResit = s['capResitMarks'];
      await prefs.setBool(_capResitKey, _capResit);
    }
    if (s['activityLog'] is Map) {
      await ActivityLog.instance.merge(ActivityLog.decode(s['activityLog']));
    }
    _announceEnded();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode([for (final r in _records) r.toJson()]));
    await prefs.setBool(_holidayKey, _holidayMode);
    if (_holidaySince != null) {
      await prefs.setInt(_holidaySinceKey, _holidaySince!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_holidaySinceKey);
    }
    await prefs.setBool(_capResitKey, _capResit);
    _syncService?.pushSettings(settingsSnapshot());
    _announceEnded();
    notifyListeners();
  }

  void _onActivity() {
    // Batch: finishing several tasks in a row sends one settings write.
    _activityPush?.cancel();
    _activityPush = Timer(const Duration(seconds: 5), () => _syncService?.pushSettings({'activityLog': ActivityLog.instance.days}));
  }

  /// Deferred: this can run while widgets are building (the provider is
  /// created during build), and the timetable notifies its own listeners.
  void _announceEnded() {
    final cb = onEndedModulesChanged;
    if (cb == null) return;
    final ended = endedModules;
    scheduleMicrotask(() => cb(ended));
  }

  // ───────────── Modules ─────────────

  /// Lower-cased module name → the day it ended (ended or waiting on a resit).
  /// A module taken again later (an ongoing record with the same name) wins.
  Map<String, DateTime> get endedModules {
    final active = {for (final r in _records) if (r.isActive) r.key};
    return {
      for (final r in _records)
        if (r.isEnded && !active.contains(r.key)) r.key: dateOnly(r.endedAt ?? DateTime.now()),
    };
  }

  /// The current record for a module: the ongoing one if any, otherwise the
  /// most recent year/semester.
  ModuleRecord? recordFor(String moduleName) {
    final k = ModuleRecord.keyFor(moduleName);
    ModuleRecord? best;
    for (final r in _records) {
      if (r.key != k) continue;
      if (r.isActive) return r;
      if (best == null || r.year * 10 + r.semester > best.year * 10 + best.semester) best = r;
    }
    return best;
  }

  bool isEnded(String moduleName) => recordFor(moduleName)?.isEnded ?? false;

  /// The record for a module in this year/semester, created on first use.
  /// An ended record from an earlier semester is left alone (repeat module).
  ModuleRecord _ensure(String moduleName, {required int year, required int semester}) {
    final k = ModuleRecord.keyFor(moduleName);
    for (final r in _records) {
      if (r.key == k && (r.isActive || (r.year == year && r.semester == semester))) return r;
    }
    final r = ModuleRecord(name: moduleName.trim(), year: year, semester: semester);
    _records = [..._records, r];
    return r;
  }

  /// Adds the timetable's modules that don't have a record this semester.
  Future<int> importModules(Iterable<String> names, {required int year, required int semester}) async {
    final before = _records.length;
    for (final n in names) {
      if (n.trim().isNotEmpty) _ensure(n, year: year, semester: semester);
    }
    final added = _records.length - before;
    if (added > 0) await _save();
    return added;
  }

  Future<void> saveRecord(ModuleRecord record) async {
    final i = _records.indexWhere((r) => r.id == record.id);
    _records = i == -1 ? [..._records, record] : ([..._records]..[i] = record);
    await _save();
  }

  /// Removes a record and returns it so the caller can offer "Undo".
  Future<ModuleRecord?> deleteRecord(String id) async {
    final i = _records.indexWhere((r) => r.id == id);
    if (i == -1) return null;
    final removed = _records[i];
    _records = [..._records]..removeAt(i);
    await _save();
    return removed;
  }

  /// Finishes a module before the semester ends (e.g. after its final test).
  Future<ModuleRecord> endModule(String moduleName,
      {required int year, required int semester, double? mark, DateTime? on}) async {
    final r = _ensure(moduleName, year: year, semester: semester);
    r
      ..status = ModuleStatus.ended
      ..endedAt = dateOnly(on ?? DateTime.now());
    if (mark != null) r.mark = mark;
    await _save();
    return r;
  }

  /// Puts an ended module back on the timetable.
  Future<void> reopenModule(String moduleName) async {
    final r = recordFor(moduleName);
    if (r == null) return;
    r
      ..status = ModuleStatus.active
      ..endedAt = null;
    await _save();
  }

  Future<void> markResit(String moduleName, {DateTime? date}) async {
    final r = recordFor(moduleName);
    if (r == null) return;
    r
      ..status = ModuleStatus.resit
      ..endedAt ??= dateOnly(DateTime.now())
      ..resitDate = date;
    await _save();
  }

  Future<void> setCapResit(bool value) async {
    _capResit = value;
    await _save();
  }

  // ───────────── Semester / holiday ─────────────

  /// Ends every ongoing module of the semester (keeping their marks) and
  /// switches the app into holiday mode.
  Future<void> endSemester(Iterable<String> timetableModules, {required int year, required int semester}) async {
    for (final n in timetableModules) {
      _ensure(n, year: year, semester: semester);
    }
    final today = dateOnly(DateTime.now());
    for (final r in _records) {
      if (r.isActive) {
        r
          ..status = ModuleStatus.ended
          ..endedAt = today;
      }
    }
    _holidayMode = true;
    _holidaySince = today;
    await _save();
  }

  Future<void> setHolidayMode(bool on) async {
    _holidayMode = on;
    _holidaySince = on ? (_holidaySince ?? dateOnly(DateTime.now())) : null;
    await _save();
  }

  // ───────────── Grades / CPA ─────────────

  double? markOf(ModuleRecord r) => r.effectiveMark(capResit: _capResit, passMark: Grading.passMark);

  /// Records with a mark, i.e. what the CPA is computed from.
  List<ModuleRecord> get graded => _records.where((r) => markOf(r) != null).toList();

  double get gradedCredits => graded.fold(0.0, (a, r) => a + r.credits);

  /// Cumulative performance average: credit-weighted mean of all marks.
  double? get cpa => Grading.weightedAverage(graded.map((r) => (r.credits, markOf(r)!)));

  /// Average for one year/semester (null when nothing is graded yet).
  double? semesterAverage(int year, int semester) => Grading.weightedAverage(
      graded.where((r) => r.year == year && r.semester == semester).map((r) => (r.credits, markOf(r)!)));

  /// Average for a whole year of study (null when nothing is graded yet).
  double? yearAverage(int year) =>
      Grading.weightedAverage(graded.where((r) => r.year == year).map((r) => (r.credits, markOf(r)!)));

  /// Years of study that have a graded module, in order.
  List<int> get gradedYears => ({for (final r in graded) r.year}.toList()..sort());

  /// CPA if every unfinished module ends on its average so far.
  double? get projectedCpa => Grading.weightedAverage([
        for (final r in _records)
          if (markOf(r) != null) (r.credits, markOf(r)!) else if (r.averageSoFar != null) (r.credits, r.averageSoFar!),
      ]);

  /// (year, semester) pairs that have records, newest first.
  List<(int, int)> get periods {
    final set = {for (final r in _records) (r.year, r.semester)}.toList()
      ..sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2));
    return set;
  }

  /// Seeds in-memory data without SharedPreferences (widget tests only).
  @visibleForTesting
  void debugSetData({List<ModuleRecord> records = const [], bool holiday = false}) {
    _seeded = true;
    _records = [...records];
    _holidayMode = holiday;
    _holidaySince = holiday ? dateOnly(DateTime.now()) : null;
    _loaded = true;
    _announceEnded();
    notifyListeners();
  }
}
