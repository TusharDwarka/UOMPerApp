import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

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
  static const double _weekHourHeight = 56;
  static const double _gutter = 54;

  DateTime _selectedDate = dateOnly(DateTime.now());
  int _view = 0; // 0 day, 1 week grid, 2 month calendar
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
    final events = timetable.getClassesForDate(_selectedDate, includeCancelled: true);
    final (startHour, endHour) = _hourRange(events);
    if (_view == 0) _autoScroll(startHour, events);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: PillSegmented<int>(
                values: const [0, 1, 2],
                selected: _view,
                labelOf: (v) => const ['Day', 'Week', 'Month'][v],
                onChanged: (v) => setState(() {
                  _view = v;
                  _didInitialScroll = false;
                }),
              ),
            ),
            if (_view != 2) _buildWeekStrip(p, timetable),
            const SizedBox(height: 8),
            Expanded(
              child: _view == 1
                  ? _weekGrid(p, timetable)
                  : _view == 2
                      ? _monthView(p, timetable)
                      : preSemester
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
                        // Explicit width: a Stack with only Positioned children
                        // collapses to zero width under loose constraints.
                        return SizedBox(
                          width: c.maxWidth,
                          height: height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var h = startHour; h <= endHour; h++) ..._hourLine(p, h, startHour),
                              ..._buildBlocks(p, timetable, events, startHour, gridWidth, date: _selectedDate),
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
                              if (isSameDate(_selectedDate, DateTime.now())) _nowLine(p, startHour, endHour, left: _gutter, right: 0),
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

  List<Widget> _hourLine(Palette p, int hour, int startHour, {double hourHeight = _hourHeight}) {
    final top = (hour - startHour) * hourHeight;
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

  Widget _nowLine(Palette p, int startHour, int endHour,
      {required double left, double? right, double? width, double hourHeight = _hourHeight}) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes < startHour * 60 || minutes > endHour * 60) return const SizedBox.shrink();
    final top = (minutes - startHour * 60) / 60 * hourHeight;
    return Positioned(
      top: top - 5,
      left: left - 5,
      right: right,
      width: width == null ? null : width + 5,
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

  /// Class blocks for one day column. [compact] is the narrow week-grid
  /// version: name only, smaller text.
  List<Widget> _buildBlocks(Palette p, TimetableProvider timetable, List<ClassSession> events, int startHour, double gridWidth,
      {required DateTime date, double left = _gutter, double hourHeight = _hourHeight, bool compact = false}) {
    final laid = layoutDayBlocks<ClassSession>(events, startOf: (s) => s.startMinutes, endOf: (s) => s.endMinutes);
    final now = DateTime.now();
    final isToday = isSameDate(date, now);
    final nowMin = now.hour * 60 + now.minute;

    return [
      for (final b in laid)
        Builder(builder: (context) {
          final s = b.item;
          final laneWidth = gridWidth / b.laneCount;
          final top = (b.start - startHour * 60) / 60 * hourHeight;
          final height = math.max((b.end - b.start) / 60 * hourHeight - 3, compact ? 20.0 : 26.0);
          final colors = moduleColors(s.subject, p.isDark);
          final cancelled = timetable.isCancelled(s, date);
          final inProgress = !cancelled && isToday && nowMin >= b.start && nowMin < b.end;
          final done = isToday && nowMin >= b.end;
          final radius = compact ? 10.0 : 18.0;
          final strike = cancelled ? TextDecoration.lineThrough : null;
          final textColor = p.isDark ? Colors.white : const Color(0xFF15171A);

          return Positioned(
            top: top + 1.5,
            left: left + (compact ? 1.5 : 4) + b.lane * laneWidth,
            width: laneWidth - (compact ? 3 : 6),
            height: height,
            child: Opacity(
              opacity: cancelled ? 0.4 : (done ? 0.55 : 1),
              child: Material(
                color: colors.$1,
                borderRadius: BorderRadius.circular(radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: () => showClassDetailsSheet(context, s, date: date),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: inProgress ? Border.all(color: colors.$2, width: 2) : null,
                    ),
                    padding: compact ? const EdgeInsets.fromLTRB(5, 4, 3, 3) : const EdgeInsets.fromLTRB(10, 6, 8, 6),
                    // Short (30-min) blocks can't fit every line; clip the
                    // extra lines instead of throwing an overflow.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: compact
                            ? Text(s.moduleCode.isNotEmpty && laneWidth < 70 ? s.moduleCode : s.subject,
                                maxLines: math.max(1, (height - 7) ~/ 13),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w700, color: textColor, decoration: strike))
                            : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(s.subject,
                                      maxLines: height > 60 ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor, decoration: strike)),
                                ),
                                if (s.meetingLink != null) Icon(Icons.videocam_rounded, size: 15, color: colors.$2),
                              ],
                            ),
                            if (height > 40)
                              Text(cancelled ? 'Cancelled' : '${s.startTime} – ${s.endTime}${b.laneCount == 1 ? '  ·  ${s.room}' : ''}',
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

  /// Mon–Fri (plus weekend days that have classes) side by side.
  Widget _weekGrid(Palette p, TimetableProvider timetable) {
    final week = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final perDay = {for (final d in week) d: timetable.getClassesForDate(d, includeCancelled: true)};
    final days = week.where((d) => d.weekday <= 5 || perDay[d]!.isNotEmpty).toList();
    final (startHour, endHour) = _hourRange([for (final d in days) ...perDay[d]!]);
    const hh = _weekHourHeight;
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 4, 10, 40),
      child: LayoutBuilder(builder: (context, c) {
        final colW = (c.maxWidth - _gutter) / days.length;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: _gutter),
                for (final d in days)
                  SizedBox(
                    width: colW,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedDate = d;
                        _view = 0;
                        _didInitialScroll = false;
                      }),
                      child: Text(DateFormat(colW < 60 ? 'E' : 'E d').format(d),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: isSameDate(d, now) ? p.accent : p.textSecondary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: c.maxWidth,
              height: (endHour - startHour) * hh,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var h = startHour; h <= endHour; h++) ..._hourLine(p, h, startHour, hourHeight: hh),
                  for (var i = 1; i < days.length; i++)
                    Positioned(left: _gutter + i * colW, top: 0, bottom: 0, child: Container(width: 1, color: p.border)),
                  for (var i = 0; i < days.length; i++)
                    ..._buildBlocks(p, timetable, perDay[days[i]]!, startHour, colW,
                        date: days[i], left: _gutter + i * colW, hourHeight: hh, compact: true),
                  for (var i = 0; i < days.length; i++)
                    if (isSameDate(days[i], now))
                      _nowLine(p, startHour, endHour, left: _gutter + i * colW, width: colW, hourHeight: hh),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Month calendar; dots show how many classes a day has. Tap a day to open it.
  Widget _monthView(Palette p, TimetableProvider timetable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
        child: TableCalendar<ClassSession>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _selectedDate,
          startingDayOfWeek: StartingDayOfWeek.monday,
          rowHeight: 52,
          availableGestures: AvailableGestures.horizontalSwipe,
          selectedDayPredicate: (d) => isSameDate(d, _selectedDate),
          onDaySelected: (sel, _) => setState(() {
            _selectedDate = dateOnly(sel);
            _view = 0;
            _didInitialScroll = false;
          }),
          onPageChanged: (foc) => setState(() => _selectedDate = dateOnly(foc)),
          eventLoader: timetable.getClassesForDate,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            defaultTextStyle: TextStyle(color: p.textPrimary),
            weekendTextStyle: TextStyle(color: p.textSecondary),
            todayDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent)),
            todayTextStyle: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
            selectedDecoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(color: p.onInk, fontWeight: FontWeight.w700),
          ),
          calendarBuilders: CalendarBuilders<ClassSession>(
            markerBuilder: (context, day, classes) => classes.isEmpty
                ? null
                : Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in classes.take(4))
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: moduleColors(s.subject, p.isDark).$2, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
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
