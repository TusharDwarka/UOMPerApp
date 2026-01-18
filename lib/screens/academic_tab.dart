import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../services/isar_service.dart';
import '../providers/timetable_provider.dart'; // Added

class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<AcademicTask> _allTasks = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final isarService = IsarService(); // Or get from Provider if set up
    final isar = await isarService.db;
    final tasks = await isar.academicTasks.where().findAll();
    setState(() {
      _allTasks = tasks;
    });
  }

  Future<void> _addTask(String title, String subject, String type, DateTime dueDate) async {
    final isarService = IsarService();
    final isar = await isarService.db;
    final newTask = AcademicTask(
      title: title,
      subject: subject,
      type: type,
      dueDate: dueDate,
      isCompleted: false
    );
    
    await isar.writeTxn(() async {
      await isar.academicTasks.put(newTask);
    });
    
    _loadTasks();
  }

  List<AcademicTask> _getEventsForDay(DateTime day) {
    return _allTasks.where((task) => isSameDay(task.dueDate, day)).toList();
  }

  // --- UI Components ---

  Future<void> _updateTask(int id, String title, String subject, String type, DateTime due) async {
    final isarService = IsarService();
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      final task = await isar.academicTasks.get(id);
      if (task != null) {
        task.title = title;
        task.subject = subject;
        task.type = type;
        task.dueDate = due;
        await isar.academicTasks.put(task);
      }
    });
    _loadTasks();
  }

  void _showAddEditTaskDialog({AcademicTask? taskToEdit}) {
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark; // Check theme
    final isEditing = taskToEdit != null;
    String title = taskToEdit?.title ?? '';
    String subject = taskToEdit?.subject ?? 'General';
    String type = taskToEdit?.type ?? 'Assignment';
    DateTime selectedDate = taskToEdit?.dueDate ?? _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = taskToEdit != null ? TimeOfDay.fromDateTime(taskToEdit.dueDate) : const TimeOfDay(hour: 23, minute: 59);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, // Dark bg
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
                  top: 30, left: 24, right: 24
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isEditing ? "Edit Task" : "Add Homework/Task", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          if (isEditing)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final isarService = IsarService();
                                final isar = await isarService.db;
                                await isar.writeTxn(() async => await isar.academicTasks.delete(taskToEdit!.id));
                                _loadTasks();
                                Navigator.pop(context);
                              },
                            )
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        initialValue: title,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: "Task Title",
                          labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                        onSaved: (v) => title = v!,
                        onChanged: (v) => title = v,
                      ),
                      const SizedBox(height: 15),
                      
                      TextFormField(
                        initialValue: subject,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: "Subject (e.g. Mobile Computing)",
                          labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                        onChanged: (v) => subject = v, 
                        onSaved: (v) => subject = v!,
                      ),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        value: type,
                        items: ["Assignment", "Exam", "Note", "Project"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
                        onChanged: (v) => setSheetState(() => type = v!),
                        dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        decoration: InputDecoration(
                          labelText: "Type",
                          labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Date/Time
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context, 
                                  initialDate: selectedDate, 
                                  firstDate: DateTime(2020), 
                                  lastDate: DateTime(2030),
                                  builder: (context, child) => Theme(
                                    data: isDark 
                                      ? ThemeData.dark().copyWith(
                                          colorScheme: const ColorScheme.dark(primary: Color(0xFF2962FF), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
                                          dialogBackgroundColor: const Color(0xFF1E1E1E)
                                        )
                                      : ThemeData.light(),
                                    child: child!,
                                  ),
                                );
                                if (d!=null) setSheetState(() => selectedDate = d);
                              }, 
                              icon: Icon(Icons.calendar_today, color: isDark ? Colors.blue[200] : const Color(0xFF2962FF)), 
                              label: Text(DateFormat('MMM dd').format(selectedDate), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF2962FF))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 12)
                              )
                            )
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context, 
                                  initialTime: selectedTime,
                                  builder: (context, child) => Theme(
                                    data: isDark 
                                      ? ThemeData.dark().copyWith(
                                          colorScheme: const ColorScheme.dark(primary: Color(0xFF2962FF), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
                                          timePickerTheme: const TimePickerThemeData(backgroundColor: Color(0xFF1E1E1E))
                                        )
                                      : ThemeData.light(),
                                    child: child!,
                                  ),
                                );
                                if (t!=null) setSheetState(() => selectedTime = t);
                              }, 
                              icon: Icon(Icons.access_time, color: isDark ? Colors.blue[200] : const Color(0xFF2962FF)), 
                              label: Text(selectedTime.format(context), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF2962FF))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 12)
                              )
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                              final dueDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                              if (isEditing) {
                                _updateTask(taskToEdit!.id, title, subject, type, dueDateTime);
                              } else {
                                _addTask(title, subject, type, dueDateTime);
                              }
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: Text(isEditing ? "Save Changes" : "Save Task"),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Academic Hub', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          bottom: TabBar(
            labelColor: const Color(0xFF2962FF),
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey,
            indicatorColor: const Color(0xFF2962FF),
            tabs: const [
              Tab(text: "Planner"),
              Tab(text: "Attendance Survival"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2962FF), size: 28),
              onPressed: () => _showAddEditTaskDialog(),
            )
          ],
        ),
        body: TabBarView(
          children: [
            _buildTaskPlanner(isDark),
            _buildAttendanceTracker(isDark),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceTracker(bool isDark) {
    return Consumer<TimetableProvider>(
      builder: (context, timetable, _) {
        final subjects = timetable.userSessions.map((s) => s.subject).toSet().toList();
        final todayClasses = timetable.getClassesForDate(DateTime.now());
        final todaySubjects = todayClasses.map((s) => s.subject).toSet().toList();

        // Global Stats
        final globalStats = timetable.getGlobalSurvivalStats();
        final int lives = globalStats['lives'];
        final int maxLives = globalStats['maxLives']; // 10
        final String status = globalStats['status'];

        if (subjects.isEmpty) {
          return Center(child: Text("No courses found. Check your schedule setup.", style: TextStyle(color: isDark ? Colors.grey : Colors.black)));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Global Survival Header ---
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: lives > 3 
                    ? [const Color(0xFF00C853), const Color(0xFF69F0AE)] 
                    : [const Color(0xFFD32F2F), const Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: (lives > 3 ? Colors.green : Colors.red).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
                ]
              ),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text("SEMESTER SURVIVAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                         child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                       )
                     ],
                   ),
                   const SizedBox(height: 20),
                   // Hearts Row
                   Wrap(
                     alignment: WrapAlignment.center,
                     spacing: 8,
                     runSpacing: 8,
                     children: List.generate(maxLives, (index) {
                        if (index < lives) {
                          return const Icon(Icons.favorite, color: Colors.white, size: 28);
                        } else {
                          return Icon(Icons.favorite_border, color: Colors.white.withOpacity(0.5), size: 28);
                        }
                     }),
                   ),
                   const SizedBox(height: 16),
                   Text("$lives Lives Remaining", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   const Text("Don't let it hit zero.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            // --- Section 1: Today's Roll Call ---
            if (todaySubjects.isNotEmpty) ...[
               Text("Today's Roll Call", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E2C))),
               const SizedBox(height: 12),
               ...todaySubjects.map((subject) {
                  final record = timetable.getAttendanceRecord(subject, DateTime.now());
                  final hasRecord = record != null;
                  final isPresent = record?.isPresent ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(
                        hasRecord ? (isPresent ? "Marked Present" : "Marked Absent") : "Are you in class?", 
                        style: TextStyle(color: hasRecord ? (isPresent ? Colors.green : Colors.red) : Colors.amber[700])
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check_circle, color: (hasRecord && isPresent) ? Colors.green : (isDark ? Colors.grey[700] : Colors.grey[300])),
                            iconSize: 32,
                            onPressed: () => timetable.setAttendance(subject, DateTime.now(), true),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel, color: (hasRecord && !isPresent) ? Colors.red : (isDark ? Colors.grey[700] : Colors.grey[300])),
                            iconSize: 32,
                            onPressed: () => timetable.setAttendance(subject, DateTime.now(), false),
                          ),
                        ],
                      ),
                    ),
                  );
               }),
               const SizedBox(height: 24),
            ],

            // --- Section 2: Subject Details ---
            Text("Attendance Log", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E2C))),
            const SizedBox(height: 12),
            
            ...subjects.map((subject) {
               final subjectStats = timetable.getSubjectStats(subject);
               final int absences = subjectStats['absences'];
               
               return Card(
                 elevation: 0,
                 color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                 margin: const EdgeInsets.only(bottom: 12),
                 child: Theme(
                   data: Theme.of(context).copyWith(dividerColor: Colors.transparent, colorScheme: isDark ? const ColorScheme.dark() : const ColorScheme.light()),
                   child: ExpansionTile(
                     collapsedIconColor: isDark ? Colors.grey : Colors.grey[600],
                     title: Text(subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                     subtitle: Text("$absences Missed Classes", style: TextStyle(color: absences > 0 ? Colors.redAccent : Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                     children: [
                       Divider(color: isDark ? Colors.white10 : Colors.grey[100]),
                       Padding(
                         padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             ...timetable.getPastClassDates(subject).map((date) {
                                final r = timetable.getAttendanceRecord(subject, date);
                                final isPresent = r?.isPresent ?? false;
                                final hasRecord = r != null;
                                
                                return InkWell(
                                  onTap: () => timetable.setAttendance(subject, date, !isPresent),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[100]!))
                                    ),
                                    child: Row(
                                      children: [
                                        Text(DateFormat('MMM d').format(date), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                                        const SizedBox(width: 8),
                                        Text(DateFormat('EEE').format(date), style: TextStyle(color: isDark ? Colors.grey : Colors.grey[500], fontSize: 12)),
                                        const Spacer(),
                                        if (!hasRecord) 
                                           Text("Unknown", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[400], fontSize: 12))
                                        else 
                                           Icon(isPresent ? Icons.check_circle_outline : Icons.highlight_off, color: isPresent ? Colors.green : Colors.red, size: 20)
                                      ],
                                    ),
                                  ),
                                );
                             }).toList(),
                              if (timetable.getPastClassDates(subject).isEmpty)
                                const Padding(padding: EdgeInsets.all(12), child: Text("No past classes.", style: TextStyle(color: Colors.grey)))
                           ],
                         ),
                       )
                     ],
                   ),
                 ),
               );
            }),
            
            const SizedBox(height: 30),
            Center(
              child: TextButton.icon(
                onPressed: () {
                   showDialog(context: context, builder: (c) => AlertDialog(
                     title: const Text("Reset Survival Mode?"),
                     content: const Text("This will clear all attendance records and restore your 10 lives. This cannot be undone."),
                     actions: [
                       TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                       TextButton(
                         onPressed: () {
                           timetable.resetAttendance();
                           Navigator.pop(c);
                         }, 
                         child: const Text("Reset All", style: TextStyle(color: Colors.red))
                       )
                     ],
                   ));
                },
                icon: const Icon(Icons.refresh, color: Colors.grey),
                label: const Text("Reset All Progress", style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      }
    );
  }

  Widget _buildTaskPlanner(bool isDark) {
    // Filter tasks for "Today's Priorities" (if selected date is today) or just show selected day tasks
    final selectedTasks = _getEventsForDay(_selectedDay ?? DateTime.now());
    
    // Calculate priorities: Tasks due in next 3 days?
    final priorityTasks = _allTasks.where((t) {
      final diff = t.dueDate.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 3 && !t.isCompleted;
    }).toList();
    
    return ListView( // Changed to ListView to allow scrolling whole page
        children: [
          // 1. Calendar View
          TableCalendar<AcademicTask>(
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
             if (_calendarFormat != format) setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
              weekendTextStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              outsideTextStyle: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400]),
              markerDecoration: const BoxDecoration(color: Color(0xFFFF1744), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: const Color(0xFF2962FF).withOpacity(0.5), shape: BoxShape.circle),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false, 
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black),
              rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 2. Selected Day Tasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isSameDay(_selectedDay, DateTime.now()) ? "Today's Priorities" : "Tasks for ${DateFormat('MMM d').format(_selectedDay!)}", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
            ),
          ),
          const SizedBox(height: 10),
          
          if (selectedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text("No tasks due this day.", style: TextStyle(color: Colors.grey[400]))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: selectedTasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(selectedTasks[index], isDark);
              },
            ),
              
            // 3. Upcoming / Priority Section (if displaying today)
             if (isSameDay(_selectedDay, DateTime.now()) && priorityTasks.isNotEmpty) ...[
               const SizedBox(height: 20),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: Text("Upcoming Deadlines (Next 3 Days)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.indigoAccent : Colors.indigo)),
               ),
               const SizedBox(height: 10),
               // Horizontal list of urgent cards
               SizedBox(
                 height: 130,
                 child: ListView.builder(
                   scrollDirection: Axis.horizontal,
                   padding: const EdgeInsets.symmetric(horizontal: 20),
                   itemCount: priorityTasks.length,
                   itemBuilder: (context, index) {
                     final t = priorityTasks[index];
                     return Container(
                       width: 160,
                       margin: const EdgeInsets.only(right: 15),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF448AFF)]),
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                            BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                         ]
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(t.type.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                           Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                           Row(
                             children: [
                               const Icon(Icons.access_time, color: Colors.white70, size: 12),
                               const SizedBox(width: 4),
                               Text(DateFormat('MMM d').format(t.dueDate), style: const TextStyle(color: Colors.white, fontSize: 12))
                             ],
                           )
                         ],
                       ),
                     );
                   },
                 ),
               ),
                const SizedBox(height: 30),
              ]
           ],
    );
  }

  Widget _buildTaskCard(AcademicTask task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: _getTypeColor(task.type).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
             child: Icon(
               _getTypeIcon(task.type), 
               color: _getTypeColor(task.type)
             ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                Text("${task.subject} • ${DateFormat('HH:mm').format(task.dueDate)}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Checkbox(
            value: task.isCompleted, 
            activeColor: const Color(0xFF2962FF),
            side: BorderSide(color: isDark ? Colors.grey : Colors.black54),
            onChanged: (val) async {
               // Update
               final isarService = IsarService();
               final isar = await isarService.db;
               task.isCompleted = val!;
               await isar.writeTxn(() async => await isar.academicTasks.put(task));
               _loadTasks();
            }
          )
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Exam': return Colors.red;
      case 'Assignment': return Colors.orange;
      case 'Project': return Colors.purple;
      case 'Note': return Colors.green;
      default: return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Exam': return Icons.warning_amber_rounded;
      case 'Assignment': return Icons.assignment_outlined;
      case 'Project': return Icons.rocket_launch_outlined;
      case 'Note': return Icons.sticky_note_2_outlined;
      default: return Icons.task_alt;
    }
  }
}
