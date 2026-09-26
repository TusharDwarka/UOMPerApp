import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

enum FocusPhase { idle, focus, rest }

/// Pomodoro-style focus timer with a per-day minutes log, streak and weekly
/// stats. The running timer is stored as an end timestamp, so it survives
/// the app being backgrounded or closed.
class FocusProvider extends ChangeNotifier {
  static final _dayFmt = DateFormat('yyyy-MM-dd');
  static const _notifKey = 'focus_timer_done';

  Map<String, int> _log = {}; // yyyy-MM-dd -> minutes
  int focusMinutes = 25;
  int breakMinutes = 5;
  int dailyGoalMinutes = 120;
  String label = '';

  FocusPhase _phase = FocusPhase.idle;
  DateTime? _endsAt;
  DateTime? _startedAt;
  Duration? _pausedRemaining;
  Timer? _ticker;

  FocusPhase get phase => _phase;
  bool get isRunning => _phase != FocusPhase.idle && _endsAt != null;
  bool get isPaused => _phase != FocusPhase.idle && _pausedRemaining != null;

  Duration get remaining {
    if (_pausedRemaining != null) return _pausedRemaining!;
    final e = _endsAt;
    if (e == null) return Duration(minutes: focusMinutes);
    final r = e.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  double get progress {
    final total = (_phase == FocusPhase.rest ? breakMinutes : focusMinutes) * 60;
    if (_phase == FocusPhase.idle || total == 0) return 0;
    return 1 - remaining.inSeconds / total;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('focus_log');
    if (raw != null) _log = Map<String, int>.from(jsonDecode(raw));
    focusMinutes = prefs.getInt('focus_len') ?? 25;
    breakMinutes = prefs.getInt('focus_break') ?? 5;
    dailyGoalMinutes = prefs.getInt('focus_goal') ?? 120;

    final endMs = prefs.getInt('focus_ends_at');
    final startMs = prefs.getInt('focus_started_at');
    final phase = prefs.getString('focus_phase');
    if (endMs != null && phase != null) {
      _phase = FocusPhase.values.byName(phase);
      _endsAt = DateTime.fromMillisecondsSinceEpoch(endMs);
      _startedAt = startMs != null ? DateTime.fromMillisecondsSinceEpoch(startMs) : null;
      label = prefs.getString('focus_label') ?? '';
      _startTicker();
    }
    notifyListeners();
  }

  Future<void> setDurations({int? focus, int? rest, int? goal}) async {
    final prefs = await SharedPreferences.getInstance();
    if (focus != null) {
      focusMinutes = focus;
      await prefs.setInt('focus_len', focus);
    }
    if (rest != null) {
      breakMinutes = rest;
      await prefs.setInt('focus_break', rest);
    }
    if (goal != null) {
      dailyGoalMinutes = goal;
      await prefs.setInt('focus_goal', goal);
    }
    notifyListeners();
  }

  void setLabel(String value) {
    label = value;
    notifyListeners();
  }

  Future<void> start({String? subject}) async {
    label = subject ?? label;
    await _begin(FocusPhase.focus, Duration(minutes: focusMinutes));
  }

  Future<void> _begin(FocusPhase phase, Duration length) async {
    _phase = phase;
    _startedAt = DateTime.now();
    _endsAt = _startedAt!.add(length);
    _pausedRemaining = null;
    await _persist();
    NotificationService().scheduleOneOff(
      key: _notifKey,
      title: phase == FocusPhase.focus ? 'Focus session complete 🎉' : 'Break over',
      body: phase == FocusPhase.focus ? 'Take a $breakMinutes min break.' : 'Ready for another round?',
      at: _endsAt!,
    );
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _pausedRemaining = remaining;
    _creditElapsed();
    _endsAt = null;
    _ticker?.cancel();
    NotificationService().cancelOneOff(_notifKey);
    _persist();
    notifyListeners();
  }

  Future<void> resume() async {
    final r = _pausedRemaining;
    if (r == null) return;
    await _begin(_phase, r);
  }

  /// Stops the timer, crediting the focused minutes so far.
  Future<void> stop() async {
    if (_phase == FocusPhase.focus && _endsAt != null) _creditElapsed();
    _reset();
    NotificationService().cancelOneOff(_notifKey);
    await _persist();
    notifyListeners();
  }

  void _reset() {
    _phase = FocusPhase.idle;
    _endsAt = null;
    _startedAt = null;
    _pausedRemaining = null;
    _ticker?.cancel();
  }

  void _creditElapsed() {
    if (_phase != FocusPhase.focus || _startedAt == null) return;
    final end = _endsAt != null && DateTime.now().isAfter(_endsAt!) ? _endsAt! : DateTime.now();
    final mins = end.difference(_startedAt!).inMinutes;
    if (mins > 0) addMinutes(mins, day: _startedAt!);
    _startedAt = DateTime.now();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endsAt != null && !DateTime.now().isBefore(_endsAt!)) {
        _onPhaseEnd();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> _onPhaseEnd() async {
    if (_phase == FocusPhase.focus) {
      _creditElapsed();
      await _begin(FocusPhase.rest, Duration(minutes: breakMinutes));
    } else {
      _reset();
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_log', jsonEncode(_log));
    if (_endsAt != null) {
      await prefs.setInt('focus_ends_at', _endsAt!.millisecondsSinceEpoch);
      await prefs.setString('focus_phase', _phase.name);
      await prefs.setString('focus_label', label);
      if (_startedAt != null) await prefs.setInt('focus_started_at', _startedAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('focus_ends_at');
      await prefs.remove('focus_phase');
      await prefs.remove('focus_started_at');
    }
  }

  void addMinutes(int minutes, {DateTime? day}) {
    final key = _dayFmt.format(day ?? DateTime.now());
    _log[key] = (_log[key] ?? 0) + minutes;
    _persist();
    notifyListeners();
  }

  // ───────────── Stats ─────────────

  int minutesOn(DateTime day) => _log[_dayFmt.format(day)] ?? 0;

  int get todayMinutes => minutesOn(DateTime.now());

  /// Monday-first minutes for the week containing [anchor].
  List<int> weekMinutes([DateTime? anchor]) {
    final a = anchor ?? DateTime.now();
    final monday = DateTime(a.year, a.month, a.day - (a.weekday - 1));
    return List.generate(7, (i) => minutesOn(DateTime(monday.year, monday.month, monday.day + i)));
  }

  int get thisWeekTotal => weekMinutes().fold(0, (a, b) => a + b);

  int get lastWeekTotal {
    final n = DateTime.now();
    return weekMinutes(DateTime(n.year, n.month, n.day - 7)).fold(0, (a, b) => a + b);
  }

  /// Change vs last week, e.g. +13 (%). Null when there's no baseline.
  int? get weekOverWeekPercent {
    final last = lastWeekTotal;
    if (last == 0) return null;
    return (((thisWeekTotal - last) / last) * 100).round();
  }

  /// Consecutive days (ending today, or yesterday if today is still empty)
  /// with at least 25 focused minutes.
  int get streak {
    var day = DateTime.now();
    if (minutesOn(day) < 25) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (minutesOn(day) >= 25) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
