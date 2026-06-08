import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/resource_provider.dart';
import '../models/module_resource.dart';

class ModuleResourcesScreen extends StatelessWidget {
  final String moduleName;

  const ModuleResourcesScreen({super.key, required this.moduleName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(moduleName, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF2962FF),
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey,
            indicatorColor: const Color(0xFF2962FF),
            tabs: const [
              Tab(text: "Lectures"),
              Tab(text: "Tutorials"),
              Tab(text: "Past Papers"),
              Tab(text: "Assignments"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CategoryList(moduleName: moduleName, category: "Lectures"),
            _CategoryList(moduleName: moduleName, category: "Tutorials"),
            _CategoryList(moduleName: moduleName, category: "Past Papers"),
            _CategoryList(moduleName: moduleName, category: "Assignments"),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final String moduleName;
  final String category;

  const _CategoryList({required this.moduleName, required this.category});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double d = bytes.toDouble();
    while (d > 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return "${d.toStringAsFixed(1)} ${suffixes[i]}";
  }

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

    return Consumer<ResourceProvider>(
      builder: (context, provider, child) {
        final files = provider.getResourcesForModuleAndCategory(moduleName, category);

        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text("No files here yet", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return Dismissible(
              key: Key('file_${file.id}'),
              background: Container(
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                provider.deleteResource(file.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File deleted")));
              },
              child: Card(
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
                  subtitle: Row(
                    children: [
                      Text(_formatBytes(file.fileSizeBytes), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      if (file.sourceApp == 'whatsapp')
                        Icon(Icons.message, size: 12, color: Colors.green[400]),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      _showFileOptions(context, file, provider);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFileOptions(BuildContext context, ModuleResource file, ResourceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text("Move to another category"),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: implement move dialog
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Delete", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  provider.deleteResource(file.id);
                },
              ),
            ],
          ),
        );
      }
    );
  }
}
