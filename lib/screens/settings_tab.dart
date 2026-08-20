import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../providers/timetable_provider.dart';
import '../widgets/end_semester_dialog.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadReminderPreference();
  }

  Future<void> _loadReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remindersEnabled = prefs.getBool('class_reminders_enabled') ?? true;
    });
  }

  Future<void> _toggleReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value) {
      final granted = await NotificationService().requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permissions denied.')));
        }
        return;
      }
    }
    
    await prefs.setBool('class_reminders_enabled', value);
    setState(() {
      _remindersEnabled = value;
    });
    
    // When turned ON, immediately schedule reminders for all upcoming classes
    if (value && mounted) {
      final timetable = Provider.of<TimetableProvider>(context, listen: false);
      NotificationService().scheduleAllUpcomingClasses(
        timetable.userSessions,
        getEventsForDay: (date) => timetable.getEventsForDay(date),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xFF3949AB), const Color(0xFF1A237E)] 
                    : [const Color(0xFF5C6BC0), const Color(0xFF1A237E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF1A237E), size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("UOMPerApp", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Version 1.0.0", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Appearance Section
            const Text("APPEARANCE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.dark_mode_rounded, color: Colors.purple),
                    ),
                    title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Consumer<ThemeProvider>(
                      builder: (context, provider, _) {
                        return DropdownButton<ThemeMode>(
                          value: provider.themeMode,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: const [
                             DropdownMenuItem(value: ThemeMode.system, child: Text("System")),
                             DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                             DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
                          ],
                          onChanged: (ThemeMode? newMode) {
                            if (newMode != null) {
                              provider.setTheme(newMode);
                            }
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // Notifications Section
            const Text("NOTIFICATIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.orange),
                    ),
                    title: const Text("Class Reminders", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Get notified 15 mins before class", style: TextStyle(fontSize: 12)),
                    value: _remindersEnabled,
                    onChanged: _toggleReminders,
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // Timetable Settings
            const Text("ACADEMIC PREFERENCES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Consumer<TimetableProvider>(
                builder: (context, provider, child) {
                  return Column(
                     children: [
                        ListTile(
                           leading: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
                             child: const Icon(Icons.class_rounded, color: Colors.indigo),
                           ),
                           title: const Text("My Course", style: TextStyle(fontWeight: FontWeight.bold)),
                           subtitle: Text(provider.courseName.isNotEmpty ? provider.courseName : "Not Set", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        ),
                     ],
                  );
                }
              ),
            ),

            const SizedBox(height: 30),

            // Data Management
            const Text("DATA & SYNC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                 boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.sync_rounded, color: Colors.blue),
                    ),
                    title: const Text("Re-import Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Upload a new schedule"),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () {
                       // We can just set hasCompletedSetup to false and navigate to OnboardingScreen.
                       // For safety, let's ask for confirmation first.
                       showDialog(
                        context: context, 
                        builder: (context) => AlertDialog(
                          title: const Text("Change Course / Timetable?"),
                          content: const Text("This will restart the setup process so you can upload a new timetable."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context); // Close dialog
                                final provider = Provider.of<TimetableProvider>(context, listen: false);
                                await provider.resetForNewSetup();
                              }, 
                              child: const Text("Continue", style: TextStyle(color: Colors.blue))
                            ),
                          ],
                        )
                      );
                    },
                  ),
                ],
              ),
            ),
             const SizedBox(height: 30),

            // University Resources
            const Text("UNIVERSITY RESOURCES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                 boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                   ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.language_rounded, color: Colors.blue),
                    ),
                    title: const Text("University Website", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("uom.ac.mu"),
                    trailing: const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 18),
                    onTap: () async {
                      final url = Uri.parse("https://uom.ac.mu"); 
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[100]),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.school_rounded, color: Colors.teal),
                    ),
                    title: const Text("Student Portal", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Access grades & modules"),
                    trailing: const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 18),
                    onTap: () async {
                      // Placeholder logic
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Student Portal...")));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Account Section
            const Text("ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.green),
                    ),
                    title: const Text("Signed In As", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.email ?? 
                      (FirebaseAuth.instance.currentUser?.isAnonymous == true ? "Guest (no sync)" : "Not signed in"),
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[100]),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.logout_rounded, color: Colors.red),
                    ),
                    title: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Switch accounts or sign out"),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Sign Out?"),
                          content: const Text("You will need to sign back in to sync your data."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await FirebaseAuth.instance.signOut();
                              },
                              child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Danger Zone
            const Text("DANGER ZONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.warning_rounded, color: Colors.red),
                    ),
                    title: const Text("End Semester", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text("Archive modules and start fresh"),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
                    onTap: () {
                      showDialog(
                        context: context, 
                        builder: (context) => const EndSemesterDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
