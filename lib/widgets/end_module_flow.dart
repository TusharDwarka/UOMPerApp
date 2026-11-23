import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/academic_task.dart';
import '../models/module_record.dart';
import '../providers/record_provider.dart';
import '../providers/timetable_provider.dart';
import '../screens/celebration_screen.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// "End module": for a module that finishes before the semester does (final
/// test done, lab module over...). Two confirmations, then confetti. Its
/// classes stop showing after today; marks go to Grades.
Future<void> startEndModuleFlow(BuildContext context, String moduleName) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  final openTasks =
      timetable.pendingTasks.where((t) => t.subject.trim().toLowerCase() == moduleName.trim().toLowerCase()).length;

  // Step 1 — acknowledge what ending means.
  final step1 = await showDialog<bool>(
    context: context,
    builder: (_) => _AcknowledgeDialog(moduleName: moduleName, openTasks: openTasks),
  );
  if (step1 != true || !context.mounted) return;

  // Step 2 — final confirmation (and the mark, if it's already out).
  final step2 = await showDialog<({double? mark})>(
    context: context,
    builder: (_) => _ConfirmDialog(moduleName: moduleName),
  );
  if (step2 == null || !context.mounted) return;

  final mark = step2.mark;
  final failed = mark != null && mark < Grading.passMark;
  await CelebrationScreen.show(
    context,
    emoji: failed ? '💪' : '🎓',
    title: failed ? 'Module done' : 'Module complete!',
    message: failed
        ? '$moduleName is over. That mark is below the pass mark, so let\'s plan the resit next.'
        : '$moduleName is finished${mark != null ? ' with ${_fmt(mark)}% (${Grading.letter(mark)})' : ''}. '
            'Its classes are off your timetable from tomorrow.',
    footer: 'Changed your mind? Grades → the module → "Put back on timetable".',
    showFor: const Duration(seconds: 3),
    work: () => records.endModule(moduleName, year: timetable.studyYear, semester: timetable.semester, mark: mark),
  );
  if (failed && context.mounted) await offerResit(context, moduleName);
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Marks a module for a resit, optionally adding the resit exam to the Hub.
Future<void> offerResit(BuildContext context, String moduleName) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  final res = await showDialog<({bool resit, DateTime? date})>(context: context, builder: (_) => _ResitDialog(moduleName: moduleName));
  if (res == null || !res.resit) return;
  await records.markResit(moduleName, date: res.date);
  final date = res.date;
  if (date != null) await addResitExam(timetable, moduleName, date);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(date == null
          ? '$moduleName marked for resit'
          : 'Resit on ${DateFormat('EEE d MMM').format(date)} added to your Hub with reminders'),
    ));
  }
}

/// Puts the resit exam in the Hub with reminders 3 days and 1 day before.
Future<void> addResitExam(TimetableProvider timetable, String moduleName, DateTime date) => timetable.saveTask(AcademicTask(
      title: 'Resit · $moduleName',
      subject: moduleName,
      type: 'Exam',
      dueDate: DateTime(date.year, date.month, date.day, 9),
    )..remindBefore = [4320, 1440]);

class _AcknowledgeDialog extends StatefulWidget {
  final String moduleName;
  final int openTasks;
  const _AcknowledgeDialog({required this.moduleName, required this.openTasks});

  @override
  State<_AcknowledgeDialog> createState() => _AcknowledgeDialogState();
}

class _AcknowledgeDialogState extends State<_AcknowledgeDialog> {
  bool _ack = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: p.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: p.textSecondary, height: 1.35))),
          ]),
        );
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('End ${widget.moduleName}?', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1 of 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.accent)),
            const SizedBox(height: 10),
            point(Icons.event_busy_rounded, 'Its classes disappear from your timetable, reminders and widget after today.'),
            point(Icons.workspace_premium_outlined, 'It moves to Grades, where you can add the final mark (or a resit).'),
            point(
                Icons.task_alt_rounded,
                widget.openTasks == 0
                    ? 'No open tasks for this module.'
                    : 'You still have ${widget.openTasks} open task${widget.openTasks == 1 ? '' : 's'} for it — they stay on your board.'),
            point(Icons.undo_rounded, 'You can put it back on the timetable later.'),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _ack,
              onChanged: (v) => setState(() => _ack = v ?? false),
              title: const Text('The last class / final test for this module is done', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _ack ? () => Navigator.pop(context, true) : null, child: const Text('Continue')),
      ],
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  final String moduleName;
  const _ConfirmDialog({required this.moduleName});

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _mark = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _mark.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _mark.text.trim().replaceAll(',', '.');
    double? mark;
    if (raw.isNotEmpty) {
      mark = double.tryParse(raw);
      if (mark == null || mark < 0 || mark > 100) {
        setState(() => _error = 'Enter a mark between 0 and 100, or leave it empty');
        return;
      }
    }
    Navigator.pop(context, (mark: mark));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Are you sure?', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 2 of 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.accent)),
            const SizedBox(height: 10),
            Text('Ending "${widget.moduleName}" now.', style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _mark,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Mark % (optional)',
                helperText: 'Or add it later in Grades',
                errorText: _error,
                prefixIcon: const Icon(Icons.percent_rounded),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.flag_rounded, size: 18),
          label: const Text('End module'),
        ),
      ],
    );
  }
}

class _ResitDialog extends StatefulWidget {
  final String moduleName;
  const _ResitDialog({required this.moduleName});

  @override
  State<_ResitDialog> createState() => _ResitDialogState();
}

class _ResitDialogState extends State<_ResitDialog> {
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Resit this module?', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${widget.moduleName}" will show as a resit in Grades. Your resit mark replaces the first one in your CPA.',
              style: TextStyle(color: p.textSecondary, height: 1.35)),
          const SizedBox(height: 14),
          SoftCard(
            color: p.surfaceAlt,
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _date ?? now.add(const Duration(days: 30)),
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Row(children: [
              Icon(Icons.event_rounded, color: p.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_date == null ? 'Resit date (if known)' : DateFormat('EEE d MMM yyyy').format(_date!),
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
              ),
              if (_date != null) const Icon(Icons.check_rounded, size: 18),
            ]),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, (resit: false, date: null)), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(context, (resit: true, date: _date)), child: const Text('Mark for resit')),
      ],
    );
  }
}
