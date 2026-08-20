import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import 'notes_tab.dart'; // We embed the existing notes tab here
import 'module_resources_screen.dart';
import 'unsorted_inbox_screen.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key});

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Resources Hub', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          bottom: TabBar(
            labelColor: const Color(0xFF2962FF),
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey,
            indicatorColor: const Color(0xFF2962FF),
            tabs: const [
              Tab(text: "Files & Folders"),
              Tab(text: "Creative Notes"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _FilesView(),
            // We reuse the existing NotesTab, but we might need to wrap it if it has its own scaffold/appbar
            // NotesTab has an AppBar. To avoid double appbars, we might need to conditionally hide it,
            // but for now let's just nest it. It's acceptable.
            const NotesTab(),
          ],
        ),
      ),
    );
  }
}

class _FilesView extends StatelessWidget {
  const _FilesView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<ResourceProvider, TimetableProvider>(
      builder: (context, resourceProv, timetableProv, child) {
        final unsortedCount = resourceProv.unsortedCount;
        final savedModules = resourceProv.moduleNames;
        // Also include any modules from the user's timetable that might not have files yet
        final allModules = {...savedModules, ...timetableProv.userSessions.map((s) => s.subject)}.toList();
        allModules.sort();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (unsortedCount > 0) ...[
              _buildUnsortedCard(context, unsortedCount, isDark),
              const SizedBox(height: 20),
            ],
            Text("My Modules", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            if (allModules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text("No modules yet. Add classes in the Schedule tab or share a file here.", style: TextStyle(color: Colors.grey[500]))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: allModules.length,
                itemBuilder: (context, index) {
                  return _buildModuleCard(context, allModules[index], resourceProv, isDark);
                },
              )
          ],
        );
      },
    );
  }

  Widget _buildUnsortedCard(BuildContext context, int count, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UnsortedInboxScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFFF4F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.move_to_inbox_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Unsorted Inbox", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  Text("$count file${count > 1 ? 's' : ''} to sort", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, String moduleName, ResourceProvider provider, bool isDark) {
    final fileCount = provider.getResourcesForModule(moduleName).length;
    // Generate a consistent color based on string
    final hue = (moduleName.hashCode.abs() % 360).toDouble();
    final color = HSVColor.fromAHSV(1.0, hue, 0.6, 0.9).toColor();

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleResourcesScreen(moduleName: moduleName)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.folder_shared_rounded, color: color),
            ),
            const Spacer(),
            Flexible(
              child: Text(moduleName, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isDark ? Colors.white : Colors.black87)),
            ),
            const SizedBox(height: 4),
            Text("$fileCount files", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
