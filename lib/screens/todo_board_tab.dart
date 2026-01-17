import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic_task.dart';
import '../services/isar_service.dart';
import 'package:isar_community/isar.dart';

class TodoBoardTab extends StatefulWidget {
  const TodoBoardTab({super.key});

  @override
  State<TodoBoardTab> createState() => _TodoBoardTabState();
}

class _TodoBoardTabState extends State<TodoBoardTab> {
  List<AcademicTask> _tasks = [];
  final IsarService _isarService = IsarService();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final isar = await _isarService.db;
    final tasks = await isar.academicTasks.where().sortByDueDateDesc().findAll();
    setState(() {
      _tasks = tasks;
    });
  }

  Future<void> _addTask(String title, String subject, String type, DateTime due) async {
    final isar = await _isarService.db;
    final newTask = AcademicTask(
      title: title,
      subject: subject,
      type: type,
      dueDate: due,
      isCompleted: false
    );
    
    await isar.writeTxn(() async {
      await isar.academicTasks.put(newTask);
    });
    _loadTasks();
  }

  Future<void> _toggleTask(AcademicTask task) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      task.isCompleted = !task.isCompleted;
      await isar.academicTasks.put(task);
    });
    _loadTasks();
  }

  Future<void> _updateTask(int id, String title, String subject, String type, DateTime due) async {
    final isar = await _isarService.db;
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

  void _showAddEditSheet({AcademicTask? taskToEdit}) {
    final isEditing = taskToEdit != null;
    String title = taskToEdit?.title ?? '';
    String subject = taskToEdit?.subject ?? 'General';
    String type = taskToEdit?.type ?? 'Assignment';
    DateTime selectedDate = taskToEdit?.dueDate ?? DateTime.now();
    TimeOfDay selectedTime = taskToEdit != null 
       ? TimeOfDay.fromDateTime(taskToEdit.dueDate) 
       : const TimeOfDay(hour: 23, minute: 59);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 25, left: 20, right: 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEditing ? "Edit Task" : "Quick Add Task", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      if (isEditing)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                             // Delete
                             final isar = await _isarService.db;
                             await isar.writeTxn(() async => await isar.academicTasks.delete(taskToEdit!.id));
                             _loadTasks();
                             Navigator.pop(context);
                          },
                        )
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Task Title
                  TextFormField(
                    initialValue: title,
                    autofocus: !isEditing,
                    decoration: InputDecoration(
                      hintText: "What needs to be done?",
                      filled: true, 
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.blueAccent)
                    ),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 15),

                  // Subject & Type Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          items: ["Assignment", "Test", "Exam", "Project", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setSheetState(() => type = v!),
                          decoration: InputDecoration(
                            labelText: "Type",
                            filled: true, fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: subject,
                          decoration: InputDecoration(
                            labelText: "Subject",
                            filled: true, fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            hintText: "e.g. Maths"
                          ),
                          onChanged: (v) => subject = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Date & Time Picker
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                            if(d != null) setSheetState(() => selectedDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM dd').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: selectedTime);
                            if(t != null) setSheetState(() => selectedTime = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        if(title.isNotEmpty) {
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
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: Text(isEditing ? "Save Changes" : "Add to Board", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group tasks by status or generic list
    // Let's do a simple "Upcoming" vs "Done" list view for speed and clarity
    final pending = _tasks.where((t) => !t.isCompleted).toList();
    final completed = _tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("To-Do Board", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 26)),
        actions: [
          IconButton(onPressed: () => _showAddEditSheet(), icon: const Icon(Icons.add_circle, color: Colors.black, size: 30))
        ],
      ),
      body: _tasks.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checklist_rounded, size: 80, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text("No tasks yet", style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Tap + to add one", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              if (pending.isNotEmpty) ...[
                const Text("UPCOMING", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                const SizedBox(height: 10),
                ...pending.map((t) => _buildTaskCard(t)),
                const SizedBox(height: 20),
              ],
              
              if (completed.isNotEmpty) ...[
                const Text("COMPLETED", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                const SizedBox(height: 10),
                ...completed.map((t) => _buildTaskCard(t)),
              ]
            ],
          ),
    );
  }

  Widget _buildTaskCard(AcademicTask task) {
    Color typeColor;
    IconData typeIcon;
    switch(task.type) {
      case 'Exam': typeColor = Colors.redAccent; typeIcon = Icons.warning_rounded; break;
      case 'Test': typeColor = Colors.orangeAccent; typeIcon = Icons.priority_high_rounded; break;
      case 'Project': typeColor = Colors.purpleAccent; typeIcon = Icons.group_work_rounded; break;
      default: typeColor = Colors.blueAccent; typeIcon = Icons.assignment_rounded;
    }

    return Dismissible(
      key: Key(task.title + task.id.toString()),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (dir) async {
        final isar = await _isarService.db;
        await isar.writeTxn(() async => await isar.academicTasks.delete(task.id));
        _loadTasks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: task.isCompleted ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: task.isCompleted ? Colors.grey[200]! : Colors.grey[100]!),
          boxShadow: task.isCompleted ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTask(task),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: task.isCompleted ? Colors.green[400] : Colors.transparent,
                  border: Border.all(color: task.isCompleted ? Colors.green[400]! : Colors.grey[300]!, width: 2),
                  shape: BoxShape.circle
                ),
                child: task.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _showAddEditSheet(taskToEdit: task),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(typeIcon, size: 10, color: typeColor),
                            const SizedBox(width: 4),
                            Text(task.type.toUpperCase(), style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(task.subject, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(task.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: task.isCompleted ? Colors.grey : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM d, h:mm a').format(task.dueDate), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
