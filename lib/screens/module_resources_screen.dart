import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../models/module_resource.dart';
import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'resources_tab.dart' show fileIcon, fileIconColor;

/// One folder (module or custom) split into user-editable sections.
class ModuleResourcesScreen extends StatefulWidget {
  final String moduleName;
  const ModuleResourcesScreen({super.key, required this.moduleName});

  @override
  State<ModuleResourcesScreen> createState() => _ModuleResourcesScreenState();
}

class _ModuleResourcesScreenState extends State<ModuleResourcesScreen> {
  String? _section;

  String get _folder => widget.moduleName;

  Future<String?> _askName(String title, {String initial = ''}) async {
    final result = await showControllerDialog<String>(
      context,
      initial: initial, builder: (ctx, controller) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Labs, Revision, Group Project'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    return result;
  }

  Future<void> _addSection() async {
    final name = await _askName('New section');
    if (name == null || !mounted) return;
    final ok = await context.read<ResourceProvider>().addSection(_folder, name);
    if (!mounted) return;
    if (ok) {
      setState(() => _section = name.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That section already exists')));
    }
  }

  void _sectionMenu(String section) {
    if (section == ResourceProvider.fallbackSection) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('"General" is the default section and can\'t be removed')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: section,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename section'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await _askName('Rename section', initial: section);
                if (name == null || !mounted) return;
                final ok = await context.read<ResourceProvider>().renameSection(_folder, section, name);
                if (ok && mounted) setState(() => _section = name.trim());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete section', style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Files move to General'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDestructive(context,
                    title: 'Delete "$section"?', message: 'Its files will be moved to General.', action: 'Delete section');
                if (!ok || !mounted) return;
                await context.read<ResourceProvider>().deleteSection(_folder, section);
                setState(() => _section = ResourceProvider.fallbackSection);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFile(String section) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    final prov = context.read<ResourceProvider>();
    var added = 0;
    for (final f in result.files) {
      if (f.path == null) continue;
      await prov.addResource(sourceFilePath: f.path!, fileName: f.name, moduleName: _folder, category: section, sourceApp: 'manual');
      added++;
    }
    if (mounted && added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $added file${added == 1 ? '' : 's'} to $section')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final prov = context.watch<ResourceProvider>();
    final sections = prov.sectionsFor(_folder);
    final current = sections.contains(_section) ? _section! : sections.first;
    final files = prov.getResourcesForModuleAndCategory(_folder, current);

    return Scaffold(
      backgroundColor: p.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFile(current),
        icon: const Icon(Icons.upload_file_rounded),
        label: Text('Add to $current', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            ScreenHeader(
              title: _folder,
              eyebrow: '${prov.getResourcesForModule(_folder).length} files · ${sections.length} sections',
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final s in sections)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: () => _sectionMenu(s),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text('$s  ${prov.getResourcesForModuleAndCategory(_folder, s).length}'),
                          selected: s == current,
                          selectedColor: p.ink,
                          backgroundColor: p.surface,
                          labelStyle: TextStyle(color: s == current ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                          onSelected: (_) => setState(() => _section = s),
                        ),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Section'),
                    onPressed: _addSection,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 6),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 13, color: p.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Hold a section to rename or delete it', style: TextStyle(fontSize: 11, color: p.textMuted)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: files.isEmpty
                  ? EmptyState(icon: Icons.folder_open_rounded, title: 'No files in $current', subtitle: 'Tap "Add" or share files here from WhatsApp.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: files.length,
                      itemBuilder: (context, i) => _FileRow(file: files[i], folder: _folder),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final ModuleResource file;
  final String folder;
  const _FileRow({required this.file, required this.folder});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var d = bytes.toDouble();
    while (d > 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _open(BuildContext context) async {
    final result = await OpenFilex.open(file.filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: ${result.message}')));
    }
  }

  Future<void> _move(BuildContext context) async {
    final prov = context.read<ResourceProvider>();
    final folders = {
      ...prov.moduleNames,
      ...context.read<TimetableProvider>().userSessions.map((s) => s.subject),
      ...prov.customFolders,
    }.toList()
      ..sort();
    var targetFolder = folder;
    var targetSection = file.category;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final sections = prov.sectionsFor(targetFolder);
          if (!sections.contains(targetSection)) targetSection = sections.first;
          return SheetScaffold(
            title: 'Move file',
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: targetFolder,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Folder'),
                    items: folders.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setSheet(() => targetFolder = v ?? targetFolder),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in sections)
                        ChoiceChip(label: Text(s), selected: targetSection == s, onSelected: (_) => setSheet(() => targetSection = s)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  InkPillButton(label: 'Move', expand: true, onPressed: () => Navigator.pop(ctx, true)),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok == true) {
      await prov.moveResource(file.id, targetFolder, targetSection);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved to $targetFolder / $targetSection')));
      }
    }
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showControllerDialog<String>(
      context,
      initial: file.fileName, builder: (ctx, controller) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != file.fileName && context.mounted) {
      await context.read<ResourceProvider>().renameResource(file.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        onTap: () => _open(context),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: fileIconColor(file.fileName).withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(fileIcon(file.fileName), color: fileIconColor(file.fileName)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  Row(
                    children: [
                      Text(_formatBytes(file.fileSizeBytes), style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      if (file.sourceApp == 'whatsapp') ...[
                        const SizedBox(width: 6),
                        Icon(Icons.chat_rounded, size: 12, color: Colors.green[400]),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'move':
                    await _move(context);
                  case 'rename':
                    await _rename(context);
                  case 'delete':
                    final ok = await confirmDestructive(context, title: 'Delete file?', message: 'Delete "${file.fileName}" from this device?');
                    if (ok && context.mounted) await context.read<ResourceProvider>().deleteResource(file.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'move', child: Text('Move to…')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
