import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import 'scroll_time_picker.dart';

class AddEditTaskSheet extends StatefulWidget {
  final AcademicTask? taskToEdit;
  final String? initialCategory;
  final String? initialModule;
  
  const AddEditTaskSheet({super.key, this.taskToEdit, this.initialCategory, this.initialModule});

  @override
  State<AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends State<AddEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late String title;
  late String subject;
  late String type;
  late String note;
  late String room;
  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  bool _showSubjectSuggestions = false;
  late TextEditingController _subjectController;
  
  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    title = t?.title ?? '';
    subject = t?.subject ?? widget.initialModule ?? 'General';
    type = t?.type ?? widget.initialCategory ?? 'Assignment';
    selectedDate = t?.dueDate ?? DateTime.now();
    selectedTime = t != null ? TimeOfDay.fromDateTime(t.dueDate) : const TimeOfDay(hour: 23, minute: 59);
    
    // Parse note and room from description
    note = '';
    room = '';
    if (t != null && t.description.isNotEmpty) {
      final parts = t.description.split('\n---ROOM---\n');
      note = parts[0];
      if (parts.length > 1) room = parts[1];
    }
    
    _subjectController = TextEditingController(text: subject);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }
  
  String _buildDescription() {
    final n = note.trim();
    final r = room.trim();
    if (n.isEmpty && r.isEmpty) return '';
    if (r.isEmpty) return n;
    return '$n\n---ROOM---\n$r';
  }

  bool get _showRoomField => type == 'Exam' || type == 'Test';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.taskToEdit != null;
    final timetable = Provider.of<TimetableProvider>(context, listen: false);
    final savedSubjects = timetable.savedSubjects;
    
    final subjectText = _subjectController.text.trim().toLowerCase();
    final filteredSubjects = savedSubjects.where((s) => 
      s.toLowerCase().contains(subjectText) && s.toLowerCase() != subjectText
    ).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
          top: 30, left: 24, right: 24
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                
                // Subject with autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _subjectController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: _buildInputDeco("Subject", isDark).copyWith(
                        suffixIcon: savedSubjects.isNotEmpty 
                          ? IconButton(
                              icon: Icon(_showSubjectSuggestions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                                   color: Colors.grey[400], size: 20),
                              onPressed: () => setState(() => _showSubjectSuggestions = !_showSubjectSuggestions),
                            )
                          : null,
                      ),
                      onChanged: (val) => setState(() => _showSubjectSuggestions = val.isNotEmpty),
                      onTap: () => setState(() => _showSubjectSuggestions = true),
                      onSaved: (v) => subject = v ?? "General",
                    ),
                    if (_showSubjectSuggestions && filteredSubjects.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 100),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filteredSubjects.length,
                          itemBuilder: (ctx, i) => InkWell(
                            onTap: () {
                              _subjectController.text = filteredSubjects[i];
                              setState(() => _showSubjectSuggestions = false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.history, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 10),
                                  Text(filteredSubjects[i], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                
                DropdownButtonFormField<String>(
                  value: ["Assignment", "Homework", "Test", "Exam", "Project", "Note", "Other"].contains(type) ? type : "Other",
                  dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  items: ["Assignment", "Homework", "Test", "Exam", "Project", "Note", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
                  onChanged: (v) => setState(() => type = v!),
                  decoration: _buildInputDeco("Type", isDark),
                ),
                const SizedBox(height: 15),

                // Room field (Exam/Test only)
                if (_showRoomField) ...[
                  TextFormField(
                    initialValue: room,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _buildInputDeco("Room (optional)", isDark).copyWith(
                      prefixIcon: Icon(Icons.location_on_outlined, color: Colors.redAccent.withOpacity(0.7)),
                      hintText: "e.g. NAC 2.12, LT1",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                    onSaved: (v) => room = v ?? '',
                  ),
                  const SizedBox(height: 15),
                ],

                // Note field
                TextFormField(
                  initialValue: note,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                  decoration: _buildInputDeco("Note (optional)", isDark).copyWith(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Icon(Icons.sticky_note_2_outlined, color: Colors.amber.withOpacity(0.7)),
                    ),
                    hintText: "Add a note...",
                    hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                  onSaved: (v) => note = v ?? '',
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
                         final t = await showScrollTimePicker(
                           context: context, 
                           initialTime: selectedTime,
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
                        final description = _buildDescription();
                        
                        final provider = Provider.of<TimetableProvider>(context, listen: false);
                        if (isEditing) {
                          provider.updateTask(widget.taskToEdit!.id, title, subject, type, due, widget.taskToEdit!.isCompleted, description: description);
                        } else {
                          provider.addTask(title, subject, type, due, description: description);
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
