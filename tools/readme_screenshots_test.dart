// Renders the README screenshots from the real screens with demo data.
//   flutter test tools/readme_screenshots_test.dart --update-goldens
// Output: docs/screenshots/*.png
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/class_session.dart';
import 'package:uom_per_app/providers/focus_provider.dart';
import 'package:uom_per_app/providers/note_provider.dart';
import 'package:uom_per_app/providers/resource_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/dashboard_tab.dart';
import 'package:uom_per_app/screens/focus_screen.dart';
import 'package:uom_per_app/screens/home_screen.dart';
import 'package:uom_per_app/screens/schedule_tab.dart';
import 'package:uom_per_app/screens/todo_board_tab.dart';
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
  // Emoji (☕ on the dashboard); phones have their own emoji font.
  final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
  if (emoji.existsSync()) {
    await (FontLoader('Emoji')..addFont(emoji.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  }
}

ThemeData _theme() {
  final t = AppTheme.light();
  return t.copyWith(textTheme: t.textTheme.apply(fontFamilyFallback: const ['Emoji']));
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
        semesterStart: monday.subtract(const Duration(days: 35)));
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final shots = <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
    'dashboard': (() => const DashboardTab(), null),
    'schedule_day': (() => const ScheduleTab(), null),
    'schedule_week': (() => const ScheduleTab(), (t) => _tap(t, 'Week')),
    'schedule_month': (() => const ScheduleTab(), (t) => _tap(t, 'Month')),
    'board': (() => const TodoBoardTab(), null),
    'focus': (() => const FocusScreen(), null),
  };

  for (final shot in shots.entries) {
    testWidgets(shot.key, (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
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
          ChangeNotifierProvider.value(value: focus),
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
