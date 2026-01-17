import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../services/isar_service.dart';

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
    final isEditing = taskToEdit != null;
    String title = taskToEdit?.title ?? '';
    String subject = taskToEdit?.subject ?? 'General';
    String type = taskToEdit?.type ?? 'Assignment';
    DateTime selectedDate = taskToEdit?.dueDate ?? _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = taskToEdit != null ? TimeOfDay.fromDateTime(taskToEdit.dueDate) : const TimeOfDay(hour: 23, minute: 59);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                          Text(isEditing ? "Edit Task" : "Add Homework/Task", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                        decoration: InputDecoration(
                          labelText: "Task Title",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                        onSaved: (v) => title = v!,
                        onChanged: (v) => title = v,
                      ),
                      const SizedBox(height: 15),
                      
                      TextFormField(
                        initialValue: subject,
                        decoration: InputDecoration(
                          labelText: "Subject (e.g. Mobile Computing)",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                        onChanged: (v) => subject = v, // update local var
                        onSaved: (v) => subject = v!,
                      ),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        value: type,
                        items: ["Assignment", "Exam", "Note", "Project"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setSheetState(() => type = v!),
                        decoration: InputDecoration(
                          labelText: "Type",
                          filled: true,
                          fillColor: Colors.grey[100],
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
                                final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (d!=null) setSheetState(() => selectedDate = d);
                              }, 
                              icon: const Icon(Icons.calendar_today), 
                              label: Text(DateFormat('MMM dd').format(selectedDate))
                            )
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(context: context, initialTime: selectedTime);
                                if (t!=null) setSheetState(() => selectedTime = t);
                              }, 
                              icon: const Icon(Icons.access_time), 
                              label: Text(selectedTime.format(context))
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
    // Filter tasks for "Today's Priorities" (if selected date is today) or just show selected day tasks
    final selectedTasks = _getEventsForDay(_selectedDay ?? DateTime.now());
    
    // Calculate priorities: Tasks due in next 3 days?
    final priorityTasks = _allTasks.where((t) {
      final diff = t.dueDate.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 3 && !t.isCompleted;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Academic Hub', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2962FF), size: 28),
            onPressed: () => _showAddEditTaskDialog(),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                markerDecoration: const BoxDecoration(color: Color(0xFFFF1744), shape: BoxShape.circle),
                selectedDecoration: const BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: const Color(0xFF2962FF).withOpacity(0.5), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
            
            const SizedBox(height: 20),
            
            // 2. Selected Day Tasks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isSameDay(_selectedDay, DateTime.now()) ? "Today's Priorities" : "Tasks for ${DateFormat('MMM d').format(_selectedDay!)}", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
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
                  final task = selectedTasks[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        // Type Indicator
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getTypeColor(task.type).withOpacity(0.1),
                            shape: BoxShape.circle
                          ),
                          child: Icon(_getTypeIcon(task.type), color: _getTypeColor(task.type), size: 20),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showAddEditTaskDialog(taskToEdit: task),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(task.subject, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        Checkbox(
                          value: task.isCompleted, 
                          activeColor: const Color(0xFF2962FF),
                          onChanged: (val) async {
                            final isarService = IsarService();
                            final isar = await isarService.db;
                            await isar.writeTxn(() async {
                              task.isCompleted = val!;
                              await isar.academicTasks.put(task);
                            });
                             _loadTasks();
                          }
                        )
                      ],
                    ),
                  );
                },
              ),
              
            // 3. Upcoming / Priority Section (if displaying today)
             if (isSameDay(_selectedDay, DateTime.now()) && priorityTasks.isNotEmpty) ...[
               const SizedBox(height: 20),
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 20),
                 child: Text("Upcoming Deadlines (Next 3 Days)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
