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

/// One decimal, dropping a trailing ".0" (75.63 → "75.6", 68.0 → "68").
String _fmt1(double v) => fmtMark(double.parse(v.toStringAsFixed(1)));

String _credits(double c) => '${fmtMark(c)} ${c == 1 ? 'credit' : 'credits'}';

double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

final _numFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
const _numKb = TextInputType.numberWithOptions(decimal: true);
const _tabular = [FontFeature.tabularFigures()];

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
    final header = ScreenHeader(
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
    );
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          // PC: grades and the CPA calculator side by side, no tab switching.
          if (wideDesktop(c)) {
            return Column(children: [
              header,
              const Expanded(
                child: SplitPanes(
                  padding: EdgeInsets.fromLTRB(0, 4, 20, 16),
                  main: _GradeList(),
                  side: CpaCalculator(),
                  sideTitle: 'CPA calculator',
                  mainFlex: 5,
                  sideFlex: 4,
                ),
              ),
            ]);
          }
          return Column(
            children: [
              header,
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
          );
        }),
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
          years: years.length > 1 ? [for (final y in years) (y, records.yearAverage(y)!)] : const [],
        ),
        const SizedBox(height: 22),
        SectionLabel('Y$year · Semester $sem', trailing: _avgText(p, records.semesterAverage(year, sem))),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('No modules yet', style: TextStyle(color: p.textSecondary)),
          )
        else
          _Group(children: [for (final (r, saved) in rows) _ModuleTile(record: r, saved: saved)]),
        for (final (y, s) in earlier) ...[
          const SizedBox(height: 18),
          SectionLabel('Y$y · Semester $s', trailing: _avgText(p, records.semesterAverage(y, s))),
          _Group(children: [
            for (final r in records.records.where((r) => r.year == y && r.semester == s && !r.isActive))
              _ModuleTile(record: r, saved: true),
          ]),
        ],
        const SizedBox(height: 22),
        const _GradeScale(),
      ],
    );
  }

  Widget? _avgText(Palette p, double? avg) => avg == null
      ? null
      : Text('${fmtMark(avg)} avg', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600, fontFeatures: _tabular));
}

/// Rows in one card, split by hairlines.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SoftCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktopPlatform ? 16 : 24),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: p.border),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// "A 70+  B 60+  C 50+  D 40+  F <40" — the bands at a glance.
class _GradeScale extends StatelessWidget {
  const _GradeScale();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const bands = [('A', '70+'), ('B', '60+'), ('C', '50+'), ('D', '40+'), ('F', '<40')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final (l, range) in bands)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '$l ', style: TextStyle(fontWeight: FontWeight.w700, color: p.textSecondary)),
                TextSpan(text: range),
              ]),
              style: TextStyle(fontSize: 12, color: p.textMuted, fontFeatures: _tabular),
            ),
        ],
      ),
    );
  }
}

/// Average per year of study, in columns: "Year 1 / 62.2".
class _YearAverages extends StatelessWidget {
  final List<(int, double)> items;
  final Color labelColor;
  final Color valueColor;
  const _YearAverages({required this.items, required this.labelColor, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 28,
      runSpacing: 10,
      children: [
        for (final (y, avg) in items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Year $y', style: TextStyle(fontSize: 12, color: labelColor)),
              const SizedBox(height: 2),
              Text(avg.toStringAsFixed(1),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor, fontFeatures: _tabular)),
            ],
          ),
      ],
    );
  }
}

class _CpaCard extends StatelessWidget {
  final double? cpa;
  final double credits;
  final int modules;

  /// CPA if ongoing modules end on their average so far.
  final double? projected;

  /// Average per year, shown when there's more than one.
  final List<(int, double)> years;
  const _CpaCard({required this.cpa, required this.credits, required this.modules, this.projected, this.years = const []});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = cpa;
    final soft = p.onInk.withValues(alpha: 0.6);
    return SoftCard(
      radius: 28,
      color: p.ink,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('CPA', style: TextStyle(color: soft, fontWeight: FontWeight.w600, letterSpacing: 1, fontSize: 12)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                modules == 0 ? '' : '${_credits(credits)} · $modules ${modules == 1 ? 'module' : 'modules'}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: soft, fontSize: 12, fontFeatures: _tabular),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(c == null ? '—' : fmtMark(double.parse(c.toStringAsFixed(2))),
              style: TextStyle(
                  color: p.onInk, fontSize: 52, height: 1.05, fontWeight: FontWeight.w300, letterSpacing: -1.5, fontFeatures: _tabular)),
          const SizedBox(height: 2),
          Text(
            c == null ? 'Add a mark to see it' : Grading.degreeBand(c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.onInk, fontWeight: FontWeight.w500),
          ),
          if (projected != null) ...[
            const SizedBox(height: 4),
            Text('Projected ${projected!.toStringAsFixed(2)}', style: TextStyle(color: soft, fontSize: 13, fontFeatures: _tabular)),
          ],
          if (years.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: p.onInk.withValues(alpha: 0.12)),
            const SizedBox(height: 14),
            _YearAverages(items: years, labelColor: soft, valueColor: p.onInk),
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

    final resit = r.status == ModuleStatus.resit;
    final sub = [
      if (r.code.isNotEmpty) r.code,
      _credits(r.credits),
      if (resit) r.resitDate == null ? 'Resit' : 'Resit ${DateFormat('d MMM').format(r.resitDate!)}',
      if (r.status == ModuleStatus.ended && mark == null) 'Ended',
      if (r.resitMark != null && r.firstMark != null) 'was ${fmtMark(r.firstMark!)}',
    ].join(' · ');

    return InkWell(
      onTap: () => editModuleRecord(context, record: r, saved: saved),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary, height: 1.25)),
                  const SizedBox(height: 3),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: resit ? Colors.orange : p.textSecondary)),
                  if (soFar != null && r.totalWeight > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (r.markedWeight / r.totalWeight).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: p.surfaceAlt,
                        color: p.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _markColumn(p, mark, soFar),
          ],
        ),
      ),
    );
  }

  /// Right-aligned number with its letter (or "so far") underneath.
  Widget _markColumn(Palette p, double? mark, double? soFar) {
    final shown = mark ?? soFar;
    if (shown == null) return Text('—', style: TextStyle(fontSize: 18, color: p.textMuted));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(mark != null ? fmtMark(mark) : _fmt1(soFar!),
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w600, color: mark != null ? p.textPrimary : p.accent, fontFeatures: _tabular)),
        if (mark != null)
          Text(Grading.letter(mark), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _passColor(p, mark)))
        else
          Text('so far', style: TextStyle(fontSize: 12, color: p.textSecondary)),
      ],
    );
  }
}

/// Add or edit a module's grade record.
Future<void> editModuleRecord(BuildContext context, {ModuleRecord? record, bool saved = true}) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  final initial = record?.copy() ?? ModuleRecord(name: '', year: timetable.studyYear, semester: timetable.semester);
  final result = await showAppSheet<Object>(
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
      messenger.showSnackBar(SnackBar(content: Text('Resit on ${DateFormat('EEE d MMM').format(date)} added to your Hub')));
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
    if (credits == null || credits <= 0 || credits > 60) return setState(() => _error = 'Credits must be above 0');
    double? mark, resit;
    if (_mark.text.trim().isNotEmpty) {
      mark = _parse(_mark.text);
      if (mark == null || mark < 0 || mark > 100) return setState(() => _error = 'Mark must be 0–100');
    }
    if (_resit.text.trim().isNotEmpty) {
      resit = _parse(_resit.text);
      if (resit == null || resit < 0 || resit > 100) return setState(() => _error = 'Resit mark must be 0–100');
    }
    for (final x in r.parts) {
      if (x.weight <= 0 || x.weight > 100) return setState(() => _error = 'Each weight must be 1–100%');
      if (x.score != null && x.score! > x.outOf) {
        return setState(() => _error = '${x.name}: ${fmtMark(x.score!)} is more than ${fmtMark(x.outOf)}');
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
    final typed = _parse(_mark.text);
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
                    title: 'Remove "${r.name}"?', message: 'Its mark leaves your grades and CPA.', action: 'Remove');
                if (ok && context.mounted) Navigator.pop(context, 'delete');
              },
            ),
        ],
        child: SingleChildScrollView(
          // Room for the first field's floating label.
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: r.name.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Module name'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code')),
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
              const SizedBox(height: 22),
              _AssessmentEditor(record: r, onChanged: () => setState(() {})),
              const SizedBox(height: 18),
              TextField(
                controller: _mark,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: hasParts
                      ? 'Official mark (optional)'
                      : r.status == ModuleStatus.resit
                          ? 'First attempt mark'
                          : 'Final mark',
                  suffixText: typed == null ? '%' : '%  ${Grading.letter(typed)}',
                ),
              ),
              if (r.status == ModuleStatus.resit || _resit.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _resit,
                  keyboardType: _numKb,
                  inputFormatters: _numFormatters,
                  decoration: const InputDecoration(labelText: 'Resit mark', suffixText: '%'),
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
                    Icon(Icons.event_rounded, size: 20, color: p.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.resitDate == null ? 'Resit date' : DateFormat('EEE d MMM yyyy').format(r.resitDate!),
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
                TextButton(
                  onPressed: () => Navigator.pop(context, 'end'),
                  child: const Text('End module'),
                ),
              ],
              if (!widget.isNew && r.isEnded) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'reopen'),
                  child: const Text('Put back on timetable'),
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
            child: Text('How it\'s marked', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary)),
          ),
          if (parts.isNotEmpty)
            Text('${fmtMark(total)}%',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: weightOk ? p.textMuted : Colors.orange, fontFeatures: _tabular)),
        ]),
        const SizedBox(height: 10),
        if (parts.isEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in AssessmentPart.templates.entries) ActionChip(label: Text(t.key), onPressed: () => _useTemplate(t.value)),
            ],
          )
        else
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.border)),
            child: Column(children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: p.border),
                _PartRow(
                  key: ValueKey(parts[i].id),
                  part: parts[i],
                  onChanged: onChanged,
                  onRemove: () {
                    parts.removeAt(i);
                    onChanged();
                  },
                ),
              ],
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            tooltip: 'Add a part',
            onSelected: _add,
            itemBuilder: (_) => [for (final k in AssessmentPart.kinds) PopupMenuItem(value: k, child: Text(k))],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 18, color: p.accent),
                const SizedBox(width: 6),
                Text(parts.isEmpty ? 'Custom' : 'Add part', style: TextStyle(fontWeight: FontWeight.w600, color: p.accent)),
              ]),
            ),
          ),
        ),
        if (parts.isNotEmpty) _BreakdownSummary(record: record),
      ],
    );
  }
}

/// One assessment: name and weight on top, score / out of and the result below.
class _PartRow extends StatelessWidget {
  final AssessmentPart part;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _PartRow({super.key, required this.part, required this.onChanged, required this.onRemove});

  InputDecoration _box({String? hint, String? suffix}) => InputDecoration(
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final x = part;
    final pct = x.percent;
    final numStyle = TextStyle(fontFeatures: _tabular, color: p.textPrimary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: x.name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Name',
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => x.name = v,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: TextFormField(
                initialValue: fmtMark(x.weight),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.end,
                style: numStyle,
                decoration: _box(suffix: '%'),
                onChanged: (v) {
                  x.weight = _parse(v) ?? 0;
                  onChanged();
                },
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.textMuted),
              onPressed: onRemove,
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 68,
              child: TextFormField(
                initialValue: x.score == null ? '' : fmtMark(x.score!),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.center,
                style: numStyle,
                decoration: _box(hint: 'Score'),
                onChanged: (v) {
                  x.score = _parse(v);
                  onChanged();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(fontSize: 16, color: p.textMuted)),
            ),
            SizedBox(
              width: 68,
              child: TextFormField(
                initialValue: fmtMark(x.outOf),
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                textAlign: TextAlign.center,
                style: numStyle,
                decoration: _box(),
                onChanged: (v) {
                  x.outOf = _parse(v) ?? 100;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: pct == null
                    ? Text('—', textAlign: TextAlign.end, style: TextStyle(color: p.textMuted))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_fmt1(pct)}%',
                              maxLines: 1, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary, fontFeatures: _tabular)),
                          Text('+${_fmt1(x.points)} pts',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.textSecondary, fontFeatures: _tabular)),
                        ],
                      ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Where the module stands: the mark so far (or final), and what's needed
/// on the rest for each grade.
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
    final big = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.textPrimary, fontFeatures: _tabular);
    final small = TextStyle(fontSize: 13, color: p.textSecondary);

    final Widget headline;
    if (calc != null) {
      headline = Text.rich(TextSpan(children: [
        TextSpan(text: 'Final mark: ${_fmt1(calc)}%', style: big),
        TextSpan(text: '  ${Grading.letter(calc)}', style: big.copyWith(color: _passColor(p, calc))),
      ]));
    } else if (avg != null) {
      headline = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: '${_fmt1(avg)}%', style: big),
          TextSpan(text: '  so far', style: small),
        ])),
        const SizedBox(height: 2),
        Text('${fmtMark(r.markedWeight)}% of the module marked', style: small),
      ]);
    } else {
      headline = Text('No results yet', style: small);
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headline,
          if (!weightOk)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Weights add up to ${fmtMark(total)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
          if (calc == null && avg != null) ...[
            const SizedBox(height: 14),
            Text('Needed on the rest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textMuted)),
            const SizedBox(height: 6),
            Row(children: [for (final (t, label) in _targets) Expanded(child: _need(p, label, r.neededForTarget(t)))]),
          ],
        ],
      ),
    );
  }

  Widget _need(Palette p, String label, double? need) {
    final (String text, Color c) = switch (need) {
      null => ('—', p.textMuted),
      <= 0 => ('✓', _passColor(p, 100)),
      > 100 => ('—', p.textMuted),
      _ => ('${need.ceil()}%', p.textPrimary),
    };
    return Tooltip(
      message: need != null && need > 100 ? 'Out of reach' : '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c, fontFeatures: _tabular)),
        ],
      ),
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

  /// Where the pre-filled mark came from, e.g. "40% marked".
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
          hint: r.averageSoFar == null ? null : 'So far · ${fmtMark(r.markedWeight)}% marked',
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
    final planned = [
      for (final w in rows)
        if (w.mark != null) (w.credits, w.mark!)
    ];
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
    final periods = {for (final w in rows) (w.year, w.semester)}.toList()..sort((a, b) => (a.$1 * 10 + a.$2).compareTo(b.$1 * 10 + b.$2));

    final String verdict;
    if (needed == null) {
      verdict = 'Leave a mark blank to see what you need.';
    } else if (needed > 100) {
      verdict = 'Out of reach — needs ${needed.toStringAsFixed(1)}% average';
    } else if (needed <= 0) {
      verdict = 'Already reached';
    } else {
      verdict = '${needed.toStringAsFixed(1)}% average needed on ${_credits(remaining)}';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Row(children: [
          Expanded(child: _stat(p, 'Current', current)),
          const SizedBox(width: 10),
          Expanded(child: _stat(p, 'Projected', projected, highlight: true)),
        ]),
        if (years.length > 1) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _YearAverages(
              items: [for (final y in years) (y, Grading.weightedAverage(byYear[y]!)!)],
              labelColor: p.textSecondary,
              valueColor: p.textPrimary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SoftCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Target', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${_target.round()}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary, fontFeatures: _tabular)),
                      TextSpan(text: '  ${Grading.degreeBand(_target)}'),
                    ]),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textSecondary),
                  ),
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
              Text(verdict, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('What if'),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Every module has a mark. Add one to plan ahead.', style: TextStyle(color: p.textSecondary)),
          ),
        for (final (y, s) in periods) ...[
          // Period name, with the column headings over the inputs.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: p.textSecondary),
              child: Row(children: [
                Expanded(child: Text('Year $y · Semester $s', maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 64, child: Text('Credits', textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                const SizedBox(width: 64, child: Text('Mark', textAlign: TextAlign.center)),
                const SizedBox(width: 44),
              ]),
            ),
          ),
          _Group(children: [for (final w in rows.where((w) => w.year == y && w.semester == s)) _row(p, rows, w)]),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton.icon(
              onPressed: () => setState(
                  () => rows.add(_WhatIf('Module ${rows.length + 1}', 3, null, year: timetable.studyYear, semester: timetable.semester))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add module'),
            ),
            TextButton.icon(
              onPressed: () {
                final (y, s) = _nextPeriod(records, timetable);
                setState(() => rows.add(_WhatIf('Module ${rows.length + 1}', 3, null, year: y, semester: s)));
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Next semester'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text('Cap passed resits at 40', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
          value: records.capResit,
          onChanged: records.setCapResit,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Marks typed here aren\'t saved.', style: TextStyle(fontSize: 12, color: p.textMuted)),
        ),
      ],
    );
  }

  Widget _stat(Palette p, String label, double? v, {bool highlight = false}) => SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
            const SizedBox(height: 2),
            Text(v == null ? '—' : v.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w400, color: highlight ? p.accent : p.textPrimary, fontFeatures: _tabular)),
            Text(v == null ? ' ' : Grading.degreeBand(v),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          ],
        ),
      );

  Widget _row(Palette p, List<_WhatIf> rows, _WhatIf w) {
    return Padding(
      key: ObjectKey(w),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary, height: 1.25)),
                if (w.hint != null)
                  Text(w.hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Credits',
            child: SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: fmtMark(w.credits),
                textAlign: TextAlign.center,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                style: const TextStyle(fontFeatures: _tabular),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                onChanged: (v) => setState(() => w.credits = _parse(v) ?? 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Mark',
            child: SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: w.mark == null ? '' : fmtMark(w.mark!),
                textAlign: TextAlign.center,
                keyboardType: _numKb,
                inputFormatters: _numFormatters,
                style: const TextStyle(fontFeatures: _tabular),
                decoration:
                    const InputDecoration(hintText: '—', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                onChanged: (v) => setState(() => w.mark = _parse(v)?.clamp(0, 100).toDouble()),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: p.textMuted),
            onPressed: () => setState(() => rows.remove(w)),
          ),
        ],
      ),
    );
  }
}
