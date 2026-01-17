import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _selectedDate = DateTime.now();
  final double _hourHeight = 80.0;
  final double _timeColumnWidth = 60.0;
  final int _startHour = 6; // Started earlier to catch 7am classes comfortably
  final int _endHour = 19;  // Ended later

  // Cache DateFormats to avoid recreating them in loops
  final DateFormat _dayNameFormat = DateFormat('EEEE');
  final DateFormat _weekdayShortFormat = DateFormat('E');
  final DateFormat _dayNumFormat = DateFormat('d');
  final DateFormat _fullDateFormat = DateFormat('MMMM d, y');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }

  // Helper: Get sessions for the selected day
  List<ClassSession> _getEventsForDay(DateTime day, List<ClassSession> allSessions) {
    final dayName = _dayNameFormat.format(day);
    return allSessions.where((s) {
       if (s.specificDate != null) {
         return isSameDay(s.specificDate!, day);
       } else {
         return s.day == dayName;
       }
    }).toList();
  }

  // Show "Add Class" Bottom Sheet
  void _showAddSessionDialog({ClassSession? sessionToEdit}) {
    final formKey = GlobalKey<FormState>();
    final isEditing = sessionToEdit != null;
    
    String subject = sessionToEdit?.subject ?? '';
    String room = sessionToEdit?.room ?? '';
    String startTime = sessionToEdit?.startTime ?? "09:00";
    String endTime = sessionToEdit?.endTime ?? "10:30";
    String selectedDayName = isEditing 
        ? sessionToEdit!.day 
        : _dayNameFormat.format(_selectedDate);
        
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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
                                     Navigator.pop(c);
                                     Navigator.pop(context);
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
                TextFormField(
                  initialValue: subject,
                  decoration: InputDecoration(
                    labelText: "Title",
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.bookmark_border_rounded, color: Colors.blue),
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                  onSaved: (v) => subject = v!,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: room,
                  decoration: InputDecoration(
                    labelText: "Location",
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.blue),
                  ),
                  onSaved: (v) => room = v ?? '',
                ),
                const SizedBox(height: 20),
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
                Row(
                  children: [
                     Expanded(child: _buildTimeField("Start", startTime, (val) => startTime = val)),
                     const SizedBox(width: 16),
                     Expanded(child: _buildTimeField("End", endTime, (val) => endTime = val)),
                  ],
                ),
                const SizedBox(height: 40),
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
                          session.id = sessionToEdit!.id;
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
    // Replaced Scaffold body with resizeToAvoidBottomInset: false to prevent layout thrashing (lag) when keyboard opens.
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // CRITICAL FIX for keyboard lag
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWeekStrip(),
            Expanded(
              child: Consumer<TimetableProvider>(
                builder: (context, timetable, _) {
                  final events = _getEventsForDay(_selectedDate, timetable.userSessions);
                  // Pre-filter tasks to avoid doing it inside the rendering loop if possible, though strict date check is fast
                  final relevantTasks = timetable.tasks.where((t) => isSameDay(t.dueDate, _selectedDate)).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    physics: const BouncingScrollPhysics(), // Smoother scroll on Android
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Expanded(
                          child: SizedBox(
                            height: (_endHour - _startHour + 1) * _hourHeight,
                            child: Stack(
                              children: [
                                ...List.generate(_endHour - _startHour + 1, (index) {
                                  return Positioned(
                                    top: index * _hourHeight,
                                    left: 0, 
                                    right: 0,
                                    child: Divider(color: Colors.grey[100], height: 1),
                                  );
                                }),
                                ...events.map((event) => _buildEventBlock(event)).toList(),
                                ...relevantTasks.map((task) => _buildTaskBlock(task)).toList(),
                                if (isSameDay(DateTime.now(), _selectedDate))
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
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(primaryColor: const Color(0xFF0066FF)),
                      child: child!,
                    ),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Row(
                  children: [
                    Text(_fullDateFormat.format(_selectedDate), style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                    const SizedBox(width: 5),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[400])
                  ],
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => _showAddSessionDialog(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x330066FF), blurRadius: 4, offset: Offset(0, 2))] // Optimized shadow
              ),
              child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final now = DateTime.now();
    // Optimize: Create only necessary dates
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
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: weekDates.map((date) {
                final isSelected = isSameDay(date, _selectedDate);
                final weekdayStr = _weekdayShortFormat.format(date)[0]; 
                final dayNum = _dayNumFormat.format(date);
                
                return GestureDetector(
                  onTap: () {
                     if (!isSelected) { // Prevent useless rebuilds
                       setState(() => _selectedDate = date);
                     }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 20),
                    padding: const EdgeInsets.all(12), 
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

  Widget _buildTaskBlock(dynamic task) {
    final time = task.dueDate;
    final startMinutes = time.hour * 60 + time.minute;
    final startOffset = startMinutes - (_startHour * 60);
    final duration = 60; 

    if (startOffset < 0) return const SizedBox();

    final top = (startOffset / 60) * _hourHeight;
    final height = (duration / 60) * _hourHeight;

    return Positioned(
      top: top,
      left: 60,
      right: 24,
      height: height - 10,
      child: GestureDetector(
        onTap: () => _showTaskEditDialog(task),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.redAccent, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x1AFF5252), blurRadius: 4, offset: Offset(0, 2))]
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("DUE: ${task.title}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(task.subject, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskEditDialog(dynamic task) {
    final titleController = TextEditingController(text: task.title);
    final subjectController = TextEditingController(text: task.subject);
    DateTime dueDate = task.dueDate;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
             return Padding(
               padding: EdgeInsets.only(
                 bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
                 top: 24, left: 24, right: 24
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text("Edit Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 20),
                   TextField(
                     controller: titleController,
                     decoration: InputDecoration(
                        labelText: "Task Title",
                        filled: true, fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                     ),
                   ),
                   const SizedBox(height: 12),
                   TextField(
                     controller: subjectController,
                     decoration: InputDecoration(
                        labelText: "Subject / Module",
                        filled: true, fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                     ),
                   ),
                   const SizedBox(height: 12),
                   Row(
                     children: [
                       Expanded(
                         child: TextButton.icon(
                           onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (d != null) {
                                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dueDate));
                                if (t != null) {
                                  setModalState(() {
                                    dueDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                                  });
                                }
                              }
                           },
                           icon: const Icon(Icons.calendar_month),
                           label: Text(DateFormat('MMM d, HH:mm').format(dueDate)),
                           style: TextButton.styleFrom(
                             backgroundColor: Colors.blue[50],
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                           )
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 24),
                   Row(
                     children: [
                       Expanded(
                         child: OutlinedButton(
                           onPressed: () {
                             // Delete Logic
                             Provider.of<TimetableProvider>(context, listen: false).deleteTask(task.id);
                             Navigator.pop(context);
                           },
                           style: OutlinedButton.styleFrom(
                             foregroundColor: Colors.red,
                             side: const BorderSide(color: Colors.red),
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                           ),
                           child: const Text("Delete"),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: ElevatedButton(
                           onPressed: () {
                             // Save Logic
                             if (titleController.text.isNotEmpty) {
                               Provider.of<TimetableProvider>(context, listen: false).updateTask(
                                 task.id,
                                 titleController.text,
                                 subjectController.text,
                                 dueDate,
                                 task.isCompleted
                               );
                               Navigator.pop(context);
                             }
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF1565C0),
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             elevation: 0
                           ),
                           child: const Text("Save Changes"),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 10),
                 ],
               ),
             );
          }
        );
      }
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

    // soft pastel aesthetic
    final colorOption = event.subject.hashCode.abs() % 6;
    
    // Aesthetic Pairs (Background, Text/Accent)
    final styles = [
      (const Color(0xFFE3F2FD), const Color(0xFF1565C0)), // Blue
      (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)), // Purple
      (const Color(0xFFE0F2F1), const Color(0xFF00695C)), // Teal
      (const Color(0xFFFFF3E0), const Color(0xFFEF6C00)), // Orange
      (const Color(0xFFFFEBEE), const Color(0xFFC62828)), // Red
      (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)), // Green
    ];
    
    final style = styles[colorOption];
    final bgColor = style.$1;
    final accentColor = style.$2;
    final textColor = Colors.black87;

    return Positioned(
      top: top,
      left: 10,
      right: 24,
      height: height - 6, 
      child: GestureDetector(
        onTap: () => _showAddSessionDialog(sessionToEdit: event),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.15), width: 1),
            // Removed heavy shadow for performance
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical colored strip
              Container(
                width: 4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2)
                ),
              ),
              const SizedBox(width: 12),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (height > 50)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: textColor.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                              event.room,
                              maxLines: 1,
                              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6), fontWeight: FontWeight.normal),
                            )),
                          ],
                        ),
                      )
                  ],
                ),
              ),
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
