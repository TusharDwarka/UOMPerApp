import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'schedule_tab.dart';
import 'academic_tab.dart';
import 'bus_tab.dart';
import 'todo_board_tab.dart';
import 'resources_tab.dart';
import 'settings_tab.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/note_provider.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late StreamSubscription _intentDataStreamSubscription;
  StreamSubscription? _homeWidgetSubscription;

  @override
  void initState() {
    super.initState();
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      }
    });

    // Handle home widget intents
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_loadFromWidget);
    _homeWidgetSubscription = HomeWidget.widgetClicked.listen(_loadFromWidget);

    // Initial Sync
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.pullFromCloud();
      
      // Reload providers after pulling
      if (mounted) {
         Provider.of<TimetableProvider>(context, listen: false).loadSessions();
         Provider.of<NoteProvider>(context, listen: false).loadNotes();
      }
    });
  }

  void _loadFromWidget(Uri? uri) {
    if (uri != null && uri.scheme == 'uomper') {
      if (uri.host == 'schedule') {
        if (mounted) setState(() => _selectedIndex = 1);
      } else if (uri.host == 'tasks') {
        if (mounted) setState(() => _selectedIndex = 3);
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _homeWidgetSubscription?.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    // We navigate to the Resources Tab (index 4) and trigger a dialog
    if (mounted) {
      setState(() => _selectedIndex = 4);
      _showSortDialog(files.first); // Handle single file for now
    }
  }

  void _showSortDialog(SharedMediaFile file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final timetable = Provider.of<TimetableProvider>(context, listen: false);
        final resourceProv = Provider.of<ResourceProvider>(context, listen: false);
        final modules = timetable.userSessions.map((s) => s.subject).toSet().toList();
        modules.sort();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Save Shared File", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("File: ${file.path.split('/').last}", maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              const Text("Which module is this for?", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...modules.map((m) => ActionChip(
                    label: Container(constraints: const BoxConstraints(maxWidth: 150), child: Text(m, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCategoryDialog(file, m, resourceProv);
                    },
                  )),
                  ActionChip(
                    label: const Text("Unsorted (Later)", style: TextStyle(color: Colors.redAccent)),
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    onPressed: () {
                      Navigator.pop(context);
                      resourceProv.addResource(
                        sourceFilePath: file.path, 
                        fileName: file.path.split('/').last, 
                        moduleName: 'Unsorted', 
                        category: 'Unsorted',
                        sourceApp: 'whatsapp'
                      );
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Inbox")));
                    },
                  )
                ],
              )
            ],
          ),
        );
      }
    );
  }

  void _showCategoryDialog(SharedMediaFile file, String moduleName, ResourceProvider resourceProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final categories = ['Lectures', 'Tutorials', 'Past Papers', 'Assignments', 'General', 'Module Catalogue'];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Category for $moduleName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...categories.map((c) => ListTile(
                title: Text(c),
                leading: const Icon(Icons.folder_open),
                onTap: () {
                  Navigator.pop(context);
                  resourceProv.addResource(
                    sourceFilePath: file.path, 
                    fileName: file.path.split('/').last, 
                    moduleName: moduleName, 
                    category: c,
                    sourceApp: 'whatsapp'
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to $moduleName / $c")));
                },
              ))
            ],
          ),
        );
      }
    );
  }

  List<Widget> get _pages => <Widget>[
    DashboardTab(onSeeAllClicked: () => _onItemTapped(1)),
    const ScheduleTab(),
    const AcademicTab(), 
    const TodoBoardTab(),
    const ResourcesTab(),
    const BusTab(),
    const SettingsTab(), // New Settings Tab
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium Vibrant Colors - Adapted
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF0066FF);
    final inactiveColor = isDark ? Colors.grey[400] : const Color(0xFF9E9E9E);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Adaptive Body using LayoutBuilder
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
             // PC / Tablet Version (Side Navigation)
             return Row(
               children: [
                 NavigationRail(
                   selectedIndex: _selectedIndex,
                   onDestinationSelected: _onItemTapped,
                   extended: constraints.maxWidth > 1100, // Show labels on very wide screens
                   backgroundColor: Theme.of(context).cardColor,
                   unselectedIconTheme: IconThemeData(color: inactiveColor),
                   selectedIconTheme: IconThemeData(color: activeColor),
                   selectedLabelTextStyle: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
                   unselectedLabelTextStyle: TextStyle(color: inactiveColor),
                   destinations: const [
                     NavigationRailDestination(icon: Icon(Icons.grid_view_rounded), label: Text('Dashboard')),
                     NavigationRailDestination(icon: Icon(Icons.calendar_view_week_rounded), label: Text('Schedule')),
                     NavigationRailDestination(icon: Icon(Icons.calendar_month_rounded), label: Text('Calendar')),
                     NavigationRailDestination(icon: Icon(Icons.assignment_turned_in_rounded), label: Text('Board')),
                     NavigationRailDestination(icon: Icon(Icons.folder_rounded), label: Text('Resources')),
                     NavigationRailDestination(icon: Icon(Icons.directions_bus_filled_rounded), label: Text('Transport')),
                     NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
                   ],
                 ),
                 // Vertical Divider
                 const VerticalDivider(thickness: 1, width: 1),
                 // Content
                 Expanded(
                   child: IndexedStack(
                     index: _selectedIndex,
                     children: _pages,
                   )
                 ),
               ],
             );
          } else {
             // Mobile Version
             return IndexedStack(
               index: _selectedIndex,
               children: _pages,
             );
          }
        }
      ),
      // Bottom Bar ONLY for Mobile
      bottomNavigationBar: MediaQuery.of(context).size.width > 800 ? null : Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ]
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent, 
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: activeColor,
          unselectedItemColor: inactiveColor,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_week_rounded),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_turned_in_rounded),
              label: 'Board',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_rounded),
              label: 'Resources',
            ),
             BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_filled_rounded),
              label: 'Transport',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
