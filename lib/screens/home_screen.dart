import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'schedule_tab.dart';
import 'academic_tab.dart';
import 'bus_tab.dart';
import 'todo_board_tab.dart';
import 'notes_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardTab(),
    ScheduleTab(),
    AcademicTab(), 
    TodoBoardTab(),
    NotesTab(),
    BusTab(),
    SettingsTab(), // New Settings Tab
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
                     NavigationRailDestination(icon: Icon(Icons.edit_note_rounded), label: Text('Notes')),
                     NavigationRailDestination(icon: Icon(Icons.directions_bus_filled_rounded), label: Text('Transport')),
                     NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
                   ],
                 ),
                 // Vertical Divider
                 const VerticalDivider(thickness: 1, width: 1),
                 // Content
                 Expanded(
                   child: _pages[_selectedIndex]
                 ),
               ],
             );
          } else {
             // Mobile Version
             return _pages[_selectedIndex];
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
              icon: Icon(Icons.edit_note_rounded),
              label: 'Notes',
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
