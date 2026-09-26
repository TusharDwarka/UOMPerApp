import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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

/// Page indices. Mobile shows the first five in the pill bar plus "More".
class AppPage {
  static const home = 0, schedule = 1, hub = 2, board = 3, bus = 4, files = 5, notes = 6, groups = 7, focus = 8, settings = 9;
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

  void _showMoreSheet() {
    final p = Palette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: 'More',
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.9,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final i in [AppPage.files, AppPage.notes, AppPage.groups, AppPage.focus, AppPage.settings])
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

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = MediaQuery.of(context).size.width > 800;

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
                  NavigationRail(
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
                      for (var i = 0; i < 5; i++) _destinations[i],
                      _selectedIndex >= 5 ? _destinations[_selectedIndex] : const NavDest(Icons.more_horiz_rounded, 'More'),
                    ],
                    selected: _selectedIndex >= 5 ? 5 : _selectedIndex,
                    onTap: (slot) => slot == 5 ? _showMoreSheet() : _onItemTapped(slot),
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
