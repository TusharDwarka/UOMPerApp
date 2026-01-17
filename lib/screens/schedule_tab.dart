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
    // We now have two types of sessions:
    // 1. Generic recurring (specificDate == null) -> Match day name
    // 2. Specific date (specificDate != null) -> Match exact date
    
    final dayName = DateFormat('EEEE').format(day);
    
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
              GestureDetector(
                onTap: () async {
                  // Month Picker
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          primaryColor: const Color(0xFF0066FF),
                          colorScheme: const ColorScheme.light(primary: Color(0xFF0066FF)),
                          buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Row(
                  children: [
                    Text(DateFormat('MMMM d, y').format(_selectedDate), style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                    const SizedBox(width: 5),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[400])
                  ],
                ),
              ),
            ],
          ),
          
          Row(
            children: [
               IconButton(
                 icon: const Icon(Icons.cloud_download_outlined, color: Colors.blueGrey),
                 tooltip: "Import Timetable",
                 onPressed: () {
                   // Import Timetable Trigger
                   final startOfSemester = DateTime(2026, 1, 19); // 19 Jan 2026
                   
                   // JSON DATA (Hardcoded as requested for "Use that file")
                   // In a real app we might read file, but for now passing the structure
                   // We need to pass the Map.
                   final jsonMap = {
                      "timetable": {
                        "Monday": [
                          {"day": "Monday", "startTime": "09:30", "endTime": "12:30", "moduleName": "Scientific Writing and Presentation", "location": "Room G3", "mode": "CAMPUS"},
                          {"day": "Monday", "startTime": "12:30", "endTime": "15:30", "moduleName": "Propositional and Predicate Logic", "location": "ROOM G3", "mode": "CAMPUS"}
                        ],
                        "Tuesday": [
                          {"day": "Tuesday", "startTime": "09:00", "endTime": "12:00", "moduleName": "Introduction to Computer Science", "location": "Online", "mode": "ONLINE"},
                          {"day": "Tuesday", "startTime": "12:00", "endTime": "15:00", "moduleName": "Linear Algebra", "location": "Online", "mode": "ONLINE"}
                        ],
                        "Wednesday": [
                          {"day": "Wednesday", "startTime": "08:30", "endTime": "10:30", "moduleName": "Lab practicals", "location": "CITS Lab 1B", "mode": "CAMPUS"},
                          {"day": "Wednesday", "startTime": "12:00", "endTime": "13:00", "moduleName": "Lab practicals", "location": "FOA Lab 2B", "mode": "CAMPUS"},
                          {"day": "Wednesday", "startTime": "13:00", "endTime": "15:30", "moduleName": "Mathematical Analysis (Tutorial)", "location": "Rm 2.12 NAC", "mode": "CAMPUS"}
                        ],
                        "Thursday": [
                          {"day": "Thursday", "startTime": "08:00", "endTime": "11:00", "moduleName": "Physics (L)", "location": "Room G1", "mode": "CAMPUS"},
                          {"day": "Thursday", "startTime": "12:00", "endTime": "15:00", "moduleName": "Linear Algebra", "location": "Room G1", "mode": "CAMPUS"}
                        ],
                        "Friday": [
                          {"day": "Friday", "startTime": "08:00", "endTime": "11:00", "moduleName": "Physics (T)", "location": "Room G3", "mode": "CAMPUS"},
                          {"day": "Friday", "startTime": "12:00", "endTime": "15:00", "moduleName": "Mathematical Analysis (Tutorial)", "location": "Room G3", "mode": "CAMPUS"}
                        ]
                      }
                   };

                   Provider.of<TimetableProvider>(context, listen: false).importSemester(jsonMap, startOfSemester);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semester Imported: Weeks 1-10 populated")));
                 },
               ),
               const SizedBox(width: 10),
               InkWell(
                onTap: () => _showAddSessionDialog(),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0066FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          )
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

    // Stylistic Logic based on Subject Hash
    // 1. Solid Pastels (Green, Purple, Red)
    // 2. Outlined/Translucent (Yellow/Orange)
    // Reference Image has: Green filled, Yellow filled, Purple filled, Red filled.
    // They are light pastels but distinct.

    final colorOption = event.subject.hashCode.abs() % 4;
    
    // Exact colors from reference image approx
    // Green: #9CCC65 (approx)
    // Yellow: #FFD600 (approx)
    // Purple: #B39DDB (approx) - actually more vibrant violet
    // Red/Pink: #FF8A80
    
    final colors = [
      const Color(0xFFC5E1A5), // Light Green (Matte)
      const Color(0xFFFFE082), // Light Amber (Matte)
      const Color(0xFFCE93D8), // Light Purple (Matte)
      const Color(0xFFFFAB91), // Light Deep Orange (Matte)
    ];
    
    // Darker text colors for contrast on pastels
    final textColors = [
      const Color(0xFF33691E), // Dark Green
      const Color(0xFFBF360C), // Dark Orange/Brown
      const Color(0xFF4A148C), // Dark Purple
      const Color(0xFFB71C1C), // Dark Red
    ];

    final bgColor = colors[colorOption];
    final textColor = textColors[colorOption];
    final iconColor = textColor.withOpacity(0.7);

    return Positioned(
      top: top,
      left: 10,
      right: 24,
      height: height - 6, // larger gap
      child: GestureDetector(
        onTap: () => _showAddSessionDialog(sessionToEdit: event),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24), // Very rounded corners like image
            // No shadow or very subtle
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
            children: [
              // Icon with square/circle bg (outlined in image)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(12), // Squircle
                ),
                child: Icon(Icons.class_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter', // Assuming standard font
                        color: Colors.white, // Actually white text looks good on these pastels? 
                        // Wait, reference image has WHITE text on Green/Purple/Red.
                        // But Yellow has DARK text.
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ).copyWith(color: (colorOption == 1) ? const Color(0xFF5D4037) : Colors.white),
                    ),
                    // If height permits, show room
                    if (height > 50)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          event.room,
                          style: TextStyle(
                            fontSize: 13,
                            color: (colorOption == 1) ? const Color(0xFF5D4037).withOpacity(0.7) : Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      )
                  ],
                ),
              ),
              
              // Three dots icon
              Icon(Icons.more_horiz, color: (colorOption == 1) ? const Color(0xFF5D4037).withOpacity(0.5) : Colors.white.withOpacity(0.6), size: 20)
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
