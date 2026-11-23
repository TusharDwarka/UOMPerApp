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

double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

final _numFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
const _numKb = TextInputType.numberWithOptions(decimal: true);

/// Grade bands offered as targets ("what do I need for a B?").
const _targets = [(40.0, 'Pass'), (50.0, 'C'), (60.0, 'B'), (70.0, 'A')];

Color _passColor(Palette p, double mark) =>
    mark >= Grading.passMark ? (p.isDark ? const Color(0xFF4CD787) : const Color(0xFF00A844)) : Colors.redAccent;

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
    final projected = records.projectedCpa;
    final years = records.gradedYears;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        _CpaCard(
          cpa: cpa,
          credits: records.gradedCredits,
          modules: records.graded.length,
          // Only worth showing when ongoing results move it.
          projected: projected != null && (cpa == null || (projected - cpa).abs() >= 0.005) ? projected : null,
        ),
        if (years.length > 1) ...[
          const SizedBox(height: 10),
          _YearStrip(items: [for (final y in years) (y, records.yearAverage(y)!)]),
        ],
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
        Text('Tap a module to add how it\'s marked (tests, assignments, exam) and fill in results as they come back — '
            'the final mark and your CPA work themselves out.\n'
            'Grades: A ≥70 · B 60–69 · C 50–59 · D 40–49 · F <40. CPA = credit-weighted average of every module, all years. '
            'Check your programme\'s regulations for exact rules.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4)),
      ],
    );
  }

  Widget? _avgText(Palette p, double? avg) =>
      avg == null ? null : Text('avg ${fmtMark(avg)}', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600));
}

/// Average per year of study: "Y1 58.2 · Y2 64".
class _YearStrip extends StatelessWidget {
  final List<(int, double)> items;
  const _YearStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (y, avg) in items)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(40), boxShadow: p.softShadow),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Year $y  ', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
                TextSpan(text: avg.toStringAsFixed(1), style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800)),
              ]),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ]),
    );
  }
}

class _CpaCard extends StatelessWidget {
  final double? cpa;
  final double credits;
  final int modules;

  /// CPA if ongoing modules end on their average so far.
  final double? projected;
  const _CpaCard({required this.cpa, required this.credits, required this.modules, this.projected});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = cpa;
    return SoftCard(
      radius: 32,
      color: p.ink,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (projected != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: p.onInk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(40)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up_rounded, size: 16, color: p.onInk),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('On track for ${projected!.toStringAsFixed(2)} with results so far',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.onInk, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
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
    // Ongoing with some results in: show how it's going.
    final soFar = mark == null && saved ? r.averageSoFar : null;
    final statusColor = switch (r.status) {
      ModuleStatus.ended => p.textSecondary,
      ModuleStatus.resit => Colors.orange,
      _ => p.accent,
    };
    final sub = [
      if (r.code.isNotEmpty) r.code,
      '${fmtMark(r.credits)} cr',
      if (soFar != null) '${fmtMark(r.markedWeight)}% marked',
      if (r.status == ModuleStatus.resit && r.resitDate != null) 'resit ${DateFormat('d MMM').format(r.resitDate!)}',
      if (r.resitMark != null && r.firstMark != null) 'first attempt ${fmtMark(r.firstMark!)}',
    ].join(' · ');

    final shown = mark ?? soFar;
    final circleColor = mark != null ? _passColor(p, mark) : (soFar != null ? p.accent : p.textMuted);

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
                color: shown == null ? p.surfaceAlt : circleColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(shown == null ? '–' : Grading.letter(shown),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: circleColor)),
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
                    Flexible(flex: 2, child: TagPill(ModuleStatus.label(r.status), color: statusColor)),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ),
                  ]),
                  if (soFar != null && r.totalWeight > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (r.markedWeight / r.totalWeight).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: p.surfaceAlt,
                        color: p.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (mark != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${fmtMark(mark)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
              )
            else if (soFar != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmtMark(double.parse(soFar.toStringAsFixed(1)))}%',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.accent)),
                    Text('so far', style: TextStyle(fontSize: 11, color: p.textSecondary)),
                  ],
                ),
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

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Give the module a name');
    final credits = _parse(_credits.text);
    if (credits == null || credits <= 0 || credits > 60) return setState(() => _error = 'Credits must be a number above 0');
    double? mark, resit;
    if (_mark.text.trim().isNotEmpty) {
      mark = _parse(_mark.text);
      if (mark == null || mark < 0 || mark > 100) return setState(() => _error = 'Mark must be between 0 and 100');
    }
    if (_resit.text.trim().isNotEmpty) {
      resit = _parse(_resit.text);
      if (resit == null || resit < 0 || resit > 100) return setState(() => _error = 'Resit mark must be between 0 and 100');
    }
    for (final x in r.parts) {
      if (x.weight <= 0 || x.weight > 100) return setState(() => _error = 'Each part needs a weight between 1 and 100%');
      if (x.score != null && x.score! > x.outOf) {
        return setState(() => _error = '"${x.name}": ${fmtMark(x.score!)} is more than ${fmtMark(x.outOf)}');
      }
    }
    for (var i = 0; i < r.parts.length; i++) {
      if (r.parts[i].name.trim().isEmpty) r.parts[i].name = 'Part ${i + 1}';
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
    final hasParts = r.parts.isNotEmpty;
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
                    keyboardType: _numKb,
                    inputFormatters: _numFormatters,
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
              const SizedBox(height: 18),
              _AssessmentEditor(record: r, onChanged: () => setState(() {})),
              const SizedBox(height: 14),
              TextField(
                controller: _mark,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: hasParts
                      ? 'Official final mark % (optional)'
                      : r.status == ModuleStatus.resit
                          ? 'First attempt mark %'
                          : 'Final mark %',
                  helperText: hasParts ? 'Leave empty to use the mark worked out above' : null,
                  prefixIcon: const Icon(Icons.percent_rounded),
                  suffixText: _parse(_mark.text) == null ? null : Grading.letter(_parse(_mark.text)!),
                ),
              ),
              if (r.status == ModuleStatus.resit || _resit.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _resit,
                  keyboardType: _numKb,
                  inputFormatters: _numFormatters,
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

/// "How it's marked": the module's tests / assignments / exam with their
/// weights, filled in as results come back. Edits [record.parts] in place.
class _AssessmentEditor extends StatelessWidget {
  final ModuleRecord record;
  final VoidCallback onChanged;
  const _AssessmentEditor({required this.record, required this.onChanged});

  List<AssessmentPart> get parts => record.parts;

  void _add(String kind) {
    // "Class test" twice → "Class test 2".
    final same = parts.where((x) => x.name == kind || x.name.startsWith('$kind ')).length;
    final left = 100 - record.totalWeight;
    parts.add(AssessmentPart(name: same == 0 ? kind : '$kind ${same + 1}', weight: left > 0 ? left : 10));
    onChanged();
  }

  void _useTemplate(List<(String, double)> t) {
    parts
      ..clear()
      ..addAll([for (final (n, w) in t) AssessmentPart(name: n, weight: w)]);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final total = record.totalWeight;
    final weightOk = (total - 100).abs() < 0.01;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text('How it\'s marked', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
          ),
          if (parts.isNotEmpty)
            Text('${fmtMark(total)} / 100%',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: weightOk ? p.textSecondary : Colors.orange)),
        ]),
        const SizedBox(height: 4),
        Text(
          parts.isEmpty
              ? 'Optional. Add the tests, assignments and exam with their weights, then fill in results as you get them.'
              : 'Fill in a result when it comes back. Leave the rest empty.',
          style: TextStyle(fontSize: 12, color: p.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (parts.isEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in AssessmentPart.templates.entries)
                ActionChip(
                  avatar: Icon(Icons.auto_awesome_mosaic_outlined, size: 16, color: p.accent),
                  label: Text(t.key),
                  onPressed: () => _useTemplate(t.value),
                ),
            ],
          ),
        for (var i = 0; i < parts.length; i++) _PartCard(key: ValueKey(parts[i].id), part: parts[i], onChanged: onChanged, onRemove: () {
          parts.removeAt(i);
          onChanged();
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            tooltip: 'Add a part',
            onSelected: _add,
            itemBuilder: (_) => [for (final k in AssessmentPart.kinds) PopupMenuItem(value: k, child: Text(k))],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 18, color: p.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(parts.isEmpty ? 'Or add parts one by one' : 'Add a part',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.accent)),
                ),
              ]),
            ),
          ),
        ),
        if (parts.isNotEmpty) _BreakdownSummary(record: record),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  final AssessmentPart part;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _PartCard({super.key, required this.part, required this.onChanged, required this.onRemove});

  InputDecoration _dense(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final x = part;
    final pct = x.percent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pct == null ? p.border : p.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: x.name,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dense('Name'),
                onChanged: (v) => x.name = v,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 74,
              child: TextFormField(
                initialValue: fmtMark(x.weight),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.center,
                decoration: _dense('Weight', suffix: '%'),
                onChanged: (v) {
                  x.weight = _parse(v) ?? 0;
                  onChanged();
                },
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
              onPressed: onRemove,
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 72,
              child: TextFormField(
                initialValue: x.score == null ? '' : fmtMark(x.score!),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.center,
                decoration: _dense('Got'),
                onChanged: (v) {
                  x.score = _parse(v);
                  onChanged();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(fontSize: 18, color: p.textSecondary)),
            ),
            SizedBox(
              width: 72,
              child: TextFormField(
                initialValue: fmtMark(x.outOf),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.center,
                decoration: _dense('Out of'),
                onChanged: (v) {
                  x.outOf = _parse(v) ?? 100;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  pct == null ? 'Not marked yet' : '${fmtMark(double.parse(pct.toStringAsFixed(1)))}%\n'
                      '${fmtMark(double.parse(x.points.toStringAsFixed(1)))} of ${fmtMark(x.weight)} pts',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: pct == null ? FontWeight.w400 : FontWeight.w700,
                    color: pct == null ? p.textMuted : p.textPrimary,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Where the module stands: average so far, the worked-out final mark, and
/// what's needed on the rest for each grade.
class _BreakdownSummary extends StatelessWidget {
  final ModuleRecord record;
  const _BreakdownSummary({required this.record});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = record;
    final avg = r.averageSoFar;
    final calc = r.calculatedMark;
    final total = r.totalWeight;
    final weightOk = (total - 100).abs() < 0.01;

    String headline;
    if (calc != null) {
      headline = 'Final mark: ${fmtMark(double.parse(calc.toStringAsFixed(1)))}% (${Grading.letter(calc)})';
    } else if (avg != null) {
      headline = '${fmtMark(double.parse(avg.toStringAsFixed(1)))}% so far on ${fmtMark(r.markedWeight)}% of the module';
    } else {
      headline = 'No results yet';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: TextStyle(fontWeight: FontWeight.w800, color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(
            calc != null
                ? 'Worked out from every part${weightOk ? '' : ' (weights scaled to 100%)'}. It counts in your CPA.'
                : avg != null
                    ? '${fmtMark(double.parse(r.pointsEarned.toStringAsFixed(1)))} points banked — on track for a ${Grading.letter(avg)}. '
                        'Average needed on what\'s left:'
                    : 'Add results as they come back to see what you need on the rest.',
            style: TextStyle(fontSize: 12, color: p.textSecondary, height: 1.35),
          ),
          if (!weightOk)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Weights add up to ${fmtMark(total)}% — usually they make 100%.',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
          if (calc == null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (t, label) in _targets) _needChip(p, label, r.neededForTarget(t)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _needChip(Palette p, String label, double? need) {
    final String text;
    final Color c;
    if (need == null) {
      text = label;
      c = p.textSecondary;
    } else if (need <= 0) {
      text = '$label  ✓ secured';
      c = _passColor(p, 100);
    } else if (need > 100) {
      text = '$label  out of reach';
      c = p.textMuted;
    } else {
      text = '$label  ${need.ceil()}%';
      c = p.textPrimary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(40)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ───────────────────────── CPA calculator ─────────────────────────

class _WhatIf {
  final String name;
  double credits;
  double? mark;
  int year;
  int semester;

  /// Where the pre-filled mark came from, e.g. "on track · 40% marked".
  final String? hint;
  _WhatIf(this.name, this.credits, this.mark, {required this.year, required this.semester, this.hint});
}

/// What-if CPA across every year: saved marks count as-is; unfinished modules
/// start on their average so far (from their assessments) and can be
/// changed; future modules can be added to see the projected CPA and how
/// much you need on the rest to reach a target.
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
      for (final r in ungraded)
        _WhatIf(
          r.name,
          r.credits,
          r.averageSoFar == null ? null : double.parse(r.averageSoFar!.toStringAsFixed(1)),
          year: r.year,
          semester: r.semester,
          hint: r.averageSoFar == null ? null : 'on track · ${fmtMark(r.markedWeight)}% marked',
        ),
      for (final s in timetable.scheduleSubjects)
        if (!names.contains(ModuleRecord.keyFor(s)) && records.recordFor(s) == null)
          _WhatIf(s, 3, null, year: timetable.studyYear, semester: timetable.semester),
    ];
  }

  /// The period after the latest one in use (Y2 S2 → Y3 S1).
  (int, int) _nextPeriod(RecordProvider records, TimetableProvider timetable) {
    var (y, s) = (timetable.studyYear, timetable.semester);
    for (final (ry, rs) in [...records.periods, for (final w in _rows!) (w.year, w.semester)]) {
      if (ry * 10 + rs > y * 10 + s) (y, s) = (ry, rs);
    }
    return s == 1 ? (y, 2) : ((y + 1).clamp(1, 5), 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final records = context.watch<RecordProvider>();
    final timetable = context.read<TimetableProvider>();
    _init(records, timetable);
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
      cpa: projected,
      doneCredits: doneCredits + plannedCredits,
      remainingCredits: remaining,
      target: _target,
    );

    // Projected average per year (saved + typed marks).
    final byYear = <int, List<(double, double)>>{};
    for (final r in records.graded) {
      byYear.putIfAbsent(r.year, () => []).add((r.credits, records.markOf(r)!));
    }
    for (final w in rows) {
      if (w.mark != null) byYear.putIfAbsent(w.year, () => []).add((w.credits, w.mark!));
    }
    final years = byYear.keys.toList()..sort();

    // Rows grouped by year/semester, in order.
    final periods = {for (final w in rows) (w.year, w.semester)}.toList()
      ..sort((a, b) => (a.$1 * 10 + a.$2).compareTo(b.$1 * 10 + b.$2));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Row(children: [
          Expanded(child: _stat(p, 'Now', current)),
          const SizedBox(width: 10),
          Expanded(child: _stat(p, 'With these marks', projected, highlight: true)),
        ]),
        if (years.length > 1) ...[
          const SizedBox(height: 10),
          _YearStrip(items: [for (final y in years) (y, Grading.weightedAverage(byYear[y]!)!)]),
        ],
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
        const SectionLabel('What if…'),
        if (rows.isEmpty)
          Text('All your modules have marks. Add a module below to plan ahead.', style: TextStyle(color: p.textSecondary)),
        for (final (y, s) in periods) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('Year $y · Semester $s',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: p.textSecondary, letterSpacing: 0.2)),
          ),
          for (final w in rows.where((w) => w.year == y && w.semester == s)) _row(p, rows, w),
        ],
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => rows.add(
                  _WhatIf('Module ${rows.length + 1}', 3, null, year: timetable.studyYear, semester: timetable.semester))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Module this semester'),
            ),
            TextButton.icon(
              onPressed: () {
                final (y, s) = _nextPeriod(records, timetable);
                setState(() => rows.add(_WhatIf('Module ${rows.length + 1}', 3, null, year: y, semester: s)));
              },
              icon: const Icon(Icons.event_repeat_rounded, size: 18),
              label: const Text('Plan a later semester'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cap passed resits at 40', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Turn on if your programme limits a resit to the pass mark'),
          value: records.capResit,
          onChanged: records.setCapResit,
        ),
        Text('Saved marks (${records.graded.length} modules, ${fmtMark(doneCredits)} credits, every year) always count. '
            'Unfinished modules start on their average so far. Marks typed here are not saved — '
            'fill in results under My grades.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4)),
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
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: highlight ? Colors.white70 : p.textSecondary)),
            Text(v == null ? '—' : v.toStringAsFixed(2),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, color: highlight ? Colors.white : p.textPrimary)),
            Text(v == null ? ' ' : Grading.degreeBand(v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: highlight ? Colors.white : p.textSecondary)),
          ],
        ),
      );

  Widget _row(Palette p, List<_WhatIf> rows, _WhatIf w) {
    return Padding(
      key: ObjectKey(w),
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  if (w.hint != null)
                    Text(w.hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.accent)),
                ],
              ),
            ),
            SizedBox(
              width: 54,
              child: TextFormField(
                initialValue: fmtMark(w.credits),
                textAlign: TextAlign.center,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                decoration: const InputDecoration(labelText: 'cr', isDense: true),
                onChanged: (v) => setState(() => w.credits = _parse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: w.mark == null ? '' : fmtMark(w.mark!),
                textAlign: TextAlign.center,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                decoration: const InputDecoration(labelText: '%', isDense: true),
                onChanged: (v) => setState(() => w.mark = _parse(v)?.clamp(0, 100).toDouble()),
              ),
            ),
            IconButton(
              tooltip: 'Remove row',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
              onPressed: () => setState(() => rows.remove(w)),
            ),
          ],
        ),
      ),
    );
  }
}
