import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../services/bus_service.dart'; // import if needed
import 'planning_screen.dart';
import '../models/class_session.dart';
import '../models/academic_task.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  
  @override
  void initState() {
    super.initState();
    // Load data once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimetableProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium Vibrant Colors
    final primaryBlue = const Color(0xFF2962FF); // Stronger electric blue
    final secondaryPurple = const Color(0xFF6200EA);
    final softBg = Colors.white; 
    const textDark = Color(0xFF1A1D1E);
    
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: Consumer<TimetableProvider>(
          builder: (context, timetable, child) {
             final today = DateFormat('EEEE').format(DateTime.now()); // e.g., "Friday"
             final todayClasses = timetable.getEventsForDay(DateTime.now());
             
             // Sort by time
             todayClasses.sort((a,b) => a.startTime.compareTo(b.startTime));
             
             // Find next class
             final now = DateTime.now();
             final nowMinutes = now.hour * 60 + now.minute;
             
             ClassSession? nextClass;
             String timeStatus = "No more classes today";
             
             for (var s in todayClasses) {
               final parts = s.startTime.split(":");
               final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
               if (startMinutes > nowMinutes) {
                 nextClass = s;
                 final diff = startMinutes - nowMinutes;
                 if (diff < 60) {
                   timeStatus = "Starts in ${diff}m";
                 } else {
                   final h = diff ~/ 60;
                   final m = diff % 60;
                   timeStatus = "Starts in ${h}h ${m}m";
                 }
                 break;
               }
             }

             // If currently in a class? (Optional logic, simpler for now)
             
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
                                style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              // Week Badge
                              Builder(
                                builder: (context) {
                                  final week = timetable.getWeekNumber(DateTime.now());
                                  final isOnline = timetable.isOnlineWeek(week);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOnline ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                                        width: 1
                                      )
                                    ),
                                    child: Text(
                                      "Week $week • ${isOnline ? "Online" : "Campus"}",
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.bold,
                                        color: isOnline ? Colors.orange[800] : Colors.blue[800]
                                      ),
                                    ),
                                  );
                                }
                              )
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Hey, Student!",
                            style: TextStyle(color: textDark, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE3F2FD),
                          child: Icon(Icons.person, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // Status Counters (Real Data: Total Classes Today)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusCard(timetable.tasks.length.toString(), "All Tasks", primaryBlue, false), // Or 'Classes' if preferred to keep classes
                      _buildStatusCard(timetable.pendingTasks.length.toString(), "Pending", textDark, false),
                      _buildStatusCard(timetable.completedTasks.length.toString(), "Done", const Color(0xFF4CAF50), timetable.completedTasks.isNotEmpty),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Featured Card (Next Class)
                  // Use a strictly defined container height to avoid layout shifts? No, auto is fine.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF2979FF), const Color(0xFF1565C0)], // Material Blue A400 -> 800
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2979FF).withOpacity(0.4),
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
                              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                            ),
                            if (nextClass != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text("${timetable.userSessions.length} Total", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1565C0))),
                              )
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          nextClass?.subject ?? "No upcoming classes",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          nextClass != null ? "${nextClass.room} • $timeStatus" : "Enjoy your free time!",
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                               if (nextClass != null) {
                                 _showClassDetailsSheet(context, nextClass);
                               } else {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No upcoming classes to view!")));
                               }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1565C0),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            child: const Text("View Class Details"), // Or "Interact" / "Options"
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 34),
                  
                  if (timetable.pendingTasks.isNotEmpty) ...[
                     Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Next Deadline", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1D1E))),
                        ],
                     ),
                     const SizedBox(height: 16),
                     _buildDeadlineCard(timetable.pendingTasks.first), // They are sorted by date in provider
                     const SizedBox(height: 34),
                  ],

                  // Today's Schedule Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Today's Schedule", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
                      TextButton(onPressed: () {
                         // Navigate to timetable?
                      }, child: Text("See All", style: TextStyle(color: Colors.grey[500], fontSize: 16))),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // List Real Classes
                  if (todayClasses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text("No classes scheduled for $today.", style: TextStyle(color: Colors.grey[400])),
                      ),
                    )
                  else
                    ...todayClasses.map((session) {
                       // Generate a consistent pastel color based on module name hash
                       final colorIndex = session.subject.hashCode.abs() % 4;
                       final colors = [
                         const Color(0xFF69F0AE), // Green
                         const Color(0xFFFFD180), // Orange
                         const Color(0xFFEA80FC), // Purple
                         const Color(0xFF40C4FF), // Light Blue
                       ];
                       final bgColor = colors[colorIndex];
                       
                       return _buildScheduleItem(
                         "${session.startTime} - ${session.endTime}", 
                         session.subject, 
                         session.room, 
                         bgColor, 
                         Colors.black87
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

  Widget _buildStatusCard(String count, String label, Color color, bool isActive) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5), // spacing
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isActive ? [
             BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))
          ] : [
             BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)) // Subtle shadow for inactive
          ],
          border: isActive ? null : Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold, 
                color: isActive ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white.withOpacity(0.9) : Colors.grey[500]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String time, String title, String subtitle, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.25), 
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time.split(' - ')[0],
                style: TextStyle(color: textColor.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                time.split(' - ')[1],
                style: TextStyle(color: textColor.withOpacity(0.5), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Divider
          Container(height: 42, width: 2, color: textColor.withOpacity(0.1)),
          const SizedBox(width: 20),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Action Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
            child: Icon(Icons.more_horiz, color: textColor.withOpacity(0.7), size: 18),
          )
        ],
      ),
    );
  }

  Widget _buildDeadlineCard(dynamic task) {
    // task is AcademicTask
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
             child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                 const SizedBox(height: 4),
                 Text("Due: ${DateFormat('MMM d, h:mm a').format(task.dueDate)}", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
               ],
             )
           ),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
             child: Text(task.subject, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
           )
        ],
      ),
    );
  }

  void _showClassDetailsSheet(BuildContext context, ClassSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(session.subject, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("${session.startTime} - ${session.endTime} • ${session.room}", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 30),
            
            const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      // Add task for this subject
                      Provider.of<TimetableProvider>(context, listen: false).addTask(
                        "Homework for ${session.subject}", 
                        session.subject, 
                        "Assignment", 
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
                       // Just a mock for now
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
