import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/academic_task.dart';
import '../models/class_session.dart';
import '../providers/focus_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/bus_repository.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../utils/bus_utils.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/class_details_sheet.dart';
import '../widgets/end_semester_dialog.dart';
import '../widgets/ui.dart';
import '../widgets/weekly_chart.dart';
import 'academic_tab.dart' show taskColor;
import 'home_screen.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onSeeAllClicked;
  const DashboardTab({super.key, this.onSeeAllClicked});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  bool _isNoClassToday = false;
  Timer? _ticker;
  ({String route, String departure, int minutes, String? bus})? _nextBus;

  @override
  void initState() {
    super.initState();
    _checkNoClassStatus();
    _refreshBus();
    // Countdowns ("starts in 5 min") used to freeze until something else
    // triggered a rebuild.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshBus();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _checkNoClassStatus() async {
    final status = await NotificationService().isNoClassToday();
    if (mounted) setState(() => _isNoClassToday = status);
  }

  Future<void> _refreshBus() async {
    final routes = await BusRepository.load();
    if (routes.isEmpty) {
      if (mounted) setState(() => _nextBus = null);
      return;
    }
    final idx = (await BusRepository.selectedIndex()).clamp(0, routes.length - 1);
    final r = routes[idx];
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final trips = sortTrips((r['schedules']?[busDayKeys[busDayIndexFor(now)]] as List?) ?? const []);
    final i = nextTripIndex(trips, nowMin);
    if (!mounted) return;
    setState(() {
      _nextBus = i == -1
          ? null
          : (
              route: (r['bus_route'] ?? '').toString(),
              departure: trips[i]['departure'].toString(),
              minutes: (parseMinutes(trips[i]['departure']) ?? nowMin) - nowMin,
              bus: (trips[i]['bus_name'] as String?)
            );
    });
  }

  String get _firstName {
    User? u;
    try {
      u = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return 'there'; // Firebase not initialised (tests / offline start-up)
    }
    final n = u?.displayName?.trim();
    if (n != null && n.isNotEmpty) return n.split(' ').first;
    final e = u?.email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'there';
  }

  Future<void> _declareDayOff(TimetableProvider timetable, List<ClassSession> todayClasses) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No classes today? 🌴'),
        content: const Text('This cancels today\'s class alarms so you can relax without notifications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, I'm free")),
        ],
      ),
    );
    if (ok != true) return;
    await NotificationService().setNoClassToday();
    await NotificationService().cancelTodayReminders(todayClasses);
    if (!mounted) return;
    setState(() => _isNoClassToday = true);
    _confettiController.play();
    WidgetService.updateWidget(timetable);
  }

  Future<void> _undoDayOff(TimetableProvider timetable) async {
    await NotificationService().clearNoClassToday();
    if (!mounted) return;
    setState(() => _isNoClassToday = false);
    await timetable.rescheduleReminders();
    await WidgetService.updateWidget(timetable);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final timetable = context.watch<TimetableProvider>();
    final resources = context.watch<ResourceProvider>();
    // Read (not watch): the focus timer notifies every second; the 30 s
    // ticker is enough to keep the weekly chart fresh.
    final focus = context.read<FocusProvider>();
    final sync = context.read<SyncService>();

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final todayClasses = timetable.getClassesForDate(now);
    final next = _isNoClassToday ? timetable.findNextClass(now, skipToday: true) : timetable.findNextClass(now);
    final pending = List<AcademicTask>.from(timetable.pendingTasks)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextDeadline = pending.isEmpty ? null : pending.first;
    final remainingToday = todayClasses.where((s) => s.endMinutes > nowMin).length;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await sync.syncAll();
                await timetable.loadSessions();
                await _refreshBus();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // ── Greeting ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back,', style: TextStyle(color: p.textSecondary, fontSize: 14)),
                            Text(_firstName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: sync.isSyncing,
                        builder: (_, syncing, __) => syncing
                            ? Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
                              )
                            : const SizedBox.shrink(),
                      ),
                      CircleIconButton(
                        icon: Icons.person_rounded,
                        tooltip: 'Settings',
                        onPressed: () => HomeNavigation.of(context, AppPage.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Big date + today's modules ──
                  _buildDateHeader(p, timetable, now, todayClasses, remainingToday),
                  const SizedBox(height: 20),

                  if (timetable.semesterEnd != null && now.isAfter(timetable.semesterEnd!)) ...[
                    _banner(
                      p,
                      icon: Icons.celebration_rounded,
                      color: Colors.redAccent,
                      title: 'Semester ended',
                      subtitle: 'Finalise and start fresh for next semester.',
                      onTap: () => showDialog(context: context, builder: (_) => const EndSemesterDialog()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (resources.unsortedCount > 0) ...[
                    _banner(
                      p,
                      icon: Icons.move_to_inbox_rounded,
                      color: Colors.deepOrange,
                      title: 'Unsorted inbox',
                      subtitle: '${resources.unsortedCount} file(s) waiting to be filed',
                      onTap: () => HomeNavigation.of(context, AppPage.files),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Hero: next / current class ──
                  _buildHero(p, timetable, next, now),
                  const SizedBox(height: 14),

                  // ── Deadline + bus ──
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _deadlineCard(p, nextDeadline)),
                        const SizedBox(width: 12),
                        Expanded(child: _busCard(p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Weekly productivity ──
                  _buildProductivity(p, focus, timetable),
                  const SizedBox(height: 24),

                  // ── Today timeline ──
                  SectionLabel(
                    "Today's schedule",
                    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                    trailing: todayClasses.isEmpty
                        ? null
                        : (_isNoClassToday
                            ? TextButton(onPressed: () => _undoDayOff(timetable), child: const Text('Undo day off'))
                            : TextButton.icon(
                                onPressed: () => _declareDayOff(timetable, todayClasses),
                                icon: const Icon(Icons.beach_access_rounded, size: 18),
                                label: const Text('Day off'),
                              )),
                  ),
                  if (_isNoClassToday)
                    SoftCard(
                      child: Row(
                        children: [
                          const Text('🌴', style: TextStyle(fontSize: 34)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text('Day off declared — alarms are muted for today.',
                                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )
                  else if (todayClasses.isEmpty)
                    SoftCard(
                      child: Row(
                        children: [
                          Icon(now.weekday >= 6 ? Icons.weekend_rounded : Icons.free_breakfast_rounded, color: p.textSecondary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(now.weekday >= 6 ? "It's the weekend!" : 'No classes today.',
                                style: TextStyle(color: p.textSecondary)),
                          ),
                          TextButton(onPressed: widget.onSeeAllClicked, child: const Text('Week')),
                        ],
                      ),
                    )
                  else
                    for (final s in todayClasses) _timelineRow(p, s, nowMin),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [AppColors.accent, Colors.lightBlueAccent, Colors.pink, Colors.orange, Colors.purple],
                createParticlePath: _drawStar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(Palette p, TimetableProvider timetable, DateTime now, List<ClassSession> today, int remaining) {
    final week = timetable.getWeekNumber(now);
    final names = today.map((s) => s.subject).toSet().toList();
    ClassSession? current;
    for (final s in today) {
      final nm = now.hour * 60 + now.minute;
      if (nm >= s.startMinutes && nm < s.endMinutes) current = s;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(40)),
              child: Text(DateFormat('MMM, EEE').format(now),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            Text('${now.day}',
                style: TextStyle(fontSize: 92, height: 1.05, fontWeight: FontWeight.w400, letterSpacing: -5, color: p.textPrimary)),
            Text(week >= 1 ? timetable.getWeekLabel(now) : 'Pre-semester',
                style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: remaining == 0 ? 'All done\n' : 'Classes\n'),
                  const TextSpan(text: 'today '),
                  TextSpan(text: '(${today.length})', style: const TextStyle(fontSize: 14, letterSpacing: 0)),
                ]),
                style: TextStyle(fontSize: 32, height: 1.05, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: p.textPrimary),
              ),
              const SizedBox(height: 12),
              for (final n in names.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current?.subject == n ? p.ink : Colors.transparent,
                          border: Border.all(color: current?.subject == n ? p.ink : p.textMuted, width: 1.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(n,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: current?.subject == n ? p.textPrimary : p.textSecondary,
                              fontWeight: current?.subject == n ? FontWeight.w700 : FontWeight.w400,
                            )),
                      ),
                    ],
                  ),
                ),
              if (names.length > 4) Text('+${names.length - 4} more', style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(Palette p, TimetableProvider timetable, UpcomingClass? next, DateTime now) {
    if (next == null) {
      return SoftCard(
        radius: 36,
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TagPill('Free', outlined: true),
                  const SizedBox(height: 14),
                  Text('No upcoming classes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, color: p.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Nothing in the next 7 days.', style: TextStyle(color: p.textSecondary)),
                ],
              ),
            ),
            CircleIconButton(icon: Icons.add_rounded, filled: true, size: 56, onPressed: () => showTaskSheet(context)),
          ],
        ),
      );
    }

    final s = next.session;
    final stats = timetable.getAttendanceStats(s.subject);
    final rate = ((stats['rate'] as double) * 100).round();
    final presents = stats['presents'] as int;
    final total = presents + (stats['absences'] as int);

    String status;
    if (next.inProgress) {
      status = 'In progress · ${formatCountdown(next.minutesUntilEnd(now))} left';
    } else if (isSameDate(next.date, now)) {
      status = 'Next · in ${formatCountdown(next.minutesUntilStart(now))}';
    } else {
      final days = next.date.difference(dateOnly(now)).inDays;
      status = '${days == 1 ? 'Tomorrow' : DateFormat('EEEE').format(next.date)} · ${s.startTime}';
    }
    final progress = next.inProgress
        ? (now.difference(next.start).inMinutes / math.max(1, next.end.difference(next.start).inMinutes)).clamp(0.0, 1.0)
        : null;

    return SoftCard(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      onTap: () => showClassDetailsSheet(context, s, date: next.date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: TagPill(status, color: next.inProgress ? p.accent : p.textPrimary, outlined: true)),
              const Spacer(),
              if (total > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$rate%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: p.textPrimary)),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$presents', style: TextStyle(fontWeight: FontWeight.w800, color: p.textPrimary)),
                      TextSpan(text: ' / $total attended'),
                    ]), style: TextStyle(fontSize: 11, color: p.textSecondary)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(s.subject,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: p.textPrimary)),
          const SizedBox(height: 6),
          Text('${s.startTime} – ${s.endTime} · ${s.room}', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w500)),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: p.surfaceAlt, color: p.accent),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (s.meetingLink != null) JoinMeetingButton(url: s.meetingLink!),
              const Spacer(),
              Tooltip(
                message: 'Add homework',
                child: CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  size: 56,
                  onPressed: () => showTaskSheet(context, initialType: 'Homework', initialModule: s.subject),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deadlineCard(Palette p, AcademicTask? t) {
    if (t == null) {
      return SoftCard(
        radius: 28,
        onTap: () => showTaskSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.task_alt_rounded, color: p.textSecondary),
            const SizedBox(height: 18),
            Text('No deadlines', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            Text('Tap to add', style: TextStyle(fontSize: 12, color: p.textSecondary)),
          ],
        ),
      );
    }
    final c = taskColor(t);
    final days = dateOnly(t.dueDate).difference(dateOnly(DateTime.now())).inDays;
    final when = days < 0 ? 'Overdue' : days == 0 ? 'Due today' : days == 1 ? 'Tomorrow' : 'In $days days';
    return SoftCard(
      radius: 28,
      color: c,
      onTap: () => HomeNavigation.of(context, AppPage.board),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(40)),
            child: Text(when, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, height: 1.15)),
          const SizedBox(height: 4),
          Text(t.type, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _busCard(Palette p) {
    final b = _nextBus;
    return SoftCard(
      radius: 28,
      onTap: () => HomeNavigation.of(context, AppPage.bus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: p.accent, size: 20),
              const SizedBox(width: 6),
              if (b != null && b.route.isNotEmpty) Text(b.route, style: TextStyle(fontWeight: FontWeight.w800, color: p.accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (b == null) ...[
            Text('No more buses', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            Text('today on your route', style: TextStyle(fontSize: 12, color: p.textSecondary)),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatCountdown(b.minutes),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -1, color: p.textPrimary)),
            ),
            Text('Leaves ${b.departure}${(b.bus ?? '').isNotEmpty ? ' · ${b.bus}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildProductivity(Palette p, FocusProvider focus, TimetableProvider timetable) {
    final wow = focus.weekOverWeekPercent;
    final total = focus.thisWeekTotal;
    return GestureDetector(
      onTap: () => HomeNavigation.of(context, AppPage.focus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeeklyBarsChart(values: focus.weekMinutes(), todayIndex: DateTime.now().weekday - 1, height: 180),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.north_east_rounded, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Weekly focus', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
              ),
              const SizedBox(width: 8),
              if (wow != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(8)),
                  child: Text('${wow >= 0 ? '+' : ''}$wow%', style: TextStyle(color: p.onInk, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(total == 0 ? 'Start a session →' : '${total ~/ 60}h ${total % 60}m',
                    textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(Palette p, ClassSession s, int nowMin) {
    final isNow = nowMin >= s.startMinutes && nowMin < s.endMinutes;
    final isDone = nowMin >= s.endMinutes;
    final colors = moduleColors(s.subject, p.isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: isDone ? 0.5 : 1,
        child: SoftCard(
          radius: 24,
          color: isNow ? colors.$1 : null,
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          onTap: () => showClassDetailsSheet(context, s),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.startTime, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                    Text(s.endTime, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              Container(width: 2, height: 36, margin: const EdgeInsets.symmetric(horizontal: 12), color: colors.$2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null)),
                    Text(s.room, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              if (isNow) TagPill('Now', color: colors.$2),
              if (s.meetingLink != null && !isDone) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: MeetingLinks.label(s.meetingLink!),
                  icon: Icon(Icons.videocam_rounded, color: MeetingLinks.color(s.meetingLink!)),
                  onPressed: () => MeetingLinks.open(context, s.meetingLink!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(Palette p,
      {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withValues(alpha: 0.35)),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    );
  }

  /// 5-point star for the confetti (the previous path drew a degenerate shape).
  static Path _drawStar(Size size) {
    final path = Path();
    final cx = size.width / 2, cy = size.height / 2;
    final outer = size.width / 2, inner = outer / 2.5;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }
}
