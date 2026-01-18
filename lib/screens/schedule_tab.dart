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
  
  final int _startHour = 8;
  
  bool _isCompareMode = false;
  bool _isEditMode = false;
  String? _currentPerspective; // Null = Selection Screen

  // Cache DateFormats
  final DateFormat _dayNumFormat = DateFormat('d');
  final DateFormat _fullDateFormat = DateFormat('MMMM d, y');

  @override
  Widget build(BuildContext context) {
    if (_currentPerspective == null) {
      return _buildCourseSelectionScreen();
    }

    final timetable = Provider.of<TimetableProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate current week
    final start = DateTime(2026, 1, 19);
    final now = DateTime.now();
    final diffDays = now.difference(start).inDays;
    int currentWeek = (diffDays / 7).floor() + 1;
    if (diffDays < 0) currentWeek = 0; 

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Schedule", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.compare_arrows, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showCompareModal(context),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: _isEditMode ? Colors.blue : (isDark ? Colors.white : Colors.black)),
             onPressed: () {
               setState(() {
                  _isEditMode = !_isEditMode;
               });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(isDark, timetable),
          
          // Week Strip
          if (!_isEditMode) ...[
            _buildWeekStrip(currentWeek, isDark),
            const SizedBox(height: 10),
          ],

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Column
                  Container(
                    width: 60,
                    padding: const EdgeInsets.only(top: 10), // Alignment correction
                    child: Column(
                      children: [
                        for (int i = 8; i <= 20; i++)
                          SizedBox(
                            height: 60, 
                            child: Text(
                              "${i.toString().padLeft(2, '0')}:00",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          )
                      ],
                    ),
                  ),

                  // Event Grid
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                         return Stack(
                           children: [
                             // Grid Lines
                             Column(
                               children: [
                                 for (int i = 8; i <= 20; i++)
                                   Container(
                                     height: 60, 
                                     decoration: BoxDecoration(
                                       border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!)) // Increased visibility
                                     ),
                                   )
                               ],
                             ),

                             // Events
                             ..._buildAllEvents(constraints.maxWidth, timetable, isDark),
                             
                             // Current Time Indicator (Visual Polish)
                             _buildCurrentTimeLine(isDark), 
                           ],
                         );
                      }
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: _isEditMode 
        ? FloatingActionButton.extended(
            onPressed: () => _showAddSessionDialog(),
            label: const Text("Add Class"),
            icon: const Icon(Icons.add),
            backgroundColor: const Color(0xFF2962FF),
            foregroundColor: Colors.white,
          )
        : null,
    );
  }

  Widget _buildCurrentTimeLine(bool isDark) {
    // Calculate current time position
    final now = DateTime.now();
    if (now.hour < 8 || now.hour > 20) return const SizedBox();
    
    final minutes = (now.hour * 60) + now.minute;
    final top = (minutes - 480).toDouble();
    
    return Positioned(
      top: top, left: 0, right: 0,
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: isDark ? Colors.redAccent : Colors.red),
          Expanded(child: Container(height: 2, color: isDark ? Colors.redAccent : Colors.red)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, TimetableProvider timetable) {
    // Get Week Label
    final weekLabel = timetable.getWeekLabel(_selectedDate);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    _currentPerspective ?? "Schedule", 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text(
                      weekLabel,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.blue[200] : Colors.blue[800])
                    ),
                  )
                ],
              ),
              const SizedBox(width: 8),
              if (_currentPerspective != null)
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.swap_horiz, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () {
                    setState(() {
                      _currentPerspective = null; 
                      _isCompareMode = false;
                    });
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.people_outline, color: _isCompareMode ? Colors.green : (isDark ? Colors.white : Colors.black)),
                onPressed: () => _showCompareModal(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
             onTap: () async {
               final DateTime? picked = await showDatePicker(
                 context: context,
                 initialDate: _selectedDate,
                 firstDate: DateTime(2020),
                 lastDate: DateTime(2030),
                 builder: (context, child) => Theme(
                   data: isDark 
                      ? ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: Color(0xFF3949AB), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
                          dialogBackgroundColor: const Color(0xFF1E1E1E)
                        )
                      : ThemeData.light().copyWith(primaryColor: const Color(0xFF0066FF)),
                   child: child!,
                 ),
               );
               if (picked != null) setState(() => _selectedDate = picked);
             },
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(
                   DateFormat('MMMM d, y').format(_selectedDate), 
                   style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)
                 ),
                 const SizedBox(width: 4),
                 Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600])
               ],
             ),
          ),
        ],
      ),
    );
  }

  // Grid Event Builder Logic (Restored)
  List<Widget> _buildAllEvents(double width, TimetableProvider timetable, bool isDark) {
    // 1. Check Date Bounds (Jan 19 2026)
    final semesterStart = DateTime(2026, 1, 19);
    
    if (_selectedDate.isBefore(semesterStart)) {
       return [
         Positioned(
           top: 100, left: 0, right: 0,
           child: Center(
             child: Text("Pre-Semester (No Classes)", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontStyle: FontStyle.italic))
           )
         )
       ];
    }

    List<Widget> children = [];
    
    // Filter events for the selected day only
    final events = timetable.getEventsForDay(_selectedDate);
    final friendEvents = _isCompareMode ? timetable.getFriendEventsForDay(_selectedDate) : <ClassSession>[];

    // 2. Build User Events
    // Handling overlap: Simple logic, if compare mode, width is halved.
    
    for (var event in events) {
      children.add(_buildEventBlock(event, width, isDark: isDark));
    }
    
    if (_isCompareMode) {
       for (var event in friendEvents) {
         children.add(_buildEventBlock(event, width, isGhost: true, isDark: isDark));
       }
    }
    
    // 3. Free to Meet Logic (Enabled ONLY in Compare Mode)
    // Constraint: Both must have at least one "On Campus" class (Room != "Online")
    // Constraint: Check availability 08:00 - 17:30
    
    if (_isCompareMode && events.isNotEmpty && friendEvents.isNotEmpty) {
       // 3.1 Check On-Campus Presence
       bool userOnCampus = events.any((e) => !e.room.toLowerCase().contains('online'));
       bool friendOnCampus = friendEvents.any((e) => !e.room.toLowerCase().contains('online'));
       
       if (userOnCampus && friendOnCampus) {
          // 3.2 Collect All Busy Intervals
          List<({int start, int end})> busyIntervals = [];
          
          final allEvents = [...events, ...friendEvents];
          for (var e in allEvents) {
             final s = e.startTime.split(':');
             final start = int.parse(s[0]) * 60 + int.parse(s[1]);
             final eStr = e.endTime.split(':');
             final end = int.parse(eStr[0]) * 60 + int.parse(eStr[1]);
             busyIntervals.add((start: start, end: end));
          }
          
          // 3.3 Sort and Merge
          busyIntervals.sort((a,b) => a.start.compareTo(b.start));
          
          List<({int start, int end})> merged = [];
          if (busyIntervals.isNotEmpty) {
             var current = busyIntervals[0];
             for (int i = 1; i < busyIntervals.length; i++) {
                if (busyIntervals[i].start < current.end) {
                   // Overlap or Abutting, merge
                   current = (start: current.start, end: busyIntervals[i].end > current.end ? busyIntervals[i].end : current.end);
                } else {
                   merged.add(current);
                   current = busyIntervals[i];
                }
             }
             merged.add(current);
          }
          
          // 3.4 Find Gaps (08:00 to 17:30)
          int startOfDay = 8 * 60; // 480
          int endOfDay = 17 * 60 + 30; // 1050
          
          int scanPtr = startOfDay;
          
          for (var block in merged) {
             if (block.start > scanPtr) {
                // Found Gap
                _addFreeBlock(children, scanPtr, block.start, width, isDark);
             }
             // Advance pointer
             if (block.end > scanPtr) scanPtr = block.end;
          }
          
          // Tail Gap
          if (scanPtr < endOfDay) {
             _addFreeBlock(children, scanPtr, endOfDay, width, isDark);
          }
       }
    }
    
    return children;
  }
  
  void _addFreeBlock(List<Widget> children, int startMin, int endMin, double totalWidth, bool isDark) {
    if (endMin - startMin < 30) return; // Ignore small gaps < 30 mins
    
    double top = (startMin - 480).toDouble();
    double height = (endMin - startMin).toDouble();
    
    children.add(Positioned(
      top: top, 
      left: 0, 
      right: 0, 
      height: height - 2,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10), // Wider to look better
        decoration: BoxDecoration(
          color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], // Subtle green
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.5), width: 1, style: BorderStyle.solid),
          // Add dashed pattern or stripes? Keep it simple for now.
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Icon(Icons.handshake_rounded, size: 16, color: isDark ? Colors.green[300] : Colors.green[700]),
               const SizedBox(width: 6),
               Text(
                 "FREE TO MEET  ${_formatMin(startMin)} - ${_formatMin(endMin)}",
                 style: TextStyle(
                   color: isDark ? Colors.green[300] : Colors.green[900], 
                   fontWeight: FontWeight.bold, 
                   fontSize: 12,
                   letterSpacing: 0.5
                 )
               )
            ],
          ),
        ),
      ),
    ));
  }

  String _formatMin(int minutes) {
    final h = (minutes / 60).floor().toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  Widget _buildEventBlock(ClassSession event, double totalWidth, {bool isGhost = false, bool isDark = false}) {
     final partsStart = event.startTime.split(':');
     final startMinutes = int.parse(partsStart[0]) * 60 + int.parse(partsStart[1]);
     final partsEnd = event.endTime.split(':');
     final endMinutes = int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1]);
     
     // 8:00 AM is 480 minutes.
     // Offset: (startMinutes - 480) * (60px / 60min) -> 1 px per minute.
     double top = (startMinutes - 480).toDouble();
     double height = (endMinutes - startMinutes).toDouble(); // 1 min = 1 px
     
     if (top < 0) return const SizedBox(); // Before 8am
     
     // Width Logic
     double left = 0;
     double width = totalWidth;
     
     if (_isCompareMode) {
       width = (totalWidth / 2) - 6; // Gap
       if (isGhost) {
         left = (totalWidth / 2) + 2;
       } else {
         left = 0; 
       }
     } else {
       width = totalWidth - 16;
       left = 0;
     }

     // Colors
     final colorOption = event.subject.hashCode.abs() % 6;
     final styles = [
       (const Color(0xFFE3F2FD), const Color(0xFF1565C0)), // Blue
       (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)), // Purple
       (const Color(0xFFE0F2F1), const Color(0xFF00695C)), // Teal
       (const Color(0xFFFFF3E0), const Color(0xFFEF6C00)), // Orange
       (const Color(0xFFFFEBEE), const Color(0xFFC62828)), // Red
       (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)), // Green
     ];
     final style = styles[colorOption];
     
     final bgColor = isGhost ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]!) : (isDark ? style.$2.withOpacity(0.2) : style.$1);
     final accentColor = isGhost ? Colors.grey : style.$2;
     final textColor = isDark ? Colors.white : Colors.black87;

     return Positioned(
       top: top,
       left: left,
       width: width,
       height: height - 1, // Slight gap
       child: GestureDetector(
         onTap: () => _showAddSessionDialog(sessionToEdit: isGhost ? null : event),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Reduced padding
           decoration: BoxDecoration(
             color: bgColor,
             borderRadius: BorderRadius.circular(8), 
             border: Border(left: BorderSide(color: accentColor, width: 3))
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               Flexible(
                 child: Text(
                   event.subject, 
                   maxLines: 1, 
                   overflow: TextOverflow.ellipsis, 
                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)
                 ),
               ),
               if (height > 35) ...[ 
                 const SizedBox(height: 1),
                 Text("${event.startTime} - ${event.endTime}", style: TextStyle(fontSize: 9, color: isDark ? Colors.white70 : Colors.black54)),
                 if (height > 50)
                 Flexible(
                   child: Text(
                     event.room, 
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis, 
                     style: TextStyle(fontSize: 9, color: isDark ? Colors.white70 : Colors.black54)
                   )
                 ),
               ]
             ],
           ),
         ),
       ),
     );
  }
  
  // Re-write Week Strip for Slidable View
  Widget _buildWeekStrip(int currentWeek, bool isDark) {
    // Show window: Selected Date - 2 to Selected Date + 2 (5 days) or 7 days
    final daysToShow = List.generate(7, (index) {
       return _selectedDate.subtract(const Duration(days: 3)).add(Duration(days: index));
    });
    
    return SizedBox( // Constrained height
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // Added bounce/friction
        itemCount: daysToShow.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
           final dayDate = daysToShow[index];
           final dayLetter = DateFormat('E').format(dayDate)[0];
           final isSelected = isSameDay2(dayDate, _selectedDate);
           
           return GestureDetector(
             onTap: () => setState(() => _selectedDate = dayDate),
             child: Container(
               width: 60,
               margin: const EdgeInsets.only(right: 8),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(dayLetter, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                   const SizedBox(height: 8),
                   Container(
                     width: 45, height: 50,
                     decoration: BoxDecoration(
                       color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                       borderRadius: BorderRadius.circular(16),
                     ),
                     alignment: Alignment.center,
                     child: Text(
                       "${dayDate.day}",
                       style: TextStyle(
                         color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black),
                         fontWeight: FontWeight.bold,
                         fontSize: 18
                       )
                     ),
                   )
                 ],
               ),
             ),
           );
        },
      ),
    );
     }
  
  // Ensure _showAddSessionDialog is fully dark aware
  void _showAddSessionDialog({ClassSession? sessionToEdit}) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     // ... (Local variables same) ...
     final subjectController = TextEditingController(text: sessionToEdit?.subject ?? '');
     final roomController = TextEditingController(text: sessionToEdit?.room ?? '');
     String day = sessionToEdit?.day ?? 'Monday';
     
     // Need to parse day from session or default to selected date's day
     if (sessionToEdit == null) {
        day = DateFormat('EEEE').format(_selectedDate); 
     }

     TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
     TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
     if (sessionToEdit != null) {
        final startP = sessionToEdit.startTime.split(":");
        startTime = TimeOfDay(hour: int.parse(startP[0]), minute: int.parse(startP[1]));
        final endP = sessionToEdit.endTime.split(":");
        endTime = TimeOfDay(hour: int.parse(endP[0]), minute: int.parse(endP[1]));
     }

     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (context) => StatefulBuilder(
         builder: (context, setSheetState) {
           return Padding(
             padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Text(sessionToEdit == null ? "Add Class" : "Edit Class", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                     const Spacer(),
                     IconButton(icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.grey[600]), onPressed: () => Navigator.pop(context))
                   ],
                 ),
                 const SizedBox(height: 24),
                 
                 // Inputs
                 _buildDialogConfigInput("Subject", subjectController, isDark),
                 const SizedBox(height: 16),
                 _buildDialogConfigInput("Room", roomController, isDark),
                 const SizedBox(height: 16),
                 
                 DropdownButtonFormField<String>(
                   value: day,
                   dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                   icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white70 : Colors.black54),
                   items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
                   onChanged: (v) => setSheetState(() => day = v!),
                   decoration: InputDecoration(
                     labelText: "Day",
                     labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                     filled: true, 
                     fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], 
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                   ),
                 ),
                 // ... (Time Pickers and Button same as before but ensured style)
                 const SizedBox(height: 24),
                 Row(
                   children: [
                     Expanded(child: _buildTimePickerButton("Start", startTime, (t) => setSheetState(() => startTime = t), isDark)),
                     const SizedBox(width: 12),
                     Expanded(child: _buildTimePickerButton("End", endTime, (t) => setSheetState(() => endTime = t), isDark)),
                   ],
                 ),
                 const SizedBox(height: 32),
                 SizedBox(
                   width: double.infinity,
                   height: 54,
                   child: ElevatedButton(
                     onPressed: () {
                       final provider = Provider.of<TimetableProvider>(context, listen: false);
                       final startStr = "${startTime.hour.toString().padLeft(2,'0')}:${startTime.minute.toString().padLeft(2,'0')}";
                       final endStr = "${endTime.hour.toString().padLeft(2,'0')}:${endTime.minute.toString().padLeft(2,'0')}";
                       
                       // Validation
                       if (subjectController.text.isEmpty) return;

                       if (sessionToEdit != null) {
                         provider.deleteSession(sessionToEdit.id); 
                       }
                       
                       final newSession = ClassSession(
                         day: day,
                         startTime: startStr,
                         endTime: endStr,
                         subject: subjectController.text,
                         room: roomController.text,
                         moduleCode: '',
                         isUser: true, 
                       );
                       provider.addSession(newSession);
                       Navigator.pop(context);
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF2962FF), 
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       elevation: 0
                     ),
                     child: const Text("Save Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                   ),
                 ),
                 if (sessionToEdit != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 12),
                     child: Center(
                       child: TextButton(
                         onPressed: () {
                           Provider.of<TimetableProvider>(context, listen: false).deleteSession(sessionToEdit.id);
                           Navigator.pop(context);
                         },
                         child: const Text("Delete Class", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                       ),
                     ),
                   )
               ],
             ),
           );
         }
       )
     );
  }

  Widget _buildDialogConfigInput(String label, TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
      // Force white/grey bg
      decoration: InputDecoration(
        labelText: label, 
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
      ),
    );
  }

  Widget _buildTimePickerButton(String label, TimeOfDay time, Function(TimeOfDay) onPicked, bool isDark) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
          context: context, 
          initialTime: time,
          builder: (context, child) {
             return Theme(
               data: isDark 
                   ? ThemeData.dark().copyWith(
                       colorScheme: const ColorScheme.dark(primary: Color(0xFF3949AB), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
                       dialogBackgroundColor: const Color(0xFF1E1E1E),
                       textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white))
                     )
                   : ThemeData.light().copyWith(primaryColor: const Color(0xFF0066FF)),
               child: child!,
             );
          }
        );
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.blue[50], borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isDark ? Colors.grey : Colors.blue[800], fontSize: 12)),
            Text(time.format(context), style: TextStyle(color: isDark ? Colors.white : Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSelectionScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Icon(Icons.school_rounded, size: 60, color: isDark ? const Color(0xFF5C6BC0) : const Color(0xFF1A237E)),
                const SizedBox(height: 20),
                Text("Select Your Course", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 10),
                Text("Choose your main perspective for the schedule.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
                const SizedBox(height: 50),
                
                _buildCourseCard("Data Science", Icons.analytics_outlined, isDark ? Colors.white : Colors.black87, () {
                   setState(() {
                     _currentPerspective = "Data Science";
                     final provider = Provider.of<TimetableProvider>(context, listen: false);
                     provider.loadFriendTimetable(); 
                     provider.setPerspective(false); 
                   });
                }, isDark),
                const SizedBox(height: 20),
                _buildCourseCard("Computer Science", Icons.computer_rounded, isDark ? Colors.white : Colors.black87, () {
                   setState(() {
                     _currentPerspective = "Computer Science";
                     final provider = Provider.of<TimetableProvider>(context, listen: false);
                     provider.loadFriendTimetable();
                     provider.setPerspective(true);
                   });
                }, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF3949AB).withOpacity(0.2) : const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isDark ? const Color(0xFF5C6BC0) : const Color(0xFF1A237E)),
            ),
            const SizedBox(width: 20),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.grey[500] : Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCompareModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text("Compare with...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
             const SizedBox(height: 20),
             ListTile(
               contentPadding: EdgeInsets.zero,
               leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.science, color: Colors.green)),
               title: Text(_currentPerspective == "Data Science" ? "Computer Science" : "Data Science", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
               subtitle: Text("View side-by-side", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
               trailing: _isCompareMode ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined, color: Colors.grey),
               onTap: () {
                 setState(() {
                   _isCompareMode = true;
                 });
                 Navigator.pop(c);
               },
             ),
             if (_isCompareMode) ...[
               Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),
               ListTile(
                 contentPadding: EdgeInsets.zero,
                 leading: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.close, color: Colors.red)),
                 title: Text("Stop Comparing", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                 onTap: () {
                   setState(() {
                     _isCompareMode = false;
                   });
                   Navigator.pop(c);
                 },
               )
             ]
           ],
        ),
      )
    );
  }

  bool isSameDay2(DateTime a, DateTime b) {
     return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _EventWrapper {
  final ClassSession session;
  final bool isFriend;
  _EventWrapper(this.session, this.isFriend);
}  


