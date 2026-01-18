import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar_community/isar.dart'; // Still needed? Maybe not if fully passing via provider, but for checkbox update logic we might keep or delegate
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../services/isar_service.dart';
import '../providers/timetable_provider.dart';
import '../widgets/add_edit_task_sheet.dart'; 

class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // _allTasks removed. We use Consumer<TimetableProvider>.

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }
  
  // _addTask, _updateTask, _loadTasks removed.

  void _showAddEditTaskDialog({AcademicTask? taskToEdit}) {
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent, // Sheet controls its own bg
       builder: (context) => AddEditTaskSheet(taskToEdit: taskToEdit)
     );
  }
  
  // Helper for calendar
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timetable = Provider.of<TimetableProvider>(context);

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
            _buildTaskPlanner(isDark, timetable),
            _buildAttendanceTracker(isDark, timetable),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceTracker(bool isDark, TimetableProvider timetable) {
         final subjects = timetable.userSessions.map((s) => s.subject).toSet().toList();
         final todayClasses = timetable.getClassesForDate(DateTime.now());
         final todaySubjects = todayClasses.map((s) => s.subject).toSet().toList();

         if (subjects.isEmpty) {
           return Center(child: Text("No courses found. Check your schedule setup.", style: TextStyle(color: isDark ? Colors.grey : Colors.black)));
         }

         return ListView(
           padding: const EdgeInsets.all(20),
           children: [
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
             Text("Module Survival Tracking", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E2C))),
             const SizedBox(height: 12),
             
             ...subjects.map((subject) {
                final stats = timetable.getAttendanceStats(subject);
                final int lives = stats['lives'];
                final int maxLives = stats['maxLives'];
                // final int absences = stats['absences'];
                
                // Visual Hearts
                List<Widget> hearts = [];
                int heartsToShow = lives > 10 ? 10 : (lives < 0 ? 0 : lives);
                for(int i=0; i<maxLives; i++) {
                  if (i < heartsToShow) {
                    hearts.add(const Icon(Icons.favorite, color: Colors.pinkAccent, size: 16));
                  } else {
                    hearts.add(Icon(Icons.favorite_border, color: isDark ? Colors.white24 : Colors.grey[300], size: 16));
                  }
                }

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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Wrap(spacing: 4, runSpacing: 4, children: hearts),
                          const SizedBox(height: 6),
                          Text("$lives / $maxLives Lives Remaining", style: TextStyle(color: lives <= 2 ? Colors.red : (lives <= 5 ? Colors.orange : Colors.green), fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  Widget _buildTaskPlanner(bool isDark, TimetableProvider timetable) {
    
    // Use timetable.tasks instead of _allTasks
    final allTasks = timetable.tasks;

    final selectedTasks = allTasks.where((task) => isSameDay(task.dueDate, _selectedDay ?? DateTime.now())).toList();
    
    // Calculate priorities: Tasks due in next 3 days?
    final priorityTasks = allTasks.where((t) {
      final diff = t.dueDate.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 3 && !t.isCompleted;
    }).toList();
    
    return ListView( 
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
             eventLoader: (day) => allTasks.where((t) => isSameDay(t.dueDate, day)).toList(),
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
                return _buildTaskCard(selectedTasks[index], isDark, timetable);
              },
            ),
              
            // 3. Upcoming / Priority Section (Always visible if tasks exist)
             if (priorityTasks.isNotEmpty) ...[
               const SizedBox(height: 30),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: Text("Upcoming Priority (Next 3 Days)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.indigoAccent : Colors.indigo)),
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
                     return GestureDetector( // Tappable for edit
                       onTap: () => _showAddEditTaskDialog(taskToEdit: t),
                       child: Container(
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

  Widget _buildTaskCard(AcademicTask task, bool isDark, TimetableProvider timetable) {
    return GestureDetector( // Make tappable to edit
      onTap: () => _showAddEditTaskDialog(taskToEdit: task),
      child: Container(
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
              onChanged: (val) {
                 // Update via Provider
                 timetable.updateTask(task.id, task.title, task.subject, task.type, task.dueDate, val!);
              }
            )
          ],
        ),
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
