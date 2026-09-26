import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import '../services/pdf_export.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/ui.dart';
import 'pdf_viewer_screen.dart';

/// Build a PDF: either a task report with exactly what you choose, or
/// printable planner pages (note paper, month calendar, week planner).
class PrintCenterScreen extends StatefulWidget {
  final int initialTab;
  const PrintCenterScreen({super.key, this.initialTab = 0});

  @override
  State<PrintCenterScreen> createState() => _PrintCenterScreenState();
}

enum _Range { week, twoWeeks, month, semester, custom }

class _PrintCenterScreenState extends State<PrintCenterScreen> {
  late int _tab = widget.initialTab;
  bool _busy = false;

  // Task report
  final _title = TextEditingController(text: 'My deadlines');
  _Range _range = _Range.twoWeeks;
  DateTimeRange? _custom;
  final Set<String> _types = {...TaskReportOptions.baseTypes, 'Other'};
  final Set<String> _statuses = {TaskStatus.todo, TaskStatus.doing};
  bool _calendar = true;
  bool _notes = true;
  bool _checkboxes = true;

  // Planner
  int _plannerKind = 3; // 3 to-do list, 0 paper, 1 month, 2 week
  String _todoGroup = 'date';
  int _todoDays = 14; // 0 = all
  int _todoBlank = 12;
  final Set<String> _todoStatuses = {TaskStatus.todo, TaskStatus.doing};
  String _paperStyle = 'lined';
  int _pages = 3;
  String _paperModule = '';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _monthCount = 1;
  DateTime _week = dateOnly(DateTime.now()).subtract(Duration(days: DateTime.now().weekday - 1));
  int _weekCount = 1;
  bool _prefill = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTimeRange _dates(TimetableProvider tp) {
    final today = dateOnly(DateTime.now());
    switch (_range) {
      case _Range.week:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 6)));
      case _Range.twoWeeks:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 13)));
      case _Range.month:
        return DateTimeRange(start: DateTime(today.year, today.month, 1), end: DateTime(today.year, today.month + 1, 0));
      case _Range.semester:
        final start = dateOnly(tp.semesterStart);
        return DateTimeRange(start: start, end: tp.semesterEnd ?? start.add(const Duration(days: 7 * 15)));
      case _Range.custom:
        return _custom ?? DateTimeRange(start: today, end: today.add(const Duration(days: 13)));
    }
  }

  TaskReportOptions _options(TimetableProvider tp) {
    final r = _dates(tp);
    return TaskReportOptions(
      title: _title.text.trim().isEmpty ? 'My deadlines' : _title.text.trim(),
      types: _types.length == 5 ? const {} : _types,
      statuses: _statuses,
      from: r.start,
      to: r.end,
      includeCalendar: _calendar,
      includeNotes: _notes,
      includeCheckboxes: _checkboxes,
    );
  }

  Future<(Uint8List, String)> _build() async {
    final tp = context.read<TimetableProvider>();
    if (_tab == 0) {
      final bytes = await PdfExport.taskReport(tp.tasks, _options(tp));
      return (bytes, 'UOMPer_${_title.text.trim().replaceAll(RegExp(r'\s+'), '_')}.pdf');
    }
    switch (_plannerKind) {
      case 3:
        final horizon = DateTime.now().add(Duration(days: _todoDays));
        final tasks = tp.tasks
            .where((t) => _todoStatuses.contains(t.effectiveStatus))
            .where((t) => _todoDays == 0 || !dateOnly(t.startDate ?? t.dueDate).isAfter(dateOnly(horizon)))
            .toList();
        return (await PdfExport.todoPages(tasks: tasks, groupBy: _todoGroup, blankLines: _todoBlank), 'UOMPer_todo.pdf');
      case 0:
        return (await PdfExport.notePaper(style: _paperStyle, pages: _pages, module: _paperModule), 'UOMPer_notes_$_paperStyle.pdf');
      case 1:
        return (
          await PdfExport.monthPlanner(month: _month, months: _monthCount, tasks: _prefill ? tp.tasks : const []),
          'UOMPer_${DateFormat('MMM_yyyy').format(_month)}.pdf'
        );
      default:
        return (
          await PdfExport.weekPlanner(
            weekStart: _week,
            weeks: _weekCount,
            classesFor: tp.getClassesForDate,
            tasks: _prefill ? tp.tasks : const [],
          ),
          'UOMPer_week_${DateFormat('d_MMM').format(_week)}.pdf'
        );
    }
  }

  Future<void> _run(Future<void> Function(Uint8List bytes, String name) action) async {
    setState(() => _busy = true);
    try {
      final (bytes, name) = await _build();
      await action(bytes, name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the PDF: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareText() {
    final tp = context.read<TimetableProvider>();
    final o = _options(tp);
    final tasks = tp.tasks.where(o.matches).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing matches these filters')));
      return;
    }
    final b = StringBuffer('📋 ${o.title}\n');
    DateTime? last;
    for (final t in tasks) {
      final d = dateOnly(t.dueDate);
      if (last != d) {
        last = d;
        b.writeln('\n${DateFormat('EEE d MMM').format(d)}');
      }
      b.writeln('${t.isCompleted ? '✅' : '⬜'} ${t.title} (${t.type}${t.subject != 'General' ? ' · ${t.subject}' : ''})');
    }
    b.writeln('\nShared from UOMPerApp');
    Share.share(b.toString(), subject: o.title);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tp = context.watch<TimetableProvider>();

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(children: [
                CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.pop(context)),
              ]),
            ),
            const ScreenHeader(title: 'Print & export', eyebrow: 'Choose exactly what goes on paper'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: PillSegmented<int>(
                values: const [0, 1],
                selected: _tab,
                labelOf: (i) => i == 0 ? 'Task report' : 'Planner pages',
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: _tab == 0 ? _reportOptions(p, tp) : _plannerOptions(p, tp),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: _busy
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                            child: InkPillButton(
                              label: 'Preview',
                              icon: Icons.visibility_outlined,
                              onPressed: () => _run((bytes, name) async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(title: name, loadBytes: () async => bytes, fileName: name),
                                ));
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleIconButton(
                            icon: Icons.print_rounded,
                            tooltip: 'Print',
                            size: 52,
                            onPressed: () => _run((bytes, name) => Printing.layoutPdf(onLayout: (_) async => bytes, name: name)),
                          ),
                          const SizedBox(width: 8),
                          CircleIconButton(
                            icon: Icons.ios_share_rounded,
                            tooltip: 'Share PDF',
                            size: 52,
                            onPressed: () => _run((bytes, name) => Printing.sharePdf(bytes: bytes, filename: name)),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── Task report options ─────────────

  List<Widget> _reportOptions(Palette p, TimetableProvider tp) {
    final o = _options(tp);
    final count = tp.tasks.where(o.matches).length;
    final r = _dates(tp);
    return [
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title on the PDF')),
      _label(p, 'Dates'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final v in _Range.values)
          _chip(p, const {
            _Range.week: 'Next 7 days',
            _Range.twoWeeks: 'Next 2 weeks',
            _Range.month: 'This month',
            _Range.semester: 'Whole semester',
            _Range.custom: 'Custom…',
          }[v]!, _range == v, () async {
            if (v == _Range.custom) {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDateRange: _custom ?? _dates(tp),
              );
              if (picked == null) return;
              _custom = picked;
            }
            setState(() => _range = v);
          }),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text('${DateFormat('d MMM').format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end)}',
            style: TextStyle(fontSize: 12, color: p.textSecondary)),
      ),
      _label(p, 'Include types'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in [...TaskReportOptions.baseTypes, 'Other'])
          _chip(p, t, _types.contains(t), () => setState(() {
                if (_types.contains(t)) {
                  if (_types.length > 1) _types.remove(t);
                } else {
                  _types.add(t);
                }
              }), color: AppColors.forType(t)),
      ]),
      _label(p, 'Include board columns'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in TaskStatus.all)
          _chip(p, TaskStatus.label(s), _statuses.contains(s), () => setState(() {
                if (_statuses.contains(s)) {
                  if (_statuses.length > 1) _statuses.remove(s);
                } else {
                  _statuses.add(s);
                }
              })),
      ]),
      _label(p, 'Layout'),
      SoftCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          SwitchListTile(
            title: const Text('Month calendar pages'),
            subtitle: const Text('A landscape calendar with your deadlines written in'),
            value: _calendar,
            onChanged: (v) => setState(() => _calendar = v),
          ),
          SwitchListTile(title: const Text('Notes & rooms'), value: _notes, onChanged: (v) => setState(() => _notes = v)),
          SwitchListTile(
            title: const Text('Tick boxes'),
            subtitle: const Text('Empty boxes to tick off on paper'),
            value: _checkboxes,
            onChanged: (v) => setState(() => _checkboxes = v),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Icon(Icons.info_outline_rounded, size: 16, color: p.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text('$count item${count == 1 ? '' : 's'} will be included', style: TextStyle(color: p.textSecondary))),
        TextButton.icon(onPressed: _shareText, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('Send as text')),
      ]),
    ];
  }

  // ───────────── Planner options ─────────────

  List<Widget> _plannerOptions(Palette p, TimetableProvider tp) {
    final modules = {...tp.userSessions.map((s) => s.subject)}.toList()..sort();
    return [
      PillSegmented<int>(
        values: const [3, 0, 1, 2],
        selected: _plannerKind,
        labelOf: (i) => const ['Paper', 'Month', 'Week', 'To-do'][i],
        onChanged: (i) => setState(() => _plannerKind = i),
      ),
      const SizedBox(height: 8),
      Text(
        const {
          3: 'Your tasks written on lined paper with tick boxes, plus empty lines to add more.',
          0: 'Blank lined, dotted or grid paper with module / topic / date boxes.',
          1: 'A month grid (optionally with your deadlines) and a notes column.',
          2: 'One box per day with your classes printed in, and lines to plan.',
        }[_plannerKind]!,
        style: TextStyle(fontSize: 12, color: p.textSecondary),
      ),
      const SizedBox(height: 6),
      if (_plannerKind == 3) ...[
        _label(p, 'Which tasks'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final st in [TaskStatus.todo, TaskStatus.doing])
            _chip(p, TaskStatus.label(st), _todoStatuses.contains(st), () => setState(() {
                  if (_todoStatuses.contains(st)) {
                    if (_todoStatuses.length > 1) _todoStatuses.remove(st);
                  } else {
                    _todoStatuses.add(st);
                  }
                })),
        ]),
        _label(p, 'Due within'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in const [7, 14, 30, 0]) _chip(p, d == 0 ? 'Any time' : '$d days', _todoDays == d, () => setState(() => _todoDays = d)),
        ]),
        _label(p, 'Group by'),
        PillSegmented<String>(
          values: const ['date', 'module'],
          selected: _todoGroup,
          labelOf: (g) => g == 'date' ? 'Due date' : 'Module',
          onChanged: (g) => setState(() => _todoGroup = g),
        ),
        _label(p, 'Empty lines at the end'),
        _stepper(p, _todoBlank, 0, 40, (v) => setState(() => _todoBlank = v), unit: 'lines'),
      ],
      if (_plannerKind == 0) ...[
        _label(p, 'Paper'),
        Row(children: [
          for (final s in const ['lined', 'dotted', 'grid'])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SoftCard(
                  radius: 22,
                  color: _paperStyle == s ? p.ink : p.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onTap: () => setState(() => _paperStyle = s),
                  child: Column(children: [
                    Icon(
                      const {'lined': Icons.notes_rounded, 'dotted': Icons.grain_rounded, 'grid': Icons.grid_4x4_rounded}[s],
                      color: _paperStyle == s ? p.onInk : p.textPrimary,
                    ),
                    const SizedBox(height: 6),
                    Text(s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(fontWeight: FontWeight.w600, color: _paperStyle == s ? p.onInk : p.textPrimary)),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(_paperStyle == 'lined' ? 'Lines every 8 mm with a margin, plus module / topic / date boxes.' : '5 mm spacing, great for maths and diagrams.',
            style: TextStyle(fontSize: 12, color: p.textSecondary)),
        _label(p, 'Pages'),
        _stepper(p, _pages, 1, 20, (v) => setState(() => _pages = v), unit: 'pages'),
        _label(p, 'Module in the header (optional)'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip(p, 'Blank', _paperModule.isEmpty, () => setState(() => _paperModule = '')),
          for (final m in modules) _chip(p, m, _paperModule == m, () => setState(() => _paperModule = m)),
        ]),
      ],
      if (_plannerKind == 1) ...[
        _label(p, 'Starting month'),
        _periodPicker(p, DateFormat('MMMM yyyy').format(_month),
            () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
        _label(p, 'How many months'),
        _stepper(p, _monthCount, 1, 12, (v) => setState(() => _monthCount = v), unit: 'months'),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fill in my deadlines'),
          subtitle: const Text('Off = a blank calendar to write on'),
          value: _prefill,
          onChanged: (v) => setState(() => _prefill = v),
        ),
      ],
      if (_plannerKind == 2) ...[
        _label(p, 'Starting week'),
        _periodPicker(p, 'Week of ${DateFormat('d MMM').format(_week)}',
            () => setState(() => _week = _week.subtract(const Duration(days: 7))),
            () => setState(() => _week = _week.add(const Duration(days: 7)))),
        _label(p, 'How many weeks'),
        _stepper(p, _weekCount, 1, 8, (v) => setState(() => _weekCount = v), unit: 'weeks'),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include deadlines'),
          subtitle: const Text('Your classes are always printed on each day'),
          value: _prefill,
          onChanged: (v) => setState(() => _prefill = v),
        ),
      ],
    ];
  }

  // ───────────── Small pieces ─────────────

  Widget _label(Palette p, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: p.textMuted)),
      );

  Widget _chip(Palette p, String label, bool selected, VoidCallback onTap, {Color? color}) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 5),
      selectedColor: p.ink,
      backgroundColor: p.surface,
      labelStyle: TextStyle(color: selected ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
      onSelected: (_) => onTap(),
    );
  }

  Widget _stepper(Palette p, int value, int min, int max, ValueChanged<int> onChanged, {required String unit}) {
    return Row(children: [
      CircleIconButton(icon: Icons.remove_rounded, onPressed: value > min ? () => onChanged(value - 1) : null),
      Expanded(
        child: Text('$value $unit', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: p.textPrimary)),
      ),
      CircleIconButton(icon: Icons.add_rounded, onPressed: value < max ? () => onChanged(value + 1) : null),
    ]);
  }

  Widget _periodPicker(Palette p, String label, VoidCallback prev, VoidCallback next) {
    return SoftCard(
      radius: 40,
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: prev),
        Expanded(
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
        ),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: next),
      ]),
    );
  }
}
