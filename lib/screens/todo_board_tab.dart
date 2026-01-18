import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import 'package:provider/provider.dart';
import '../services/isar_service.dart';
import 'package:isar_community/isar.dart';

class TodoBoardTab extends StatefulWidget {
  const TodoBoardTab({super.key});

  @override
  State<TodoBoardTab> createState() => _TodoBoardTabState();
}

class _TodoBoardTabState extends State<TodoBoardTab> {

  @override
  void initState() {
    super.initState();
    // No need to loadTasks here if Dashboard/Main already triggered it, 
    // but safe to trigger once ensuring provider has data.
    // Provider.of<TimetableProvider>(context, listen: false).loadSessions();
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
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
                      Text(isEditing ? "Edit Task" : "Quick Add Task", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)
                      ),
                      if (isEditing)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                             Provider.of<TimetableProvider>(context, listen: false).deleteTask(taskToEdit!.id);
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
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "What needs to be done?",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      filled: true, 
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.blueAccent)
                    ),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 20),
                  
                  // Type Selector (Chips instead of Dropdown for better UX/Placement)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Assignment", "Test", "Exam", "Project", "Other"].map((t) {
                        final isSelected = type == t;
                        Color chipColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
                        Color textColor = isDark ? Colors.white70 : Colors.black87;
                        
                        if (isSelected) {
                          chipColor = Colors.blueAccent;
                          textColor = Colors.white;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent,
                            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                            labelStyle: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            onSelected: (bool selected) {
                              if (selected) setSheetState(() => type = t);
                            },
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Subject Input
                   TextFormField(
                    initialValue: subject,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: "Subject",
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      filled: true, 
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50], // Slightly different grey for differentiation
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      hintText: "e.g. Maths",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14) 
                    ),
                    onChanged: (v) => subject = v,
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
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM dd').format(selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))
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
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(selectedTime.format(context), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))
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
                          final provider = Provider.of<TimetableProvider>(context, listen: false);
                          
                          if (isEditing) {
                             taskToEdit!.title = title;
                             taskToEdit.subject = subject;
                             taskToEdit.type = type;
                             taskToEdit.dueDate = dueDateTime;
                             provider.updateTask(
                               taskToEdit.id,
                               taskToEdit.title,
                               taskToEdit.subject,
                               taskToEdit.type,
                               taskToEdit.dueDate,
                               taskToEdit.isCompleted
                             );
                          } else {
                             provider.addTask(title, subject, type, dueDateTime);
                          }
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF5C6BC0) : Colors.black,
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
    return Consumer<TimetableProvider>(
      builder: (context, timetable, child) {
        final pending = timetable.pendingTasks;
        final completed = timetable.completedTasks;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text("To-Do Board", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 26)),
            actions: [
              IconButton(onPressed: () => _showAddEditSheet(), icon: Icon(Icons.add_circle, color: isDark ? Colors.white : Colors.black, size: 30))
            ],
          ),
          body: timetable.tasks.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
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
                    ...pending.map((t) => _buildTaskCard(t, isDark: isDark)),
                    const SizedBox(height: 20),
                  ],
                  
                  if (completed.isNotEmpty) ...[
                    const Text("COMPLETED", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                    const SizedBox(height: 10),
                    ...completed.map((t) => _buildTaskCard(t, isDark: isDark)),
                  ]
                ],
              ),
        );
      }
    );
  }

  Widget _buildTaskCard(AcademicTask task, {bool isDark = false}) {
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
      onDismissed: (dir) {
        Provider.of<TimetableProvider>(context, listen: false).deleteTask(task.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: task.isCompleted 
             ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]) 
             : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white10 : (task.isCompleted ? Colors.grey[200]! : Colors.grey[100]!)),
          boxShadow: (task.isCompleted || isDark) ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                 task.isCompleted = !task.isCompleted;
                 Provider.of<TimetableProvider>(context, listen: false).updateTask(
                   task.id,
                   task.title,
                   task.subject,
                   task.type,
                   task.dueDate,
                   task.isCompleted
                 );
              },
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
                  Text(task.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: task.isCompleted ? Colors.grey : (isDark ? Colors.white : Colors.black87))),
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
