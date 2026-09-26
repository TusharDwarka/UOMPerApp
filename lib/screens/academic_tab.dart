import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/academic_task.dart';
import '../models/class_session.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/ui.dart';
import 'print_center_screen.dart';

Color taskColor(AcademicTask t) => t.colorValue != null ? Color(t.colorValue!) : AppColors.forType(t.type);

class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final timetable = context.watch<TimetableProvider>();

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Hub',
              eyebrow: DateFormat('MMMM yyyy').format(_focusedDay),
              actions: [
                CircleIconButton(
                  icon: Icons.print_rounded,
                  tooltip: 'Print & export',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrintCenterScreen())),
                ),
                CircleIconButton(
                  icon: _calendarFormat == CalendarFormat.month ? Icons.view_week_rounded : Icons.calendar_view_month_rounded,
                  tooltip: _calendarFormat == CalendarFormat.month ? 'Week view' : 'Month view',
                  onPressed: () => setState(() => _calendarFormat =
                      _calendarFormat == CalendarFormat.month ? CalendarFormat.twoWeeks : CalendarFormat.month),
                ),
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'Add',
                  onPressed: () => showTaskSheet(context, initialDate: _selectedDay, initialType: 'Other'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildCalendarTab(p, timetable)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Calendar ─────────────────────────

  Widget _buildCalendarTab(Palette p, TimetableProvider timetable) {
    final allTasks = timetable.tasks;
    final dayTasks = timetable.getTasksForDay(_selectedDay)
      ..sort((a, b) => (a.startDate ?? a.dueDate).compareTo(b.startDate ?? b.dueDate));
    final dayClasses = timetable.getClassesForDate(_selectedDay);

    final today = dateOnly(DateTime.now());
    final upcoming = allTasks
        .where((t) => !t.isCompleted && !dateOnly(t.dueDate).isBefore(today) && dateOnly(t.dueDate).difference(today).inDays <= 14)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Stable row order so a multi-day bar stays on the same line each day.
    int barOrder(AcademicTask a, AcademicTask b) {
      final s = (a.startDate ?? a.dueDate).compareTo(b.startDate ?? b.dueDate);
      return s != 0 ? s : a.id.compareTo(b.id);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: TableCalendar<AcademicTask>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 66,
              daysOfWeekHeight: 26,
              selectedDayPredicate: (day) => isSameDate(_selectedDay, day),
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = dateOnly(selected);
                _focusedDay = focused;
              }),
              onFormatChanged: (f) => setState(() => _calendarFormat = f),
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
              eventLoader: (day) => allTasks.where((t) => t.occursOn(day)).toList()..sort(barOrder),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.textPrimary),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: p.textPrimary),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: p.textPrimary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                weekendStyle: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 12),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellAlignment: Alignment.topCenter,
                cellPadding: const EdgeInsets.only(top: 6),
                defaultTextStyle: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w500),
                weekendTextStyle: TextStyle(color: p.textSecondary),
              ),
              calendarBuilders: CalendarBuilders<AcademicTask>(
                selectedBuilder: (context, day, _) => _dayCircle(day, bg: p.ink, fg: p.onInk),
                todayBuilder: (context, day, _) => _dayCircle(day, border: p.accent, fg: p.accent),
                markerBuilder: (context, day, events) => events.isEmpty ? null : _markers(day, events),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── Selected day agenda ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            isSameDate(_selectedDay, DateTime.now()) ? 'Today' : DateFormat('EEEE d MMMM').format(_selectedDay),
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
            trailing: TextButton.icon(
              onPressed: () => showTaskSheet(context, initialDate: _selectedDay, initialType: 'Other'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ),
        ),
        if (dayClasses.isEmpty && dayTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text('Nothing scheduled.', style: TextStyle(color: p.textSecondary)),
          ),
        for (final c in dayClasses) _classRow(p, c),
        for (final t in dayTasks) _eventRow(p, t, timetable),

        // ── Coming up ──
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Coming up · 14 days', padding: EdgeInsets.fromLTRB(4, 0, 0, 10)),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _upcomingCard(upcoming[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dayCircle(DateTime day, {Color? bg, Color? border, required Color fg}) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border, width: 2),
        ),
        child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Coloured bars under the date. Multi-day events are drawn edge-to-edge
  /// so they read as one continuous bar across the week.
  Widget _markers(DateTime day, List<AcademicTask> events) {
    final shown = events.take(3).toList();
    final extra = events.length - shown.length;
    return Positioned(
      left: 0,
      right: 0,
      // Directly under the date number, so bars clearly belong to that day.
      top: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in shown)
            Builder(builder: (context) {
              final c = taskColor(e);
              if (!e.isSpanning) {
                return Container(
                  width: 24,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                );
              }
              final isStart = isSameDate(day, e.startDate!);
              final isEnd = isSameDate(day, e.dueDate);
              final weekStart = day.weekday == DateTime.monday;
              final weekEnd = day.weekday == DateTime.sunday;
              return Container(
                height: 6,
                margin: EdgeInsets.only(top: 2, left: isStart ? 6 : 0, right: isEnd ? 6 : 0),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(isStart || weekStart ? 4 : 0),
                    right: Radius.circular(isEnd || weekEnd ? 4 : 0),
                  ),
                ),
              );
            }),
          if (extra > 0)
            Text('+$extra', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Palette.of(context).textSecondary)),
        ],
      ),
    );
  }

  Widget _classRow(Palette p, ClassSession c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.startTime, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                  Text(c.endTime, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ),
            Container(width: 3, height: 34, margin: const EdgeInsets.only(right: 12), color: p.accent),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  Text('Class · ${c.room}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ),
            if (c.meetingLink != null) JoinMeetingButton(url: c.meetingLink!, dense: true),
          ],
        ),
      ),
    );
  }

  Widget _eventRow(Palette p, AcademicTask t, TimetableProvider timetable) {
    final c = taskColor(t);
    String when;
    if (t.isSpanning) {
      final total = dateOnly(t.dueDate).difference(dateOnly(t.startDate!)).inDays + 1;
      final n = dateOnly(_selectedDay).difference(dateOnly(t.startDate!)).inDays + 1;
      when = 'Day $n of $total · ends ${DateFormat('EEE d MMM').format(t.dueDate)}';
    } else {
      when = DateFormat('HH:mm').format(t.dueDate);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SoftCard(
        radius: 24,
        padding: EdgeInsets.zero,
        onTap: () => showTaskSheet(context, task: t),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 8,
                decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.horizontal(left: Radius.circular(24))),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TagPill(t.type, color: c),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(when, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: p.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: p.textPrimary,
                            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                          )),
                      if (t.subject != 'General')
                        Text(t.subject, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      if (t.meetingLink != null) ...[
                        const SizedBox(height: 8),
                        JoinMeetingButton(url: t.meetingLink!, dense: true),
                      ],
                    ],
                  ),
                ),
              ),
              Checkbox(
                value: t.isCompleted,
                shape: const CircleBorder(),
                activeColor: c,
                onChanged: (_) => timetable.toggleTaskDone(t),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingCard(AcademicTask t) {
    final c = taskColor(t);
    final days = dateOnly(t.dueDate).difference(dateOnly(DateTime.now())).inDays;
    final light = c.computeLuminance() > 0.5;
    final fg = light ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: () => showTaskSheet(context, task: t),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: fg), borderRadius: BorderRadius.circular(40)),
              child: Text(t.type, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600, height: 1.15)),
            const SizedBox(height: 6),
            Text(days == 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days'),
                style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
