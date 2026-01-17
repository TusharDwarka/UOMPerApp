import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'schedule_tab.dart';
import 'academic_tab.dart';
import 'bus_tab.dart';
import 'todo_board_tab.dart';
import 'notes_tab.dart';

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
    NotesTab(), // New Notes Tab
    BusTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium bottom bar colors
    const activeColor = Color(0xFF0066FF);
    const inactiveColor = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
          backgroundColor: Colors.transparent, // Handled by Container
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
              icon: Icon(Icons.edit_note_rounded), // Notes Icon
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_filled_rounded),
              label: 'Transport',
            ),
          ],
        ),
      ),
    );
  }
}
