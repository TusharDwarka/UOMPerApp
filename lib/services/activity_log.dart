import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-day counters behind the Activity heatmap ("tasks finished", "notes
/// written"). Finished tasks are auto-cleared from the board after a while,
/// so the count is kept here instead of being recomputed from the tasks.
///
/// Stored as {"yyyy-MM-dd": {"tasks": n, "notes": n}} in SharedPreferences
/// and synced through settings (merged by taking the larger count per day).
class ActivityLog extends ChangeNotifier {
  ActivityLog._();
  static final instance = ActivityLog._();

  static const prefsKey = 'activity_log';
  static const tasks = 'tasks';
  static const notes = 'notes';
  static final dayFmt = DateFormat('yyyy-MM-dd');

  Map<String, Map<String, int>> _days = {};
  bool _loaded = false;

  Map<String, Map<String, int>> get days => _days;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _days = decode(prefs.getString(prefsKey));
    _loaded = true;
    notifyListeners();
  }

  int count(DateTime day, String kind) => _days[dayFmt.format(day)]?[kind] ?? 0;

  Future<void> bump(String kind, {DateTime? day}) async {
    if (!_loaded) await load();
    final key = dayFmt.format(day ?? DateTime.now());
    final entry = {...?_days[key]};
    entry[kind] = (entry[kind] ?? 0) + 1;
    _days = {..._days, key: entry};
    await _save();
  }

  /// Takes the larger count per day/kind, so two devices never lose activity.
  Future<void> merge(Map<String, Map<String, int>> other) async {
    if (!_loaded) await load();
    var changed = false;
    final out = {for (final e in _days.entries) e.key: {...e.value}};
    other.forEach((day, kinds) {
      final mine = out.putIfAbsent(day, () => {});
      kinds.forEach((k, v) {
        if (v > (mine[k] ?? 0)) {
          mine[k] = v;
          changed = true;
        }
      });
    });
    if (!changed) return;
    _days = out;
    await _save();
  }

  Future<void> clear() async {
    _days = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(_days));
    notifyListeners();
  }

  static Map<String, Map<String, int>> decode(Object? raw) {
    Object? data = raw;
    if (raw is String) {
      try {
        data = jsonDecode(raw);
      } catch (_) {
        return {};
      }
    }
    if (data is! Map) return {};
    final out = <String, Map<String, int>>{};
    data.forEach((day, kinds) {
      if (kinds is Map) {
        out[day.toString()] = {
          for (final e in kinds.entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt()
        };
      }
    });
    return out;
  }

  @visibleForTesting
  void debugSet(Map<String, Map<String, int>> days) {
    _days = days;
    _loaded = true;
    notifyListeners();
  }
}
