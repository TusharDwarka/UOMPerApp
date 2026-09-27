import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../providers/timetable_provider.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'group_detail_screen.dart';
import 'login_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _tab = 0;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
  int? _yearFilter;
  int? _semesterFilter;

  // Streams are created once per signed-in user, not on every rebuild.
  String? _streamsUid;
  Stream<List<StudyGroup>>? _mine;
  Stream<List<StudyGroup>>? _public;

  void _ensureStreams(GroupService service) {
    if (_streamsUid == service.uid && _mine != null) return;
    _streamsUid = service.uid;
    _mine = service.myGroups();
    _public = service.discover();
  }

  void _open(StudyGroup g) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id, initial: g)));
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<(StudyGroup, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupSheet(),
    );
    if (created == null || !mounted) return;
    final (group, code) = created;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group created 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.isPublic
                ? 'Classmates can find it under Discover, or join with this code:'
                : 'Share this code with classmates so they can join:'),
            const SizedBox(height: 14),
            SelectableText(code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: 6)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
            },
            child: const Text('Copy code'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
    if (mounted) _open(group);
  }

  Future<void> _joinWithCode() async {
    final code = await showControllerDialog<String>(
      context,
      builder: (ctx, controller) => AlertDialog(
        title: const Text('Join with code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: const TextStyle(fontSize: 26, letterSpacing: 6),
          decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final g = await context.read<GroupService>().joinByCode(code);
      if (mounted) _open(g);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: ${_clean(e)}')));
    }
  }

  static String _clean(Object e) => e.toString().replaceFirst(RegExp(r'^.*?(Exception|Error): '), '');

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final service = context.read<GroupService>();

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, _) {
            if (!service.canUseGroups) return _guestState(p);
            _ensureStreams(service);
            return Column(
              children: [
                ScreenHeader(
                  title: 'Groups',
                  eyebrow: 'Your cohort, shared timetable & chat',
                  actions: [
                    CircleIconButton(icon: Icons.key_rounded, tooltip: 'Join with code', onPressed: _joinWithCode),
                    CircleIconButton(icon: Icons.add_rounded, filled: true, tooltip: 'Create group', onPressed: _create),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: PillSegmented<int>(
                    values: const [0, 1],
                    selected: _tab,
                    labelOf: (i) => i == 0 ? 'My groups' : 'Discover',
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(child: _tab == 0 ? _myGroups(p, service) : _discover(p, service)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _guestState(Palette p) {
    return EmptyState(
      icon: Icons.groups_rounded,
      title: 'Groups need an account',
      subtitle: 'Create a free account to join your cohort, share a timetable and chat. Your guest data comes with you.',
      action: InkPillButton(
        label: 'Create account',
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(upgradeGuest: true)));
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _myGroups(Palette p, GroupService service) {
    return StreamBuilder<List<StudyGroup>>(
      stream: _mine,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load groups', subtitle: '${snap.error}');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snap.data!;
        if (groups.isEmpty) {
          return EmptyState(
            icon: Icons.diversity_3_rounded,
            title: 'No groups yet',
            subtitle: 'Find your programme under Discover, join with a code from a classmate, or start one for your cohort.',
            action: InkPillButton(label: 'Discover groups', icon: Icons.explore_rounded, onPressed: () => setState(() => _tab = 1)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _GroupCard(group: groups[i], onTap: () => _open(groups[i]), showNext: true),
        );
      },
    );
  }

  /// Search + filters scroll with the results: pinned above them they
  /// overflowed once the keyboard left little room.
  Widget _discover(Palette p, GroupService service) {
    final filters = [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(hintText: 'Search programme or name', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final y in [null, 1, 2, 3, 4, 5])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(y == null ? 'All years' : 'Y$y'),
                  selected: _yearFilter == y,
                  showCheckmark: false,
                  selectedColor: p.ink,
                  labelStyle: TextStyle(color: _yearFilter == y ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _yearFilter = y),
                ),
              ),
            Container(width: 1, margin: const EdgeInsets.fromLTRB(4, 10, 12, 10), color: p.border),
            for (final sem in [null, 1, 2])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(sem == null ? 'Any sem' : 'S$sem'),
                  selected: _semesterFilter == sem,
                  showCheckmark: false,
                  selectedColor: p.ink,
                  labelStyle: TextStyle(color: _semesterFilter == sem ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _semesterFilter = sem),
                ),
              ),
          ],
        ),
      ),
    ];
    // One ListView root in every state keeps the search field's element (and
    // focus) alive while results load or change.
    return StreamBuilder<List<StudyGroup>>(
      stream: _public,
      builder: (context, snap) {
        Widget page(List<Widget> body) =>
            ListView(padding: const EdgeInsets.only(bottom: 32), children: [...filters, ...body]);
        if (snap.hasError) {
          return page([EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load', subtitle: '${snap.error}')]);
        }
        if (!snap.hasData) return page(const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))]);
        final list = snap.data!.where((g) {
          if (_yearFilter != null && g.year != _yearFilter) return false;
          if (_semesterFilter != null && g.semester != _semesterFilter) return false;
          if (_query.isEmpty) return true;
          return g.name.toLowerCase().contains(_query) ||
              g.programme.toLowerCase().contains(_query) ||
              g.description.toLowerCase().contains(_query);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (list.isEmpty) {
          return page([
            EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'No public groups found',
              subtitle: 'Be the first — create one for your programme and year.',
              action: InkPillButton(label: 'Create group', icon: Icons.add, onPressed: _create),
            ),
          ]);
        }
        return page([
          for (final g in list)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _GroupCard(
                key: ValueKey(g.id),
                group: g,
                onTap: () => _open(g),
                trailing: InkPillButton(
                  label: 'Join',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await service.joinPublic(g);
                      if (mounted) _open(g);
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Could not join: ${_clean(e)}')));
                    }
                  },
                ),
              ),
            ),
        ]);
      },
    );
  }
}

/// Group card in the design language: big light name, member stack, next class.
class _GroupCard extends StatefulWidget {
  final StudyGroup group;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showNext;
  const _GroupCard({super.key, required this.group, required this.onTap, this.trailing, this.showNext = false});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late Stream<List<GroupMember>> _members;
  late Stream<List<GroupSession>> _sessions;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _GroupCard old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id) _subscribe();
  }

  void _subscribe() {
    final service = context.read<GroupService>();
    _members = service.members(widget.group.id);
    // Only members can read the shared timetable.
    _sessions = widget.showNext ? service.sessions(widget.group.id) : const Stream.empty();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final group = widget.group;
    final onTap = widget.onTap;
    final trailing = widget.trailing;
    final showNext = widget.showNext;
    final accent = group.colorValue != null ? Color(group.colorValue!) : p.accent;

    return SoftCard(
      radius: 32,
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(group.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              if (!group.isPublic) Icon(Icons.lock_rounded, size: 14, color: p.textMuted),
              StreamBuilder<List<GroupMember>>(
                stream: _members,
                builder: (context, snap) => snap.hasData ? _MemberStack(members: snap.data!) : const SizedBox(height: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w300, letterSpacing: -0.8, color: p.textPrimary)),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary)),
          ],
          if (showNext || trailing != null) const SizedBox(height: 12),
          Row(
            children: [
              if (showNext)
                Expanded(
                  child: StreamBuilder<List<GroupSession>>(
                    stream: _sessions,
                    builder: (context, snap) {
                      final next = snap.hasData ? GroupService.nextSession(snap.data!, DateTime.now()) : null;
                      if (next == null) return Text('No shared classes yet', style: TextStyle(fontSize: 12, color: p.textMuted));
                      final label = next.inProgress
                          ? 'Now: ${next.session.subject}'
                          : '${next.session.subject} ${GroupService.describeCountdown(next.start, DateTime.now())}';
                      return Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberStack extends StatelessWidget {
  final List<GroupMember> members;
  const _MemberStack({required this.members});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final shown = members.take(3).toList();
    final extra = members.length - shown.length;
    const size = 32.0;
    final width = size + (shown.length - 1 + (extra > 0 ? 1 : 0)) * 22.0;
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: i * 22.0, child: MemberAvatar(name: shown[i].displayName, size: size)),
          if (extra > 0)
            Positioned(
              left: shown.length * 22.0,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 2)),
                child: Text('$extra+', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textPrimary)),
              ),
            ),
        ],
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;
  const MemberAvatar({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final c = AppColors.eventPalette[h % AppColors.eventPalette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 2)),
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  late final _programme = TextEditingController(text: context.read<TimetableProvider>().courseName);
  final _desc = TextEditingController();
  late int _year = context.read<TimetableProvider>().studyYear;
  late int _semester = context.read<TimetableProvider>().semester;
  bool _public = true;
  bool _membersCanPost = false;
  int _color = AppColors.eventPalette.first.toARGB32();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _programme.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the group a name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<GroupService>().createGroup(
            name: _name.text,
            programme: _programme.text,
            description: _desc.text,
            year: _year,
            semester: _semester,
            isPublic: _public,
            membersCanPost: _membersCanPost,
            colorValue: _color,
          );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not create the group: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SheetScaffold(
      title: 'New group',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Group name', hintText: 'DS Year 2 — Cohort A')),
            const SizedBox(height: 10),
            TextField(controller: _programme, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Programme', hintText: 'Data Science')),
            const SizedBox(height: 10),
            TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 14),
            Text('Year', style: TextStyle(fontWeight: FontWeight.w600, color: p.textSecondary)),
            const SizedBox(height: 8),
            PillSegmented<int>(values: const [1, 2, 3, 4, 5], selected: _year, labelOf: (y) => 'Y$y', onChanged: (y) => setState(() => _year = y)),
            const SizedBox(height: 12),
            Text('Semester', style: TextStyle(fontWeight: FontWeight.w600, color: p.textSecondary)),
            const SizedBox(height: 8),
            PillSegmented<int>(values: const [1, 2], selected: _semester, labelOf: (s) => 'Semester $s', onChanged: (s) => setState(() => _semester = s)),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Public'),
              subtitle: const Text('Anyone can find & join from Discover. Off = join code only.'),
              value: _public,
              onChanged: (v) => setState(() => _public = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Members can add classes & events'),
              subtitle: const Text('Off = only leaders edit the shared timetable.'),
              value: _membersCanPost,
              onChanged: (v) => setState(() => _membersCanPost = v),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in AppColors.eventPalette)
                    GestureDetector(
                      onTap: () => setState(() => _color = c.toARGB32()),
                      child: Container(
                        width: 34,
                        height: 34,
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
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 18),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : InkPillButton(label: 'Create group', icon: Icons.check_rounded, expand: true, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
