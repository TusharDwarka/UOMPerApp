import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';

class AddEditTaskSheet extends StatefulWidget {
  final AcademicTask? taskToEdit;
  
  const AddEditTaskSheet({super.key, this.taskToEdit});

  @override
  State<AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends State<AddEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late String title;
  late String subject;
  late String type;
  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  
  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    title = t?.title ?? '';
    subject = t?.subject ?? 'General';
    type = t?.type ?? 'Assignment';
    selectedDate = t?.dueDate ?? DateTime.now();
    selectedTime = t != null ? TimeOfDay.fromDateTime(t.dueDate) : const TimeOfDay(hour: 23, minute: 59);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.taskToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        top: 30, left: 24, right: 24
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEditing ? "Edit Task" : "Add Task", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                       Provider.of<TimetableProvider>(context, listen: false).deleteTask(widget.taskToEdit!.id);
                       Navigator.pop(context);
                    },
                  )
              ],
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              initialValue: title,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: _buildInputDeco("Task Title", isDark),
              validator: (v) => v!.isEmpty ? "Required" : null,
              onSaved: (v) => title = v!,
            ),
            const SizedBox(height: 15),
            
            TextFormField(
              initialValue: subject,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: _buildInputDeco("Subject", isDark),
              onSaved: (v) => subject = v ?? "General",
            ),
            const SizedBox(height: 15),
            
            DropdownButtonFormField<String>(
              value: ["Assignment", "Test", "Exam", "Project", "Note", "Other"].contains(type) ? type : "Other",
              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              items: ["Assignment", "Test", "Exam", "Project", "Note", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
              onChanged: (v) => setState(() => type = v!),
              decoration: _buildInputDeco("Type", isDark),
            ),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(isDark, false, () async {
                    final d = await showDatePicker(
                      context: context, 
                      initialDate: selectedDate, 
                      firstDate: DateTime(2020), 
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: isDark ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2962FF), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF1E1E1E)) : ThemeData.light(),
                        child: child!,
                      )
                    );
                    if(d!=null) setState(() => selectedDate = d);
                  })
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateButton(isDark, true, () async {
                     final t = await showTimePicker(
                       context: context, 
                       initialTime: selectedTime,
                       builder: (context, child) => Theme(
                        data: isDark ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2962FF), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white), timePickerTheme: const TimePickerThemeData(backgroundColor: Color(0xFF1E1E1E))) : ThemeData.light(),
                        child: child!,
                      )
                     );
                     if(t!=null) setState(() => selectedTime = t);
                  })
                )
              ],
            ),
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final due = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                    
                    final provider = Provider.of<TimetableProvider>(context, listen: false);
                    if (isEditing) {
                      provider.updateTask(widget.taskToEdit!.id, title, subject, type, due, widget.taskToEdit!.isCompleted);
                    } else {
                      provider.addTask(title, subject, type, due);
                    }
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0
                ),
                child: Text(isEditing ? "Save Changes" : "Create Task", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
  
  InputDecoration _buildInputDeco(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
    );
  }
  
  Widget _buildDateButton(bool isDark, bool isTime, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(isTime ? Icons.access_time : Icons.calendar_today, color: isDark ? Colors.blue[200] : const Color(0xFF2962FF), size: 18),
      label: Text(
        isTime ? selectedTime.format(context) : DateFormat('MMM d').format(selectedDate),
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF2962FF))
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      )
    );
  }
}
