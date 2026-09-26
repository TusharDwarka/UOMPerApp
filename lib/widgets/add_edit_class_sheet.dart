import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import 'scroll_time_picker.dart';
import 'ui.dart';

/// Add / edit a class. Returns a map (moduleName, moduleCode, location, day,
/// startTime, endTime, weeks, specificDate, meetingLink) or {'delete': true}.
class AddEditClassSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isEditing;

  const AddEditClassSheet({super.key, this.initialData, this.isEditing = false});

  @override
  State<AddEditClassSheet> createState() => _AddEditClassSheetState();
}

class _AddEditClassSheetState extends State<AddEditClassSheet> {
  late final TextEditingController _moduleNameCtrl;
  late final TextEditingController _moduleCodeCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _linkCtrl;
  final _moduleFocus = FocusNode();

  late String _selectedDay;
  late int _start; // minutes from midnight
  late int _end;
  bool _isOneOff = false;
  late DateTime _specificDate;
  bool _allowConflict = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _moduleNameCtrl = TextEditingController(text: d?['moduleName'] ?? '');
    _moduleCodeCtrl = TextEditingController(text: d?['moduleCode'] ?? '');
    _locationCtrl = TextEditingController(text: (d?['location'] == 'TBD') ? '' : (d?['location'] ?? ''));
    _linkCtrl = TextEditingController(text: d?['meetingLink'] ?? '');

    _selectedDay = WeekdayPicker.days.contains(d?['day']) ? d!['day'] : 'Monday';
    final parsedDate = d?['specificDate'] != null ? DateTime.tryParse(d!['specificDate'].toString()) : null;
    _isOneOff = d?['isTemporary'] ?? (parsedDate != null && widget.isEditing);
    _specificDate = dateOnly(parsedDate ?? DateTime.now());

    _start = parseMinutes(d?['startTime']) ?? 9 * 60;
    _end = parseMinutes(d?['endTime']) ?? _start + 60;
  }

  @override
  void dispose() {
    _moduleNameCtrl.dispose();
    _moduleCodeCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    _moduleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final m = start ? _start : _end;
    final picked = await showScrollTimePicker(context: context, initialTime: TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60));
    if (picked == null) return;
    setState(() {
      final v = picked.hour * 60 + picked.minute;
      _allowConflict = false;
      if (start) {
        final length = _end - _start;
        _start = v;
        _end = v + (length > 0 ? length : 60);
      } else {
        _end = v;
      }
    });
  }

  void _save() {
    setState(() => _errorMessage = null);
    final name = _moduleNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Enter the module name');
      return;
    }
    if (_end <= _start) {
      setState(() => _errorMessage = 'The class must end after it starts');
      return;
    }
    final link = _linkCtrl.text.trim();
    if (link.isNotEmpty && !MeetingLinks.isValid(link)) {
      setState(() => _errorMessage = "That meeting link doesn't look right");
      return;
    }

    final dayToSave = _isOneOff ? DateFormat('EEEE').format(_specificDate) : _selectedDay;

    // Conflict check (week-aware; a clash is a warning, tap Save again to keep both).
    if (!_allowConflict) {
      final provider = context.read<TimetableProvider>();
      final editId = widget.initialData?['id'];
      final myWeeks = List<int>.from(widget.initialData?['weeks'] ?? const []);
      bool weeksOverlap(List<int>? other) =>
          myWeeks.isEmpty || other == null || other.isEmpty || other.any(myWeeks.contains);

      for (final s in provider.userSessions) {
        if (editId != null && s.id == editId) continue;
        final sameSlot = _isOneOff
            ? (s.specificDate != null ? isSameDate(s.specificDate!, _specificDate) : s.day == dayToSave)
            : (s.day == dayToSave && s.specificDate == null);
        if (!sameSlot || !weeksOverlap(s.weeks)) continue;
        if (_start < s.endMinutes && _end > s.startMinutes) {
          setState(() {
            _errorMessage = 'Clashes with ${s.subject} (${s.startTime}–${s.endTime}). Tap Save again to keep both.';
            _allowConflict = true;
          });
          return;
        }
      }
    }

    Navigator.of(context).pop({
      'moduleName': name,
      'moduleCode': _moduleCodeCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty ? 'TBD' : _locationCtrl.text.trim(),
      'day': dayToSave,
      'startTime': formatMinutes(_start),
      'endTime': formatMinutes(_end),
      'weeks': widget.initialData?['weeks'] ?? [],
      'specificDate': _isOneOff ? _specificDate.toIso8601String() : null,
      'meetingLink': MeetingLinks.normalize(link),
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await confirmDestructive(context,
        title: 'Delete class?', message: 'Remove ${_moduleNameCtrl.text} from your timetable?');
    if (ok && mounted) Navigator.of(context).pop({'delete': true});
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final subjects = context.read<TimetableProvider>().savedSubjects;
    final length = _end - _start;

    return Padding(
      // Lifts the whole sheet above the keyboard so the field being typed in stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
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
                          child: Text(widget.isEditing ? 'Edit class' : 'Add class',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: -0.8, color: p.textPrimary)),
                        ),
                        if (widget.isEditing)
                          IconButton(
                            tooltip: 'Delete class',
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: _confirmDelete,
                          ),
                        IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                  children: [
                    // ── When (at the top) ──
                    _label(p, 'When'),
                    PillSegmented<bool>(
                      values: const [false, true],
                      selected: _isOneOff,
                      labelOf: (v) => v ? 'One-off date' : 'Every week',
                      onChanged: (v) => setState(() {
                        _isOneOff = v;
                        _allowConflict = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (!_isOneOff)
                      WeekdayPicker(
                        selected: _selectedDay,
                        onChanged: (d) => setState(() {
                          _selectedDay = d;
                          _allowConflict = false;
                        }),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(28)),
                        child: CalendarDatePicker(
                          initialDate: _specificDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                          onDateChanged: (d) => setState(() {
                            _specificDate = dateOnly(d);
                            _allowConflict = false;
                          }),
                        ),
                      ),
                    const SizedBox(height: 18),

                    // ── Time ──
                    _label(p, 'Time'),
                    Row(
                      children: [
                        Expanded(child: _timeBox(p, 'Starts', _start, () => _pickTime(true))),
                        const SizedBox(width: 10),
                        Expanded(child: _timeBox(p, 'Ends', _end, () => _pickTime(false), error: _end <= _start)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final len in const [60, 90, 120, 180])
                          ChoiceChip(
                            showCheckmark: false,
                            label: Text(formatCountdown(len)),
                            selected: length == len,
                            selectedColor: p.ink,
                            backgroundColor: p.surfaceAlt,
                            labelStyle: TextStyle(color: length == len ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                            onSelected: (_) => setState(() {
                              _end = _start + len;
                              _allowConflict = false;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Details ──
                    _label(p, 'Details'),
                    RawAutocomplete<String>(
                      textEditingController: _moduleNameCtrl,
                      focusNode: _moduleFocus,
                      optionsBuilder: (v) {
                        final q = v.text.toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return subjects.where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q);
                      },
                      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                        controller: controller,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Module name', prefixIcon: Icon(Icons.menu_book_rounded)),
                      ),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          color: p.surface,
                          borderRadius: BorderRadius.circular(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              children: options
                                  .map((o) => ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _moduleCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Code', hintText: 'CS1010'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _locationCtrl,
                            decoration: const InputDecoration(labelText: 'Room', hintText: 'NAC 2.12'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _linkCtrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Online link (optional)',
                        hintText: 'Google Meet / Teams / Zoom',
                        prefixIcon: const Icon(Icons.videocam_outlined),
                        suffixIcon: MeetingLinks.isValid(_linkCtrl.text)
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: TagPill(MeetingLinks.label(_linkCtrl.text).replaceFirst('Join ', ''),
                                    color: MeetingLinks.color(_linkCtrl.text)),
                              )
                            : null,
                      ),
                    ),
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_allowConflict ? Colors.orange : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(_allowConflict ? Icons.warning_amber_rounded : Icons.error_outline,
                                color: _allowConflict ? Colors.orange[800] : Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: TextStyle(
                                      color: _allowConflict ? Colors.orange[900] : Colors.redAccent, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 22),
                    InkPillButton(
                      label: _allowConflict ? 'Save anyway' : (widget.isEditing ? 'Save changes' : 'Add class'),
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(Palette p, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: p.textMuted)),
      );

  Widget _timeBox(Palette p, String label, int minutes, VoidCallback onTap, {bool error = false}) {
    return SoftCard(
      color: p.surfaceAlt,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: error ? Border.all(color: Colors.redAccent, width: 1.5) : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.schedule_rounded, size: 14, color: p.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMinutes(minutes),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -1, color: p.textPrimary)),
          ),
        ],
      ),
    );
  }
}
