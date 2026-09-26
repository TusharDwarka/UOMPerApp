import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/attendance_record.dart';
import 'package:uom_per_app/models/class_session.dart';
import 'package:uom_per_app/providers/focus_provider.dart';
import 'package:uom_per_app/providers/note_provider.dart';
import 'package:uom_per_app/providers/resource_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/academic_tab.dart';
import 'package:uom_per_app/screens/bus_tab.dart';
import 'package:uom_per_app/screens/dashboard_tab.dart';
import 'package:uom_per_app/screens/focus_screen.dart';
import 'package:uom_per_app/screens/home_screen.dart';
import 'package:uom_per_app/screens/resources_tab.dart';
import 'package:uom_per_app/screens/schedule_tab.dart';
import 'package:uom_per_app/screens/todo_board_tab.dart';
import 'package:uom_per_app/services/isar_service.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/screens/notes_tab.dart';
import 'package:uom_per_app/screens/print_center_screen.dart';
import 'package:uom_per_app/theme/app_theme.dart';
import 'package:uom_per_app/widgets/add_edit_class_sheet.dart';
import 'package:uom_per_app/widgets/add_edit_task_sheet.dart';
import 'package:uom_per_app/widgets/class_details_sheet.dart';

/// Isar can't open inside `flutter test`; screens only need providers.
class FakeIsarService implements IsarService {
  @override
  Future<Isar> db = Completer<Isar>().future;
  @override
  Future<Isar> openDB() => db;
  @override
  Future<void> cleanDb() async {}
}

const longModule = 'Advanced Statistical Methods for Data Science and Machine Learning';

TimetableProvider seededTimetable(SyncService sync, IsarService isar) {
  final now = DateTime.now();
  final today = DateFormat('EEEE').format(now);
  final tomorrow = DateFormat('EEEE').format(now.add(const Duration(days: 1)));
  final sessions = [
    ClassSession(subject: longModule, day: today, startTime: '07:30', endTime: '09:00', room: 'NAC 2.12 — Lecture Theatre 1'),
    ClassSession(subject: 'Mobile Computing', day: today, startTime: '08:30', endTime: '10:00', room: 'Online',
        meetingLink: 'https://teams.microsoft.com/l/meetup-join/abc'),
    ClassSession(subject: 'Databases', day: today, startTime: '09:00', endTime: '10:00', room: 'Lab 3'),
    ClassSession(subject: 'Late Seminar', day: today, startTime: '19:00', endTime: '20:30', room: 'Room 101',
        meetingLink: 'https://meet.google.com/abc-defg-hij'),
    ClassSession(subject: 'Statistics', day: tomorrow, startTime: '10:00', endTime: '12:00', room: 'ENG 1'),
  ];
  final tasks = [
    AcademicTask(title: 'A very long assignment title that goes on and on to test wrapping and ellipsis in cards',
        subject: longModule, type: 'Assignment', dueDate: now.add(const Duration(days: 1)), priority: 2,
        meetingLink: 'https://meet.google.com/xyz'),
    AcademicTask(title: 'Exam week', subject: 'Statistics', type: 'Exam', dueDate: now.add(const Duration(days: 5)),
        startDate: now.add(const Duration(days: 2)), colorValue: 0xFF7C4DFF,
        description: 'Bring calculator\n---ROOM---\nMain Hall, seat block C'),
    AcademicTask(title: 'Read chapter 4', subject: 'Databases', type: 'Homework', dueDate: now, status: TaskStatus.doing),
    AcademicTask(title: 'Overdue quiz', subject: 'Mobile Computing', type: 'Test', dueDate: now.subtract(const Duration(days: 2))),
    AcademicTask(title: 'Done project', subject: 'Databases', type: 'Project', dueDate: now, isCompleted: true, status: TaskStatus.done),
  ];
  final attendance = [
    AttendanceRecord()
      ..subjectName = 'Databases'
      ..date = DateTime(now.year, now.month, now.day - 7)
      ..isPresent = true,
    AttendanceRecord()
      ..subjectName = longModule
      ..date = DateTime(now.year, now.month, now.day - 7)
      ..isPresent = false,
  ];
  return TimetableProvider(isar, sync)
    ..debugSetData(
      sessions: sessions,
      tasks: tasks,
      attendance: attendance,
      courseName: 'BSc (Hons) Data Science and Artificial Intelligence',
      semesterStart: now.subtract(const Duration(days: 30)),
    );
}

Future<void> pumpScreen(WidgetTester tester, Widget screen, {required Size size, required bool dark}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final isar = FakeIsarService();
  final sync = SyncService(isar);
  final focus = FocusProvider();
  await focus.load();
  focus.addMinutes(95);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SyncService>.value(value: sync),
        ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
        ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
        ChangeNotifierProvider(create: (_) => ResourceProvider(isar, sync)),
        ChangeNotifierProvider.value(value: focus),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: HomeNavigation(goTo: (_) {}, child: screen),
      ),
    ),
  );
  // Let async prefs loads (bus data, focus log) settle.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  // Any overflow/build error is reported by the framework and fails the
  // test with the offending widget's source location.

  // Dispose so periodic timers (countdowns) are cancelled.
  await tester.pumpWidget(const SizedBox());
  focus.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, Widget Function()>{
    'Dashboard': () => const DashboardTab(),
    'Schedule': () => const ScheduleTab(),
    'Hub': () => const AcademicTab(),
    'Board': () => const TodoBoardTab(),
    'Bus': () => const BusTab(),
    'Files': () => const ResourcesTab(),
    'Notes': () => const NotesScreen(),
    'Print & export': () => const PrintCenterScreen(),
    'Print planners': () => const PrintCenterScreen(initialTab: 1),
    'Focus': () => const FocusScreen(),
  };
  const sizes = {'small phone 320x640': Size(320, 640), 'phone 390x844': Size(390, 844), 'desktop 1280x800': Size(1280, 800)};

  for (final screen in screens.entries) {
    for (final size in sizes.entries) {
      for (final dark in [false, true]) {
        testWidgets('${screen.key} renders without overflow on ${size.key} (${dark ? 'dark' : 'light'})', (tester) async {
          await pumpScreen(tester, screen.value(), size: size.value, dark: dark);
        });
      }
    }
  }

  testWidgets('Board columns render on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final isar = FakeIsarService();
    final sync = SyncService(isar);

    Widget app(Widget child) => MultiProvider(
          providers: [
            Provider<SyncService>.value(value: sync),
            ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
            ChangeNotifierProvider(create: (_) => FocusProvider()),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: child),
        );

    await tester.pumpWidget(app(const TodoBoardTab()));
    await tester.pump();
    for (final label in ['In Progress', 'Done']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  group('bottom sheets fit on a 320px phone', () {
    Future<void> openSheet(WidgetTester tester, Future<void> Function(BuildContext) open) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final isar = FakeIsarService();
      final sync = SyncService(isar);
      final tp = seededTimetable(sync, isar);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<SyncService>.value(value: sync),
          ChangeNotifierProvider.value(value: tp),
          ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Builder(builder: (context) => Center(child: TextButton(onPressed: () => open(context), child: const Text('open'))))),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('task / event editor (editing a spanning event)', (tester) async {
      await openSheet(tester, (c) => showTaskSheet(c, task: AcademicTask(
            title: 'Exam week', type: 'Exam', dueDate: DateTime.now().add(const Duration(days: 4)),
            startDate: DateTime.now(), meetingLink: 'https://teams.microsoft.com/l/x', priority: 2,
            description: 'note\n---ROOM---\nMain hall')));
    });

    testWidgets('new task editor', (tester) async {
      await openSheet(tester, (c) => showTaskSheet(c, initialType: 'Homework', initialModule: longModule));
    });

    testWidgets('class editor', (tester) async {
      await openSheet(tester, (c) => showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddEditClassSheet(
              isEditing: true,
              initialData: {'moduleName': longModule, 'day': 'Monday', 'startTime': '9:00', 'endTime': '10:30',
                'meetingLink': 'https://meet.google.com/abc'},
            ),
          ));
    });

    testWidgets('class editor with one-off calendar', (tester) async {
      await openSheet(tester, (c) => showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddEditClassSheet(
              initialData: {'moduleName': longModule, 'isTemporary': true, 'specificDate': DateTime.now().toIso8601String()},
            ),
          ));
    });

    testWidgets('class details', (tester) async {
      await openSheet(tester, (c) => showClassDetailsSheet(
          c, ClassSession(subject: longModule, day: 'Monday', startTime: '09:00', endTime: '10:00', room: 'NAC 2.12',
              meetingLink: 'https://meet.google.com/abc', moduleCode: 'CS1010')));
    });

    testWidgets('note editor', (tester) async {
      await openSheet(tester, (c) async => showNoteEditor(c));
    });
  });

  for (final width in [280.0, 320.0, 360.0, 412.0]) {
    testWidgets('pill nav fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var selected = 0; selected < 6; selected++) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(12),
              child: PillNavBar(
                items: const [
                  NavDest(Icons.grid_view_rounded, 'Home'),
                  NavDest(Icons.view_timeline_rounded, 'Schedule'),
                  NavDest(Icons.calendar_month_rounded, 'Hub'),
                  NavDest(Icons.view_kanban_rounded, 'Board'),
                  NavDest(Icons.directions_bus_filled_rounded, 'Bus'),
                  NavDest(Icons.more_horiz_rounded, 'Settings'),
                ],
                selected: selected,
                onTap: (_) {},
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
