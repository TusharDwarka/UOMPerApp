import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'module_resources_screen.dart';
import 'unsorted_inbox_screen.dart';
import 'pdf_viewer_screen.dart';

/// Files: module folders and custom folders (Notes has its own page).
class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key});

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {

  Future<void> _newFolder() async {
    final name = await showControllerDialog<String>(
      context,
      builder: (ctx, controller) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Internship, Final Year Project'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final ok = await context.read<ResourceProvider>().addCustomFolder(name);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A folder with that name already exists')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Files',
              eyebrow: 'Lecture slides, past papers & more',
              actions: [
                CircleIconButton(icon: Icons.create_new_folder_rounded, filled: true, tooltip: 'New folder', onPressed: _newFolder),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(child: _FilesView()),
          ],
        ),
      ),
    );
  }
}

class _FilesView extends StatefulWidget {
  const _FilesView();

  @override
  State<_FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<_FilesView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final resources = context.watch<ResourceProvider>();
    final timetable = context.watch<TimetableProvider>();

    final modules = {...resources.moduleNames, ...timetable.userSessions.map((s) => s.subject)}
        .where((m) => !resources.customFolders.contains(m) && !resources.isHidden(m))
        .toList()
      ..sort();
    final custom = resources.customFolders;
    final hidden = resources.hiddenFolders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Search all files…', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        const SizedBox(height: 14),
        if (_query.isNotEmpty) ..._searchResults(p, resources),
        if (_query.isEmpty) ...[
          if (resources.unsortedCount > 0) ...[
            SoftCard(
              radius: 24,
              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.35)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnsortedInboxScreen())),
              child: Row(
                children: [
                  const Icon(Icons.move_to_inbox_rounded, color: Colors.deepOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Unsorted inbox · ${resources.unsortedCount} to file',
                        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.deepOrange),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          SectionLabel('Modules', trailing: Text('${modules.length}', style: TextStyle(color: p.textMuted))),
          if (modules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Add classes in Schedule and a folder appears for each module.', style: TextStyle(color: p.textSecondary)),
            )
          else
            _grid(modules, resources, false),
          const SizedBox(height: 22),
          SectionLabel('My folders', trailing: Text('${custom.length}', style: TextStyle(color: p.textMuted))),
          if (custom.isEmpty)
            Text('Create folders for anything outside your modules — tap the folder button above.',
                style: TextStyle(color: p.textSecondary))
          else
            _grid(custom, resources, true),
          if (hidden.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text('Show hidden folders (${hidden.length})'),
                  onPressed: () async {
                    final folder = await showChoiceSheet<String>(
                      context,
                      title: 'Restore a folder',
                      options: hidden,
                      selected: null,
                      labelOf: (f) => f,
                      iconOf: (_) => Icons.folder_off_outlined,
                    );
                    if (folder != null) resources.unhideFolder(folder);
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _searchResults(Palette p, ResourceProvider resources) {
    final hits = resources.search(_query);
    if (hits.isEmpty) return [Padding(padding: const EdgeInsets.all(20), child: Text('No files match', style: TextStyle(color: p.textSecondary)))];
    return [
      for (final f in hits)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => PdfViewerScreen.isPdf(f.fileName)
                ? PdfViewerScreen.openFile(context, f.filePath, title: f.fileName)
                : OpenFilex.open(f.filePath),
            child: Row(
              children: [
                Icon(fileIcon(f.fileName), color: fileIconColor(f.fileName)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                      Text('${f.moduleName} / ${f.category}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _grid(List<String> folders, ResourceProvider resources, bool custom) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: folders.length,
        itemBuilder: (context, i) => _FolderCard(name: folders[i], count: resources.getResourcesForModule(folders[i]).length, custom: custom),
      );
    });
  }
}

class _FolderCard extends StatelessWidget {
  final String name;
  final int count;
  final bool custom;
  const _FolderCard({required this.name, required this.count, required this.custom});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final color = AppColors.eventPalette[h % AppColors.eventPalette.length];

    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleResourcesScreen(moduleName: name))),
      onLongPress: () => confirmDeleteFolder(context, name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(custom ? Icons.folder_special_rounded : Icons.folder_rounded, color: color, size: 22),
              ),
              const Spacer(),
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: p.textPrimary)),
              SizedBox(
                width: 30,
                height: 30,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Folder options',
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: p.textSecondary),
                  onSelected: (_) => confirmDeleteFolder(context, name),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete folder'))],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.2, color: p.textPrimary)),
          Text(count == 1 ? '1 file' : '$count files', style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ],
      ),
    );
  }
}

IconData fileIcon(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_rounded;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_rounded;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'webp':
      return Icons.image_rounded;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_rounded;
    case 'py':
    case 'java':
    case 'dart':
    case 'ipynb':
    case 'c':
    case 'cpp':
      return Icons.code_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color fileIconColor(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'pdf':
      return Colors.redAccent;
    case 'doc':
    case 'docx':
      return Colors.blueAccent;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Colors.green;
    case 'ppt':
    case 'pptx':
      return Colors.orangeAccent;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'webp':
      return Colors.purpleAccent;
    case 'zip':
    case 'rar':
    case '7z':
      return Colors.brown;
    default:
      return Colors.blueGrey;
  }
}


/// Confirms, then deletes a folder and its files (module folders are hidden
/// so the timetable doesn't bring them straight back).
Future<bool> confirmDeleteFolder(BuildContext context, String name) async {
  final prov = context.read<ResourceProvider>();
  final count = prov.getResourcesForModule(name).length;
  final ok = await confirmDestructive(
    context,
    title: 'Delete "$name"?',
    message: count == 0
        ? 'The folder will be removed. You can restore it later from "Show hidden folders".'
        : "This deletes the folder and its $count file${count == 1 ? '' : 's'} from this device. This can't be undone.",
    action: 'Delete folder',
  );
  if (!ok) return false;
  await prov.deleteFolder(name);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "$name"')));
  }
  return true;
}
