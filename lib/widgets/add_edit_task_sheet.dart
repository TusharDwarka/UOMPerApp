import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import 'scroll_time_picker.dart';
import 'ui.dart';

const taskTypes = ['Assignment', 'Homework', 'Test', 'Exam', 'Project', 'Event', 'Other'];

/// Opens the task/event editor. Used by the board, Academic Hub, dashboard
/// and schedule quick actions so they all behave the same.
Future<void> showTaskSheet(
  BuildContext context, {
  AcademicTask? task,
  String? initialType,
  String? initialModule,
  DateTime? initialDate,
  String? initialStatus,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddEditTaskSheet(
      taskToEdit: task,
      initialCategory: initialType,
      initialModule: initialModule,
      initialDate: initialDate,
      initialStatus: initialStatus,
    ),
  );
}

/// Deletes with an Undo snackbar (used by every delete entry point).
/// Pass [provider]/[messenger] when the calling widget is about to close.
Future<void> deleteTaskWithUndo(
  BuildContext context,
  AcademicTask task, {
  TimetableProvider? provider,
  ScaffoldMessengerState? messenger,
}) async {
  final prov = provider ?? context.read<TimetableProvider>();
  final msg = messenger ?? ScaffoldMessenger.of(context);
  final removed = await prov.deleteTask(task.id);
  if (removed == null) return;
  msg.hideCurrentSnackBar();
  msg.showSnackBar(SnackBar(
    content: Text('Deleted "${removed.title}"'),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Undo', onPressed: () => prov.restoreTask(removed)),
  ));
}

class AddEditTaskSheet extends StatefulWidget {
  final AcademicTask? taskToEdit;
  final String? initialCategory;
  final String? initialModule;
  final DateTime? initialDate;
  final String? initialStatus;

  const AddEditTaskSheet({
    super.key,
    this.taskToEdit,
    this.initialCategory,
    this.initialModule,
    this.initialDate,
    this.initialStatus,
  });

  @override
  State<AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends State<AddEditTaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _note;
  late final TextEditingController _room;
  late final TextEditingController _link;
  final _subjectFocus = FocusNode();
  late String _type;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  DateTime? _startDate;
  bool _multiDay = false;
  int? _color;
  late String _status;
  int _priority = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _title = TextEditingController(text: t?.title ?? '');
    _subject = TextEditingController(text: t?.subject == 'General' ? '' : (t?.subject ?? widget.initialModule ?? ''));
    _type = t?.type ?? widget.initialCategory ?? 'Assignment';
    if (!taskTypes.contains(_type)) _type = 'Other';

    final base = t?.dueDate ?? widget.initialDate ?? DateTime.now();
    _dueDate = dateOnly(base);
    _dueTime = t != null ? TimeOfDay.fromDateTime(t.dueDate) : const TimeOfDay(hour: 23, minute: 59);
    _startDate = t?.startDate;
    _multiDay = t?.isSpanning ?? false;
    _color = t?.colorValue;
    _status = t?.effectiveStatus ?? widget.initialStatus ?? TaskStatus.todo;
    _priority = t?.priority ?? 1;

    var note = '';
    var room = '';
    if (t != null && t.description.isNotEmpty) {
      final parts = t.description.split('\n---ROOM---\n');
      note = parts[0];
      if (parts.length > 1) room = parts[1];
    }
    _note = TextEditingController(text: note);
    _room = TextEditingController(text: room);
    _link = TextEditingController(text: t?.meetingLink ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _note.dispose();
    _room.dispose();
    _link.dispose();
    _subjectFocus.dispose();
    super.dispose();
  }

  String _buildDescription() {
    final n = _note.text.trim();
    final r = _room.text.trim();
    if (r.isEmpty) return n;
    return '$n\n---ROOM---\n$r';
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give it a title');
      return;
    }
    final link = _link.text.trim();
    if (link.isNotEmpty && !MeetingLinks.isValid(link)) {
      setState(() => _error = 'That meeting link doesn\'t look right');
      return;
    }
    final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day, _dueTime.hour, _dueTime.minute);
    DateTime? start;
    if (_multiDay && _startDate != null) {
      start = dateOnly(_startDate!);
      if (start.isAfter(dateOnly(due))) {
        setState(() => _error = 'Start date must be before the end date');
        return;
      }
    }

    final provider = context.read<TimetableProvider>();
    final task = widget.taskToEdit ?? AcademicTask(dueDate: due);
    task
      ..title = title
      ..subject = _subject.text.trim().isEmpty ? 'General' : _subject.text.trim()
      ..type = _type
      ..dueDate = due
      ..description = _buildDescription()
      ..startDate = start
      ..colorValue = _color
      ..meetingLink = MeetingLinks.normalize(link)
      ..status = _status
      ..priority = _priority
      ..isCompleted = _status == TaskStatus.done;

    Navigator.pop(context);
    await provider.saveTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isEditing = widget.taskToEdit != null;
    final subjects = context.read<TimetableProvider>().savedSubjects;
    final showRoom = _type == 'Exam' || _type == 'Test' || _type == 'Event' || _room.text.isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(color: p.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(isEditing ? 'Edit' : 'New ${_type.toLowerCase()}',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: -0.8, color: p.textPrimary)),
                      ),
                      if (isEditing)
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () async {
                            final ok = await confirmDestructive(context,
                                title: 'Delete?', message: 'Delete "${widget.taskToEdit!.title}"?');
                            if (!ok || !context.mounted) return;
                            final task = widget.taskToEdit!;
                            final provider = context.read<TimetableProvider>();
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            await deleteTaskWithUndo(context, task, provider: provider, messenger: messenger);
                          },
                        ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(22, 6, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  TextField(
                    controller: _title,
                    autofocus: !isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
                    decoration: const InputDecoration(hintText: 'What is it?'),
                  ),
                  const SizedBox(height: 14),
                  _label('Type'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: taskTypes.map((t) {
                      final sel = t == _type;
                      return ChoiceChip(
                        label: Text(t),
                        selected: sel,
                        showCheckmark: false,
                        selectedColor: p.ink,
                        backgroundColor: p.surfaceAlt,
                        labelStyle: TextStyle(color: sel ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _type = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  RawAutocomplete<String>(
                    textEditingController: _subject,
                    focusNode: _subjectFocus,
                    optionsBuilder: (v) {
                      final q = v.text.toLowerCase();
                      return subjects.where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q);
                    },
                    fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                      controller: controller,
                      focusNode: focus,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Module / subject', prefixIcon: Icon(Icons.menu_book_rounded)),
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        color: p.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            children: options
                                .map((o) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.history_rounded, size: 18),
                                      title: Text(o),
                                      onTap: () => onSelected(o),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('When'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Spans several days'),
                    subtitle: const Text('e.g. exam week, field trip, hackathon'),
                    value: _multiDay,
                    onChanged: (v) => setState(() {
                      _multiDay = v;
                      _startDate ??= _dueDate.subtract(const Duration(days: 1));
                    }),
                  ),
                  Row(
                    children: [
                      if (_multiDay) ...[
                        Expanded(
                          child: _pickerBox(
                            p,
                            'Starts',
                            DateFormat('EEE d MMM').format(_startDate ?? _dueDate),
                            Icons.first_page_rounded,
                            () async {
                              final d = await _pickDate(_startDate ?? _dueDate);
                              if (d != null) setState(() => _startDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _pickerBox(
                          p,
                          _multiDay ? 'Ends' : 'Due',
                          DateFormat('EEE d MMM').format(_dueDate),
                          Icons.event_rounded,
                          () async {
                            final d = await _pickDate(_dueDate);
                            if (d != null) setState(() => _dueDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _pickerBox(p, 'Time', _dueTime.format(context), Icons.schedule_rounded, () async {
                          FocusScope.of(context).unfocus();
                          final t = await showScrollTimePicker(context: context, initialTime: _dueTime);
                          if (t != null) setState(() => _dueTime = t);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('Colour on calendar'),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _colorDot(p, null),
                        for (final c in AppColors.eventPalette) _colorDot(p, c.toARGB32()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Board column'),
                  PillSegmented<String>(
                    values: TaskStatus.all,
                    selected: _status,
                    labelOf: TaskStatus.label,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Priority', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Low')),
                          ButtonSegment(value: 1, label: Text('Normal')),
                          ButtonSegment(value: 2, label: Text('High')),
                        ],
                        selected: {_priority},
                        onSelectionChanged: (s) => setState(() => _priority = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('Online meeting'),
                  TextField(
                    controller: _link,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Paste a Google Meet / Teams / Zoom link',
                      prefixIcon: const Icon(Icons.videocam_outlined),
                      suffixIcon: MeetingLinks.isValid(_link.text)
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: TagPill(MeetingLinks.label(_link.text).replaceFirst('Join ', ''),
                                  color: MeetingLinks.color(_link.text)),
                            )
                          : null,
                    ),
                  ),
                  if (showRoom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _room,
                      decoration: const InputDecoration(labelText: 'Room / location', prefixIcon: Icon(Icons.location_on_outlined)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    minLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 22),
                  InkPillButton(label: isEditing ? 'Save changes' : 'Add', icon: Icons.check_rounded, expand: true, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Palette.of(context).textMuted)),
      );

  Widget _pickerBox(Palette p, String label, String value, IconData icon, VoidCallback onTap) {
    return SoftCard(
      color: p.surfaceAlt,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: p.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: p.textSecondary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
        ],
      ),
    );
  }

  Widget _colorDot(Palette p, int? value) {
    final selected = _color == value;
    final c = value == null ? AppColors.forType(_type) : Color(value);
    return GestureDetector(
      onTap: () => setState(() => _color = value),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? p.ink : Colors.transparent, width: 3),
        ),
        child: value == null
            ? const Center(child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))
            : (selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
      ),
    );
  }
}
