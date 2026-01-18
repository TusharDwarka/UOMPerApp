import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../providers/timetable_provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

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
                          onChanged: (mode) {
                             if(mode != null) provider.setTheme(mode);
                          },
                        );
                      }
                    ),
                  ),
                ],
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
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    ),
                    title: const Text("Reset Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Reloads default course data"),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () {
                      showDialog(
                        context: context, 
                        builder: (context) => AlertDialog(
                          title: const Text("Reset Timetable?"),
                          content: const Text("This will revert your schedule to the default module data. Custom edits may be lost."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final provider = Provider.of<TimetableProvider>(context, listen: false);
                                await provider.loadFriendTimetable();
                                if(context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Timetable reset successfully")));
                                }
                              }, 
                              child: const Text("Reset", style: TextStyle(color: Colors.red))
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
          ],
        ),
      ),
    );
  }
}
