import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/class_session.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_layout.dart';
import '../utils/time_utils.dart';
import '../widgets/class_details_sheet.dart';
import '../widgets/ui.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  static const double _hourHeight = 68;
  static const double _gutter = 54;

  DateTime _selectedDate = dateOnly(DateTime.now());
  final _scroll = ScrollController();
  Timer? _minuteTicker;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    // Keeps the "now" line and in-progress highlighting current.
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  DateTime get _weekStart => _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

  void _select(DateTime d) {
    setState(() => _selectedDate = dateOnly(d));
    _didInitialScroll = false;
  }

  /// Hour range shown for the day: at least 08:00–18:00, stretched to fit
  /// early/late classes (these used to be silently hidden before 08:00).
  (int, int) _hourRange(List<ClassSession> events) {
    var start = 8, end = 18;
    for (final e in events) {
      start = math.min(start, e.startMinutes ~/ 60);
      end = math.max(end, ((math.max(e.endMinutes, e.startMinutes + 30)) / 60).ceil());
    }
    return (start.clamp(0, 23), end.clamp(start + 1, 24));
  }

  void _autoScroll(int startHour, List<ClassSession> events) {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final now = DateTime.now();
      int targetMin;
      if (isSameDate(_selectedDate, now)) {
        targetMin = now.hour * 60 + now.minute - 60;
      } else if (events.isNotEmpty) {
        targetMin = events.first.startMinutes - 30;
      } else {
        targetMin = startHour * 60;
      }
      final offset = ((targetMin - startHour * 60) / 60 * _hourHeight).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(offset, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final timetable = context.watch<TimetableProvider>();
    final events = timetable.getClassesForDate(_selectedDate);
    final (startHour, endHour) = _hourRange(events);
    _autoScroll(startHour, events);

    final title = timetable.courseName.isNotEmpty ? timetable.courseName : 'Schedule';
    final preSemester = _selectedDate.isBefore(dateOnly(timetable.semesterStart));

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: title,
              eyebrow: '${timetable.getWeekLabel(_selectedDate)} · ${DateFormat('MMMM yyyy').format(_selectedDate)}',
              actions: [
                CircleIconButton(
                  icon: Icons.event_rounded,
                  tooltip: 'Pick a date',
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) _select(picked);
                  },
                ),
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'Add class',
                  onPressed: () => editClass(context, forDate: _selectedDate),
                ),
              ],
            ),
            _buildWeekStrip(p, timetable),
            const SizedBox(height: 8),
            Expanded(
              child: preSemester
                  ? const EmptyState(
                      icon: Icons.beach_access_rounded,
                      title: 'Before the semester',
                      subtitle: 'Classes start on your semester start date. Change it in Settings.',
                    )
                  : SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(0, 12, 16, 40),
                      child: LayoutBuilder(builder: (context, c) {
                        final gridWidth = c.maxWidth - _gutter;
                        final height = (endHour - startHour) * _hourHeight;
                        return SizedBox(
                          height: height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var h = startHour; h <= endHour; h++) ..._hourLine(p, h, startHour),
                              ..._buildBlocks(p, timetable, events, startHour, gridWidth),
                              if (events.isEmpty)
                                Positioned(
                                  top: _hourHeight * 1.5,
                                  left: _gutter,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      _selectedDate.weekday >= 6 ? 'Weekend — no classes' : 'No classes this day',
                                      style: TextStyle(color: p.textSecondary),
                                    ),
                                  ),
                                ),
                              if (isSameDate(_selectedDate, DateTime.now())) _nowLine(p, startHour, endHour),
                            ],
                          ),
                        );
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _hourLine(Palette p, int hour, int startHour) {
    final top = (hour - startHour) * _hourHeight;
    return [
      // Label is vertically centred on its grid line.
      Positioned(
        top: top - 8,
        left: 0,
        width: _gutter - 8,
        child: Text(
          hour == 24 ? '00:00' : '${hour.toString().padLeft(2, '0')}:00',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, height: 1.4, color: p.textMuted, fontWeight: FontWeight.w600),
        ),
      ),
      Positioned(top: top, left: _gutter, right: 0, child: Container(height: 1, color: p.border)),
    ];
  }

  Widget _nowLine(Palette p, int startHour, int endHour) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes < startHour * 60 || minutes > endHour * 60) return const SizedBox.shrink();
    final top = (minutes - startHour * 60) / 60 * _hourHeight;
    return Positioned(
      top: top - 5,
      left: _gutter - 5,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
            Expanded(child: Container(height: 2, color: p.accent)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBlocks(Palette p, TimetableProvider timetable, List<ClassSession> events, int startHour, double gridWidth) {
    final laid = layoutDayBlocks<ClassSession>(events, startOf: (s) => s.startMinutes, endOf: (s) => s.endMinutes);
    final now = DateTime.now();
    final isToday = isSameDate(_selectedDate, now);
    final nowMin = now.hour * 60 + now.minute;

    return [
      for (final b in laid)
        Builder(builder: (context) {
          final s = b.item;
          final laneWidth = gridWidth / b.laneCount;
          final top = (b.start - startHour * 60) / 60 * _hourHeight;
          final height = math.max((b.end - b.start) / 60 * _hourHeight - 3, 26.0);
          final colors = moduleColors(s.subject, p.isDark);
          final inProgress = isToday && nowMin >= b.start && nowMin < b.end;
          final done = isToday && nowMin >= b.end;
          final record = timetable.getAttendanceRecord(s.subject, _selectedDate);

          return Positioned(
            top: top + 1.5,
            left: _gutter + 4 + b.lane * laneWidth,
            width: laneWidth - 6,
            height: height,
            child: Opacity(
              opacity: done ? 0.55 : 1,
              child: Material(
                color: colors.$1,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showClassDetailsSheet(context, s, date: _selectedDate),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: inProgress ? Border.all(color: colors.$2, width: 2) : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                    // Short (30-min) blocks can't fit every line; clip the
                    // extra lines instead of throwing an overflow.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(s.subject,
                                      maxLines: height > 60 ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: p.isDark ? Colors.white : const Color(0xFF15171A))),
                                ),
                                if (s.meetingLink != null) Icon(Icons.videocam_rounded, size: 15, color: colors.$2),
                                if (record != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(record.isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        size: 15, color: record.isPresent ? Colors.green : Colors.redAccent),
                                  ),
                              ],
                            ),
                            if (height > 40)
                              Text('${s.startTime} – ${s.endTime}${b.laneCount == 1 ? '  ·  ${s.room}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: colors.$2, fontWeight: FontWeight.w600)),
                            if (height > 64 && b.laneCount > 1)
                              Text(s.room, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: colors.$2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
    ];
  }

  Widget _buildWeekStrip(Palette p, TimetableProvider timetable) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _select(_selectedDate.subtract(const Duration(days: 7))),
          ),
          Expanded(
            child: Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _select(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSameDate(d, _selectedDate) ? p.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Column(
                          children: [
                            Text(DateFormat('E').format(d).substring(0, 1),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSameDate(d, _selectedDate) ? p.onInk.withValues(alpha: 0.7) : p.textMuted)),
                            const SizedBox(height: 4),
                            Text('${d.day}',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: isSameDate(d, _selectedDate)
                                        ? p.onInk
                                        : (isSameDate(d, DateTime.now()) ? p.accent : p.textPrimary))),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: timetable.getClassesForDate(d).isEmpty
                                    ? Colors.transparent
                                    : (isSameDate(d, _selectedDate) ? p.onInk : p.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _select(_selectedDate.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }
}
