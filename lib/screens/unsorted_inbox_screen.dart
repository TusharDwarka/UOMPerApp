import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/module_resource.dart';

class UnsortedInboxScreen extends StatelessWidget {
  const UnsortedInboxScreen({super.key});

  void _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      debugPrint("Could not open file: ${result.message}");
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.article;
      case 'png':
      case 'jpg':
      case 'jpeg': return Icons.image;
      case 'zip':
      case 'rar': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf': return Colors.redAccent;
      case 'doc':
      case 'docx': return Colors.blueAccent;
      case 'xls':
      case 'xlsx': return Colors.green;
      case 'ppt':
      case 'pptx': return Colors.orangeAccent;
      case 'txt': return Colors.grey;
      case 'png':
      case 'jpg':
      case 'jpeg': return Colors.purpleAccent;
      case 'zip':
      case 'rar': return Colors.brown;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Unsorted Inbox", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Consumer<ResourceProvider>(
        builder: (context, provider, child) {
          final files = provider.unsortedResources;

          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Inbox is empty! Great job.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF252525) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => _openFile(file.filePath),
                  leading: Icon(_getFileIcon(file.fileName), color: _getFileIconColor(file.fileName), size: 32),
                  title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text("Added ${file.addedAt.day}/${file.addedAt.month}/${file.addedAt.year}", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showSortDialog(context, file, provider),
                    child: const Text("Sort"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSortDialog(BuildContext context, ModuleResource file, ResourceProvider resourceProv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final timetable = Provider.of<TimetableProvider>(context, listen: false);
        final modules = timetable.userSessions.map((s) => s.subject).toSet().toList();
        modules.sort();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sort to Module", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: modules.map((m) => ActionChip(
                  label: Text(m),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCategoryDialog(context, file, m, resourceProv);
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Delete File", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  resourceProv.deleteResource(file.id);
                },
              )
            ],
          ),
        );
      }
    );
  }

  void _showCategoryDialog(BuildContext context, ModuleResource file, String moduleName, ResourceProvider resourceProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final categories = ['Lectures', 'Tutorials', 'Past Papers', 'Assignments'];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Category for $moduleName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...categories.map((c) => ListTile(
                title: Text(c),
                leading: const Icon(Icons.folder_open),
                onTap: () {
                  Navigator.pop(context);
                  resourceProv.moveResource(file.id, moduleName, c);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved to $moduleName / $c")));
                },
              ))
            ],
          ),
        );
      }
    );
  }
}
