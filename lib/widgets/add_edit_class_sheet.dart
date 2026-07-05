import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import 'scroll_time_picker.dart';

class AddEditClassSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddEditClassSheet({super.key, this.initialData});

  @override
  State<AddEditClassSheet> createState() => _AddEditClassSheetState();
}

class _AddEditClassSheetState extends State<AddEditClassSheet> {
  late TextEditingController _moduleNameCtrl;
  late TextEditingController _moduleCodeCtrl;
  late TextEditingController _locationCtrl;
  late String _selectedDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isTemporary = false;
  DateTime? _specificDate;
  String? _errorMessage;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _moduleNameCtrl = TextEditingController(text: d?['moduleName'] ?? '');
    _moduleCodeCtrl = TextEditingController(text: d?['moduleCode'] ?? '');
    _locationCtrl = TextEditingController(text: d?['location'] ?? '');
    _selectedDay = d?['day'] ?? 'Monday';
    
    if (!_days.contains(_selectedDay)) {
      _selectedDay = 'Monday';
    }

    _specificDate = d?['specificDate'] != null ? DateTime.tryParse(d!['specificDate'].toString()) : null;
    _isTemporary = d?['isTemporary'] ?? (_specificDate != null);

    _startTime = _parseTime(d?['startTime']) ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = _parseTime(d?['endTime']) ?? const TimeOfDay(hour: 10, minute: 0);
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _moduleNameCtrl.dispose();
    _moduleCodeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _errorMessage = null;
    });

    if (_moduleNameCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Module Name is required';
      });
      return;
    }

    if (_isTemporary && _specificDate == null) {
      setState(() {
        _errorMessage = 'Please select a date for the one-off class';
      });
      return;
    }

    final dayToSave = _isTemporary ? DateFormat('EEEE').format(_specificDate!) : _selectedDay;
    
    // Conflict Detection
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final newStart = _startTime.hour * 60 + _startTime.minute;
    final newEnd = _endTime.hour * 60 + _endTime.minute;
    final editId = widget.initialData?['id'];

    final sessionsToCheck = provider.userSessions.where((s) {
       if (editId != null && s.id == editId) return false;
       
       if (_isTemporary && _specificDate != null) {
          if (s.specificDate != null) {
             return s.specificDate!.year == _specificDate!.year && s.specificDate!.month == _specificDate!.month && s.specificDate!.day == _specificDate!.day;
          } else {
             return s.day == dayToSave;
          }
       } else {
          return s.day == dayToSave && s.specificDate == null;
       }
    }).toList();
    
    for (var s in sessionsToCheck) {
       final sStartParts = s.startTime.split(':');
       final sStart = int.parse(sStartParts[0]) * 60 + int.parse(sStartParts[1]);
       final sEndParts = s.endTime.split(':');
       final sEnd = int.parse(sEndParts[0]) * 60 + int.parse(sEndParts[1]);
       
       if (newStart < sEnd && newEnd > sStart) {
          setState(() {
            _errorMessage = 'Time conflict with ${s.subject}! Please choose a different time.';
          });
          return;
       }
    }

    final result = {
      'moduleName': _moduleNameCtrl.text.trim(),
      'moduleCode': _moduleCodeCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty ? 'TBD' : _locationCtrl.text.trim(),
      'day': dayToSave,
      'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'weeks': widget.initialData?['weeks'] ?? [],
      'specificDate': _isTemporary ? _specificDate?.toIso8601String() : null,
    };

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    final isEditing = widget.initialData != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header
            Text(
              isEditing ? "Edit Class" : "Add Class",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 24),

            // Details section
            _buildSectionHeader("Details", Icons.info_outline),
            const SizedBox(height: 16),
            _buildTextField("Module Name", "e.g. Programming", _moduleNameCtrl, isDark),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField("Code (Opt)", "e.g. CS101", _moduleCodeCtrl, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField("Room", "e.g. NAC 2.12", _locationCtrl, isDark)),
              ],
            ),
            const SizedBox(height: 24),

            // Timing section
            _buildSectionHeader("Timing", Icons.access_time_rounded),
            const SizedBox(height: 16),
            
            // Toggle Regular vs One-Off
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Regular", style: TextStyle(color: !_isTemporary ? accentColor : Colors.grey, fontWeight: FontWeight.bold)),
                Switch(
                  value: _isTemporary, 
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => _isTemporary = v),
                ),
                Text("One-Off", style: TextStyle(color: _isTemporary ? accentColor : Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Day Dropdown OR Date Picker
            if (!_isTemporary)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDay,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF2A2A3C) : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.grey),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _specificDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _specificDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _specificDate == null ? Colors.red.withOpacity(0.5) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _specificDate != null ? DateFormat('EEEE, MMM d, yyyy').format(_specificDate!) : "Select Date",
                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Time Pickers
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker(
                    "Start Time", 
                    _startTime, 
                    (t) {
                      setState(() {
                        _startTime = t;
                        // Automatically add 1 hour to end time
                        _endTime = TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
                      });
                    }, 
                    isDark, 
                    accentColor
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePicker(
                    "End Time", 
                    _endTime, 
                    (t) => setState(() => _endTime = t), 
                    isDark, 
                    accentColor,
                    hasError: _endTime.hour * 60 + _endTime.minute <= _startTime.hour * 60 + _startTime.minute
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Error Message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Row(
              children: [
                if (isEditing)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                         Navigator.of(context).pop({'delete': true});
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text("Delete", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isEditing)
                  const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final startMins = _startTime.hour * 60 + _startTime.minute;
                      final endMins = _endTime.hour * 60 + _endTime.minute;
                      if (endMins <= startMins) {
                        setState(() {
                          _errorMessage = "End time must be after start time.";
                        });
                        return;
                      }
                      _save();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController ctrl, bool isDark) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
        hintStyle: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged, bool isDark, Color accentColor, {bool hasError = false}) {
    return GestureDetector(
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus(); // Fully drop focus
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for keyboard to retract
        if (!context.mounted) return;
        final picked = await showScrollTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: hasError ? Border.all(color: Colors.redAccent, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[700])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
