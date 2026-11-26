// Renders the Windows (desktop shell) screenshots for the website.
//   flutter test tools/website_desktop_shots_test.dart --update-goldens
//   (DARK=1 for the dark theme, SHOTS=home,board to render a subset)
// Output: tools/_website/*.png  → converted to website/assets/desktop/*.webp
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:uom_per_app/providers/theme_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/academic_tab.dart';
import 'package:uom_per_app/screens/dashboard_tab.dart';
import 'package:uom_per_app/screens/focus_screen.dart';
import 'package:uom_per_app/screens/grades_screen.dart';
import 'package:uom_per_app/screens/home_screen.dart';
import 'package:uom_per_app/screens/schedule_tab.dart';
import 'package:uom_per_app/screens/todo_board_tab.dart';
import 'package:uom_per_app/services/activity_log.dart';
import 'package:uom_per_app/services/bus_repository.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/theme/app_theme.dart';
import 'package:uom_per_app/widgets/desktop_shell.dart';

import '../test/screens_overflow_test.dart' show FakeIsarService;

Future<void> _loadFonts() async {
  Future<ByteData> win(String f) => File('C:/Windows/Fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer));
  final segoe = FontLoader('Segoe UI');
  for (final f in ['segoeui.ttf', 'seguisb.ttf', 'segoeuib.ttf', 'segoeuil.ttf']) {
    segoe.addFont(win(f));
  }
  await segoe.load();
  await (FontLoader('Georgia')..addFont(win('georgia.ttf'))).load();
  await (FontLoader('Emoji')..addFont(win('seguiemj.ttf'))).load();
  final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')
        ..addFont(File('$fonts/materialicons-regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
}

const _btnText = WidgetStatePropertyAll(TextStyle(fontFamily: 'Segoe UI', fontSize: 13.5, fontWeight: FontWeight.w600));

ThemeData _fix(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: 'Segoe UI', fontFamilyFallback: const ['Emoji']),
      primaryTextTheme: t.primaryTextTheme.apply(fontFamily: 'Segoe UI'),
      textButtonTheme: TextButtonThemeData(style: t.textButtonTheme.style?.copyWith(textStyle: _btnText)),
      filledButtonTheme: FilledButtonThemeData(style: t.filledButtonTheme.style?.copyWith(textStyle: _btnText)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: t.outlinedButtonTheme.style?.copyWith(textStyle: _btnText)),
    );

TimetableProvider _demo(SyncService sync, FakeIsarService isar) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  String day(int i) => DateFormat('EEEE').format(monday.add(Duration(days: i)));
  final today = DateFormat('EEEE').format(now);
  ClassSession c(String subject, String code, String d, String start, String end, String room, {String? link}) =>
      ClassSession(subject: subject, moduleCode: code, day: d, startTime: start, endTime: end, room: room, meetingLink: link);
  // One clean week: no two classes overlap, today has a cancelled lecture.
  final sessions = [
    c('Data Structures', 'CS2001', day(0), '09:00', '11:00', 'LT 2'),
    c('Databases', 'CS2010', day(0), '13:00', '14:30', 'Lab 3'),
    c('Mobile Computing', 'CS2040', day(1), '10:00', '12:00', 'Online', link: 'https://meet.google.com/abc-defg-hij'),
    c('Statistics', 'MA2002', day(1), '14:00', '16:00', 'ENG 1'),
    c('Data Structures', 'CS2001', day(2), '09:00', '11:00', 'LT 2'),
    c('Databases', 'CS2010', day(2), '13:00', '14:30', 'Lab 3'),
    c('Mobile Computing', 'CS2040', day(3), '10:00', '12:00', 'Online', link: 'https://meet.google.com/abc-defg-hij'),
    c('Databases', 'CS2010', day(3), '13:00', '14:30', 'Lab 3'),
    c('Statistics', 'MA2002', day(3), '15:00', '16:30', 'ENG 1'),
    c('Software Engineering', 'CS2030', day(4), '09:00', '12:00', 'NAC 2.12'),
    c('Data Structures', 'CS2001', day(4), '13:00', '14:00', 'Tutorial room 4'),
  ];
  for (final s in sessions.where((s) => s.day == today && s.subject == 'Databases')) {
    s.cancelledDates = [DateFormat('yyyy-MM-dd').format(now)];
  }
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

/// Text whose style names no font (e.g. buttons with their own TextStyle) is
/// drawn in the test font; on Windows it would be Segoe UI, so set that.
Future<void> _segoeEverywhere(WidgetTester t) async {
  for (final rp in t.allRenderObjects.whereType<RenderParagraph>()) {
    final span = rp.text;
    if (span is TextSpan && span.style?.fontFamily == null) {
      rp.text = TextSpan(
        text: span.text,
        children: span.children,
        style: (span.style ?? const TextStyle())
            .copyWith(fontFamily: 'Segoe UI', fontFamilyFallback: const ['Emoji']),
      );
    }
  }
  await t.pump();
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  final shots = <String, (int, Widget Function(), Future<void> Function(WidgetTester)?)>{
    'home': (AppPage.home, () => const DashboardTab(), null),
    'schedule': (AppPage.schedule, () => const ScheduleTab(), (t) => _tap(t, 'Week')),
    'schedule_month': (AppPage.schedule, () => const ScheduleTab(), (t) => _tap(t, 'Month')),
    'hub': (AppPage.hub, () => const AcademicTab(), null),
    'board': (AppPage.board, () => const TodoBoardTab(), null),
    'focus': (AppPage.focus, () => const FocusScreen(), null),
    'grades': (AppPage.grades, () => const GradesScreen(), null),
    'palette': (AppPage.home, () => const DashboardTab(), (t) => _tap(t, 'Jump to…')),
  };
  final only = Platform.environment['SHOTS'];
  final dark = Platform.environment['DARK'] == '1';

  for (final shot in shots.entries) {
    if (only != null && !only.split(',').contains(shot.key)) continue;
    testWidgets(shot.key, (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_locations_json': jsonEncode(BusRepository.presets),
        ActivityLog.prefsKey: _activity(),
      });
      await ActivityLog.instance.load();
      tester.view.physicalSize = const Size(2880, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
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
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
          ChangeNotifierProvider(
              create: (ctx) => RecordProvider(null, ctx.read<TimetableProvider>().setEndedModules)
                ..debugSetData(records: _records())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _fix(AppTheme.light()),
          darkTheme: _fix(AppTheme.dark()),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: HomeNavigation(
            goTo: (_) {},
            child: Scaffold(body: DesktopShell(selected: shot.value.$1, onSelect: (_) {}, body: shot.value.$2())),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await shot.value.$3?.call(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _segoeEverywhere(tester);
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('_website/${shot.key}${dark ? '_dark' : ''}.png'));
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
