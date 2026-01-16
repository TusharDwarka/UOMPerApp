import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/class_session.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key});

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }

  List<ClassSession> _getEventsForDay(DateTime day, List<ClassSession> allSessions) {
    // Convert DateTime day to string (e.g., "Monday")
    final dayName = DateFormat('EEEE').format(day);
    
    // Filter recurring sessions for this weekday
    return allSessions.where((s) => s.day == dayName).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _showAddSessionDialog() {
    final formKey = GlobalKey<FormState>();
    String subject = '';
    String room = '';
    String startTime = "09:00";
    String endTime = "10:30";
    // Default to selected day name
    String selectedDayName = DateFormat('EEEE').format(_selectedDay ?? DateTime.now());
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Add New Class", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Subject / Module",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.book_outlined),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => subject = v!,
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Room / Location",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                onSaved: (v) => room = v ?? '',
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: days.contains(selectedDayName) ? selectedDayName : 'Monday',
                decoration: InputDecoration(labelText: "Day", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => selectedDayName = v!,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: startTime,
                      decoration: const InputDecoration(labelText: "Start (HH:MM)", border: OutlineInputBorder()),
                      onSaved: (v) => startTime = v!,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: endTime,
                      decoration: const InputDecoration(labelText: "End (HH:MM)", border: OutlineInputBorder()),
                      onSaved: (v) => endTime = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final newSession = ClassSession(
                        subject: subject,
                        room: room,
                        day: selectedDayName,
                        startTime: startTime,
                        endTime: endTime,
                        isUser: true,
                      );
                      Provider.of<TimetableProvider>(context, listen: false).addSession(newSession);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Save Class"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.blue),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSessionDialog,
        backgroundColor: const Color(0xFF2962FF),
        icon: const Icon(Icons.add),
        label: const Text("Add Class"),
      ),
      body: Consumer<TimetableProvider>(
        builder: (context, timetable, _) {
          final events = _getEventsForDay(_selectedDay ?? DateTime.now(), timetable.userSessions);
          
          return Column(
            children: [
              _buildCalendar(),
              const Divider(height: 1),
              Expanded(
                child: events.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _buildClassCard(events[index]);
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
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
      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Color(0xFF90CAF9), shape: BoxShape.circle),
        markerDecoration: BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
      ),
    );
  }

  Widget _buildClassCard(ClassSession session) {
    // Generate color from subject hash for consistency
    final color = [
       const Color(0xFFE3F2FD), // Blue
       const Color(0xFFF3E5F5), // Purple
       const Color(0xFFE8F5E9), // Green
       const Color(0xFFFFF3E0), // Orange
    ][session.subject.hashCode.abs() % 4];

    final accentColor = [
       const Color(0xFF1565C0),
       const Color(0xFF7B1FA2),
       const Color(0xFF2E7D32),
       const Color(0xFFEF6C00),
    ][session.subject.hashCode.abs() % 4];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(session.startTime, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
                Container(height: 1, width: 20, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 4)),
                Text(session.endTime, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.subject, 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: accentColor.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(session.room, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text(
            "No classes on this day", 
            style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 10),
          TextButton.icon(
             onPressed: _showAddSessionDialog,
             icon: const Icon(Icons.add),
             label: const Text("Add a class"),
          )
        ],
      ),
    );
  }
}
