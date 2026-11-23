import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../providers/note_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/activity_log.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/ui.dart';

/// One day's activity: finished tasks, notes written and minutes focused.
class DayActivity {
  final int tasks;
  final int notes;
  final int focusMinutes;
  const DayActivity({this.tasks = 0, this.notes = 0, this.focusMinutes = 0});

  /// Each task / note counts 1, every started 25 minutes of focus counts 1.
  int get score => tasks + notes + (focusMinutes + 24) ~/ 25;

  static int level(int score) => score == 0 ? 0 : score <= 2 ? 1 : score <= 4 ? 2 : score <= 7 ? 3 : 4;
}

/// Builds per-day activity from the log, the current tasks/notes and the
/// focus log (the log keeps tasks that were auto-cleared from the board).
Map<DateTime, DayActivity> buildActivity({
  required DateTime from,
  required DateTime to,
  required ActivityLog log,
  required Iterable<DateTime> doneTaskDays,
  required Iterable<DateTime> noteDays,
  required int Function(DateTime) focusMinutesOn,
}) {
  final tasks = <DateTime, int>{}, notes = <DateTime, int>{};
  for (final d in doneTaskDays) {
    tasks.update(dateOnly(d), (v) => v + 1, ifAbsent: () => 1);
  }
  for (final d in noteDays) {
    notes.update(dateOnly(d), (v) => v + 1, ifAbsent: () => 1);
  }
  final out = <DateTime, DayActivity>{};
  for (var d = dateOnly(from); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final t = [log.count(d, ActivityLog.tasks), tasks[d] ?? 0].reduce((a, b) => a > b ? a : b);
    final n = [log.count(d, ActivityLog.notes), notes[d] ?? 0].reduce((a, b) => a > b ? a : b);
    final f = focusMinutesOn(d);
    if (t + n + f > 0) out[d] = DayActivity(tasks: t, notes: n, focusMinutes: f);
  }
  return out;
}

/// GitHub-style contribution graph of the last year.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _scroll = ScrollController();
  DateTime? _selected;
  bool _scrolledToEnd = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final log = context.watch<ActivityLog>();
    final timetable = context.watch<TimetableProvider>();
    final notes = context.watch<NoteProvider>();
    // Focus ticks every second while running; the heatmap doesn't need that.
    final focus = context.read<FocusProvider>();

    final today = dateOnly(DateTime.now());
    // 53 Monday-first weeks ending with the current one.
    final firstMonday = today.subtract(Duration(days: today.weekday - 1 + 52 * 7));
    final data = buildActivity(
      from: firstMonday,
      to: today,
      log: log,
      doneTaskDays: [for (final t in timetable.tasks) if (t.isCompleted) t.updatedAt ?? t.dueDate],
      noteDays: [for (final n in notes.notes) n.timestamp],
      focusMinutesOn: focus.minutesOn,
    );

    final total = data.values.fold(0, (a, d) => a + d.score);
    final activeDays = data.length;
    var current = 0;
    for (var d = data.containsKey(today) ? today : today.subtract(const Duration(days: 1));
        data.containsKey(d);
        d = DateTime(d.year, d.month, d.day - 1)) {
      current++;
    }
    var longest = 0, run = 0;
    for (var d = firstMonday; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      run = data.containsKey(d) ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    final sel = _selected;
    final selData = sel == null ? null : data[sel];

    if (!_scrolledToEnd) {
      _scrolledToEnd = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const ScreenHeader(title: 'Activity', eyebrow: 'Tasks finished, notes and focus — every day'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: _stat(p, '$total', 'contributions\nthis year')),
                const SizedBox(width: 10),
                Expanded(child: _stat(p, '$current', 'day\nstreak', accent: current > 0)),
                const SizedBox(width: 10),
                Expanded(child: _stat(p, '$longest', 'longest\nstreak')),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 8),
                      child: Text('$activeDays active day${activeDays == 1 ? '' : 's'} in the last year',
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    ),
                    _Heatmap(
                      controller: _scroll,
                      firstMonday: firstMonday,
                      today: today,
                      data: data,
                      selected: sel,
                      onTap: (d) => setState(() => _selected = sel == d ? null : d),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Less', style: TextStyle(fontSize: 11, color: p.textSecondary)),
                        for (var l = 0; l <= 4; l++)
                          Container(
                            width: 11,
                            height: 11,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(color: heatColor(p, l), borderRadius: BorderRadius.circular(3)),
                          ),
                        Text('More', style: TextStyle(fontSize: 11, color: p.textSecondary)),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: sel == null
                    ? Text('Tap a square to see that day.', key: const ValueKey('hint'), style: TextStyle(color: p.textSecondary))
                    : SoftCard(
                        key: ValueKey(sel),
                        radius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('EEEE d MMMM yyyy').format(sel),
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.textPrimary)),
                            const SizedBox(height: 10),
                            if (selData == null)
                              Text('No activity — a rest day.', style: TextStyle(color: p.textSecondary))
                            else ...[
                              _line(p, Icons.task_alt_rounded, '${selData.tasks} task${selData.tasks == 1 ? '' : 's'} finished'),
                              _line(p, Icons.sticky_note_2_outlined, '${selData.notes} note${selData.notes == 1 ? '' : 's'} written'),
                              _line(p, Icons.timer_outlined, '${selData.focusMinutes} min focused'),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(Palette p, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: p.textSecondary),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: p.textPrimary)),
        ]),
      );

  Widget _stat(Palette p, String value, String label, {bool accent = false}) => SoftCard(
        radius: 22,
        color: accent ? p.ink : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: accent ? p.onInk : p.textPrimary)),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, height: 1.2, color: accent ? p.onInk.withValues(alpha: 0.75) : p.textSecondary)),
          ],
        ),
      );
}

/// Green shades like GitHub's graph (level 0 = empty).
Color heatColor(Palette p, int level) {
  const light = [Color(0xFFEBEDF0), Color(0xFF9BE9A8), Color(0xFF40C463), Color(0xFF30A14E), Color(0xFF216E39)];
  const dark = [Color(0xFF2A2D31), Color(0xFF0E4429), Color(0xFF006D32), Color(0xFF26A641), Color(0xFF39D353)];
  return (p.isDark ? dark : light)[level.clamp(0, 4)];
}

class _Heatmap extends StatelessWidget {
  final ScrollController controller;
  final DateTime firstMonday;
  final DateTime today;
  final Map<DateTime, DayActivity> data;
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;

  const _Heatmap({
    required this.controller,
    required this.firstMonday,
    required this.today,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  static const cell = 13.0, gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final weeks = (today.difference(firstMonday).inDays ~/ 7) + 1;
    final labelStyle = TextStyle(fontSize: 10, color: p.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekday labels (Mon / Wed / Fri, like GitHub).
        Padding(
          padding: const EdgeInsets.only(top: 16, right: 4),
          child: Column(children: [
            for (var r = 0; r < 7; r++)
              SizedBox(
                height: cell + gap,
                child: Text(r == 0 ? 'Mon' : r == 2 ? 'Wed' : r == 4 ? 'Fri' : '', style: labelStyle),
              ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 16,
                  child: Row(children: [
                    for (var w = 0; w < weeks; w++)
                      SizedBox(
                        width: cell + gap,
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: 40,
                          child: Builder(builder: (_) {
                            final monday = firstMonday.add(Duration(days: w * 7));
                            final prev = monday.subtract(const Duration(days: 7));
                            final show = w == 0 ? monday.day <= 7 : monday.month != prev.month;
                            return Text(show ? DateFormat('MMM').format(monday) : '', style: labelStyle);
                          }),
                        ),
                      ),
                  ]),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Padding(
                        padding: const EdgeInsets.only(right: gap),
                        child: Column(children: [
                          for (var r = 0; r < 7; r++) _cell(p, firstMonday.add(Duration(days: w * 7 + r))),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(Palette p, DateTime day) {
    final d = dateOnly(day);
    if (d.isAfter(today)) return const SizedBox(width: cell, height: cell + gap);
    final a = data[d];
    final level = DayActivity.level(a?.score ?? 0);
    final isSel = selected != null && isSameDate(selected!, d);
    return Padding(
      padding: const EdgeInsets.only(bottom: gap),
      child: Tooltip(
        message: '${DateFormat('d MMM').format(d)}: ${a?.score ?? 0}',
        child: GestureDetector(
          onTap: () => onTap(d),
          child: Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
              color: heatColor(p, level),
              borderRadius: BorderRadius.circular(3),
              border: isSel || isSameDate(d, today) ? Border.all(color: p.ink, width: isSel ? 2 : 1) : null,
            ),
          ),
        ),
      ),
    );
  }
}
