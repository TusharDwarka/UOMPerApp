import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/note_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'print_center_screen.dart';

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
  showAppSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    desktopWidth: 760,
    builder: (_) => NoteEditorSheet(note: note, colors: noteColors),
  );
}

/// Bumped by the header's "New note": the wide desktop layout creates the
/// note inline; everywhere else it opens the editor sheet.
final _newNoteRequests = ValueNotifier<int>(0);

/// Notes as their own section (no longer tucked under Files).
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final count = context.select<NoteProvider, int>((n) => n.notes.length);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Notes',
              badge: CountBadge(count),
              eyebrow: 'Ideas, formulas, checklists',
              actions: [
                CircleIconButton(
                  icon: Icons.print_rounded,
                  tooltip: 'Print note paper',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrintCenterScreen(initialTab: 1))),
                ),
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'New note',
                  onPressed: () => isDesktopPlatform ? _newNoteRequests.value++ : showNoteEditor(context),
                ),
              ],
            ),
            const Expanded(child: NotesView()),
          ],
        ),
      ),
    );
  }
}

/// Notes grid (it no longer brings its
/// own Scaffold/AppBar, which caused the doubled header).
class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  String _query = '';
  String? _subject;

  // Desktop two-pane state.
  bool _wide = false;
  int? _selectedId; // note open in the editor pane
  bool _creating = false; // editor pane holds a new, unsaved note
  int _editorKey = 0; // bumps only when the user switches notes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NoteProvider>().loadNotes());
    _newNoteRequests.addListener(_onNewNote);
  }

  @override
  void dispose() {
    _newNoteRequests.removeListener(_onNewNote);
    super.dispose();
  }

  void _onNewNote() {
    if (!mounted) return;
    if (_wide) {
      _newInline();
    } else {
      showNoteEditor(context);
    }
  }

  void _newInline() => setState(() {
        _creating = true;
        _selectedId = null;
        _editorKey++;
      });

  void _open(Note n) {
    if (!_creating && n.id == _selectedId) return;
    setState(() {
      _creating = false;
      _selectedId = n.id;
      _editorKey++;
    });
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

    return LayoutBuilder(builder: (context, c) {
      _wide = wideDesktop(c);
      if (_wide) return _desktop(p, notes, filtered, subjects);
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
                  action:
                      notes.isEmpty ? InkPillButton(label: 'New note', icon: Icons.add, onPressed: () => showNoteEditor(context)) : null,
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
    });
  }

  /// PC: list of notes on the left, the open note on the right (saved as
  /// you type), like a desktop notes app.
  Widget _desktop(Palette p, List<Note> notes, List<Note> filtered, List<String> subjects) {
    Note? selected;
    if (!_creating) {
      for (final n in notes) {
        if (n.id == _selectedId) selected = n;
      }
      // Nothing chosen yet (or it was deleted): open the first note.
      if (selected == null && filtered.isNotEmpty) {
        selected = filtered.first;
        _selectedId = selected.id;
      }
    }

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: TextField(
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search notes',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
              prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 34),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Row(children: [
          if (subjects.isNotEmpty)
            Flexible(
              child: ChoicePill<String>(
                title: 'Module',
                value: _subject ?? '',
                options: ['', ...subjects],
                labelOf: (s) => s.isEmpty ? 'All modules' : s,
                onChanged: (s) => setState(() => _subject = s.isEmpty ? null : s),
              ),
            ),
          const Spacer(),
          Text('${filtered.length} ${filtered.length == 1 ? 'note' : 'notes'}', style: TextStyle(fontSize: 12, color: p.textMuted)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(notes.isEmpty ? 'No notes yet' : 'No matches', style: TextStyle(color: p.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final n = filtered[i];
                    return _NoteRow(note: n, selected: !_creating && n.id == _selectedId, onTap: () => _open(n));
                  },
                ),
        ),
      ],
    );

    final Widget editor = _creating || selected != null
        ? NoteEditorSheet(
            key: ValueKey(_editorKey),
            note: _creating ? null : selected,
            colors: noteColors,
            embedded: true,
            onSaved: (n) => setState(() {
              _creating = false;
              _selectedId = n.id;
            }),
            onDeleted: () => setState(() {
              _creating = false;
              _selectedId = null;
              _editorKey++;
            }),
          )
        : EmptyState(
            icon: Icons.sticky_note_2_outlined,
            title: 'Empty canvas',
            subtitle: 'Jot down ideas, formulas, lecture takeaways.',
            action: InkPillButton(label: 'New note', icon: Icons.add, onPressed: _newInline),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 300, child: list),
          const SizedBox(width: 16),
          Expanded(child: editor),
        ],
      ),
    );
  }
}

/// One line in the desktop note list: colour dot, title, first line, date.
class _NoteRow extends StatelessWidget {
  final Note note;
  final bool selected;
  final VoidCallback onTap;
  const _NoteRow({required this.note, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = noteColors[note.colorIndex % noteColors.length];
    final firstLine = note.content
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^(# |• |- |☐ |☑ )'), '').replaceAll('**', '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final now = DateTime.now();
    final date = _sameDay(note.timestamp, now)
        ? DateFormat('HH:mm').format(note.timestamp)
        : DateFormat(note.timestamp.year == now.year ? 'd MMM' : 'd MMM yyyy').format(note.timestamp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: HoverTap(
        onTap: onTap,
        builder: (hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: selected ? p.surface : (hover ? p.textPrimary.withValues(alpha: 0.04) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected ? p.softShadow : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.textPrimary)),
                  ),
                  if (note.isPinned == true) Icon(Icons.push_pin_rounded, size: 12, color: p.textMuted),
                ]),
                const SizedBox(height: 2),
                Text(
                  [date, if (note.subject.isNotEmpty && note.subject != 'General') note.subject, if (firstLine.isNotEmpty) firstLine]
                      .join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
        borderRadius: BorderRadius.circular(isDesktopPlatform ? 14 : 26),
        child: InkWell(
          borderRadius: BorderRadius.circular(isDesktopPlatform ? 14 : 26),
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
                          child: Text(note.subject.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  NoteBody(
                    text: note.content,
                    maxLines: 10,
                    fontSize: 14,
                    onToggle: (line) {
                      note.content = toggleChecklistLine(note.content, line);
                      context.read<NoteProvider>().updateNote(note);
                    },
                  ),
                  if (checklistProgress(note.content) != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: checklistProgress(note.content),
                        minHeight: 5,
                        backgroundColor: Colors.black.withValues(alpha: 0.08),
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 10),
                Text(DateFormat('d MMM').format(note.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.4))),
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

  /// Desktop pane instead of a sheet: no close/Save, saves as you type.
  final bool embedded;
  final ValueChanged<Note>? onSaved;
  final VoidCallback? onDeleted;

  const NoteEditorSheet({
    super.key,
    this.note,
    required this.colors,
    this.embedded = false,
    this.onSaved,
    this.onDeleted,
  });

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
  bool _preview = false;
  final _contentFocus = FocusNode();

  // Embedded autosave.
  late final NoteProvider _provider;
  Note? _note;
  Timer? _debounce;
  bool _dirty = false;
  bool _saved = false;
  Future<void> _writes = Future.value(); // keeps saves in order (no duplicate inserts)

  @override
  void initState() {
    super.initState();
    _provider = context.read<NoteProvider>();
    _note = widget.note;
    _isNew = widget.note == null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _subjectController = TextEditingController(text: widget.note?.subject == 'General' ? '' : (widget.note?.subject ?? ''));
    _pinned = widget.note?.isPinned ?? false;
    _selectedColorIndex = widget.note != null ? widget.note!.colorIndex % widget.colors.length : Random().nextInt(widget.colors.length);
    _contentFocus.addListener(() => setState(() {}));
    if (widget.embedded) {
      for (final c in [_titleController, _contentController, _subjectController]) {
        c.addListener(_changed);
      }
      if (_isNew) WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocus.requestFocus());
    }
  }

  final _titleFocus = FocusNode();
  String _lastSnapshot = '';

  String get _snapshot =>
      '${_titleController.text}\u0000${_contentController.text}\u0000${_subjectController.text}\u0000$_selectedColorIndex\u0000$_pinned';

  /// Something changed in the embedded editor: save shortly after typing stops.
  void _changed() {
    if (!widget.embedded || _snapshot == _lastSnapshot) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _persist);
    if (_saved && mounted) setState(() => _saved = false);
  }

  /// Writes the note without closing anything (embedded mode).
  void _persist() {
    _debounce?.cancel();
    if (!_dirty) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return; // never store blank notes
    _dirty = false;
    _lastSnapshot = _snapshot;
    final firstSave = _note == null;
    final note = _note ??= Note(timestamp: DateTime.now());
    note
      ..title = title.isEmpty ? content.split('\n').first : title
      ..content = content
      ..subject = _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim()
      ..colorIndex = _selectedColorIndex
      ..isPinned = _pinned
      ..timestamp = DateTime.now();
    _writes = _writes.then((_) => _provider.updateNote(note)).then((_) {
      if (!mounted) return;
      setState(() {
        _isNew = false;
        _saved = true;
      });
      if (firstSave) widget.onSaved?.call(note);
    });
  }

  @override
  void dispose() {
    if (widget.embedded) _persist(); // switching notes keeps what was typed
    _debounce?.cancel();
    _titleFocus.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _subjectController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  // ── Formatting helpers (markdown-like, stored as plain text) ──

  static const _linePrefixes = ['# ', '• ', '☐ ', '☑ '];

  /// Toggles [prefix] on the line under the cursor (replacing another list
  /// prefix if present).
  void _toggleLinePrefix(String prefix) {
    final c = _contentController;
    final text = c.text;
    final sel = c.selection.isValid ? c.selection : TextSelection.collapsed(offset: text.length);
    final lineStart = sel.start <= 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
    final line = text.substring(lineStart);
    var existing = '';
    for (final p in _linePrefixes) {
      if (line.startsWith(p)) existing = p;
    }
    final same = existing == prefix || (prefix == '☐ ' && existing == '☑ ');
    final insert = same ? '' : prefix;
    final newText = text.replaceRange(lineStart, lineStart + existing.length, insert);
    final delta = insert.length - existing.length;
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (sel.end + delta).clamp(lineStart, newText.length)),
    );
    setState(() {});
  }

  void _toggleBold() {
    final c = _contentController;
    final text = c.text;
    final sel = c.selection.isValid ? c.selection : TextSelection.collapsed(offset: text.length);
    final selected = text.substring(sel.start, sel.end);
    final newText = text.replaceRange(sel.start, sel.end, '**$selected**');
    c.value = TextEditingValue(
      text: newText,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: sel.start + 2)
          : TextSelection(baseOffset: sel.start, extentOffset: sel.end + 4),
    );
    setState(() {});
  }

  /// Pressing Enter on a bullet/checklist line continues the list; Enter on
  /// an empty item ends it.
  void _continueList(String value) {
    final c = _contentController;
    final pos = c.selection.baseOffset;
    if (pos <= 0 || pos > value.length || value[pos - 1] != '\n') return;
    final prevStart = pos - 1 <= 0 ? 0 : value.lastIndexOf('\n', pos - 2) + 1;
    final prev = value.substring(prevStart, pos - 1);
    for (final p in const ['• ', '☐ ', '☑ ']) {
      if (prev.startsWith(p)) {
        if (prev.trim() == p.trim()) {
          final t = value.replaceRange(prevStart, pos, '');
          c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: prevStart));
        } else {
          final cont = p == '☑ ' ? '☐ ' : p;
          final t = value.replaceRange(pos, pos, cont);
          c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + cont.length));
        }
        return;
      }
    }
  }

  /// Jumps the editor to [offset] (switching out of preview).
  void _jumpTo(int offset) {
    setState(() => _preview = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocus.requestFocus();
      _contentController.selection = TextSelection.collapsed(offset: offset.clamp(0, _contentController.text.length));
    });
  }

  /// Outline (headings) + find-in-note, for long notes.
  Future<void> _openNavigator() async {
    FocusScope.of(context).unfocus();
    final text = _contentController.text;
    final lines = text.split('\n');
    final starts = <int>[];
    var pos = 0;
    for (final l in lines) {
      starts.add(pos);
      pos += l.length + 1;
    }
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    final target = await showAppSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final p = Palette.of(ctx);
          final results = <(int, String, bool)>[]; // offset, label, isHeading
          if (query.isEmpty) {
            for (var i = 0; i < lines.length; i++) {
              if (lines[i].startsWith('# ')) results.add((starts[i], lines[i].substring(2), true));
            }
          } else {
            final q = query.toLowerCase();
            for (var i = 0; i < lines.length; i++) {
              final idx = lines[i].toLowerCase().indexOf(q);
              if (idx >= 0) results.add((starts[i] + idx, lines[i].trim(), false));
            }
          }
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            child: SheetScaffold(
              title: 'Outline & find',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${lines.length} lines · $words words', style: TextStyle(color: p.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: false,
                    decoration: const InputDecoration(hintText: 'Find in this note…', prefixIcon: Icon(Icons.search_rounded)),
                    onChanged: (v) => setSheet(() => query = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: InkPillButton(label: 'Top', icon: Icons.vertical_align_top_rounded, onPressed: () => Navigator.pop(ctx, 0))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkPillButton(
                          label: 'Bottom', icon: Icons.vertical_align_bottom_rounded, onPressed: () => Navigator.pop(ctx, text.length)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        query.isEmpty ? 'Add headings with the H button to build an outline.' : 'No matches',
                        style: TextStyle(color: p.textSecondary),
                      ),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in results)
                          ListTile(
                            dense: true,
                            leading: Icon(r.$3 ? Icons.title_rounded : Icons.subdirectory_arrow_right_rounded, size: 18),
                            title: Text(r.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.pop(ctx, r.$1),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    if (target != null) _jumpTo(target);
  }

  Widget _tool(IconData icon, String tip, VoidCallback? onTap) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: onTap == null ? Colors.black26 : Colors.black87),
      );

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
    if (widget.embedded) {
      _debounce?.cancel();
      _dirty = false;
      await _writes;
      widget.onDeleted?.call();
    } else {
      Navigator.pop(context);
    }
    final removed = await provider.deleteNote((_note ?? widget.note)!.id);
    if (removed == null) return;
    messenger.showSnackBar(SnackBar(
      content: const Text('Note deleted'),
      persist: false, // Flutter keeps action snackbars forever by default
      action: SnackBarAction(label: 'Undo', onPressed: () => provider.restoreNote(removed)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = widget.colors[_selectedColorIndex];
    final mq = MediaQuery.of(context);
    // With the keyboard up the writing area used to shrink to a sliver on
    // small phones: use the full height and tuck away the colour/tag rows.
    final typing = mq.viewInsets.bottom > 0;
    final writing = typing && _contentFocus.hasFocus;

    final editor = Container(
      height: isDesktopPlatform ? double.infinity : (typing ? mq.size.height - mq.padding.top : mq.size.height * 0.88),
      decoration: BoxDecoration(color: bg, borderRadius: sheetRadius),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 10, left: 20, right: 12),
      child: Column(
        children: [
          if (!isDesktopPlatform)
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
          Row(
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    _saved ? 'Saved' : (_dirty ? 'Editing…' : (_isNew ? 'New note' : 'Edited ${DateFormat('d MMM, HH:mm').format((_note ?? widget.note)!.timestamp)}')),
                    style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                  ),
                )
              else
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              IconButton(
                tooltip: 'Outline & find',
                icon: const Icon(Icons.toc_rounded, color: Colors.black87),
                onPressed: _openNavigator,
              ),
              IconButton(
                tooltip: _pinned ? 'Unpin' : 'Pin',
                icon: Icon(_pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: Colors.black87),
                onPressed: () {
                  setState(() => _pinned = !_pinned);
                  _changed();
                },
              ),
              if (!_isNew)
                IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _delete),
              const SizedBox(width: 4),
              if (!widget.embedded)
              Material(
                color: Colors.black,
                shape: isDesktopPlatform ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const StadiumBorder(),
                child: InkWell(
                  customBorder: isDesktopPlatform ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const StadiumBorder(),
                  onTap: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          if (!typing) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(widget.colors.length, (index) {
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedColorIndex = index);
                      _changed();
                    },
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
          ],
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: const InputDecoration.collapsed(hintText: 'Title', hintStyle: TextStyle(color: Colors.black38), filled: false),
          ),
          if (!writing) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
              decoration:
                  const InputDecoration.collapsed(hintText: 'Module / tag', hintStyle: TextStyle(color: Colors.black26), filled: false),
            ),
          ],
          Divider(height: 26, color: p.isDark ? Colors.black26 : Colors.black12),
          Expanded(
            child: _preview
                ? SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: NoteBody(
                        text: _contentController.text,
                        fontSize: 17,
                        onToggle: (line) => setState(() {
                          _contentController.text = toggleChecklistLine(_contentController.text, line);
                        }),
                      ),
                    ),
                  )
                : TextField(
                    controller: _contentController,
                    focusNode: _contentFocus,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: _continueList,
                    style: const TextStyle(fontSize: 17, height: 1.5, color: Colors.black),
                    decoration: const InputDecoration.collapsed(
                        hintText: 'Start writing… the toolbar below adds headings, bold, lists and checklists',
                        hintStyle: TextStyle(color: Colors.black38),
                        filled: false),
                  ),
          ),
          // Formatting toolbar sits just above the keyboard.
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 10, right: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(40)),
            child: Row(
              children: [
                _tool(Icons.title_rounded, 'Heading', _preview ? null : () => _toggleLinePrefix('# ')),
                _tool(Icons.format_bold_rounded, 'Bold', _preview ? null : _toggleBold),
                _tool(Icons.format_list_bulleted_rounded, 'Bullet list', _preview ? null : () => _toggleLinePrefix('• ')),
                _tool(Icons.check_box_outlined, 'Checklist', _preview ? null : () => _toggleLinePrefix('☐ ')),
                const Spacer(),
                Flexible(
                  child: Material(
                    color: _preview ? Colors.black : Colors.transparent,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() {
                        _preview = !_preview;
                        if (_preview) FocusScope.of(context).unfocus();
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(_preview ? 'Edit' : 'Preview',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: _preview ? Colors.white : Colors.black87)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!isDesktopPlatform) return editor;
    // The desktop theme outlines focused fields; on the note paper the
    // title and body read as plain writing surfaces instead.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      child: editor,
    );
  }
}

// ───────────── Lightweight note formatting ─────────────
// Stored as plain text so it syncs and searches as before:
//   "# " heading · "• " or "- " bullet · "☐ "/"☑ " checklist · **bold**

String toggleChecklistLine(String text, int lineIndex) {
  final lines = text.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return text;
  final l = lines[lineIndex];
  if (l.startsWith('☐ ')) {
    lines[lineIndex] = '☑ ${l.substring(2)}';
  } else if (l.startsWith('☑ ')) {
    lines[lineIndex] = '☐ ${l.substring(2)}';
  }
  return lines.join('\n');
}

/// Fraction of checklist items ticked, or null if the note has none.
double? checklistProgress(String text) {
  var total = 0, done = 0;
  for (final l in text.split('\n')) {
    if (l.startsWith('☐ ')) total++;
    if (l.startsWith('☑ ')) {
      total++;
      done++;
    }
  }
  return total == 0 ? null : done / total;
}

class NoteBody extends StatelessWidget {
  final String text;
  final int? maxLines;
  final double fontSize;
  final ValueChanged<int>? onToggle;

  const NoteBody({super.key, required this.text, this.maxLines, this.fontSize = 15, this.onToggle});

  List<TextSpan> _inline(String s) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, height: 1.45, color: Colors.black.withValues(alpha: 0.78));
    final lines = text.split('\n');
    final shown = maxLines == null ? lines.length : lines.length.clamp(0, maxLines!);
    final children = <Widget>[];
    for (var i = 0; i < shown; i++) {
      final l = lines[i];
      if (l.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(TextSpan(children: _inline(l.substring(2))),
              style: base.copyWith(fontSize: fontSize + 4, fontWeight: FontWeight.w800, color: Colors.black)),
        ));
      } else if (l.startsWith('☐ ') || l.startsWith('☑ ')) {
        final done = l.startsWith('☑ ');
        // Only the box toggles: a tap on the text falls through to the card,
        // so checklist-heavy notes still open when tapped.
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle == null ? null : () => onToggle!(i),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
                  child: Icon(done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: fontSize + 6, color: done ? Colors.black87 : Colors.black45),
                ),
              ),
              Expanded(
                child: Text.rich(TextSpan(children: _inline(l.substring(2))),
                    style: base.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.black38 : base.color,
                    )),
              ),
            ],
          ),
        ));
      } else if (l.startsWith('• ') || l.startsWith('- ')) {
        children.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: base.copyWith(fontWeight: FontWeight.w900)),
            Expanded(child: Text.rich(TextSpan(children: _inline(l.substring(2))), style: base)),
          ],
        ));
      } else {
        children.add(Text.rich(TextSpan(children: _inline(l)), style: base));
      }
    }
    if (shown < lines.length) children.add(Text('…', style: base.copyWith(color: Colors.black38)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
