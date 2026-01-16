import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/class_session.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _selectedDate = DateTime.now();
  final double _hourHeight = 80.0;
  final double _timeColumnWidth = 60.0;
  final int _startHour = 7; // 07:00
  final int _endHour = 18;  // 18:00

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }

  // Helper: Get sessions for the selected day
  List<ClassSession> _getEventsForDay(DateTime day, List<ClassSession> allSessions) {
    final dayName = DateFormat('EEEE').format(day);
    return allSessions.where((s) => s.day == dayName).toList();
  }

  // Show "Add Class" Bottom Sheet
  void _showAddSessionDialog({ClassSession? sessionToEdit}) {
    final formKey = GlobalKey<FormState>();
    final isEditing = sessionToEdit != null;
    
    String subject = sessionToEdit?.subject ?? '';
    String room = sessionToEdit?.room ?? '';
    String startTime = sessionToEdit?.startTime ?? "09:00";
    String endTime = sessionToEdit?.endTime ?? "10:30";
    // If editing, use existing session day, else use selected date
    String selectedDayName = isEditing 
        ? sessionToEdit!.day 
        : DateFormat('EEEE').format(_selectedDate);
        
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    // Ensure keyboard doesn't cover content
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
            top: 30, right: 24, left: 24),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? "Edit Task" : "Add New Task", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                           // Quick delete confirm
                           showDialog(
                             context: context, 
                             builder: (c) => AlertDialog(
                               title: const Text("Delete Task?"),
                               content: const Text("This cannot be undone."),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                                 TextButton(
                                   onPressed: () {
                                     Provider.of<TimetableProvider>(context, listen: false).deleteSession(sessionToEdit!.id);
                                     Navigator.pop(c); // Close Dialog
                                     Navigator.pop(context); // Close Sheet
                                   }, 
                                   child: const Text("Delete", style: TextStyle(color: Colors.red))
                                 ),
                               ],
                             )
                           );
                        },
                      )
                  ],
                ),
                const SizedBox(height: 30),
                
                // Subject Input
                TextFormField(
                  initialValue: subject,
                  decoration: InputDecoration(
                    labelText: "Title (e.g. Mobile Computing)",
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.bookmark_border_rounded, color: Colors.blue),
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                  onSaved: (v) => subject = v!,
                ),
                const SizedBox(height: 20),
                
                // Room Input
                TextFormField(
                  initialValue: room,
                  decoration: InputDecoration(
                    labelText: "Location / Room",
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.blue),
                  ),
                  onSaved: (v) => room = v ?? '',
                ),
                const SizedBox(height: 20),
                
                // Day Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      value: days.contains(selectedDayName) ? selectedDayName : 'Monday',
                      decoration: const InputDecoration(border: InputBorder.none, icon: Icon(Icons.calendar_today_outlined, color: Colors.blue)),
                      items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) => selectedDayName = v!,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Time Pickers
                Row(
                  children: [
                     Expanded(child: _buildTimeField("Start", startTime, (val) => startTime = val)),
                     const SizedBox(width: 16),
                     Expanded(child: _buildTimeField("End", endTime, (val) => endTime = val)),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        final session = ClassSession(
                          subject: subject,
                          room: room,
                          day: selectedDayName,
                          startTime: startTime,
                          endTime: endTime,
                          isUser: true,
                        );
                        
                        if (isEditing) {
                          session.id = sessionToEdit!.id; // Preserve ID for update
                          Provider.of<TimetableProvider>(context, listen: false).addSession(session);
                        } else {
                          Provider.of<TimetableProvider>(context, listen: false).addSession(session);
                        }
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(isEditing ? "Update Task" : "Create Task", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, String initialVal, Function(String) onSave) {
    return TextFormField(
      initialValue: initialVal,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        suffixText: "HH:MM",
      ),
      onSaved: (v) => onSave(v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Section
            _buildHeader(),
            
            // 2. Week Selector (Horizontal Strip)
            _buildWeekStrip(),
            
            Expanded(
              child: Consumer<TimetableProvider>(
                builder: (context, timetable, _) {
                  final events = _getEventsForDay(_selectedDate, timetable.userSessions);
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 3. Time Column
                        SizedBox(
                          width: _timeColumnWidth,
                          child: Column(
                            children: List.generate(_endHour - _startHour + 1, (index) {
                              final hour = _startHour + index;
                              return SizedBox(
                                height: _hourHeight,
                                child: Text(
                                  "${hour.toString().padLeft(2, '0')}:00",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }),
                          ),
                        ),
                        
                        // 4. Vertical Grid / Event Canvas
                        Expanded(
                          child: SizedBox(
                            height: (_endHour - _startHour + 1) * _hourHeight,
                            child: Stack(
                              children: [
                                // Horizontal Grid Lines
                                ...List.generate(_endHour - _startHour + 1, (index) {
                                  return Positioned(
                                    top: index * _hourHeight,
                                    left: 0, 
                                    right: 0,
                                    child: Divider(color: Colors.grey[100], height: 1),
                                  );
                                }),

                                // Events
                                ...events.map((event) => _buildEventBlock(event)).toList(),
                                
                                // Current Time Line (Red)
                                if (DateFormat('EEEE').format(DateTime.now()) == DateFormat('EEEE').format(_selectedDate))
                                   _buildCurrentTimeLine(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
              const SizedBox(height: 4),
              Text(DateFormat('MMMM d').format(_selectedDate), style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
            ],
          ),
          
          // Enhanced Touch Target Button
          InkWell(
            onTap: () => _showAddSessionDialog(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0066FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ]
              ),
              child: const Text("Add task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final now = DateTime.now();
    // Generate dates: 3 days back + 3 days forward to center today roughly or just next 7 days
    final weekDates = List.generate(7, (index) => now.add(Duration(days: index))); 

    return Container(
      padding: const EdgeInsets.only(left: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("This week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(width: 20),
              Text("Next week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: weekDates.map((date) {
                final isSelected = isSameDay(date, _selectedDate);
                final weekdayStr = DateFormat('E').format(date)[0]; 
                final dayNum = DateFormat('d').format(date);
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.only(right: 20),
                    padding: const EdgeInsets.all(12), // Touch area
                    decoration: isSelected 
                      ? BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12))
                      : null,
                    child: Column(
                      children: [
                        Text(weekdayStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[400])),
                        const SizedBox(height: 4),
                        Text(dayNum, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEventBlock(ClassSession event) {
    // Calculate Position
    final partsStart = event.startTime.split(':');
    final startMinutes = int.parse(partsStart[0]) * 60 + int.parse(partsStart[1]);
    final startOffset = startMinutes - (_startHour * 60);

    final partsEnd = event.endTime.split(':');
    final endMinutes = int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1]);
    final duration = endMinutes - startMinutes;

    final top = (startOffset / 60) * _hourHeight;
    final height = (duration / 60) * _hourHeight;

    // Hash Color
    final colorOption = event.subject.hashCode.abs() % 4;
    final colors = [
      const Color(0xFF69F0AE), // Green
      const Color(0xFFFFD180), // Orange
      const Color(0xFFEA80FC), // Purple
      const Color(0xFFFF5252), // Red
    ];
    final color = colors[colorOption];

    return Positioned(
      top: top,
      left: 10,
      right: 24,
      height: height - 4,
      child: GestureDetector(
        onTap: () => _showAddSessionDialog(sessionToEdit: event),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
            ]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.school, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(event.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(event.room, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.edit, color: Colors.white60, size: 16) // Edit Hint
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeLine() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final offset = nowMinutes - (_startHour * 60);
    
    if (offset < 0) return const SizedBox();

    final top = (offset / 60) * _hourHeight;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
           Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
           Expanded(child: Container(height: 1, color: Colors.red)),
        ],
      )
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
