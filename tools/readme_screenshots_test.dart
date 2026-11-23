// Renders the README screenshots from the real screens with demo data.
//   flutter test tools/readme_screenshots_test.dart --update-goldens
// Output: docs/screenshots/*.png
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/class_session.dart';
import 'package:uom_per_app/models/module_record.dart';
import 'package:uom_per_app/providers/focus_provider.dart';
import 'package:uom_per_app/providers/note_provider.dart';
import 'package:uom_per_app/providers/record_provider.dart';
import 'package:uom_per_app/providers/resource_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/dashboard_tab.dart';
import 'package:uom_per_app/screens/focus_screen.dart';
import 'package:uom_per_app/screens/grades_screen.dart';
import 'package:uom_per_app/screens/home_screen.dart';
import 'package:uom_per_app/screens/schedule_tab.dart';
import 'package:uom_per_app/screens/todo_board_tab.dart';
import 'package:uom_per_app/services/activity_log.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/theme/app_theme.dart';

import '../test/screens_overflow_test.dart' show FakeIsarService;

/// Tests render text as boxes unless real fonts are loaded.
Future<void> _loadFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) => File('$fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer));
  final roboto = FontLoader('Roboto');
  for (final w in ['light', 'regular', 'medium', 'bold', 'black']) {
    roboto.addFont(bytes('roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'))).load();
  // Emoji (â˜• on the dashboard); phones have their own emoji font.
  final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
  if (emoji.existsSync()) {
    await (FontLoader('Emoji')..addFont(emoji.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  }
}

ThemeData _theme() {
  final t = AppTheme.light();
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamilyFallback: const ['Emoji']),
    // The theme's button text has no family; tests would draw it as boxes.
    textButtonTheme: TextButtonThemeData(
        style: t.textButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600)))),
  );
}

TimetableProvider _demo(SyncService sync, FakeIsarService isar) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  String day(int i) => DateFormat('EEEE').format(monday.add(Duration(days: i)));
  final today = DateFormat('EEEE').format(now);
  ClassSession c(String subject, String code, String d, String start, String end, String room, {String? link}) =>
      ClassSession(subject: subject, moduleCode: code, day: d, startTime: start, endTime: end, room: room, meetingLink: link);
  final sessions = [
    for (final d in {day(0), day(2), today}) ...[
      c('Data Structures', 'CS2001', d, '09:00', '11:00', 'LT 2'),
      c('Databases', 'CS2010', d, '13:00', '14:30', 'Lab 3'),
    ],
    for (final d in {day(1), day(3), today})
      c('Mobile Computing', 'CS2040', d, '10:00', '12:00', 'Online', link: 'https://meet.google.com/abc-defg-hij'),
    c('Statistics', 'MA2002', day(1), '14:00', '16:00', 'ENG 1'),
    c('Software Engineering', 'CS2030', day(4), '09:00', '12:00', 'NAC 2.12'),
    c('Statistics', 'MA2002', day(3), '15:00', '16:30', 'ENG 1'),
  ];
  // One cancelled lecture today so the screenshots show the feature.
  sessions.lastWhere((s) => s.day == today && s.subject == 'Databases').cancelledDates = [
    DateFormat('yyyy-MM-dd').format(now)
  ];
  final tasks = [
    AcademicTask(title: 'Linked list assignment', subject: 'Data Structures', type: 'Assignment',
        dueDate: now.add(const Duration(days: 2)), priority: 2),
    AcademicTask(title: 'ER diagram', subject: 'Databases', type: 'Homework', dueDate: now.add(const Duration(days: 1)),
        status: TaskStatus.doing),
    AcademicTask(title: 'Midterm', subject: 'Statistics', type: 'Exam', dueDate: now.add(const Duration(days: 6))),
    AcademicTask(title: 'App prototype', subject: 'Mobile Computing', type: 'Project',
        dueDate: now.add(const Duration(days: 10)), status: TaskStatus.doing),
    AcademicTask(title: 'Quiz 2', subject: 'Software Engineering', type: 'Test', dueDate: now.add(const Duration(days: 3))),
    AcademicTask(title: 'Lab report 1', subject: 'Databases', type: 'Homework', dueDate: now, isCompleted: true,
        status: TaskStatus.done),
  ];
  return TimetableProvider(isar, sync)
    ..debugSetData(
        sessions: sessions,
        tasks: tasks,
        courseName: 'BSc Computer Science',
        studyYear: 2,
        semester: 1,
        semesterStart: monday.subtract(const Duration(days: 35)));
}

/// Year 2 so far plus a graded Year 1, with ongoing modules part-marked.
List<ModuleRecord> _records() => [
      ModuleRecord(name: 'Data Structures', code: 'CS2001', credits: 4, year: 2, semester: 1, parts: [
        AssessmentPart(name: 'Test 1', weight: 20, score: 16, outOf: 20),
        AssessmentPart(name: 'Test 2', weight: 20, score: 14, outOf: 20),
        AssessmentPart(name: 'Assignment', weight: 10, score: 78),
        AssessmentPart(name: 'Final exam', weight: 50),
      ]),
      ModuleRecord(name: 'Databases', code: 'CS2010', credits: 3, year: 2, semester: 1, status: ModuleStatus.ended, mark: 72),
      ModuleRecord(name: 'Mobile Computing', code: 'CS2040', credits: 3, year: 2, semester: 1, parts: [
        AssessmentPart(name: 'Coursework', weight: 40, score: 68),
        AssessmentPart(name: 'Final exam', weight: 60),
      ]),
      ModuleRecord(name: 'Software Engineering', code: 'CS2030', credits: 4, year: 2, semester: 1, parts: [
        AssessmentPart(name: 'Class test 1', weight: 10, score: 8, outOf: 10),
        AssessmentPart(name: 'Class test 2', weight: 10, score: 7, outOf: 10),
        AssessmentPart(name: 'Class test 3', weight: 10),
        AssessmentPart(name: 'Final exam', weight: 70),
      ]),
      ModuleRecord(name: 'Statistics', code: 'MA2002', credits: 3, year: 2, semester: 1),
      ModuleRecord(name: 'Programming II', credits: 3, year: 1, semester: 2, status: ModuleStatus.ended, mark: 66),
      ModuleRecord(name: 'Discrete Maths', credits: 3, year: 1, semester: 2, status: ModuleStatus.ended, mark: 58),
      ModuleRecord(name: 'Computer Architecture', credits: 3, year: 1, semester: 2, status: ModuleStatus.ended, mark: 38, resitMark: 61),
      ModuleRecord(name: 'Programming I', credits: 3, year: 1, semester: 1, status: ModuleStatus.ended, mark: 71),
      ModuleRecord(name: 'Maths for Computing', credits: 3, year: 1, semester: 1, status: ModuleStatus.ended, mark: 55),
    ];

/// Half a year of tasks and notes for the Home heatmap.
String _activity() {
  final rnd = Random(7);
  final now = DateTime.now();
  return jsonEncode({
    for (var d = 0; d < 180; d++)
      if (rnd.nextDouble() < 0.62)
        DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: d))): {
          'tasks': rnd.nextInt(5),
          'notes': rnd.nextInt(3),
        },
  });
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

/// Home customised with the activity heatmap first (as set in "Customise home").
const _activityHome = {
  'home_sections_order': ['activity', 'next', 'cards', 'focus', 'deadlines', 'today'],
  'home_sections_enabled': ['activity', 'next', 'cards', 'today'],
};

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({ActivityLog.prefsKey: _activity()}));

  final shots = <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
    'dashboard': (() => const DashboardTab(), null),
    'schedule_day': (() => const ScheduleTab(), null),
    'schedule_week': (() => const ScheduleTab(), (t) => _tap(t, 'Week')),
    'schedule_month': (() => const ScheduleTab(), (t) => _tap(t, 'Month')),
    'board': (() => const TodoBoardTab(), null),
    'focus': (() => const FocusScreen(), null),
    'activity': (() => const DashboardTab(), null),
    'grades': (() => const GradesScreen(), null),
    'module_marks': (() => const GradesScreen(), (t) => _tap(t, 'Data Structures')),
  };

  for (final shot in shots.entries) {
    testWidgets(shot.key, (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
      addTearDown(tester.view.reset);
      if (shot.key == 'activity') {
        SharedPreferences.setMockInitialValues({ActivityLog.prefsKey: _activity(), ..._activityHome});
      }
      final isar = FakeIsarService();
      final sync = SyncService(isar);
      final focus = FocusProvider();
      await focus.load();
      for (var d = 0; d < 7; d++) {
        focus.addMinutes([50, 95, 30, 120, 75, 20, 60][d], day: DateTime.now().subtract(Duration(days: d)));
      }
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<SyncService>.value(value: sync),
          ChangeNotifierProvider(create: (_) => _demo(sync, isar)),
          ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
          ChangeNotifierProvider(create: (_) => ResourceProvider(isar, sync)),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
          ChangeNotifierProvider(create: (ctx) {
            final records = RecordProvider(null, ctx.read<TimetableProvider>().setEndedModules);
            if (shot.key == 'grades' || shot.key == 'module_marks') records.debugSetData(records: _records());
            return records;
          }),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          home: HomeNavigation(goTo: (_) {}, child: shot.value.$1()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await shot.value.$2?.call(tester);
      await tester.pump(const Duration(milliseconds: 800));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/${shot.key}.png'));
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });
  }
}
