import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'bus_tab.dart';
import 'timetable_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardTab(),
    TimetableTab(),
    Center(child: Text('Academic')),
    BusTab(), // Transport
    Center(child: Text('Notes')),
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
    const bgColor = Colors.white;

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
              icon: Icon(Icons.calendar_month_rounded),
              label: 'Timetable',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Academic',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_filled_rounded),
              label: 'Transport',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Notes',
            ),
          ],
        ),
      ),
    );
  }
}
