import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/class_session.dart';
import 'package:uom_per_app/screens/notes_tab.dart';
import 'package:uom_per_app/services/bus_repository.dart';
import 'package:uom_per_app/services/pdf_export.dart';

void main() {
  group('bus route sharing', () {
    final route = {
      'location_name': "At Réduit (going to L'Escalier)",
      'bus_route': '200',
      'schedules': {
        'weekdays': [
          {'departure': '08:05', 'arrival': '09:11', 'bus_name': 'UBS'},
          {'departure': '6:14', 'arrival': '7:20'},
        ],
        'saturdays': [],
        'sundays_public_holidays': [],
      },
    };

    test('round-trips through a share message, accents and all', () {
      final message = BusRepository.shareMessage(route);
      expect(message, contains('UOMBUS1:'));
      final decoded = BusRepository.decodeRoute('Hey try this bus!\n$message\nthanks');
      expect(decoded, isNotNull);
      expect(decoded!['location_name'], "At Réduit (going to L'Escalier)");
      final trips = decoded['schedules']['weekdays'] as List;
      expect(trips.map((t) => t['departure']), ['06:14', '08:05'], reason: 'normalised and sorted on import');
      expect(trips.last['bus_name'], 'UBS');
    });

    test('rejects text without a valid code', () {
      expect(BusRepository.decodeRoute('no code here'), isNull);
      expect(BusRepository.decodeRoute('UOMBUS1:not-really-base64!!'), isNull);
    });

    test('presets are available but not forced on new users', () {
      expect(BusRepository.presets, isNotEmpty);
    });
  });

  group('note formatting', () {
    test('ticking a checklist line', () {
      const text = '# Revision\n☐ Chapter 1\n☑ Chapter 2\n• bullet';
      final ticked = toggleChecklistLine(text, 1);
      expect(ticked.split('\n')[1], '☑ Chapter 1');
      expect(toggleChecklistLine(ticked, 1), text);
      expect(toggleChecklistLine(text, 3), text, reason: 'non-checklist lines are unchanged');
    });

    test('checklist progress', () {
      expect(checklistProgress('plain note'), isNull);
      expect(checklistProgress('☐ a\n☑ b\n☑ c\n☐ d'), 0.5);
    });

    testWidgets('formatted note renders on a narrow card without overflow', (tester) async {
      tester.view.physicalSize = const Size(160, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteBody(
              text: '# A long heading that wraps\n**Bold** start and more words\n'
                  '• bullet point with plenty of text\n☐ unchecked item that is long\n☑ done item\nplain',
              maxLines: 5,
            ),
          ),
        ),
      ));
      expect(find.text('…'), findsOneWidget, reason: 'extra lines are cut off with an ellipsis');
    });
  });

  group('PDF export', () {
    final now = DateTime.now();
    final tasks = [
      AcademicTask(title: 'Stats assignment — part 2', type: 'Assignment', subject: 'Statistics', dueDate: now.add(const Duration(days: 2))),
      AcademicTask(title: 'Exam week', type: 'Exam', dueDate: now.add(const Duration(days: 6)), startDate: now.add(const Duration(days: 3)),
          colorValue: 0xFF7C4DFF, description: 'Bring ID\n---ROOM---\nMain Hall'),
      AcademicTask(title: 'Lab report 🚀 “final”', type: 'Lab report', dueDate: now.add(const Duration(days: 1)), status: TaskStatus.doing),
      AcademicTask(title: 'Done thing', type: 'Homework', dueDate: now, isCompleted: true, status: TaskStatus.done),
    ];

    test('text is made safe for the built-in fonts', () {
      expect(pdfSafe('3:00 PM'), '3:00 PM');
      expect(pdfSafe('Réduit'), 'Réduit');
      expect(pdfSafe('“quote” — dash 🚀'), '"quote" - dash ');
      expect(pdfSafe('☐ todo'), '[ ] todo');
    });

    test('filters: custom types count as Other; Done excluded by default', () {
      final o = TaskReportOptions(from: now, to: now.add(const Duration(days: 30)), types: const {'Other'});
      final matched = tasks.where(o.matches).map((t) => t.title).toList();
      expect(matched, ['Lab report 🚀 “final”']);
    });

    test('task report with calendar pages renders', () async {
      final bytes = await PdfExport.taskReport(
          tasks, TaskReportOptions(from: now, to: now.add(const Duration(days: 40)), statuses: TaskStatus.all.toSet()));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('empty report still renders', () async {
      final bytes = await PdfExport.taskReport(const [], TaskReportOptions(from: now, to: now));
      expect(bytes.length, greaterThan(500));
    });

    for (final style in ['lined', 'dotted', 'grid']) {
      test('$style note paper renders', () async {
        final bytes = await PdfExport.notePaper(style: style, pages: 2, module: 'Réseaux');
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      });
    }

    test('month and week planners render', () async {
      final month = await PdfExport.monthPlanner(month: DateTime(now.year, now.month), months: 2, tasks: tasks);
      expect(String.fromCharCodes(month.take(4)), '%PDF');
      final week = await PdfExport.weekPlanner(
        weekStart: now,
        weeks: 2,
        tasks: tasks,
        classesFor: (d) => [ClassSession(subject: 'Databases', day: 'Monday', startTime: '09:00', endTime: '10:00', room: 'Lab 3')],
      );
      expect(String.fromCharCodes(week.take(4)), '%PDF');
    });
  });
}
