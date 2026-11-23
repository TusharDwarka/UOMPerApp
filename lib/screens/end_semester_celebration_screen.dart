import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/record_provider.dart';
import '../providers/timetable_provider.dart';
import '../utils/time_utils.dart';
import '../widgets/ui.dart';
import 'celebration_screen.dart';

/// Ends the semester: confetti, modules archived to Grades, and the app
/// switches to holiday mode (calendar, board, notes, focus keep working).
/// The timetable is only cleared when the student starts the next semester.
Future<void> finishSemester(BuildContext context) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  await CelebrationScreen.show(
    context,
    emoji: '🎉',
    title: 'Semester complete!',
    message: 'Well done. Your modules are saved in Grades and the app is now in holiday mode — '
        'your calendar, board, notes and focus timer keep working.',
    footer: 'Start the next semester from Home or Settings whenever you\'re ready.',
    work: () async {
      await records.endSemester(timetable.scheduleSubjects, year: timetable.studyYear, semester: timetable.semester);
      // Classes stop showing from tomorrow.
      final today = dateOnly(DateTime.now());
      final end = timetable.semesterEnd;
      if (end == null || end.isAfter(today)) {
        await timetable.setSemesterDates(timetable.semesterStart, today);
        await timetable.loadSessions();
      }
    },
  );
}

/// Leaves holiday mode: suggests the next year/semester, clears the old
/// timetable and opens onboarding to import the new one. Grades, tasks,
/// notes and files are kept.
Future<void> startNextSemester(BuildContext context) async {
  final timetable = context.read<TimetableProvider>();
  final records = context.read<RecordProvider>();
  var year = timetable.semester == 2 ? (timetable.studyYear + 1).clamp(1, 5) : timetable.studyYear;
  var semester = timetable.semester == 2 ? 1 : 2;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Start next semester?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Holiday mode ends and you\'ll set up the new timetable. Last semester\'s classes are cleared; '
                'your grades, tasks, notes and files stay.'),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('New period', style: TextStyle(fontWeight: FontWeight.w600))),
              ChoicePill<int>(
                title: 'Year of study',
                value: year,
                options: const [1, 2, 3, 4, 5],
                labelOf: (y) => 'Y$y',
                onChanged: (y) => setD(() => year = y),
              ),
              const SizedBox(width: 6),
              ChoicePill<int>(
                title: 'Semester',
                value: semester,
                options: const [1, 2],
                labelOf: (s) => 'S$s',
                onChanged: (s) => setD(() => semester = s),
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await records.setHolidayMode(false);
  await timetable.setStudyPeriod(year: year, semester: semester);
  // Same programme next semester: keep its name for setup.
  await timetable.resetForNewSetup(keepCourse: true);
}
