import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/resource_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Folder value meaning "leave it in the Unsorted inbox".
const unsortedFolder = 'Unsorted';

/// Folders a file can go to: module folders (timetable + ones holding files)
/// and the user's own, without the ones they deleted/hid.
List<String> availableFolders(ResourceProvider resources, TimetableProvider timetable) {
  return {
    ...resources.moduleNames,
    ...timetable.userSessions.map((s) => s.subject),
    ...resources.customFolders,
  }.where((f) => f.trim().isNotEmpty && f != unsortedFolder && !resources.isHidden(f)).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// One sheet with a folder dropdown and a section dropdown. Returns
/// (folder, section), or null when cancelled. With [allowUnsorted] the
/// folder list starts with "Unsorted (decide later)".
Future<(String, String)?> pickFolderAndSection(
  BuildContext context, {
  required String title,
  String? fileName,
  String? initialFolder,
  String? initialSection,
  bool allowUnsorted = false,
  String action = 'Save',
}) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderSheet(
      title: title,
      fileName: fileName,
      initialFolder: initialFolder,
      initialSection: initialSection,
      allowUnsorted: allowUnsorted,
      action: action,
    ),
  );
}

class _FolderSheet extends StatefulWidget {
  final String title;
  final String? fileName;
  final String? initialFolder;
  final String? initialSection;
  final bool allowUnsorted;
  final String action;
  const _FolderSheet({
    required this.title,
    this.fileName,
    this.initialFolder,
    this.initialSection,
    required this.allowUnsorted,
    required this.action,
  });

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  String? _folder;
  String? _section;

  @override
  void initState() {
    super.initState();
    _folder = widget.initialFolder;
    _section = widget.initialSection;
  }

  InputDecoration _deco(Palette p, String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: p.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final resources = context.watch<ResourceProvider>();
    final folders = availableFolders(resources, context.read<TimetableProvider>());
    final options = [
      if (widget.allowUnsorted) unsortedFolder,
      if (_folder != null && _folder != unsortedFolder && !folders.contains(_folder)) _folder!,
      ...folders,
    ];
    final folder = _folder;
    final isUnsorted = folder == unsortedFolder;
    final sections = folder == null || isUnsorted ? const <String>[] : resources.sectionsFor(folder);
    final section = sections.contains(_section) ? _section : (sections.isEmpty ? null : sections.first);
    final canSave = folder != null && (isUnsorted || section != null);

    return SheetScaffold(
      title: widget.title,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fileName != null) ...[
              Row(children: [
                Icon(Icons.insert_drive_file_outlined, size: 18, color: p.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.fileName!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary)),
                ),
              ]),
              const SizedBox(height: 16),
            ],
            if (options.isEmpty)
              Text('No folders yet — add classes in Schedule or create a folder in Files.', style: TextStyle(color: p.textSecondary))
            else
              DropdownButtonFormField<String>(
                initialValue: folder,
                isExpanded: true,
                borderRadius: BorderRadius.circular(18),
                menuMaxHeight: 420,
                decoration: _deco(p, 'Folder', Icons.folder_rounded),
                hint: const Text('Choose a folder'),
                items: [
                  for (final f in options)
                    DropdownMenuItem(
                      value: f,
                      child: Text(f == unsortedFolder ? 'Unsorted (decide later)' : f, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _folder = v;
                  _section = null;
                }),
              ),
            if (sections.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(folder), // reset when the folder changes
                initialValue: section,
                isExpanded: true,
                borderRadius: BorderRadius.circular(18),
                decoration: _deco(p, 'Section', Icons.folder_open_rounded),
                items: [
                  for (final s in sections) DropdownMenuItem(value: s, child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _section = v),
              ),
            ],
            const SizedBox(height: 20),
            InkPillButton(
              label: widget.action,
              icon: Icons.check_rounded,
              expand: true,
              onPressed: canSave ? () => Navigator.pop(context, (folder, isUnsorted ? unsortedFolder : section!)) : null,
            ),
          ],
        ),
      ),
    );
  }
}
