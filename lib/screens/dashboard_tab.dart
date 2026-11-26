import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academic_task.dart';
import '../models/class_session.dart';
import '../providers/focus_provider.dart';
import '../providers/record_provider.dart';
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
import '../widgets/activity_card.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/class_details_sheet.dart';
import '../widgets/end_semester_dialog.dart';
import '../widgets/ui.dart';
import '../widgets/weekly_chart.dart';
import 'academic_tab.dart' show taskColor;
import 'end_semester_celebration_screen.dart';
import 'notes_tab.dart' show showNoteEditor;
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

  // Home sections the user can show/hide and reorder.
  static const _sectionLabels = {
    'next': 'Next class',
    'cards': 'Next deadline & bus',
    'focus': 'Weekly focus',
    'activity': 'Activity',
    'deadlines': 'Upcoming deadlines',
    'today': "Today's schedule",
  };
  List<String> _order = const ['next', 'cards', 'focus', 'activity', 'deadlines', 'today'];
  Set<String> _enabled = const {'next', 'cards', 'focus', 'activity', 'today'};

  Future<void> _loadSections() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('home_sections_order');
    final enabled = prefs.getStringList('home_sections_enabled');
    if (!mounted) return;
    setState(() {
      if (order != null) {
        // Keep saved order, append any sections added in newer versions.
        _order = [...order.where(_sectionLabels.containsKey), ..._sectionLabels.keys.where((k) => !order.contains(k))];
      }
      if (enabled != null) {
        // Sections new since the order was saved start switched on.
        _enabled = {...enabled, if (order != null) ..._sectionLabels.keys.where((k) => !order.contains(k))};
      }
    });
  }

  Future<void> _saveSections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_sections_order', _order);
    await prefs.setStringList('home_sections_enabled', _enabled.toList());
  }

  void _customize() {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final p = Palette.of(ctx);
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
            _saveSections();
          }

          return SheetScaffold(
            title: 'Customise home',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Turn sections on or off, and drag ☰ to reorder.', style: TextStyle(color: p.textSecondary)),
                const SizedBox(height: 10),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    onReorder: (from, to) => update(() {
                      final list = [..._order];
                      final item = list.removeAt(from);
                      list.insert(to > from ? to - 1 : to, item);
                      _order = list;
                    }),
                    children: [
                      for (var i = 0; i < _order.length; i++)
                        Padding(
                          key: ValueKey(_order[i]),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(22),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Icon(Icons.drag_handle_rounded, color: p.textSecondary),
                                  ),
                                ),
                                Expanded(
                                  child: Text(_sectionLabels[_order[i]]!,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                                ),
                                Switch(
                                  value: _enabled.contains(_order[i]),
                                  onChanged: (v) => update(() {
                                    final set = {..._enabled};
                                    v ? set.add(_order[i]) : set.remove(_order[i]);
                                    _enabled = set;
                                  }),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _upcomingDeadlines(Palette p, List<AcademicTask> pending) {
    final items = pending.take(4).toList();
    return [
      const SectionLabel('Upcoming deadlines', padding: EdgeInsets.fromLTRB(4, 0, 0, 8)),
      if (items.isEmpty)
        SoftCard(child: Text('Nothing due — nice.', style: TextStyle(color: p.textSecondary)))
      else
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              onTap: () => showTaskSheet(context, task: t),
              child: Row(
                children: [
                  Container(width: 4, height: 32, decoration: BoxDecoration(color: taskColor(t), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                        Text('${t.type}${t.subject != 'General' ? ' · ${t.subject}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      ],
                    ),
                  ),
                  Text(DateFormat('EEE d MMM').format(t.dueDate), style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ),
          ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _checkNoClassStatus();
    _refreshBus();
    _loadSections();
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
    final holiday = context.select<RecordProvider, bool>((r) => r.holidayMode);
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

    final phone = Scaffold(
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
                            Text(holiday ? 'Enjoy your break,' : 'Welcome back,', style: TextStyle(color: p.textSecondary, fontSize: 14)),
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

                  if (!holiday && timetable.semesterEnd != null && now.isAfter(timetable.semesterEnd!)) ...[
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

                  for (final id in _order)
                    if (_enabled.contains(id)) ...switch (id) {
                      'next' => [
                          holiday ? _holidayCard(p) : _buildHero(p, timetable, next, now, todayClasses),
                          const SizedBox(height: 14),
                        ],
                      'cards' => [
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
                        ],
                      'focus' => [_buildProductivity(p, focus, timetable), const SizedBox(height: 24)],
                      'activity' => [const ActivityCard(), const SizedBox(height: 20)],
                      'deadlines' => [..._upcomingDeadlines(p, pending), const SizedBox(height: 14)],
                      'today' => [..._todaySection(p, timetable, todayClasses, now, nowMin), const SizedBox(height: 14)],
                      _ => const <Widget>[],
                    },
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _customize,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Customise home'),
                    ),
                  ),
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

    // Android/iOS: always the phone layout above, untouched.
    if (!isDesktopPlatform) return phone;
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 860
          ? phone
          : _buildDesktop(
              p,
              timetable: timetable,
              resources: resources,
              holiday: holiday,
              focus: focus,
              now: now,
              todayClasses: todayClasses,
              next: next,
              pending: pending,
              nextDeadline: nextDeadline,
              remainingToday: remainingToday,
            ),
    );
  }

  List<Widget> _todaySection(Palette p, TimetableProvider timetable, List<ClassSession> todayClasses, DateTime now, int nowMin) => [
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
      ];

  // ───────────────────────── Desktop (Windows/macOS/Linux) ─────────────────────────

  static String _timeGreeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Up late';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Wide-window home: a calm serif greeting, a quick-add box and shortcuts
  /// (after the reference in images/image.png), then the same cards as the
  /// phone arranged in two columns. Respects "Customise home".
  Widget _buildDesktop(
    Palette p, {
    required TimetableProvider timetable,
    required ResourceProvider resources,
    required bool holiday,
    required FocusProvider focus,
    required DateTime now,
    required List<ClassSession> todayClasses,
    required UpcomingClass? next,
    required List<AcademicTask> pending,
    required AcademicTask? nextDeadline,
    required int remainingToday,
  }) {
    final nowMin = now.hour * 60 + now.minute;
    const leftIds = {'next', 'cards', 'today', 'deadlines'};
    const gap = SizedBox(height: 18);

    List<Widget> section(String id) => switch (id) {
          'next' => [holiday ? _holidayCard(p) : _buildHero(p, timetable, next, now, todayClasses), gap],
          'cards' => [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _deadlineCard(p, nextDeadline)),
                    const SizedBox(width: 14),
                    Expanded(child: _busCard(p)),
                  ],
                ),
              ),
              gap,
            ],
          'focus' => [_buildProductivity(p, focus, timetable), const SizedBox(height: 26)],
          'activity' => [const ActivityCard(), gap],
          'deadlines' => [..._upcomingDeadlines(p, pending), gap],
          'today' => [..._todaySection(p, timetable, todayClasses, now, nowMin), gap],
          _ => const <Widget>[],
        };

    final shown = _order.where(_enabled.contains);
    final left = [for (final id in shown.where(leftIds.contains)) ...section(id)];
    final right = [for (final id in shown.where((id) => !leftIds.contains(id))) ...section(id)];

    final week = timetable.getWeekNumber(now);
    final dueSoon = pending.where((t) => !dateOnly(t.dueDate).isAfter(dateOnly(now).add(const Duration(days: 7)))).length;
    final facts = [
      if (week >= 1) timetable.getWeekLabel(now),
      if (holiday)
        'Holiday mode'
      else if (_isNoClassToday)
        'Day off'
      else if (todayClasses.isEmpty)
        'No classes today'
      else if (remainingToday == 0)
        'Classes done for today'
      else
        '$remainingToday ${remainingToday == 1 ? 'class' : 'classes'} left today',
      if (dueSoon > 0) '$dueSoon due this week',
    ];

    String? nextLine;
    if (!holiday && next != null) {
      final s = next.session;
      final when = next.inProgress
          ? 'now, until ${s.endTime}'
          : isSameDate(next.date, now)
              ? 'in ${formatCountdown(next.minutesUntilStart(now))}'
              : '${next.date.difference(dateOnly(now)).inDays == 1 ? 'tomorrow' : DateFormat('EEEE').format(next.date)} at ${s.startTime}';
      nextLine = '${s.subject} · $when';
    }

    final banners = <Widget>[
      if (!holiday && timetable.semesterEnd != null && now.isAfter(timetable.semesterEnd!)) ...[
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
    ];

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Greeting ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(9)),
                            child: Icon(Icons.school_rounded, size: 19, color: p.onInk),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              '${holiday ? 'Enjoy your break' : _timeGreeting(now)}, $_firstName.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: desktopSerif.copyWith(
                                  fontSize: 40, height: 1.15, fontWeight: FontWeight.w400, letterSpacing: -0.8, color: p.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(facts.join('  ·  '),
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.textSecondary)),
                      const SizedBox(height: 30),

                      // ── Quick add ──
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: _DesktopQuickAdd(subjects: todayClasses.map((s) => s.subject).toSet().toList()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _quickLink(p, Icons.view_day_outlined, 'Schedule', () => HomeNavigation.of(context, AppPage.schedule)),
                          _quickLink(p, Icons.calendar_today_outlined, 'Hub', () => HomeNavigation.of(context, AppPage.hub)),
                          _quickLink(p, Icons.view_kanban_outlined, 'Board', () => HomeNavigation.of(context, AppPage.board)),
                          _quickLink(p, Icons.timer_outlined, 'Focus', () => HomeNavigation.of(context, AppPage.focus)),
                          _quickLink(p, Icons.edit_note_rounded, 'New note', () => showNoteEditor(context)),
                        ],
                      ),
                      if (nextLine != null) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            onPressed: () => showClassDetailsSheet(context, next!.session, date: next.date),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.explore_outlined, size: 16, color: p.textMuted),
                                const SizedBox(width: 8),
                                Text('Next up', style: TextStyle(fontSize: 13.5, color: p.textMuted, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(nextLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13.5, color: p.textPrimary, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 44),

                      ...banners,

                      // ── Cards ──
                      if (left.isEmpty || right.isEmpty)
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...left, ...right])
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                            const SizedBox(width: 28),
                            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton.icon(
                          onPressed: _customize,
                          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                          icon: const Icon(Icons.tune_rounded, size: 17),
                          label: const Text('Customise home'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    );
  }

  Widget _quickLink(Palette p, IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: p.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
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

  Widget _buildHero(Palette p, TimetableProvider timetable, UpcomingClass? next, DateTime now, List<ClassSession> todayClasses) {
    // Cosy card once today's classes are over (or nothing is coming up).
    if (next == null) return _cosyCard(p, null, now);
    if (!isSameDate(next.date, now) && (todayClasses.isNotEmpty || now.hour >= 16)) return _cosyCard(p, next, now);

    final s = next.session;
    // Open work for this module (replaces the old attendance %).
    final openForModule = timetable.pendingTasks.where((t) => t.subject.toLowerCase() == s.subject.toLowerCase()).length;

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
              if (openForModule > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$openForModule', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: p.textPrimary)),
                    Text(openForModule == 1 ? 'task due' : 'tasks due', style: TextStyle(fontSize: 11, color: p.textSecondary)),
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
              // Shrinks on narrow phones instead of pushing the + off-screen.
              if (s.meetingLink != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: JoinMeetingButton(url: s.meetingLink!),
                  ),
                ),
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

  /// Holiday mode (semester ended): no classes, but the rest of the app is
  /// here for planning the break.
  Widget _holidayCard(Palette p) {
    final records = context.read<RecordProvider>();
    final since = records.holidaySince;
    final day = since == null ? null : dateOnly(DateTime.now()).difference(since).inDays + 1;
    final bg = p.isDark ? const Color(0xFF14302B) : const Color(0xFFDDF6EE);
    final ink = p.isDark ? const Color(0xFFBDF0E0) : const Color(0xFF0B4F3F);
    return SoftCard(
      radius: 36,
      color: bg,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: ink, width: 1.2), borderRadius: BorderRadius.circular(40)),
                  child: Text(day == null ? 'Holiday mode' : 'Holiday · day $day',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
              const Spacer(),
              const Text('🏖', style: TextStyle(fontSize: 30)),
            ],
          ),
          const SizedBox(height: 14),
          Text("Semester's over", style: TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: ink)),
          const SizedBox(height: 6),
          Text('Plan trips, side projects or revision — the calendar, board and notes are all yours.',
              style: TextStyle(color: ink.withValues(alpha: 0.75), fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _cosyChip(Icons.calendar_month_outlined, 'Plan something', ink, () => HomeNavigation.of(context, AppPage.hub)),
              _cosyChip(Icons.workspace_premium_outlined, 'Grades', ink, () => HomeNavigation.of(context, AppPage.grades)),
              _cosyChip(Icons.sticky_note_2_outlined, 'Notes', ink, () => HomeNavigation.of(context, AppPage.notes)),
              _cosyChip(Icons.school_outlined, 'Start next semester', ink, () => startNextSemester(context)),
            ],
          ),
        ],
      ),
    );
  }

  /// Warm, calm card once classes are over for the day.
  Widget _cosyCard(Palette p, UpcomingClass? next, DateTime now) {
    final evening = now.hour >= 18 || now.hour < 5;
    final bg = p.isDark ? const Color(0xFF2A221B) : const Color(0xFFFFF1E2);
    final ink = p.isDark ? const Color(0xFFF3DCC4) : const Color(0xFF5B3A1E);
    final soft = ink.withValues(alpha: 0.7);
    String? nextLine;
    if (next != null) {
      final days = next.date.difference(dateOnly(now)).inDays;
      final when = days == 1 ? 'Tomorrow' : DateFormat('EEEE').format(next.date);
      nextLine = 'Next: $when ${next.session.startTime} · ${next.session.subject}';
    }
    return SoftCard(
      radius: 36,
      color: bg,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(border: Border.all(color: ink, width: 1.2), borderRadius: BorderRadius.circular(40)),
                child: Text('Classes done for today', style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const Spacer(),
              Text(evening ? '🌙' : '☕', style: const TextStyle(fontSize: 30)),
            ],
          ),
          const SizedBox(height: 14),
          Text(evening ? 'Time to unwind' : 'Nice work today',
              style: TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: ink)),
          const SizedBox(height: 6),
          Text(nextLine ?? 'No classes coming up this week.', style: TextStyle(color: soft, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _cosyChip(Icons.timer_outlined, 'Focus a bit', ink, () => HomeNavigation.of(context, AppPage.focus)),
              _cosyChip(Icons.sticky_note_2_outlined, 'Jot a note', ink, () => HomeNavigation.of(context, AppPage.notes)),
              _cosyChip(Icons.view_kanban_outlined, 'Plan tomorrow', ink, () => HomeNavigation.of(context, AppPage.board)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cosyChip(IconData icon, String label, Color ink, VoidCallback onTap) {
    return Material(
      color: ink.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly focus', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    Text(total == 0 ? 'No sessions yet this week' : '${total ~/ 60}h ${total % 60}m this week',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              if (wow != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text('${wow >= 0 ? '+' : ''}$wow%',
                      style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Material(
                color: p.ink,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => HomeNavigation.of(context, AppPage.focus),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 18, color: p.onInk),
                        const SizedBox(width: 4),
                        Text('Focus', style: TextStyle(color: p.onInk, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
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

/// Desktop home's capture box: type a title, pick a type, press Enter and
/// the usual task sheet opens pre-filled to set the date.
class _DesktopQuickAdd extends StatefulWidget {
  final List<String> subjects;
  const _DesktopQuickAdd({required this.subjects});

  @override
  State<_DesktopQuickAdd> createState() => _DesktopQuickAddState();
}

class _DesktopQuickAddState extends State<_DesktopQuickAdd> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String _type = 'Assignment';

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _text.text.trim();
    await showTaskSheet(context, initialTitle: title.isEmpty ? null : title, initialType: _type);
    if (mounted) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hasText = _text.text.trim().isNotEmpty;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: focused ? p.textMuted.withValues(alpha: 0.7) : p.border, spreadRadius: 1),
          BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.05), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 15.5, color: p.textPrimary),
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              hintText: 'Add a deadline or task…',
              hintStyle: TextStyle(color: p.textMuted, fontSize: 15.5),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Type',
                initialValue: _type,
                onSelected: (v) => setState(() => _type = v),
                itemBuilder: (_) => [for (final t in taskTypes) PopupMenuItem(value: t, height: 38, child: Text(t))],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(border: Border.all(color: p.border), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.forType(_type), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(_type, style: TextStyle(fontSize: 13, color: p.textSecondary, fontWeight: FontWeight.w500)),
                      Icon(Icons.expand_more_rounded, size: 18, color: p.textMuted),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: hasText ? 1 : 0,
                child: Text('Enter ↵', style: TextStyle(fontSize: 12, color: p.textMuted)),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Add',
                child: Material(
                  color: hasText ? p.ink : p.surfaceAlt,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _submit,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(Icons.arrow_upward_rounded, size: 18, color: hasText ? p.onInk : p.textMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
