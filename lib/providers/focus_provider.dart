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
///
/// Sessions can be linked to a board task (time spent is tracked per task),
/// every Nth break is a long one, and a break reminder fires after too much
/// continuous focus so students don't overwork.
class FocusProvider extends ChangeNotifier {
  static final _dayFmt = DateFormat('yyyy-MM-dd');
  static const _notifKey = 'focus_timer_done';
  static const _overworkKey = 'focus_overwork';

  /// Focus sessions closer together than this count as one continuous run.
  static const _runGap = Duration(minutes: 20);

  Map<String, int> _log = {}; // yyyy-MM-dd -> minutes
  Map<String, int> _taskMinutes = {}; // task syncId -> minutes

  int focusMinutes = 25;
  int breakMinutes = 5;
  int longBreakMinutes = 15;
  int sessionsBeforeLongBreak = 4;
  int dailyGoalMinutes = 120;

  /// Minutes of continuous focus before a "take a real break" reminder (0 = off).
  int workLimitMinutes = 90;

  String label = '';
  String? taskId;
  String? taskTitle;

  FocusPhase _phase = FocusPhase.idle;
  DateTime? _endsAt;
  DateTime? _startedAt;
  Duration? _pausedRemaining;
  int _phaseLengthMinutes = 25;
  int _sessionsSinceLongBreak = 0;
  int _runMinutes = 0;
  DateTime? _lastFocusAt;
  bool _longBreakActive = false;
  Timer? _ticker;

  FocusPhase get phase => _phase;
  bool get isRunning => _phase != FocusPhase.idle && _endsAt != null;
  bool get isPaused => _phase != FocusPhase.idle && _pausedRemaining != null;
  bool get isLongBreak => _phase == FocusPhase.rest && _longBreakActive;
  int get sessionsSinceLongBreak => _sessionsSinceLongBreak;

  /// Continuous focus in the current run (resets after a 20-min gap or a long break).
  int get runMinutes {
    final last = _lastFocusAt;
    if (last == null || DateTime.now().difference(last) > _runGap) return 0;
    return _runMinutes;
  }

  /// True when the user has focused past [workLimitMinutes] without a real break.
  bool get needsBreak => workLimitMinutes > 0 && runMinutes >= workLimitMinutes;

  Duration get remaining {
    if (_pausedRemaining != null) return _pausedRemaining!;
    final e = _endsAt;
    if (e == null) return Duration(minutes: focusMinutes);
    final r = e.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  double get progress {
    final total = _phaseLengthMinutes * 60;
    if (_phase == FocusPhase.idle || total == 0) return 0;
    return (1 - remaining.inSeconds / total).clamp(0.0, 1.0);
  }

  int minutesForTask(String? syncId) => syncId == null ? 0 : (_taskMinutes[syncId] ?? 0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('focus_log');
    if (raw != null) _log = Map<String, int>.from(jsonDecode(raw));
    final rawTasks = prefs.getString('focus_task_minutes');
    if (rawTasks != null) _taskMinutes = Map<String, int>.from(jsonDecode(rawTasks));
    focusMinutes = prefs.getInt('focus_len') ?? 25;
    breakMinutes = prefs.getInt('focus_break') ?? 5;
    longBreakMinutes = prefs.getInt('focus_long_break') ?? 15;
    sessionsBeforeLongBreak = prefs.getInt('focus_sessions_before_long') ?? 4;
    dailyGoalMinutes = prefs.getInt('focus_goal') ?? 120;
    workLimitMinutes = prefs.getInt('focus_work_limit') ?? 90;
    _sessionsSinceLongBreak = prefs.getInt('focus_sessions_since_long') ?? 0;
    _runMinutes = prefs.getInt('focus_run_minutes') ?? 0;
    final lastMs = prefs.getInt('focus_last_at');
    _lastFocusAt = lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);

    final endMs = prefs.getInt('focus_ends_at');
    final startMs = prefs.getInt('focus_started_at');
    final phase = prefs.getString('focus_phase');
    if (endMs != null && phase != null) {
      _phase = FocusPhase.values.byName(phase);
      _endsAt = DateTime.fromMillisecondsSinceEpoch(endMs);
      _startedAt = startMs != null ? DateTime.fromMillisecondsSinceEpoch(startMs) : null;
      _phaseLengthMinutes = prefs.getInt('focus_phase_len') ?? focusMinutes;
      _longBreakActive = prefs.getBool('focus_long_active') ?? false;
      label = prefs.getString('focus_label') ?? '';
      taskId = prefs.getString('focus_task_id');
      taskTitle = prefs.getString('focus_task_title');
      _startTicker();
    }
    notifyListeners();
  }

  Future<void> setDurations({int? focus, int? rest, int? longRest, int? sessionsBeforeLong, int? goal, int? workLimit}) async {
    final prefs = await SharedPreferences.getInstance();
    if (focus != null) {
      focusMinutes = focus;
      await prefs.setInt('focus_len', focus);
    }
    if (rest != null) {
      breakMinutes = rest;
      await prefs.setInt('focus_break', rest);
    }
    if (longRest != null) {
      longBreakMinutes = longRest;
      await prefs.setInt('focus_long_break', longRest);
    }
    if (sessionsBeforeLong != null) {
      sessionsBeforeLongBreak = sessionsBeforeLong;
      await prefs.setInt('focus_sessions_before_long', sessionsBeforeLong);
    }
    if (goal != null) {
      dailyGoalMinutes = goal;
      await prefs.setInt('focus_goal', goal);
    }
    if (workLimit != null) {
      workLimitMinutes = workLimit;
      await prefs.setInt('focus_work_limit', workLimit);
    }
    notifyListeners();
  }

  void setLabel(String value) {
    label = value;
    notifyListeners();
  }

  /// Links (or unlinks, with null) the next session to a board task.
  void setTask(String? id, String? title, {String? subject}) {
    taskId = id;
    taskTitle = title;
    if (subject != null && subject != 'General') label = subject;
    notifyListeners();
  }

  Future<void> start({String? subject}) async {
    label = subject ?? label;
    await _begin(FocusPhase.focus, focusMinutes);
  }

  /// Starts a long break now (from the overwork banner).
  Future<void> takeLongBreak() async {
    if (_phase == FocusPhase.focus && _endsAt != null) _creditElapsed();
    _endRun();
    _longBreakActive = true;
    await _begin(FocusPhase.rest, longBreakMinutes);
  }

  Future<void> _begin(FocusPhase phase, int minutes, {Duration? length}) async {
    _phase = phase;
    _phaseLengthMinutes = minutes;
    if (phase == FocusPhase.focus) _longBreakActive = false;
    _startedAt = DateTime.now();
    _endsAt = _startedAt!.add(length ?? Duration(minutes: minutes));
    _pausedRemaining = null;
    await _persist();
    NotificationService().scheduleOneOff(
      key: _notifKey,
      title: phase == FocusPhase.focus ? 'Focus session complete 🎉' : 'Break over',
      body: phase == FocusPhase.focus
          ? (_nextBreakIsLong ? 'Great run — take a longer $longBreakMinutes min break.' : 'Take a $breakMinutes min break.')
          : 'Ready for another round?',
      at: _endsAt!,
    );
    _startTicker();
    notifyListeners();
  }

  bool get _nextBreakIsLong =>
      needsBreak || (sessionsBeforeLongBreak > 0 && _sessionsSinceLongBreak + 1 >= sessionsBeforeLongBreak);

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
    await _begin(_phase, _phaseLengthMinutes, length: r);
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
    _longBreakActive = false;
    _ticker?.cancel();
  }

  void _endRun() {
    _runMinutes = 0;
    _sessionsSinceLongBreak = 0;
    NotificationService().cancelOneOff(_overworkKey);
  }

  void _creditElapsed() {
    if (_phase != FocusPhase.focus || _startedAt == null) return;
    final end = _endsAt != null && DateTime.now().isAfter(_endsAt!) ? _endsAt! : DateTime.now();
    final mins = end.difference(_startedAt!).inMinutes;
    if (mins > 0) {
      final wasOver = needsBreak;
      _runMinutes = runMinutes + mins; // runMinutes resets itself after a long gap
      _lastFocusAt = end;
      final id = taskId;
      if (id != null) _taskMinutes[id] = (_taskMinutes[id] ?? 0) + mins;
      addMinutes(mins, day: _startedAt!);
      if (!wasOver && needsBreak) {
        NotificationService().scheduleOneOff(
          key: _overworkKey,
          title: 'Time for a real break 🧠',
          body: "You've focused for ${_runMinutes ~/ 60}h ${_runMinutes % 60}m straight. Step away for 15 minutes.",
          at: DateTime.now().add(const Duration(seconds: 2)),
        );
      }
    }
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
      _sessionsSinceLongBreak++;
      final long = needsBreak || (sessionsBeforeLongBreak > 0 && _sessionsSinceLongBreak >= sessionsBeforeLongBreak);
      if (long) _endRun();
      _longBreakActive = long;
      await _begin(FocusPhase.rest, long ? longBreakMinutes : breakMinutes);
    } else {
      _reset();
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_log', jsonEncode(_log));
    await prefs.setString('focus_task_minutes', jsonEncode(_taskMinutes));
    await prefs.setInt('focus_sessions_since_long', _sessionsSinceLongBreak);
    await prefs.setInt('focus_run_minutes', _runMinutes);
    if (_lastFocusAt != null) await prefs.setInt('focus_last_at', _lastFocusAt!.millisecondsSinceEpoch);
    if (_endsAt != null) {
      await prefs.setInt('focus_ends_at', _endsAt!.millisecondsSinceEpoch);
      await prefs.setString('focus_phase', _phase.name);
      await prefs.setInt('focus_phase_len', _phaseLengthMinutes);
      await prefs.setBool('focus_long_active', _longBreakActive);
      await prefs.setString('focus_label', label);
      if (taskId != null) {
        await prefs.setString('focus_task_id', taskId!);
        await prefs.setString('focus_task_title', taskTitle ?? '');
      } else {
        await prefs.remove('focus_task_id');
        await prefs.remove('focus_task_title');
      }
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
