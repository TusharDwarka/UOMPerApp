import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/class_session.dart';
import '../providers/record_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/timetable_provider.dart';
import '../screens/home_screen.dart' show AppPage;
import '../screens/notes_tab.dart' show showNoteEditor;
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'add_edit_task_sheet.dart';
import 'class_details_sheet.dart';

/// Strong ease-out: fast start, soft landing. Used for everything that moves.
const _easeOut = Cubic(0.23, 1, 0.32, 1);

/// Pages laid out as a single reading column (capped width) on wide windows.
const _readingPages = <int>{};

const _expandedWidth = 252.0;
const _collapsedWidth = 60.0;
const _collapsedPrefKey = 'desktop_sidebar_collapsed';

class _Dest {
  final int page;
  final IconData icon;
  final String label;
  const _Dest(this.page, this.icon, this.label);
}

const _home = _Dest(AppPage.home, Icons.home_outlined, 'Home');
const _settings = _Dest(AppPage.settings, Icons.settings_outlined, 'Settings');

/// Sidebar groups. Thin outlined icons read better at desktop sizes.
const _groups = <(String, List<_Dest>)>[
  ('Study', [
    _Dest(AppPage.schedule, Icons.view_day_outlined, 'Schedule'),
    _Dest(AppPage.hub, Icons.calendar_today_outlined, 'Hub'),
    _Dest(AppPage.board, Icons.view_kanban_outlined, 'Board'),
    _Dest(AppPage.focus, Icons.timer_outlined, 'Focus'),
    _Dest(AppPage.grades, Icons.workspace_premium_outlined, 'Grades'),
  ]),
  ('Library', [
    _Dest(AppPage.notes, Icons.sticky_note_2_outlined, 'Notes'),
    _Dest(AppPage.files, Icons.folder_outlined, 'Files'),
  ]),
  ('Campus', [
    _Dest(AppPage.groups, Icons.groups_outlined, 'Groups'),
    _Dest(AppPage.bus, Icons.directions_bus_outlined, 'Bus'),
  ]),
];

final _allDests = <_Dest>[_home, for (final g in _groups) ...g.$2, _settings];

_Dest _destFor(int page) => _allDests.firstWhere((d) => d.page == page, orElse: () => _home);

/// Ctrl+1…9 follow the sidebar order.
final _shortcutPages = [for (final d in _allDests) d.page].take(9).toList();

/// The PC layout: a collapsible sidebar (like Notion / Claude), a slim
/// breadcrumb bar and the page. Only used on Windows/macOS/Linux; phones keep
/// the pill bar in [HomeScreen].
class DesktopShell extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget body;

  const DesktopShell({super.key, required this.selected, required this.onSelect, required this.body});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final v = prefs.getBool(_collapsedPrefKey);
      if (v != null && mounted) setState(() => _collapsed = v);
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() => _collapsed = !_collapsed);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_collapsedPrefKey, _collapsed));
  }

  /// App-wide shortcuts. A global handler (not a Shortcuts widget) so they
  /// still work after a text field gives up focus; ignored while a dialog or
  /// sheet is open on top of the app.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed) || kb.isAltPressed) return false;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.keyK) {
      _openPalette();
    } else if (k == LogicalKeyboardKey.backslash) {
      _toggleSidebar();
    } else if (k == LogicalKeyboardKey.keyN && !kb.isShiftPressed) {
      showTaskSheet(context);
    } else {
      const digits = [
        LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, //
        LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6, //
        LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
      ];
      final i = digits.indexOf(k);
      if (i < 0 || i >= _shortcutPages.length) return false;
      widget.onSelect(_shortcutPages[i]);
    }
    return true;
  }

  void _toggleTheme() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    context.read<ThemeProvider>().setTheme(dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _openPalette() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final commands = <_Command>[
      for (var i = 0; i < _allDests.length; i++)
        _Command(
          _allDests[i].icon,
          _allDests[i].label,
          'Go to',
          () => widget.onSelect(_allDests[i].page),
          shortcut: i < 9 ? 'Ctrl ${i + 1}' : null,
        ),
      _Command(Icons.add_task_rounded, 'New task', 'Create', () => showTaskSheet(context), shortcut: 'Ctrl N'),
      _Command(Icons.edit_note_rounded, 'New note', 'Create', () => showNoteEditor(context)),
      _Command(Icons.play_circle_outline_rounded, 'Start a focus session', 'Action', () => widget.onSelect(AppPage.focus)),
      _Command(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, dark ? 'Light mode' : 'Dark mode', 'Action', _toggleTheme),
      _Command(Icons.view_sidebar_outlined, _collapsed ? 'Expand sidebar' : 'Collapse sidebar', 'Action', _toggleSidebar,
          shortcut: 'Ctrl \\'),
    ];
    final picked = await showGeneralDialog<_Command>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _CommandPalette(commands: commands),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: _easeOut, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), alignment: Alignment.topCenter, child: child),
        );
      },
    );
    picked?.run();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        _Sidebar(
          collapsed: _collapsed,
          selected: widget.selected,
          onSelect: widget.onSelect,
          onToggle: _toggleSidebar,
          onSearch: _openPalette,
          onToggleTheme: _toggleTheme,
        ),
        Container(width: 1, color: p.border),
        Expanded(
          child: Column(
            children: [
              _TopBar(page: widget.selected, onSearch: _openPalette),
              Expanded(
                // Same tree for every page (the IndexedStack below keeps each
                // page alive); only the width cap changes. List-style pages
                // read better as a centred column than stretched edge to edge.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _readingPages.contains(widget.selected) ? 1000 : double.infinity),
                      child: widget.body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Sidebar ─────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle, onSearch, onToggleTheme;

  const _Sidebar({
    required this.collapsed,
    required this.selected,
    required this.onSelect,
    required this.onToggle,
    required this.onSearch,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final unsorted = context.select<ResourceProvider, int>((r) => r.unsortedCount);
    final holiday = context.select<RecordProvider, bool>((r) => r.holidayMode);

    Widget item(_Dest d, {int? badge}) => _SideItem(
          icon: d.icon,
          label: d.label,
          selected: d.page == selected,
          collapsed: collapsed,
          badge: badge,
          onTap: () => onSelect(d.page),
        );

    // The content is always laid out at full width and clipped while the
    // width animates, so nothing reflows or jumps: icons sit exactly where
    // the collapsed rail shows them.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: _easeOut,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      color: p.sidebar,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _expandedWidth,
          maxWidth: _expandedWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SidebarHeader(collapsed: collapsed, onToggle: onToggle),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                    children: [
                      _SideItem(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        hint: 'Ctrl K',
                        collapsed: collapsed,
                        onTap: onSearch,
                      ),
                      _SideItem(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'New task',
                        hint: 'Ctrl N',
                        collapsed: collapsed,
                        onTap: () => showTaskSheet(context),
                      ),
                      const SizedBox(height: 10),
                      item(_home),
                      for (final g in _groups) ...[
                        _SectionTitle(g.$1, collapsed: collapsed),
                        for (final d in g.$2) item(d, badge: d.page == AppPage.files && unsorted > 0 ? unsorted : null),
                      ],
                      if (!holiday) _TodayList(collapsed: collapsed, onSeeAll: () => onSelect(AppPage.schedule)),
                    ],
                  ),
                ),
              ),
              _AccountRow(
                collapsed: collapsed,
                selected: selected == AppPage.settings,
                onTap: () => onSelect(AppPage.settings),
                onToggleTheme: onToggleTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App mark + name + collapse button. Collapsed, the mark turns into the
/// expand button on hover (the collapse button is clipped away).
class _SidebarHeader extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  const _SidebarHeader({required this.collapsed, required this.onToggle});

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final showExpand = widget.collapsed && _hover;
    final mark = MouseRegion(
      cursor: widget.collapsed ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.collapsed ? widget.onToggle : null,
        child: Tooltip(
          message: widget.collapsed ? 'Expand sidebar  (Ctrl \\)' : '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: showExpand ? p.sidebarSelected : p.ink, borderRadius: BorderRadius.circular(8)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: showExpand
                  ? Icon(Icons.keyboard_double_arrow_right_rounded, key: const ValueKey('e'), size: 17, color: p.textPrimary)
                  : Icon(Icons.school_rounded, key: const ValueKey('m'), size: 16, color: p.onInk),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(
          children: [
            mark,
            const SizedBox(width: 10),
            Expanded(
              child: _Fade(
                visible: !widget.collapsed,
                child: Text('UOM Personal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: p.textPrimary, letterSpacing: -0.2)),
              ),
            ),
            _IconHoverButton(
              icon: Icons.keyboard_double_arrow_left_rounded,
              tooltip: 'Collapse sidebar  (Ctrl \\)',
              onTap: widget.onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool collapsed;
  const _SectionTitle(this.text, {required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 18, 8, 6),
      child: _Fade(
        visible: !collapsed,
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.textMuted)),
      ),
    );
  }
}

/// One sidebar row: instant hover tint, solid tint when selected.
class _SideItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final String? hint;
  final int? badge;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
    this.selected = false,
    this.hint,
    this.badge,
  });

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sel = widget.selected;
    final bg = sel ? p.sidebarSelected : (_hover ? p.sidebarHover : p.sidebar.withValues(alpha: 0));
    final fg = sel ? p.textPrimary : p.textSecondary;

    Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: 34,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.only(left: 11, right: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(widget.icon, size: 18, color: sel ? p.textPrimary : p.textSecondary),
          const SizedBox(width: 11),
          Expanded(
            child: _Fade(
              visible: !widget.collapsed,
              child: Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: fg)),
            ),
          ),
          if (widget.badge != null)
            _Fade(
              visible: !widget.collapsed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.badge}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            )
          else if (widget.hint != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 90),
              opacity: _hover && !widget.collapsed ? 1 : 0,
              child: Text(widget.hint!, style: TextStyle(fontSize: 11.5, color: p.textMuted)),
            ),
        ],
      ),
    );

    row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: row),
    );
    row = Semantics(button: true, selected: sel, label: widget.label, child: row);
    // Labels are hidden when collapsed, so say what the icon is.
    return widget.collapsed ? Tooltip(message: widget.label, preferBelow: false, child: row) : row;
  }
}

/// Today's classes, like the recent-chats list in the reference design.
class _TodayList extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onSeeAll;
  const _TodayList({required this.collapsed, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final timetable = context.watch<TimetableProvider>();
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = timetable.getClassesForDate(now);
    const max = 6;

    return _Fade(
      visible: !collapsed,
      child: IgnorePointer(
        ignoring: collapsed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 18, 8, 6),
              child: Row(
                children: [
                  Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.textMuted)),
                  const SizedBox(width: 6),
                  if (today.isNotEmpty) Text('${today.length}', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                ],
              ),
            ),
            if (today.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 2, 8, 0),
                child: Text(now.weekday >= 6 ? 'Weekend — no classes' : 'No classes today',
                    style: TextStyle(fontSize: 13, color: p.textMuted)),
              ),
            for (final s in today.take(max)) _TodayRow(session: s, nowMin: nowMin),
            if (today.length > max)
              _TodayMore(label: '${today.length - max} more', onTap: onSeeAll),
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatefulWidget {
  final ClassSession session;
  final int nowMin;
  const _TodayRow({required this.session, required this.nowMin});

  @override
  State<_TodayRow> createState() => _TodayRowState();
}

class _TodayRowState extends State<_TodayRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = widget.session;
    final isNow = widget.nowMin >= s.startMinutes && widget.nowMin < s.endMinutes;
    final done = widget.nowMin >= s.endMinutes ||
        (s.cancelledDates?.contains(DateFormat('yyyy-MM-dd').format(DateTime.now())) ?? false);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showClassDetailsSheet(context, s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 30,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(color: _hover ? p.sidebarHover : p.sidebar.withValues(alpha: 0), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNow ? p.accent : Colors.transparent,
                  border: Border.all(color: isNow ? p.accent : p.textMuted, width: 1.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? p.textMuted : p.textPrimary,
                      fontWeight: isNow ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
              const SizedBox(width: 8),
              Text(s.startTime, style: TextStyle(fontSize: 11.5, color: p.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayMore extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TodayMore({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: p.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 30),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Signed-in account at the bottom; opens Settings. Theme toggle on the right.
class _AccountRow extends StatefulWidget {
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleTheme;
  const _AccountRow({required this.collapsed, required this.selected, required this.onTap, required this.onToggleTheme});

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _hover = false;

  (String, String?) get _who {
    User? u;
    try {
      u = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return ('Student', null); // Firebase not initialised (tests)
    }
    final name = u?.displayName?.trim();
    final email = u?.email;
    if (name != null && name.isNotEmpty) return (name, email);
    if (email != null && email.contains('@')) return (email.split('@').first, email);
    return (u?.isAnonymous == true ? 'Guest' : 'Student', email);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (name, email) = _who;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected ? p.sidebarSelected : (_hover ? p.sidebarHover : p.sidebar.withValues(alpha: 0));

    Widget row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 46,
          padding: const EdgeInsets.only(left: 6, right: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fade(
                  visible: !widget.collapsed,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textPrimary)),
                      Text(email ?? 'Settings',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                    ],
                  ),
                ),
              ),
              _IconHoverButton(
                icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                tooltip: dark ? 'Light mode' : 'Dark mode',
                onTap: widget.onToggleTheme,
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.collapsed) row = Tooltip(message: 'Settings', preferBelow: false, child: row);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: row,
    );
  }
}

// ───────────────────────────── Top bar ─────────────────────────────

/// "Schedule / Week 6" breadcrumb, sync state and search on the right.
class _TopBar extends StatelessWidget {
  final int page;
  final VoidCallback onSearch;
  const _TopBar({required this.page, required this.onSearch});

  String? _context(BuildContext context) {
    final now = DateTime.now();
    switch (page) {
      case AppPage.home:
        return DateFormat('EEEE d MMMM').format(now);
      case AppPage.schedule:
        final t = context.read<TimetableProvider>();
        return t.getWeekNumber(now) >= 1 ? t.getWeekLabel(now) : 'Pre-semester';
      case AppPage.hub:
        return DateFormat('MMMM y').format(now);
      case AppPage.board:
        final n = context.read<TimetableProvider>().pendingTasks.length;
        return n == 0 ? 'All clear' : '$n open';
      case AppPage.files:
        final n = context.read<ResourceProvider>().unsortedCount;
        return n == 0 ? null : '$n in inbox';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Rebuild the crumb when tasks/files change.
    context.watch<TimetableProvider>();
    context.watch<ResourceProvider>();
    final d = _destFor(page);
    final sub = _context(context);
    SyncService? sync;
    try {
      sync = context.read<SyncService>();
    } catch (_) {}

    // Narrow windows: icon-only search, no "Syncing" label.
    final compact = MediaQuery.sizeOf(context).width < 1000;

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(d.icon, size: 16, color: p.textPrimary),
                  const SizedBox(width: 8),
                  Text(d.label,
                      maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.textPrimary)),
                ],
              ),
            ),
            if (sub != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('/', style: TextStyle(color: p.textMuted, fontSize: 14)),
              ),
              // Expanded (not Flexible + Spacer, which split the free space
              // and left the search pill floating mid-bar).
              Expanded(
                child: Text(sub,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
              ),
            ] else
              const Spacer(),
            if (sync != null)
              ValueListenableBuilder<bool>(
                valueListenable: sync.isSyncing,
                // Only built while syncing: an idle spinner at opacity 0
                // would still repaint every frame.
                builder: (_, syncing, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: !syncing
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: p.textMuted)),
                            if (!compact) ...[
                              const SizedBox(width: 8),
                              Text('Syncing', style: TextStyle(fontSize: 12.5, color: p.textMuted)),
                            ],
                            const SizedBox(width: 12),
                          ],
                        ),
                ),
              ),
            _SearchPill(onTap: onSearch, compact: compact),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _SearchPill({required this.onTap, this.compact = false});

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 32,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: _hover ? p.surfaceAlt : p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 16, color: p.textSecondary),
              const SizedBox(width: 8),
              if (!widget.compact) ...[
                Text('Jump to…', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                const SizedBox(width: 18),
              ],
              const _Kbd('Ctrl K'),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Command palette ─────────────────────────────

class _Command {
  final IconData icon;
  final String label;
  final String group;
  final VoidCallback run;
  final String? shortcut;
  const _Command(this.icon, this.label, this.group, this.run, {this.shortcut});
}

class _CommandPalette extends StatefulWidget {
  final List<_Command> commands;
  const _CommandPalette({required this.commands});

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _index = 0;

  static const _rowHeight = 38.0;

  List<_Command> get _results {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.commands;
    return widget.commands.where((c) => c.label.toLowerCase().contains(q) || c.group.toLowerCase().startsWith(q)).toList();
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final n = _results.length;
    if (n == 0) return;
    setState(() => _index = (_index + delta) % n < 0 ? n - 1 : (_index + delta) % n);
    // Keep the highlighted row in view.
    final top = _index * _rowHeight;
    if (_scroll.hasClients) {
      final view = _scroll.position.viewportDimension;
      if (top < _scroll.offset) {
        _scroll.jumpTo(top);
      } else if (top + _rowHeight > _scroll.offset + view) {
        _scroll.jumpTo(top + _rowHeight - view);
      }
    }
  }

  void _run() {
    final r = _results;
    if (r.isEmpty) return;
    Navigator.pop(context, r[_index.clamp(0, r.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final results = _results;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 96, left: 24, right: 24),
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
                    const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
                  },
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() => _index = 0),
                    onSubmitted: (_) => _run(),
                    style: TextStyle(fontSize: 15, color: p.textPrimary),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Jump to a page or run a command…',
                      hintStyle: TextStyle(color: p.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                Divider(height: 1, color: p.border),
                Flexible(
                  child: results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No matches', style: TextStyle(color: p.textMuted)),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(6),
                          itemExtent: _rowHeight,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final c = results[i];
                            final sel = i == _index;
                            return MouseRegion(
                              onHover: (_) {
                                if (_index != i) setState(() => _index = i);
                              },
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context, c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: sel ? p.surfaceAlt : p.surface.withValues(alpha: 0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(c.icon, size: 18, color: sel ? p.textPrimary : p.textSecondary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(c.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, color: p.textPrimary, fontWeight: FontWeight.w500)),
                                      ),
                                      Text(c.group, style: TextStyle(fontSize: 12, color: p.textMuted)),
                                      if (c.shortcut != null) ...[const SizedBox(width: 10), _Kbd(c.shortcut!)],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: p.canvas, border: Border(top: BorderSide(color: p.border))),
                  child: Row(
                    children: [
                      const _Kbd('↑↓'),
                      const SizedBox(width: 6),
                      Text('navigate', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                      const SizedBox(width: 14),
                      const _Kbd('Enter'),
                      const SizedBox(width: 6),
                      Text('open', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                      const SizedBox(width: 14),
                      const _Kbd('Esc'),
                      const SizedBox(width: 6),
                      Text('close', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Small pieces ─────────────────────────────

/// Keyboard key hint, e.g. "Ctrl K".
class _Kbd extends StatelessWidget {
  final String text;
  const _Kbd(this.text);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.border),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: p.textSecondary, fontWeight: FontWeight.w500)),
    );
  }
}

/// Square icon button with a hover tint (no ripple).
class _IconHoverButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconHoverButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_IconHoverButton> createState() => _IconHoverButtonState();
}

class _IconHoverButtonState extends State<_IconHoverButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _hover ? p.sidebarSelected : p.sidebarSelected.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(widget.icon, size: 17, color: _hover ? p.textPrimary : p.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Fades a label in/out as the sidebar collapses (it's clipped, not reflowed).
class _Fade extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _Fade({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Duration(milliseconds: visible ? 180 : 90),
      curve: _easeOut,
      child: child,
    );
  }
}
