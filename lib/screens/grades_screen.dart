import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/module_record.dart';
import '../providers/record_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/end_module_flow.dart';
import '../widgets/ui.dart';

String fmtMark(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Grade holder (every module and its mark, per year/semester) and a CPA
/// calculator with "what if" marks and a target.
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _calculator = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Grades',
              eyebrow: 'Modules, marks & CPA',
              actions: [
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'Add a module',
                  onPressed: () => editModuleRecord(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: PillSegmented<bool>(
                values: const [false, true],
                selected: _calculator,
                labelOf: (v) => v ? 'CPA calculator' : 'My grades',
                onChanged: (v) => setState(() => _calculator = v),
              ),
            ),
            Expanded(child: _calculator ? const CpaCalculator() : const _GradeList()),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Grade holder ─────────────────────────

class _GradeList extends StatelessWidget {
  const _GradeList();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final records = context.watch<RecordProvider>();
    final timetable = context.watch<TimetableProvider>();
    final year = timetable.studyYear, sem = timetable.semester;

    // This semester: saved records plus timetable modules not saved yet.
    final current = records.records.where((r) => (r.year == year && r.semester == sem) || r.isActive).toList();
    final missing = timetable.scheduleSubjects.where((s) => !current.any((r) => r.key == ModuleRecord.keyFor(s))).toList();
    final rows = <(ModuleRecord, bool)>[
      for (final r in current) (r, true),
      if (!records.holidayMode)
        for (final s in missing) (ModuleRecord(name: s, year: year, semester: sem), false),
    ]..sort((a, b) {
        final s = (a.$1.isActive ? 0 : 1).compareTo(b.$1.isActive ? 0 : 1);
        return s != 0 ? s : a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
      });

    final earlier = records.periods.where((pr) => pr != (year, sem)).toList();
    final cpa = records.cpa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        _CpaCard(cpa: cpa, credits: records.gradedCredits, modules: records.graded.length),
        const SizedBox(height: 18),
        SectionLabel('Y$year · Semester $sem', trailing: _avgText(p, records.semesterAverage(year, sem))),
        if (rows.isEmpty)
          SoftCard(
            child: Text('No modules yet. Add one with + or import your timetable.', style: TextStyle(color: p.textSecondary)),
          ),
        for (final (r, saved) in rows) _ModuleTile(record: r, saved: saved),
        for (final (y, s) in earlier) ...[
          const SizedBox(height: 14),
          SectionLabel('Y$y · Semester $s', trailing: _avgText(p, records.semesterAverage(y, s))),
          for (final r in records.records.where((r) => r.year == y && r.semester == s && !r.isActive))
            _ModuleTile(record: r, saved: true),
        ],
        const SizedBox(height: 16),
        Text('Grades: A ≥70 · B 60–69 · C 50–59 · D 40–49 · F <40. CPA = credit-weighted average of your marks. '
            'Check your programme\'s regulations for exact rules.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4)),
      ],
    );
  }

  Widget? _avgText(Palette p, double? avg) =>
      avg == null ? null : Text('avg ${fmtMark(avg)}', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600));
}

class _CpaCard extends StatelessWidget {
  final double? cpa;
  final double credits;
  final int modules;
  const _CpaCard({required this.cpa, required this.credits, required this.modules});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = cpa;
    return SoftCard(
      radius: 32,
      color: p.ink,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CPA', style: TextStyle(color: p.onInk.withValues(alpha: 0.7), fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
                Text(c == null ? '—' : fmtMark(double.parse(c.toStringAsFixed(2))),
                    style: TextStyle(color: p.onInk, fontSize: 56, height: 1.05, fontWeight: FontWeight.w300, letterSpacing: -2)),
                Text(
                  c == null ? 'Add marks to see your CPA' : Grading.degreeBand(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.onInk, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtMark(credits), style: TextStyle(color: p.onInk, fontSize: 24, fontWeight: FontWeight.w600)),
              Text('credits', style: TextStyle(color: p.onInk.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 6),
              Text('$modules', style: TextStyle(color: p.onInk, fontSize: 24, fontWeight: FontWeight.w600)),
              Text(modules == 1 ? 'module' : 'modules', style: TextStyle(color: p.onInk.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final ModuleRecord record;

  /// False for a timetable module with no saved record yet.
  final bool saved;
  const _ModuleTile({required this.record, required this.saved});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final records = context.read<RecordProvider>();
    final r = record;
    final mark = saved ? records.markOf(r) : null;
    final statusColor = switch (r.status) {
      ModuleStatus.ended => const Color(0xFF00C853),
      ModuleStatus.resit => Colors.orange,
      _ => p.accent,
    };
    final sub = [
      if (r.code.isNotEmpty) r.code,
      '${fmtMark(r.credits)} cr',
      if (r.status == ModuleStatus.resit && r.resitDate != null) 'resit ${DateFormat('d MMM').format(r.resitDate!)}',
      if (r.resitMark != null && r.mark != null) 'first attempt ${fmtMark(r.mark!)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        onTap: () => editModuleRecord(context, record: r, saved: saved),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mark == null ? p.surfaceAlt : (mark >= Grading.passMark ? const Color(0xFF00C853) : Colors.redAccent).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(mark == null ? '–' : Grading.letter(mark),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: mark == null ? p.textMuted : (mark >= Grading.passMark ? const Color(0xFF00A844) : Colors.redAccent))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    TagPill(ModuleStatus.label(r.status), color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ),
                  ]),
                ],
              ),
            ),
            if (mark != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${fmtMark(mark)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
              )
            else if (r.isActive)
              TextButton(
                onPressed: () => startEndModuleFlow(context, r.name),
                child: const Text('End'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a module's grade record.
Future<void> editModuleRecord(BuildContext context, {ModuleRecord? record, bool saved = true}) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  final initial = record?.copy() ?? ModuleRecord(name: '', year: timetable.studyYear, semester: timetable.semester);
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ModuleSheet(record: initial, isNew: record == null || !saved),
  );
  if (!context.mounted || result == null) return;
  final messenger = ScaffoldMessenger.of(context);
  if (result == 'delete' && record != null) {
    final removed = await records.deleteRecord(record.id);
    if (removed == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text('Removed "${removed.name}"'),
      persist: false,
      action: SnackBarAction(label: 'Undo', onPressed: () => records.saveRecord(removed)),
    ));
  } else if (result == 'end' && record != null) {
    await startEndModuleFlow(context, record.name);
  } else if (result == 'reopen' && record != null) {
    await records.reopenModule(record.name);
    messenger.showSnackBar(SnackBar(content: Text('${record.name} is back on your timetable')));
  } else if (result is ModuleRecord) {
    await records.saveRecord(result);
    final date = result.resitDate;
    if (result.status == ModuleStatus.resit && date != null && date != record?.resitDate && !date.isBefore(DateTime.now())) {
      await addResitExam(timetable, result.name, date);
      messenger.showSnackBar(SnackBar(content: Text('Resit on ${DateFormat('EEE d MMM').format(date)} added to your Hub with reminders')));
    }
  }
}

class _ModuleSheet extends StatefulWidget {
  final ModuleRecord record;
  final bool isNew;
  const _ModuleSheet({required this.record, required this.isNew});

  @override
  State<_ModuleSheet> createState() => _ModuleSheetState();
}

class _ModuleSheetState extends State<_ModuleSheet> {
  late final ModuleRecord r = widget.record;
  late final _name = TextEditingController(text: r.name);
  late final _code = TextEditingController(text: r.code);
  late final _credits = TextEditingController(text: fmtMark(r.credits));
  late final _mark = TextEditingController(text: r.mark == null ? '' : fmtMark(r.mark!));
  late final _resit = TextEditingController(text: r.resitMark == null ? '' : fmtMark(r.resitMark!));
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _code, _credits, _mark, _resit]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Give the module a name');
    final credits = _num(_credits);
    if (credits == null || credits <= 0 || credits > 60) return setState(() => _error = 'Credits must be a number above 0');
    double? mark, resit;
    if (_mark.text.trim().isNotEmpty) {
      mark = _num(_mark);
      if (mark == null || mark < 0 || mark > 100) return setState(() => _error = 'Mark must be between 0 and 100');
    }
    if (_resit.text.trim().isNotEmpty) {
      resit = _num(_resit);
      if (resit == null || resit < 0 || resit > 100) return setState(() => _error = 'Resit mark must be between 0 and 100');
    }
    r
      ..name = name
      ..code = _code.text.trim()
      ..credits = credits
      ..mark = mark
      ..resitMark = resit;
    if (r.isEnded) r.endedAt ??= DateTime.now();
    Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final num = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const numKb = TextInputType.numberWithOptions(decimal: true);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: SheetScaffold(
        title: widget.isNew ? 'Module' : r.name,
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Remove from grades',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () async {
                final ok = await confirmDestructive(context,
                    title: 'Remove "${r.name}"?', message: 'Its mark is removed from your grades and CPA.', action: 'Remove');
                if (ok && context.mounted) Navigator.pop(context, 'delete');
              },
            ),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: r.name.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Module name', prefixIcon: Icon(Icons.menu_book_rounded)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code (optional)')),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _credits,
                    keyboardType: numKb,
                    inputFormatters: num,
                    decoration: const InputDecoration(labelText: 'Credits'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('Taken in', style: TextStyle(fontWeight: FontWeight.w600, color: p.textSecondary)),
                const Spacer(),
                ChoicePill<int>(
                  title: 'Year of study',
                  value: r.year,
                  options: const [1, 2, 3, 4, 5],
                  labelOf: (y) => 'Y$y',
                  onChanged: (y) => setState(() => r.year = y),
                ),
                const SizedBox(width: 6),
                ChoicePill<int>(
                  title: 'Semester',
                  value: r.semester,
                  options: const [1, 2],
                  labelOf: (s) => 'S$s',
                  onChanged: (s) => setState(() => r.semester = s),
                ),
              ]),
              const SizedBox(height: 14),
              PillSegmented<String>(
                values: ModuleStatus.all,
                selected: r.status,
                labelOf: ModuleStatus.label,
                onChanged: (s) => setState(() => r.status = s),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mark,
                keyboardType: numKb,
                inputFormatters: num,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: r.status == ModuleStatus.resit ? 'First attempt mark %' : 'Final mark %',
                  prefixIcon: const Icon(Icons.percent_rounded),
                  suffixText: _num(_mark) == null ? null : Grading.letter(_num(_mark)!),
                ),
              ),
              if (r.status == ModuleStatus.resit || _resit.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _resit,
                  keyboardType: numKb,
                  inputFormatters: num,
                  decoration: const InputDecoration(
                    labelText: 'Resit mark % (replaces the first)',
                    prefixIcon: Icon(Icons.replay_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SoftCard(
                  color: p.surfaceAlt,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: r.resitDate ?? now,
                      firstDate: DateTime(now.year - 3),
                      lastDate: DateTime(now.year + 3),
                    );
                    if (d != null) setState(() => r.resitDate = d);
                  },
                  child: Row(children: [
                    Icon(Icons.event_rounded, color: p.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.resitDate == null ? 'Resit date' : 'Resit ${DateFormat('EEE d MMM yyyy').format(r.resitDate!)}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    ),
                  ]),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 18),
              InkPillButton(label: 'Save', icon: Icons.check_rounded, expand: true, onPressed: _save),
              if (!widget.isNew && r.isActive) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'end'),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Finished early? End module'),
                ),
              ],
              if (!widget.isNew && r.isEnded) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'reopen'),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Put back on timetable'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── CPA calculator ─────────────────────────

class _WhatIf {
  final String name;
  double credits;
  double? mark;
  final bool fromRecord;
  _WhatIf(this.name, this.credits, this.mark, {this.fromRecord = false});
}

/// What-if CPA: your saved marks count as-is; type expected marks for
/// ongoing modules (or made-up ones) to see the projected CPA, and how much
/// you need on the rest to reach a target.
class CpaCalculator extends StatefulWidget {
  const CpaCalculator({super.key});

  @override
  State<CpaCalculator> createState() => _CpaCalculatorState();
}

class _CpaCalculatorState extends State<CpaCalculator> {
  List<_WhatIf>? _rows;
  double _target = 60;

  void _init(RecordProvider records, TimetableProvider timetable) {
    if (_rows != null) return;
    final ungraded = records.records.where((r) => records.markOf(r) == null).toList();
    final names = {for (final r in ungraded) r.key};
    _rows = [
      for (final r in ungraded) _WhatIf(r.name, r.credits, null, fromRecord: true),
      for (final s in timetable.scheduleSubjects)
        if (!names.contains(ModuleRecord.keyFor(s)) && records.recordFor(s) == null) _WhatIf(s, 3, null, fromRecord: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final records = context.watch<RecordProvider>();
    _init(records, context.read<TimetableProvider>());
    final rows = _rows!;

    final graded = [for (final r in records.graded) (r.credits, records.markOf(r)!)];
    final planned = [for (final w in rows) if (w.mark != null) (w.credits, w.mark!)];
    final current = records.cpa;
    final projected = Grading.weightedAverage([...graded, ...planned]);
    final doneCredits = records.gradedCredits;
    final remaining = rows.where((w) => w.mark == null).fold(0.0, (a, w) => a + w.credits);
    final plannedCredits = planned.fold(0.0, (a, x) => a + x.$1);
    // Needed on the still-blank rows, counting the marks typed in.
    final needed = Grading.neededAverage(
      cpa: Grading.weightedAverage([...graded, ...planned]),
      doneCredits: doneCredits + plannedCredits,
      remainingCredits: remaining,
      target: _target,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Row(children: [
          Expanded(child: _stat(p, 'Now', current)),
          const SizedBox(width: 10),
          Expanded(child: _stat(p, 'With these marks', projected, highlight: true)),
        ]),
        const SizedBox(height: 16),
        SoftCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Target CPA', style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${_target.round()} · ${Grading.degreeBand(_target)}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ]),
              Slider(
                value: _target,
                min: 40,
                max: 85,
                divisions: 45,
                label: '${_target.round()}',
                onChanged: (v) => setState(() => _target = v),
              ),
              Text(
                needed == null
                    ? 'Leave some modules blank below to see what you need on them.'
                    : needed > 100
                        ? 'Out of reach on the blank modules (would need ${needed.toStringAsFixed(1)}%).'
                        : needed <= 0
                            ? 'Already there — any mark on the blank modules keeps you above ${_target.round()}.'
                            : 'You need an average of ${needed.toStringAsFixed(1)}% on the ${fmtMark(remaining)} credits left blank.',
                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel('What if…',
            trailing: TextButton.icon(
              onPressed: () => setState(() => rows.add(_WhatIf('Module ${rows.length + 1}', 3, null))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Row'),
            )),
        if (rows.isEmpty)
          Text('All your modules have marks. Add a row to try out future modules.', style: TextStyle(color: p.textSecondary)),
        for (var i = 0; i < rows.length; i++) _row(p, rows, i),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cap passed resits at 40', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Turn on if your programme limits a resit to the pass mark'),
          value: records.capResit,
          onChanged: records.setCapResit,
        ),
        Text('Saved marks (${records.graded.length} modules, ${fmtMark(doneCredits)} credits) always count. '
            'Marks typed here are not saved.',
            style: TextStyle(fontSize: 11, color: p.textMuted)),
      ],
    );
  }

  Widget _stat(Palette p, String label, double? v, {bool highlight = false}) => SoftCard(
        radius: 24,
        color: highlight ? p.accent : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: highlight ? Colors.white70 : p.textSecondary)),
            Text(v == null ? '—' : v.toStringAsFixed(2),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, color: highlight ? Colors.white : p.textPrimary)),
            Text(v == null ? ' ' : Grading.degreeBand(v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: highlight ? Colors.white : p.textSecondary)),
          ],
        ),
      );

  Widget _row(Palette p, List<_WhatIf> rows, int i) {
    final w = rows[i];
    return Padding(
      key: ObjectKey(w),
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(w.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            ),
            SizedBox(
              width: 54,
              child: TextFormField(
                initialValue: fmtMark(w.credits),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'cr', isDense: true),
                onChanged: (v) => setState(() => w.credits = double.tryParse(v.replaceAll(',', '.')) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: w.mark == null ? '' : fmtMark(w.mark!),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: '%', isDense: true),
                onChanged: (v) => setState(() {
                  final m = double.tryParse(v.replaceAll(',', '.'));
                  w.mark = m?.clamp(0, 100).toDouble();
                }),
              ),
            ),
            IconButton(
              tooltip: 'Remove row',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
              onPressed: () => setState(() => rows.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }
}
