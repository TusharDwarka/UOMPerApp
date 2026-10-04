import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'academic_tab.dart';
import 'bus_tab.dart';
import 'dashboard_tab.dart';
import 'focus_screen.dart';
import 'notes_tab.dart';
import 'groups_screen.dart';
import 'resources_tab.dart';
import 'schedule_tab.dart';
import 'settings_tab.dart';
import 'todo_board_tab.dart';

/// Page indices. Mobile shows the user's first [barSlots] pages (see
/// [navOrderFrom]) in the pill bar plus "More".
class AppPage {
  static const home = 0, schedule = 1, hub = 2, board = 3, bus = 4, files = 5, notes = 6, groups = 7, focus = 8, settings = 9;
  static const count = 10, barSlots = 5;
}

const _navOrderKey = 'nav_order';

/// Saved page order → full valid order: keeps the user's order, drops
/// unknown/duplicate entries and appends pages added in newer versions.
List<int> navOrderFrom(List<String>? saved) {
  final order = <int>{};
  for (final s in saved ?? const <String>[]) {
    final i = int.tryParse(s);
    if (i != null && i >= 0 && i < AppPage.count) order.add(i);
  }
  return [...order, for (var i = 0; i < AppPage.count; i++) if (!order.contains(i)) i];
}

class NavDest {
  final IconData icon;
  final String label;
  const NavDest(this.icon, this.label);
}

const _destinations = <NavDest>[
  NavDest(Icons.grid_view_rounded, 'Home'),
  NavDest(Icons.view_timeline_rounded, 'Schedule'),
  NavDest(Icons.calendar_month_rounded, 'Hub'),
  NavDest(Icons.view_kanban_rounded, 'Board'),
  NavDest(Icons.directions_bus_filled_rounded, 'Bus'),
  NavDest(Icons.folder_rounded, 'Files'),
  NavDest(Icons.sticky_note_2_rounded, 'Notes'),
  NavDest(Icons.groups_rounded, 'Groups'),
  NavDest(Icons.timer_rounded, 'Focus'),
  NavDest(Icons.settings_rounded, 'Settings'),
];

/// Lets any screen switch tabs, e.g. the dashboard's quick tiles.
class HomeNavigation extends InheritedWidget {
  final ValueChanged<int> goTo;
  const HomeNavigation({super.key, required this.goTo, required super.child});

  static void of(BuildContext context, int page) =>
      context.getInheritedWidgetOfExactType<HomeNavigation>()?.goTo(page);

  @override
  bool updateShouldNotify(HomeNavigation oldWidget) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<int> _navOrder = navOrderFrom(null);
  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _homeWidgetSubscription;

  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  late final List<Widget> _pages = [
    DashboardTab(onSeeAllClicked: () => _onItemTapped(AppPage.schedule)),
    const ScheduleTab(),
    const AcademicTab(),
    const TodoBoardTab(),
    const BusTab(),
    const ResourcesTab(),
    const NotesScreen(),
    const GroupsScreen(),
    const FocusScreen(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _navOrder = navOrderFrom(prefs.getStringList(_navOrderKey)));
    });
    if (_isMobile) {
      _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        if (value.isNotEmpty) _handleSharedFiles(value);
      }, onError: (err) => debugPrint("getIntentDataStream error: $err"));

      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) {
          _handleSharedFiles(value);
          ReceiveSharingIntent.instance.reset();
        }
      });

      HomeWidget.initiallyLaunchedFromHomeWidget().then(_loadFromWidget);
      _homeWidgetSubscription = HomeWidget.widgetClicked.listen(_loadFromWidget);
    }
  }

  void _loadFromWidget(Uri? uri) {
    if (uri == null || uri.scheme != 'uomper' || !mounted) return;
    switch (uri.host) {
      case 'schedule':
        setState(() => _selectedIndex = AppPage.schedule);
      case 'tasks':
        setState(() => _selectedIndex = AppPage.board);
      case 'bus':
        setState(() => _selectedIndex = AppPage.bus);
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _homeWidgetSubscription?.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (!mounted) return;
    setState(() => _selectedIndex = AppPage.files);
    _showSortDialog(files.first);
  }

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  void _showSortDialog(SharedMediaFile file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final timetable = Provider.of<TimetableProvider>(context, listen: false);
        final resourceProv = Provider.of<ResourceProvider>(context, listen: false);
        final modules = {...timetable.userSessions.map((s) => s.subject), ...resourceProv.customFolders}.toList()..sort();

        return SheetScaffold(
          title: 'Save shared file',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fileName(file.path), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 18),
                const Text("Which folder is this for?", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...modules.map((m) => ActionChip(
                          label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(m, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          onPressed: () {
                            Navigator.pop(context);
                            _showCategoryDialog(file, m, resourceProv);
                          },
                        )),
                    ActionChip(
                      label: const Text("Unsorted (later)", style: TextStyle(color: Colors.redAccent)),
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      onPressed: () {
                        Navigator.pop(context);
                        resourceProv.addResource(
                          sourceFilePath: file.path,
                          fileName: _fileName(file.path),
                          moduleName: 'Unsorted',
                          category: 'Unsorted',
                          sourceApp: 'whatsapp',
                        );
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Saved to Inbox")));
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryDialog(SharedMediaFile file, String moduleName, ResourceProvider resourceProv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final sections = resourceProv.sectionsFor(moduleName);
        return SheetScaffold(
          title: moduleName,
          child: ListView(
            shrinkWrap: true,
            children: sections
                .map((c) => ListTile(
                      title: Text(c),
                      leading: const Icon(Icons.folder_open_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        resourceProv.addResource(
                          sourceFilePath: file.path,
                          fileName: _fileName(file.path),
                          moduleName: moduleName,
                          category: c,
                          sourceApp: 'whatsapp',
                        );
                        ScaffoldMessenger.of(this.context)
                            .showSnackBar(SnackBar(content: Text("Saved to $moduleName / $c")));
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  List<int> get _barPages => _navOrder.take(AppPage.barSlots).toList();

  void _showMoreSheet() {
    final p = Palette.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: 'More',
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _editBar();
            },
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Edit bar'),
          ),
        ],
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            for (final i in _navOrder.skip(AppPage.barSlots))
              SoftCard(
                color: i == _selectedIndex ? p.ink : p.surfaceAlt,
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.pop(ctx);
                  _onItemTapped(i);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(_destinations[i].icon, color: i == _selectedIndex ? p.onInk : p.textPrimary),
                    Text(_destinations[i].label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16, color: i == _selectedIndex ? p.onInk : p.textPrimary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Drag pages into the top five to put them in the bar; the rest live
  /// under More.
  void _editBar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final p = Palette.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SheetScaffold(
            title: 'Edit bar',
            actions: [
              TextButton(
                onPressed: () => setSheet(() => _setNavOrder(navOrderFrom(null))),
                child: const Text('Reset'),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Drag ☰ to reorder. The top ${AppPage.barSlots} sit in the bar, the rest under More.',
                    style: TextStyle(color: p.textSecondary)),
                const SizedBox(height: 10),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    onReorder: (from, to) => setSheet(() {
                      final list = [..._navOrder];
                      final item = list.removeAt(from);
                      list.insert(to > from ? to - 1 : to, item);
                      _setNavOrder(list);
                    }),
                    children: [
                      for (var i = 0; i < _navOrder.length; i++)
                        Padding(
                          key: ValueKey(_navOrder[i]),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: i < AppPage.barSlots ? p.accentSoft : p.surfaceAlt,
                            borderRadius: BorderRadius.circular(22),
                            // Long-press anywhere, or drag the handle straight away.
                            child: ReorderableDelayedDragStartListener(
                              index: i,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(_destinations[_navOrder[i]].icon, color: p.textPrimary),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(_destinations[_navOrder[i]].label,
                                        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                                  ),
                                  Text(i < AppPage.barSlots ? 'Bar' : 'More',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary)),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Icon(Icons.drag_handle_rounded, color: p.textSecondary),
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
              ],
            ),
          ),
        );
      }),
    );
  }

  void _setNavOrder(List<int> order) {
    setState(() => _navOrder = order);
    SharedPreferences.getInstance().then((prefs) => prefs.setStringList(_navOrderKey, [for (final i in order) '$i']));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = MediaQuery.of(context).size.width > 800;
    final bar = _barPages;
    final slot = bar.indexOf(_selectedIndex);

    final body = IndexedStack(index: _selectedIndex, children: _pages);

    return HomeNavigation(
      goTo: _onItemTapped,
      child: Scaffold(
        backgroundColor: p.canvas,
        // Each tab has its own Scaffold that already makes room for the
        // keyboard; resizing here too made screens jump and left fields
        // hidden behind the keyboard.
        resizeToAvoidBottomInset: false,
        body: wide
            ? Row(
                children: [
                  // A rotated phone is "wide" but only ~360px tall: 10 rail
                  // items don't fit, so the rail scrolls instead of overflowing.
                  LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: _onItemTapped,
                            extended: MediaQuery.of(context).size.width > 1100,
                            backgroundColor: p.surface,
                            indicatorColor: p.ink,
                            selectedIconTheme: IconThemeData(color: p.onInk),
                            unselectedIconTheme: IconThemeData(color: p.textSecondary),
                            selectedLabelTextStyle: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700),
                            unselectedLabelTextStyle: TextStyle(color: p.textSecondary),
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: CircleAvatar(backgroundColor: p.ink, child: Icon(Icons.school_rounded, color: p.onInk)),
                            ),
                            destinations: [
                              for (final d in _destinations) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        // Hide the nav while typing so it doesn't sit on top of the keyboard.
        bottomNavigationBar: wide || MediaQuery.of(context).viewInsets.bottom > 0
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: PillNavBar(
                    items: [
                      for (final i in bar) _destinations[i],
                      slot == -1 ? _destinations[_selectedIndex] : const NavDest(Icons.more_horiz_rounded, 'More'),
                    ],
                    selected: slot == -1 ? bar.length : slot,
                    onTap: (s) => s == bar.length ? _showMoreSheet() : _onItemTapped(bar[s]),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The design's floating nav: a tray of round icon buttons where the active
/// one expands into a black pill with its label. Sizes adapt to the width so
/// it never overflows on narrow phones.
class PillNavBar extends StatelessWidget {
  final List<NavDest> items;
  final int selected;
  final ValueChanged<int> onTap;
  const PillNavBar({super.key, required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      const pad = 5.0, gap = 5.0;
      final n = items.length;
      final inner = c.maxWidth - pad * 2 - gap * (n - 1);
      final circle = ((inner - 104) / (n - 1)).clamp(34.0, 50.0);
      final active = (inner - circle * (n - 1)).clamp(circle, 132.0);
      final showLabel = active >= circle + 44;

      return Container(
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: p.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E8EC),
          borderRadius: BorderRadius.circular(60),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < n; i++)
              Semantics(
                button: true,
                selected: i == selected,
                label: items[i].label,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: i == selected ? active : circle,
                    height: circle,
                    decoration: BoxDecoration(
                      color: i == selected ? p.ink : p.surface,
                      borderRadius: BorderRadius.circular(circle),
                    ),
                    child: ClipRect(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[i].icon, size: circle * 0.44, color: i == selected ? p.onInk : p.textPrimary),
                          if (i == selected && showLabel) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(items[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  style: TextStyle(color: p.onInk, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
