import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/academic_task.dart';
import '../models/class_session.dart';
import '../models/group_models.dart';
import '../providers/focus_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/scroll_time_picker.dart';
import '../widgets/ui.dart';
import 'groups_screen.dart' show MemberAvatar;

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final StudyGroup? initial;
  const GroupDetailScreen({super.key, required this.groupId, this.initial});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final GroupService _service = context.read<GroupService>();
  final List<StreamSubscription> _subs = [];
  Timer? _ticker;
  Timer? _reminderDebounce;

  StudyGroup? _group;
  List<GroupMember> _members = [];
  List<GroupSession> _sessions = [];
  List<GroupEvent> _events = [];
  List<GroupMessage> _messages = [];
  int? _reminderMinutes;
  int _tab = 0;
  final _msgController = TextEditingController();
  final _outer = ScrollController();
  bool _announce = false;
  String? _error;

  // Events tab: list or calendar, plus who has ticked each event off.
  bool _eventsCalendar = false;
  DateTime _calFocused = DateTime.now();
  DateTime _calSelected = dateOnly(DateTime.now());
  final Map<String, Map<String, String>> _done = {};
  final Map<String, StreamSubscription> _doneSubs = {};

  void _syncDoneSubscriptions() {
    final today = dateOnly(DateTime.now()).subtract(const Duration(days: 7));
    final wanted = _events.where((e) => !(e.end ?? e.start).isBefore(today)).take(40).map((e) => e.id).toSet();
    for (final id in _doneSubs.keys.toList()) {
      if (!wanted.contains(id)) _doneSubs.remove(id)?.cancel();
    }
    for (final id in wanted) {
      _doneSubs[id] ??= _service.eventDone(_gid, id).listen((m) {
        if (mounted) setState(() => _done[id] = m);
      }, onError: (_) {});
    }
  }

  String get _gid => widget.groupId;
  GroupMember? get _me => _members.where((m) => m.uid == _service.uid).firstOrNull;
  bool get _isLeader => _me?.isLeader ?? false;
  bool get _isOwner => _group?.ownerId == _service.uid;
  bool get _canPost => _isLeader || (_group?.membersCanPost ?? false);

  @override
  void initState() {
    super.initState();
    _group = widget.initial;
    void onErr(Object e) {
      if (mounted) setState(() => _error = '$e');
    }

    _subs.add(_service.watchGroup(_gid).listen((g) => setState(() => _group = g), onError: onErr));
    _subs.add(_service.members(_gid).listen((m) {
      setState(() => _members = m);
      if (_me != null) _publishStats();
    }, onError: onErr));
    _subs.add(_service.sessions(_gid).listen((s) {
      setState(() => _sessions = s);
      _scheduleReminders();
    }, onError: (_) {}));
    _subs.add(_service.events(_gid).listen((e) {
      setState(() => _events = e);
      _syncDoneSubscriptions();
      _scheduleReminders();
    }, onError: (_) {}));
    _subs.add(_service.messages(_gid).listen((m) => setState(() => _messages = m), onError: (_) {}));
    _service.reminderMinutesFor(_gid).then((m) {
      if (mounted) setState(() => _reminderMinutes = m);
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    _reminderDebounce?.cancel();
    for (final s in _doneSubs.values) {
      s.cancel();
    }
    _msgController.dispose();
    _outer.dispose();
    super.dispose();
  }

  bool _statsPublished = false;
  void _publishStats() {
    if (_statsPublished) return;
    _statsPublished = true;
    final focus = context.read<FocusProvider>();
    final tasks = context.read<TimetableProvider>().completedTasks;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final doneThisWeek = tasks.where((t) => (t.updatedAt ?? t.dueDate).isAfter(monday)).length;
    _service.publishStats(_gid,
        focusMinutes: focus.thisWeekTotal, tasksDone: doneThisWeek, streak: focus.streak, visibility: _me?.rankVisibility ?? 'full');
  }

  void _scheduleReminders() {
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(seconds: 2), () {
      final g = _group;
      if (g != null) _service.scheduleGroupReminders(_gid, g.name, _sessions, _events);
    });
  }

  // ───────────── Actions ─────────────

  Future<void> _pickReminder() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: 'Remind me before group classes',
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in [-1, 5, 10, 15, 30, 60])
              ListTile(
                leading: Icon(m == -1 ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
                title: Text(m == -1 ? 'Off' : '$m minutes before'),
                trailing: (_reminderMinutes ?? -1) == m ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final minutes = choice == -1 ? null : choice;
    await _service.setReminderMinutes(_gid, minutes);
    setState(() => _reminderMinutes = minutes);
    _scheduleReminders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(minutes == null ? 'Group reminders off' : 'You\'ll be reminded $minutes min before')));
    }
  }

  Future<void> _shareCode() async {
    final code = await _service.joinCodeFor(_gid);
    if (code == null || !mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite classmates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('They can tap Groups → 🔑 and enter:'),
            const SizedBox(height: 14),
            SelectableText(code, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: 8)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _leaveOrDelete() async {
    final owner = _isOwner;
    final ok = await confirmDestructive(
      context,
      title: owner ? 'Delete group?' : 'Leave group?',
      message: owner
          ? 'This deletes "${_group?.name}" for everyone. This cannot be undone.'
          : 'You can rejoin later if the group is public or you have the code.',
      action: owner ? 'Delete' : 'Leave',
    );
    if (!ok) return;
    try {
      owner ? await _service.deleteGroup(_gid) : await _service.leave(_gid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _copyTimetableToMine() async {
    final tp = context.read<TimetableProvider>();
    var added = 0;
    for (final s in _sessions) {
      final exists = tp.userSessions.any((u) =>
          u.subject.toLowerCase() == s.subject.toLowerCase() && u.day == s.day && u.startMinutes == s.startMinutes);
      if (exists) continue;
      await tp.addSession(ClassSession(
        subject: s.subject,
        startTime: s.startTime,
        endTime: s.endTime,
        day: s.day,
        room: s.room.isEmpty ? 'TBD' : s.room,
        meetingLink: s.meetingLink,
      ));
      added++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(added == 0 ? 'Your schedule already has these classes' : 'Added $added classes to your schedule')));
    }
  }

  Future<void> _addEventToMine(GroupEvent e) async {
    await context.read<TimetableProvider>().saveTask(AcademicTask(
          title: e.title,
          type: e.type,
          subject: _group?.name ?? 'Group',
          dueDate: e.end ?? e.start,
          startDate: e.end != null && !isSameDate(e.start, e.end!) ? e.start : null,
          colorValue: e.colorValue,
          meetingLink: e.meetingLink,
          description: [e.notes ?? '', if (e.room.isNotEmpty) '\n---ROOM---\n${e.room}'].join(),
        ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to your Hub & Board')));
  }

  Future<void> _send() async {
    final text = _msgController.text;
    if (text.trim().isEmpty) return;
    _msgController.clear();
    try {
      await _service.sendMessage(_gid, text, announcement: _announce && _isLeader);
      setState(() => _announce = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not sent: $e')));
    }
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final g = _group;
    final accent = g?.colorValue != null ? Color(g!.colorValue!) : p.accent;

    // The header scrolls away with the tab content so the timetable gets the
    // whole screen; the tab pills stay pinned at the top of the body.
    final header = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(
            children: [
              CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.pop(context)),
              const Spacer(),
              CircleIconButton(
                icon: _reminderMinutes == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                tooltip: 'Class reminders',
                onPressed: _pickReminder,
              ),
              const SizedBox(width: 8),
              CircleIconButton(icon: Icons.person_add_alt_1_rounded, tooltip: 'Invite', onPressed: _shareCode),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: _isOwner ? Icons.delete_outline_rounded : Icons.logout_rounded,
                tooltip: _isOwner ? 'Delete group' : 'Leave group',
                onPressed: _leaveOrDelete,
              ),
            ],
          ),
        ),
        ScreenHeader(
          title: g?.name ?? 'Group',
          eyebrow: g?.subtitle,
          badge: CountBadge(_members.length),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Could not load everything: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _nextClassCard(p, accent)),
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: NestedScrollView(
          controller: _outer,
          headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: PillSegmented<int>(
                  values: const [0, 1, 2, 3, 4],
                  selected: _tab,
                  scrollable: true,
                  labelOf: (i) => const ['Timetable', 'Events', 'Chat', 'Members', 'Ranking'][i],
                  countOf: (i) => i == 1 ? _events.where((e) => !e.start.isBefore(dateOnly(DateTime.now()))).length : (i == 3 ? _members.length : null),
                  onChanged: (i) {
                    setState(() => _tab = i);
                    // Chat needs the full height for the message box.
                    if (i == 2) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_outer.hasClients) {
                          _outer.animateTo(_outer.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (_tab) {
                  0 => _timetableTab(p),
                  1 => _eventsTab(p),
                  2 => _chatTab(p),
                  3 => _membersTab(p),
                  _ => _rankingTab(p),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextClassCard(Palette p, Color accent) {
    final now = DateTime.now();
    final next = GroupService.nextSession(_sessions, now);
    final upcomingEvent = _events.where((e) => e.start.isAfter(now)).firstOrNull;

    String headline;
    String big;
    String detail;
    String? link;
    if (next != null) {
      headline = next.inProgress ? 'In class now' : 'Next class';
      big = next.inProgress ? formatCountdown(next.end.difference(now).inMinutes) : GroupService.describeCountdown(next.start, now);
      if (next.inProgress) big = '$big left';
      detail = '${next.session.subject} · ${next.session.startTime}${next.session.room.isNotEmpty ? ' · ${next.session.room}' : ''}';
      link = next.session.meetingLink;
    } else if (upcomingEvent != null) {
      headline = 'Coming up';
      big = GroupService.describeCountdown(upcomingEvent.start, now);
      detail = '${upcomingEvent.title} · ${upcomingEvent.type}';
      link = upcomingEvent.meetingLink;
    } else {
      headline = 'Nothing scheduled';
      big = '—';
      detail = _canPost ? 'Add the shared timetable below' : 'Leaders haven\'t added classes yet';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(40)),
                  child: Text(headline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(big, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -1)),
                ),
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (link != null)
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: MeetingLinks.label(link),
                icon: Icon(Icons.videocam_rounded, color: accent),
                onPressed: () => MeetingLinks.open(context, link!),
              ),
            ),
        ],
      ),
    );
  }

  // ── Timetable ──
  Widget _timetableTab(Palette p) {
    final byDay = {for (final d in _weekdays) d: _sessions.where((s) => s.day == d).toList()};
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // Wrap, not Row: both buttons don't fit side by side on narrow phones.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (_sessions.isNotEmpty)
              TextButton.icon(
                onPressed: _copyTimetableToMine,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Copy to my schedule'),
              ),
            if (_canPost)
              TextButton.icon(
                onPressed: () => _editSession(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add class'),
              ),
          ],
        ),
        if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: EmptyState(
              icon: Icons.view_timeline_outlined,
              title: 'No shared timetable yet',
              subtitle: _canPost ? 'Add the cohort\'s classes so everyone sees what\'s next.' : 'A group leader can add the classes.',
            ),
          ),
        for (final d in _weekdays)
          if (byDay[d]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
              child: Text(d, style: TextStyle(fontWeight: FontWeight.w700, color: p.textSecondary)),
            ),
            for (final s in byDay[d]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  onTap: _canPost ? () => _editSession(s) : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.startTime, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                          Text(s.endTime, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                        ]),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                          if (s.room.isNotEmpty) Text(s.room, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                        ]),
                      ),
                      if (s.meetingLink != null)
                        IconButton(
                          icon: Icon(Icons.videocam_rounded, color: MeetingLinks.color(s.meetingLink!)),
                          onPressed: () => MeetingLinks.open(context, s.meetingLink!),
                        ),
                    ],
                  ),
                ),
              ),
          ],
      ],
    );
  }

  Future<void> _editSession([GroupSession? existing]) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupSessionSheet(existing: existing),
    );
    if (result == null) return;
    try {
      if (result == 'delete' && existing != null) {
        await _service.deleteSession(_gid, existing.id);
      } else if (result is GroupSession) {
        await _service.saveSession(_gid, result);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not saved: $e')));
    }
  }

  // ── Events (list or shared calendar) ──
  Widget _eventsTab(Palette p) {
    final today = dateOnly(DateTime.now());
    final upcoming = _events.where((e) => !(e.end ?? e.start).isBefore(today)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: PillSegmented<bool>(
                values: const [false, true],
                selected: _eventsCalendar,
                labelOf: (v) => v ? 'Calendar' : 'List',
                onChanged: (v) => setState(() => _eventsCalendar = v),
              ),
            ),
            if (_canPost) ...[
              const SizedBox(width: 8),
              CircleIconButton(icon: Icons.add_rounded, filled: true, tooltip: 'Add event / deadline', onPressed: () => _editEvent()),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_eventsCalendar) ..._calendarView(p) else ...[
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.event_available_rounded, title: 'No upcoming events', subtitle: 'Shared deadlines, exams and meetups show here.'),
            ),
          for (final e in upcoming) _eventCard(p, e),
        ],
      ],
    );
  }

  List<Widget> _calendarView(Palette p) {
    final dayEvents = _events.where((e) => _eventOn(e, _calSelected)).toList();
    final dayName = DateFormat('EEEE').format(_calSelected);
    final dayClasses = _sessions.where((s) => s.day == dayName).toList();
    return [
      SoftCard(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
        child: TableCalendar<GroupEvent>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _calFocused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          rowHeight: 56,
          selectedDayPredicate: (d) => isSameDate(d, _calSelected),
          onDaySelected: (sel, foc) => setState(() {
            _calSelected = dateOnly(sel);
            _calFocused = foc;
          }),
          onPageChanged: (foc) => setState(() => _calFocused = foc),
          eventLoader: (d) => _events.where((e) => _eventOn(e, d)).toList(),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            cellAlignment: Alignment.topCenter,
            cellPadding: const EdgeInsets.only(top: 6),
            defaultTextStyle: TextStyle(color: p.textPrimary),
            weekendTextStyle: TextStyle(color: p.textSecondary),
          ),
          calendarBuilders: CalendarBuilders<GroupEvent>(
            selectedBuilder: (context, day, _) => _calCircle(day, p.ink, p.onInk),
            todayBuilder: (context, day, _) => _calCircle(day, null, p.accent, border: p.accent),
            markerBuilder: (context, day, events) => events.isEmpty
                ? null
                : Positioned(
                    top: 38,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in events.take(3))
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(color: _eventColor(e), shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(DateFormat('EEEE d MMMM').format(_calSelected), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary)),
      const SizedBox(height: 8),
      if (dayEvents.isEmpty && dayClasses.isEmpty)
        Text('Nothing shared for this day.', style: TextStyle(color: p.textSecondary)),
      for (final c in dayClasses)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              Text(c.startTime, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
              const SizedBox(width: 12),
              Expanded(child: Text(c.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textPrimary))),
              TagPill('Class', color: p.accent),
            ]),
          ),
        ),
      for (final e in dayEvents) _eventCard(p, e),
    ];
  }

  bool _eventOn(GroupEvent e, DateTime day) {
    final d = dateOnly(day);
    final start = dateOnly(e.start);
    final end = dateOnly(e.end ?? e.start);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  Color _eventColor(GroupEvent e) => e.colorValue != null ? Color(e.colorValue!) : AppColors.forType(e.type);

  Widget _calCircle(DateTime day, Color? bg, Color fg, {Color? border}) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 2),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border == null ? null : Border.all(color: border, width: 2)),
          child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ),
      );

  /// "I'm done" toggle + how many members have finished.
  Widget _doneRow(Palette p, GroupEvent e) {
    final done = _done[e.id] ?? const {};
    final mine = done.containsKey(_service.uid);
    final total = _members.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Material(
            color: mine ? const Color(0xFF00C853) : p.surfaceAlt,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _service.setEventDone(_gid, e.id, !mine),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(mine ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16, color: mine ? Colors.white : p.textSecondary),
                  const SizedBox(width: 6),
                  Text(mine ? "I'm done" : 'Mark done',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: mine ? Colors.white : p.textPrimary)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              total == 0 ? '' : '${done.length} of $total done',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Palette p, GroupEvent e) {
    return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              radius: 24,
              padding: EdgeInsets.zero,
              onTap: _canPost ? () => _editEvent(e) : null,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: e.colorValue != null ? Color(e.colorValue!) : AppColors.forType(e.type),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              TagPill(e.type, color: e.colorValue != null ? Color(e.colorValue!) : AppColors.forType(e.type)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.end != null && !isSameDate(e.start, e.end!)
                                      ? '${DateFormat('d MMM').format(e.start)} – ${DateFormat('d MMM').format(e.end!)}'
                                      : DateFormat('EEE d MMM · HH:mm').format(e.start),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(e.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: p.textPrimary)),
                            if (e.room.isNotEmpty) Text(e.room, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                            if ((e.notes ?? '').isNotEmpty) Text(e.notes!, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                            if (e.createdByName != null)
                              Text('Added by ${e.createdByName}', style: TextStyle(fontSize: 11, color: p.textMuted)),
                            if (e.meetingLink != null) ...[
                              const SizedBox(height: 8),
                              JoinMeetingButton(url: e.meetingLink!, dense: true),
                            ],
                            _doneRow(p, e),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add to my calendar',
                      icon: const Icon(Icons.event_available_rounded),
                      onPressed: () => _addEventToMine(e),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Future<void> _editEvent([GroupEvent? existing]) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupEventSheet(existing: existing),
    );
    if (result == null) return;
    try {
      if (result == 'delete' && existing != null) {
        await _service.deleteEvent(_gid, existing.id);
      } else if (result is GroupEvent) {
        await _service.saveEvent(_gid, result);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not saved: $e')));
    }
  }

  // ── Chat ──
  Widget _chatTab(Palette p) {
    final me = _service.uid;
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const EmptyState(icon: Icons.forum_outlined, title: 'Say hi 👋', subtitle: 'Share notes, ask about deadlines, plan study sessions.')
              : ListView.builder(
                  // Reversed lists can't share the header's scroll; chat
                  // scrolls on its own.
                  primary: false,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final mine = m.senderId == me;
                    final showName = !mine && (i == _messages.length - 1 || _messages[i + 1].senderId != m.senderId);
                    if (m.isAnnouncement) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SoftCard(
                          radius: 22,
                          color: p.accentSoft,
                          padding: const EdgeInsets.all(14),
                          onLongPress: mine || _isLeader ? () => _deleteMessage(m) : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📣 Announcement · ${m.senderName}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.accent)),
                              const SizedBox(height: 4),
                              Text(m.text, style: TextStyle(color: p.textPrimary)),
                            ],
                          ),
                        ),
                      );
                    }
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: mine || _isLeader ? () => _deleteMessage(m) : null,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          margin: EdgeInsets.only(top: showName ? 8 : 2, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: mine ? p.ink : p.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showName)
                                Text(m.senderName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.accent)),
                              Text(m.text, style: TextStyle(color: mine ? p.onInk : p.textPrimary)),
                              if (m.createdAt != null)
                                Text(DateFormat('HH:mm').format(m.createdAt!),
                                    style: TextStyle(fontSize: 10, color: (mine ? p.onInk : p.textSecondary).withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(
            children: [
              if (_isLeader)
                IconButton(
                  tooltip: 'Send as announcement',
                  isSelected: _announce,
                  icon: Icon(Icons.campaign_outlined, color: _announce ? p.accent : p.textSecondary),
                  onPressed: () => setState(() => _announce = !_announce),
                ),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(hintText: _announce ? 'Announcement to everyone…' : 'Message'),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(icon: Icons.send_rounded, filled: true, onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMessage(GroupMessage m) async {
    final ok = await confirmDestructive(context, title: 'Delete message?', message: m.text);
    if (ok) await _service.deleteMessage(_gid, m.id);
  }

  // ── Members ──
  Widget _membersTab(Palette p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        for (final m in _members)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              onTap: _isLeader && m.uid != _service.uid && m.uid != _group?.ownerId ? () => _memberActions(m) : null,
              child: Row(
                children: [
                  MemberAvatar(name: m.displayName, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayName + (m.uid == _service.uid ? ' (you)' : ''),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                        Text(m.uid == _group?.ownerId ? 'Owner · leader' : (m.isLeader ? 'Leader' : 'Member'),
                            style: TextStyle(fontSize: 12, color: m.isLeader ? p.accent : p.textSecondary)),
                      ],
                    ),
                  ),
                  if (_isLeader && m.uid != _service.uid && m.uid != _group?.ownerId)
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        try {
                          if (v == 'remove') {
                            final ok = await confirmDestructive(context, title: 'Remove member?', message: 'Remove ${m.displayName}?', action: 'Remove');
                            if (ok) await _service.removeMember(_gid, m.uid);
                          } else {
                            await _service.setRole(_gid, m.uid, v);
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                      itemBuilder: (_) => [
                        if (!m.isLeader) const PopupMenuItem(value: 'leader', child: Text('Make leader')),
                        if (m.isLeader) const PopupMenuItem(value: 'member', child: Text('Make member')),
                        const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _memberActions(GroupMember m) async {
    final action = await showChoiceSheet<String>(
      context,
      title: m.displayName,
      options: [m.isLeader ? 'member' : 'leader', 'remove'],
      selected: null,
      labelOf: (a) => const {'leader': 'Make leader', 'member': 'Make regular member', 'remove': 'Remove from group'}[a]!,
      subtitleOf: (a) => const {
        'leader': 'Leaders manage the shared timetable, events and announcements',
        'member': 'Removes leader rights',
        'remove': 'They can rejoin if the group is public or they have the code',
      }[a],
      iconOf: (a) => const {'leader': Icons.star_rounded, 'member': Icons.star_border_rounded, 'remove': Icons.person_remove_outlined}[a],
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'remove') {
        final ok = await confirmDestructive(context, title: 'Remove member?', message: 'Remove ${m.displayName}?', action: 'Remove');
        if (ok) await _service.removeMember(_gid, m.uid);
      } else {
        await _service.setRole(_gid, m.uid, action);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(action == 'leader' ? '${m.displayName} is now a leader' : '${m.displayName} is now a member')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // ── Ranking (friendly contest) ──
  Widget _rankingTab(Palette p) {
    final week = GroupService.weekKey();
    final ranked = _members.where((m) => m.rankVisibility != 'hidden').toList()
      ..sort((a, b) => b.scoreFor(week).compareTo(a.scoreFor(week)));
    final myVisibility = _me?.rankVisibility ?? 'full';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text('This week\'s focus contest', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.textPrimary)),
        const SizedBox(height: 4),
        Text('1 pt per focused minute · 20 pts per finished task · 10 pts per streak day. Resets every Monday.',
            style: TextStyle(fontSize: 12, color: p.textSecondary)),
        const SizedBox(height: 12),
        SoftCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Icon(Icons.visibility_outlined, size: 18, color: p.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text('Show me as', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary))),
            Flexible(
              child: ChoicePill<String>(
                title: 'Your ranking privacy',
                value: myVisibility,
                options: const ['full', 'nameOnly', 'hidden'],
                labelOf: (v) => const {'full': 'Name & progress', 'nameOnly': 'Name only', 'hidden': 'Hidden'}[v]!,
                iconOf: (v) => const {'full': Icons.leaderboard_rounded, 'nameOnly': Icons.person_outline, 'hidden': Icons.visibility_off_outlined}[v],
                onChanged: (v) async {
                  await _service.setRankVisibility(_gid, v);
                  if (v == 'full') {
                    _statsPublished = false;
                    _publishStats();
                  }
                },
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < ranked.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              radius: 22,
              color: i == 0 && ranked[i].scoreFor(week) > 0 ? p.ink : null,
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
              child: Builder(builder: (context) {
                final m = ranked[i];
                final lead = i == 0 && m.scoreFor(week) > 0;
                final fg = lead ? p.onInk : p.textPrimary;
                final private = m.rankVisibility == 'nameOnly';
                final stale = private || m.statsWeek != week;
                return Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(i < 3 && !stale ? const ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                          style: TextStyle(fontSize: i < 3 ? 22 : 16, fontWeight: FontWeight.w700, color: fg)),
                    ),
                    MemberAvatar(name: m.displayName, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
                          Text(
                            private
                                ? 'Keeps progress private'
                                : stale
                                ? 'No activity this week'
                                : '${m.weeklyFocusMinutes} min · ${m.tasksDone} tasks · ${m.streak}🔥',
                            style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    Text(private ? '—' : '${m.scoreFor(week)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: fg)),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ───────────── Sheets ─────────────

class _GroupSessionSheet extends StatefulWidget {
  final GroupSession? existing;
  const _GroupSessionSheet({this.existing});

  @override
  State<_GroupSessionSheet> createState() => _GroupSessionSheetState();
}

class _GroupSessionSheetState extends State<_GroupSessionSheet> {
  late final _subject = TextEditingController(text: widget.existing?.subject ?? '');
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  late final _link = TextEditingController(text: widget.existing?.meetingLink ?? '');
  late String _day = widget.existing?.day ?? _weekdays[DateTime.now().weekday - 1];
  late int _start = widget.existing?.startMinutes ?? 9 * 60;
  late int _end = widget.existing?.endMinutes ?? 10 * 60;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final m = start ? _start : _end;
    final t = await showScrollTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t == null) return;
    setState(() {
      final v = t.hour * 60 + t.minute;
      if (start) {
        final len = _end - _start;
        _start = v;
        _end = v + (len > 0 ? len : 60);
      } else {
        _end = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SheetScaffold(
      title: widget.existing == null ? 'Add shared class' : 'Edit shared class',
      actions: [
        if (widget.existing != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _subject, autofocus: widget.existing == null, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Module')),
            const SizedBox(height: 10),
            WeekdayPicker(selected: _day, onChanged: (d) => setState(() => _day = d)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _timeBox(p, 'Starts', _start, () => _pick(true))),
              const SizedBox(width: 10),
              Expanded(child: _timeBox(p, 'Ends', _end, () => _pick(false))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room (optional)')),
            const SizedBox(height: 10),
            TextField(controller: _link, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Meet / Teams link (optional)', prefixIcon: Icon(Icons.videocam_outlined))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 18),
            InkPillButton(
              label: 'Save',
              expand: true,
              onPressed: () {
                if (_subject.text.trim().isEmpty) return setState(() => _error = 'Enter the module name');
                if (_end <= _start) return setState(() => _error = 'End must be after start');
                if (_link.text.trim().isNotEmpty && !MeetingLinks.isValid(_link.text)) {
                  return setState(() => _error = 'Invalid meeting link');
                }
                Navigator.pop(
                  context,
                  GroupSession(
                    id: widget.existing?.id ?? '',
                    subject: _subject.text.trim(),
                    day: _day,
                    startTime: formatMinutes(_start),
                    endTime: formatMinutes(_end),
                    room: _room.text.trim(),
                    meetingLink: MeetingLinks.normalize(_link.text),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _timeBox(Palette p, String label, int minutes, VoidCallback onTap) => SoftCard(
      color: p.surfaceAlt,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: p.textSecondary, fontWeight: FontWeight.w600)),
        Text(formatMinutes(minutes), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: p.textPrimary)),
      ]),
    );

class _GroupEventSheet extends StatefulWidget {
  final GroupEvent? existing;
  const _GroupEventSheet({this.existing});

  @override
  State<_GroupEventSheet> createState() => _GroupEventSheetState();
}

class _GroupEventSheetState extends State<_GroupEventSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  late final _link = TextEditingController(text: widget.existing?.meetingLink ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  static const _types = ['Assignment', 'Test', 'Exam', 'Other'];
  late String _type = _types.contains(widget.existing?.type) ? widget.existing!.type : (widget.existing == null ? 'Assignment' : 'Other');
  late final _customType = TextEditingController(
      text: widget.existing != null && !_types.contains(widget.existing!.type) ? widget.existing!.type : '');
  late DateTime _start = widget.existing?.start ?? DateTime.now().add(const Duration(days: 1));
  late DateTime? _endDate = widget.existing?.end;
  late int? _color = widget.existing?.colorValue;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _link.dispose();
    _notes.dispose();
    _customType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SheetScaffold(
      title: widget.existing == null ? 'Shared event' : 'Edit event',
      actions: [
        if (widget.existing != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _title, autofocus: widget.existing == null, textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'Stats assignment 2 due')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    showCheckmark: false,
                    selectedColor: p.ink,
                    labelStyle: TextStyle(color: _type == t ? p.onInk : p.textPrimary),
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            if (_type == 'Other') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customType,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name this type', hintText: 'e.g. Meetup, Presentation'),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SoftCard(
                  color: p.surfaceAlt,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Date', style: TextStyle(fontSize: 11, color: p.textSecondary, fontWeight: FontWeight.w600)),
                    Text(DateFormat('EEE d MMM').format(_start), style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeBox(p, 'Time', _start.hour * 60 + _start.minute, () async {
                  final t = await showScrollTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
                  if (t != null) setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
                }),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Spans several days'),
              value: _endDate != null,
              onChanged: (v) => setState(() => _endDate = v ? _start.add(const Duration(days: 2)) : null),
            ),
            if (_endDate != null)
              SoftCard(
                color: p.surfaceAlt,
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _endDate!, firstDate: _start, lastDate: DateTime(2035));
                  if (d != null) setState(() => _endDate = DateTime(d.year, d.month, d.day, 23, 59));
                },
                child: Text('Ends ${DateFormat('EEE d MMM').format(_endDate!)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
              ),
            const SizedBox(height: 10),
            TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room / place (optional)')),
            const SizedBox(height: 10),
            TextField(controller: _link, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Meet / Teams link (optional)', prefixIcon: Icon(Icons.videocam_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in AppColors.eventPalette)
                    GestureDetector(
                      onTap: () => setState(() => _color = c.toARGB32()),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: _color == c.toARGB32() ? p.ink : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 18),
            InkPillButton(
              label: 'Save',
              expand: true,
              onPressed: () {
                if (_title.text.trim().isEmpty) return setState(() => _error = 'Enter a title');
                if (_link.text.trim().isNotEmpty && !MeetingLinks.isValid(_link.text)) {
                  return setState(() => _error = 'Invalid meeting link');
                }
                Navigator.pop(
                  context,
                  GroupEvent(
                    id: widget.existing?.id ?? '',
                    title: _title.text.trim(),
                    type: _type == 'Other' ? (_customType.text.trim().isEmpty ? 'Other' : _customType.text.trim()) : _type,
                    start: _start,
                    end: _endDate,
                    room: _room.text.trim(),
                    meetingLink: MeetingLinks.normalize(_link.text),
                    colorValue: _color,
                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
