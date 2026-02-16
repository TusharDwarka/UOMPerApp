import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../services/bus_service.dart';
import 'planning_screen.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';
import '../widgets/add_edit_task_sheet.dart'; 

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }

  // Find the next upcoming class — may be tomorrow or later
  Map<String, dynamic>? _findNextUpcomingClass(TimetableProvider timetable) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    
    // 1. Check today first
    final todayClasses = timetable.getEventsForDay(now);
    todayClasses.sort((a,b) => a.startTime.compareTo(b.startTime));
    
    for (var s in todayClasses) {
      final parts = s.startTime.split(":");
      final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (startMinutes > nowMinutes) {
        final diff = startMinutes - nowMinutes;
        String timeStatus;
        if (diff < 60) {
          timeStatus = "Starts in ${diff}m";
        } else {
          timeStatus = "Starts in ${diff ~/ 60}h ${diff % 60}m";
        }
        return {'session': s, 'timeStatus': timeStatus, 'dayLabel': 'Today'};
      }
    }
    
    // Check "currently in class"
    for (var s in todayClasses) {
      final startParts = s.startTime.split(":");
      final endParts = s.endTime.split(":");
      final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      if (nowMinutes >= startMins && nowMinutes < endMins) {
        final remaining = endMins - nowMinutes;
        return {'session': s, 'timeStatus': "In class • ${remaining}m left", 'dayLabel': 'Now', 'inClass': true};
      }
    }
    
    // 2. Check next 7 days
    for (int d = 1; d <= 7; d++) {
      final futureDate = now.add(Duration(days: d));
      final week = timetable.getWeekNumber(futureDate);
      
      // Skip if before semester or online week
      if (week < 1) continue;
      if (timetable.isOnlineWeek(week)) continue;
      
      final classes = timetable.getEventsForDay(futureDate);
      if (classes.isNotEmpty) {
        classes.sort((a,b) => a.startTime.compareTo(b.startTime));
        final first = classes.first;
        final dayLabel = d == 1 ? "Tomorrow" : DateFormat('EEEE').format(futureDate);
        return {'session': first, 'timeStatus': "$dayLabel at ${first.startTime}", 'dayLabel': dayLabel};
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryBlue = const Color(0xFF2962FF); 
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1D1E);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<TimetableProvider>(
          builder: (context, timetable, child) {
             final today = DateFormat('EEEE').format(DateTime.now()); 
             final todayClasses = timetable.getEventsForDay(DateTime.now());
             todayClasses.sort((a,b) => a.startTime.compareTo(b.startTime));
             
             // Smart next class finder
             final nextInfo = _findNextUpcomingClass(timetable);
             final nextClass = nextInfo != null ? nextInfo['session'] as ClassSession : null;
             final timeStatus = nextInfo?['timeStatus'] ?? '';
             final dayLabel = nextInfo?['dayLabel'] ?? '';
             final isInClass = nextInfo?['inClass'] == true;
             
             // Check week status
             final currentWeek = timetable.getWeekNumber(DateTime.now());
             final isOnline = currentWeek >= 1 && timetable.isOnlineWeek(currentWeek);
             final isWeekend = DateTime.now().weekday >= 6;
             
             // Status message for the hero card
             String heroSubject;
             String heroDetail;
             IconData heroIcon;
             List<Color> heroGradient;
             
             if (nextClass != null) {
               heroSubject = nextClass.subject;
               heroDetail = "${nextClass.room} • $timeStatus";
               heroIcon = isInClass ? Icons.school_rounded : Icons.menu_book_rounded;
               heroGradient = isInClass 
                 ? [const Color(0xFF00C853), const Color(0xFF009624)]
                 : isDark 
                   ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                   : [const Color(0xFF2979FF), const Color(0xFF1565C0)];
             } else if (isOnline) {
               heroSubject = "Online Week";
               heroDetail = "Week $currentWeek • No campus classes";
               heroIcon = Icons.laptop_mac_rounded;
               heroGradient = isDark 
                 ? [const Color(0xFFE65100), const Color(0xFFBF360C)]
                 : [const Color(0xFFFF9800), const Color(0xFFE65100)];
             } else if (isWeekend) {
               heroSubject = "Weekend Break";
               heroDetail = "Enjoy your time off!";
               heroIcon = Icons.weekend_rounded;
               heroGradient = isDark
                 ? [const Color(0xFF6A1B9A), const Color(0xFF4A148C)]
                 : [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)];
             } else if (currentWeek < 1) {
               heroSubject = "Semester Not Started";
               final start = DateTime(2026, 1, 19);
               final diff = start.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
               heroDetail = diff > 0 ? "Starts in $diff days" : "Check your schedule";
               heroIcon = Icons.event_note_rounded;
               heroGradient = [Colors.grey[600]!, Colors.grey[800]!];
             } else {
               heroSubject = "All Done for Today!";
               heroDetail = "No more classes — enjoy your evening";
               heroIcon = Icons.celebration_rounded;
               heroGradient = isDark
                 ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                 : [const Color(0xFF2979FF), const Color(0xFF1565C0)];
             }
             
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                DateFormat('MMMM d').format(DateTime.now()),
                                style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  if (currentWeek < 1) {
                                     final start = DateTime(2026, 1, 19);
                                     final now = DateTime.now();
                                     final diff = start.difference(DateTime(now.year, now.month, now.day)).inDays;
                                     
                                     return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3))
                                        ),
                                        child: Text(
                                          diff > 0 ? "Starts in $diff days" : "Semester Active",
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
                                        ),
                                     );
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOnline 
                                          ? (isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.withOpacity(0.1))
                                          : (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOnline 
                                            ? (isDark ? Colors.orangeAccent : Colors.orange.withOpacity(0.3))
                                            : (isDark ? Colors.blueAccent : Colors.blue.withOpacity(0.3)),
                                        width: 1
                                      )
                                    ),
                                    child: Text(
                                      "Week $currentWeek • ${isOnline ? "Online" : "Campus"}", 
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.bold,
                                        color: isOnline 
                                            ? (isDark ? Colors.orangeAccent : Colors.orange[800])
                                            : (isDark ? Colors.blueAccent : Colors.blue[800])
                                      ),
                                    ),
                                  );
                                }
                              )
                            ],
                          ),
                          const SizedBox(height: 4),
                           Text(
                            "Hey, Student!",
                            style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE3F2FD),
                          child: Icon(Icons.person, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // Status Counters 
                  Builder(builder: (context) {
                    // Check if all today's classes are done
                    final nowMins = DateTime.now().hour * 60 + DateTime.now().minute;
                    final allClassesDone = todayClasses.isNotEmpty && todayClasses.every((s) {
                      final endParts = s.endTime.split(":");
                      final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                      return nowMins >= endMins;
                    });
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        allClassesDone 
                          ? _buildStatusCard("✓", "All Done", const Color(0xFF4CAF50), true, isDark)
                          : _buildStatusCard(todayClasses.length.toString(), "Today", primaryBlue, todayClasses.isNotEmpty, isDark), 
                        _buildStatusCard(timetable.pendingTasks.length.toString(), "Pending", textPrimary, false, isDark),
                        _buildStatusCard(timetable.completedTasks.length.toString(), "Done", const Color(0xFF4CAF50), timetable.completedTasks.isNotEmpty, isDark),
                      ],
                    );
                  }),

                  const SizedBox(height: 30),

                  // Featured Card (Next Class / Status)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: heroGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: heroGradient[0].withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(heroIcon, color: Colors.white, size: 24),
                            ),
                            if (dayLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                              )
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          heroSubject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroDetail,
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        if (nextClass != null) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showClassDetailsSheet(context, nextClass),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: heroGradient[1],
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                              child: const Text("View Class Details"),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 34),
                  
                  if (timetable.pendingTasks.isNotEmpty) ...[
                     Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text("Next Deadline", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                        ],
                     ),
                     const SizedBox(height: 16),
                     // Show nearest deadline first (sorted by date)
                     Builder(builder: (context) {
                       final sorted = List<AcademicTask>.from(timetable.pendingTasks);
                       sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                       return _buildDeadlineCard(sorted.first, isDark: isDark);
                     }),
                     const SizedBox(height: 34),
                  ],

                  // Today's Schedule Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text("Today's Schedule", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                       TextButton(onPressed: () {}, child: Text("See All", style: TextStyle(color: textSecondary, fontSize: 16))),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  if (todayClasses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              isOnline ? Icons.laptop_mac : (isWeekend ? Icons.weekend : Icons.free_breakfast),
                              size: 40, color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isOnline ? "Online week — no campus classes" 
                                : isWeekend ? "It's the weekend!" 
                                : "No classes scheduled for $today.",
                              style: TextStyle(color: textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...todayClasses.map((session) {
                       final colorIndex = session.subject.hashCode.abs() % 4;
                       final colors = [
                         const Color(0xFF69F0AE),
                         const Color(0xFFFFD180),
                         const Color(0xFFEA80FC),
                         const Color(0xFF40C4FF),
                       ];
                       final bgColor = colors[colorIndex];
                       
                       // Highlight currently-in-progress class / done class
                       final nowMins = DateTime.now().hour * 60 + DateTime.now().minute;
                       final startParts = session.startTime.split(":");
                       final endParts = session.endTime.split(":");
                       final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                       final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                       final isNow = nowMins >= startMins && nowMins < endMins;
                       final isDone = nowMins >= endMins;
                       
                       return _buildScheduleItem(
                         "${session.startTime} - ${session.endTime}", 
                         session.subject, 
                         session.room, 
                         bgColor, 
                         isDark,
                         isActive: isNow,
                         isDone: isDone,
                         session: session,
                       );
                    }).toList(),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildStatusCard(String count, String label, Color color, bool isActive, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isActive ? color : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(28),
          boxShadow: isActive ? [
             BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))
          ] : [
             if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: isActive ? null : Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isActive ? Colors.white.withOpacity(0.9) : Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String time, String title, String subtitle, Color bgColor, bool isDark, {bool isActive = false, bool isDone = false, ClassSession? session}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: session != null ? () => _showClassDetailsSheet(context, session) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDone 
            ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08))
            : (isDark ? bgColor.withOpacity(0.15) : bgColor.withOpacity(0.25)), 
          borderRadius: BorderRadius.circular(26),
          border: isActive ? Border.all(color: bgColor, width: 2) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time.split(' - ')[0], style: TextStyle(color: isDone ? textColor.withOpacity(0.4) : textColor.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 13, decoration: isDone ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 4),
                Text(time.split(' - ')[1], style: TextStyle(color: isDone ? textColor.withOpacity(0.3) : textColor.withOpacity(0.5), fontWeight: FontWeight.w600, fontSize: 13, decoration: isDone ? TextDecoration.lineThrough : null)),
              ],
            ),
            const SizedBox(width: 20),
            Container(height: 42, width: 2, color: isDone ? textColor.withOpacity(0.05) : textColor.withOpacity(0.1)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: TextStyle(color: isDone ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w700, fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null))),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Text("NOW", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      if (isDone && !isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1), 
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: isDark ? Colors.green[300] : Colors.green[700]),
                              const SizedBox(width: 3),
                              Text("Done", style: TextStyle(color: isDark ? Colors.green[300] : Colors.green[700], fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: isDone ? textColor.withOpacity(0.3) : textColor.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineCard(dynamic task, {bool isDark = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final diff = taskDate.difference(today).inDays;
    
    Color baseColor;
    IconData icon;
    
    if (diff <= 3) {
       baseColor = Colors.redAccent;
       icon = Icons.warning_amber_rounded;
    } else if (diff <= 7) {
       baseColor = Colors.orangeAccent;
       icon = Icons.priority_high_rounded;
    } else {
       baseColor = const Color(0xFF2962FF);
       icon = Icons.event_available_rounded;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context, 
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AddEditTaskSheet(taskToEdit: task)
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(isDark ? 0.05 : 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: baseColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: baseColor.withOpacity(0.1), shape: BoxShape.circle),
               child: Icon(icon, color: baseColor),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                   const SizedBox(height: 4),
                   Text("Due: ${DateFormat('MMM d, h:mm a').format(task.dueDate)}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                 ],
               )
             ),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)),
               child: Text(task.subject, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.black54)),
             )
          ],
        ),
      ),
    );
  }

  void _showClassDetailsSheet(BuildContext context, ClassSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(session.subject, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            Text("${session.startTime} - ${session.endTime} • ${session.room}", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 30),
            
            Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.assignment_add, 
                    label: "Add Homework", 
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Provider.of<TimetableProvider>(context, listen: false).addTask(
                        "Homework for ${session.subject}", 
                        session.subject, 
                        "Homework", 
                        DateTime.now().add(const Duration(days: 7))
                      );
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Homework added to Board!")));
                    }
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.notification_add_rounded, 
                    label: "Set Reminder", 
                    color: Colors.orangeAccent,
                    onTap: () {
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder set for 15 min before!")));
                    }
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      )
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3))
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}
