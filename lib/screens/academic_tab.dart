import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar_community/isar.dart'; // Ensure correct import
import 'package:intl/intl.dart';
import '../services/isar_service.dart';
import '../models/class_session.dart'; // We can reuse this or create a new Task model
// For now, let's create a simple Task model inside this file or strictly for Isar?
// Let's use a local class for UI and maybe specific isar collection later if needed.
// Actually user asked for "Tasks and Reminders".
// Let's assume we use a new "AcademicTask" model. 

class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Mock events for now, or linked to Isar if we had a Task model
  final Map<DateTime, List<String>> _events = {}; 
  // e.g. DateTime(2023,10,12) -> ["Assignment 1 Due", "Quiz"]

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<String> _getEventsForDay(DateTime day) {
    // Basic normalization to strip time? TableCalendar usually handles utc/local
    // simple lookup
    return _events.entries
        .where((e) => isSameDay(e.key, day))
        .expand((e) => e.value)
        .toList();
  }
  
  void _addEvent(String title) {
    if (_selectedDay != null) {
      final key = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      if (_events[key] == null) {
        _events[key] = []; // Use standard list
      }
      setState(() {
        _events[key]!.add(title);
      });
    }
  }

  void _showAddEventDialog() {
    String newEvent = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Academic Task"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Assignment / Exam / Reminder"),
          onChanged: (v) => newEvent = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (newEvent.isNotEmpty) {
                _addEvent(newEvent);
                Navigator.pop(context);
              }
            }, 
            child: const Text("Add")
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Academic Calendar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
           IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: Colors.black))
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              // markers
              markerDecoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.indigo.withOpacity(0.5), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50], 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
              ),
              child: selectedEvents.isEmpty 
                ? Center(child: Text("No tasks for today", style: TextStyle(color: Colors.grey[400])))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 25),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ] 
                        ),
                        child: Row(
                          children: [
                            Container(width: 4, height: 40, color: Colors.indigoAccent),
                            const SizedBox(width: 15),
                            Expanded(child: Text(selectedEvents[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            const Icon(Icons.check_circle_outline, color: Colors.grey)
                          ],
                        ),
                      );
                    },
                  ),
            ),
          )
        ],
      ),
    );
  }
}
