import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/note_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Pastel note colours (text on them stays dark in both themes).
const noteColors = <Color>[
  Color(0xFFFFF8E1),
  Color(0xFFE3EBFF),
  Color(0xFFF3E5F5),
  Color(0xFFE8F5E9),
  Color(0xFFFFEBEE),
  Color(0xFFE0F7FA),
  Color(0xFFFFF3E0),
  Color(0xFFFCE4EC),
];

void showNoteEditor(BuildContext context, {Note? note}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NoteEditorSheet(note: note, colors: noteColors),
  );
}

/// Notes grid, embedded in the Files & Notes page (it no longer brings its
/// own Scaffold/AppBar, which caused the doubled header).
class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  String _query = '';
  String? _subject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NoteProvider>().loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final notes = context.watch<NoteProvider>().notes;
    final subjects = notes.map((n) => n.subject).where((s) => s.isNotEmpty && s != 'General').toSet().toList()..sort();
    final q = _query.toLowerCase();
    final filtered = notes.where((n) {
      if (_subject != null && n.subject != _subject) return false;
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q) || n.subject.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search notes…', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (subjects.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final s in [null, ...subjects])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s ?? 'All'),
                      selected: _subject == s,
                      showCheckmark: false,
                      selectedColor: p.ink,
                      labelStyle: TextStyle(color: _subject == s ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _subject = s),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: notes.isEmpty ? 'Empty canvas' : 'No matches',
                  subtitle: notes.isEmpty ? 'Jot down ideas, formulas, lecture takeaways.' : null,
                  action: notes.isEmpty
                      ? InkPillButton(label: 'New note', icon: Icons.add, onPressed: () => showNoteEditor(context))
                      : null,
                )
              : LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 3 : 2);
                  final columns = List.generate(cols, (_) => <Widget>[]);
                  for (var i = 0; i < filtered.length; i++) {
                    columns[i % cols].add(_NoteCard(note: filtered[i]));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < cols; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: Column(children: columns[i])),
                        ],
                      ],
                    ),
                  );
                }),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final color = noteColors[note.colorIndex % noteColors.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => showNoteEditor(context, note: note),
          onLongPress: () => context.read<NoteProvider>().togglePin(note),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.subject.isNotEmpty && note.subject != 'General')
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
                          child: Text(note.subject.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.black87)),
                        ),
                      )
                    else
                      const Spacer(),
                    if (note.isPinned == true) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin_rounded, size: 14, color: Colors.black54),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(note.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.2, color: Colors.black)),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note.content, maxLines: 8, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.7), height: 1.45)),
                ],
                const SizedBox(height: 10),
                Text(DateFormat('d MMM').format(note.timestamp), style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoteEditorSheet extends StatefulWidget {
  final Note? note;
  final List<Color> colors;

  const NoteEditorSheet({super.key, this.note, required this.colors});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _subjectController;
  late int _selectedColorIndex;
  late bool _isNew;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _isNew = widget.note == null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _subjectController = TextEditingController(text: widget.note?.subject == 'General' ? '' : (widget.note?.subject ?? ''));
    _pinned = widget.note?.isPinned ?? false;
    _selectedColorIndex = widget.note != null
        ? widget.note!.colorIndex % widget.colors.length
        : Random().nextInt(widget.colors.length);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final provider = context.read<NoteProvider>();
    final note = widget.note ?? Note(timestamp: DateTime.now());
    note
      ..title = title.isEmpty ? content.split('\n').first : title
      ..content = content
      ..subject = _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim()
      ..colorIndex = _selectedColorIndex
      ..isPinned = _pinned
      ..timestamp = DateTime.now();
    Navigator.pop(context);
    await provider.updateNote(note);
  }

  Future<void> _delete() async {
    final provider = context.read<NoteProvider>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final removed = await provider.deleteNote(widget.note!.id);
    if (removed == null) return;
    messenger.showSnackBar(SnackBar(
      content: const Text('Note deleted'),
      action: SnackBarAction(label: 'Undo', onPressed: () => provider.restoreNote(removed)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = widget.colors[_selectedColorIndex];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 10, left: 20, right: 12),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              IconButton(
                tooltip: _pinned ? 'Unpin' : 'Pin',
                icon: Icon(_pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: Colors.black87),
                onPressed: () => setState(() => _pinned = !_pinned),
              ),
              if (!_isNew)
                IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _delete),
              const SizedBox(width: 4),
              Material(
                color: Colors.black,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(widget.colors.length, (index) {
                final isSelected = _selectedColorIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.black : Colors.black12, width: isSelected ? 2 : 1),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: const InputDecoration.collapsed(hintText: 'Title', hintStyle: TextStyle(color: Colors.black38), filled: false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectController,
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
            decoration: const InputDecoration.collapsed(hintText: 'Module / tag', hintStyle: TextStyle(color: Colors.black26), filled: false),
          ),
          Divider(height: 26, color: p.isDark ? Colors.black26 : Colors.black12),
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 17, height: 1.5, color: Colors.black),
              decoration: const InputDecoration.collapsed(hintText: 'Start writing…', hintStyle: TextStyle(color: Colors.black38), filled: false),
            ),
          ),
        ],
      ),
    );
  }
}
