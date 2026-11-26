import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uom_per_app/providers/focus_provider.dart';
import 'package:uom_per_app/providers/note_provider.dart';
import 'package:uom_per_app/providers/record_provider.dart';
import 'package:uom_per_app/providers/resource_provider.dart';
import 'package:uom_per_app/providers/theme_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/academic_tab.dart';
import 'package:uom_per_app/screens/bus_tab.dart';
import 'package:uom_per_app/screens/dashboard_tab.dart';
import 'package:uom_per_app/screens/focus_screen.dart';
import 'package:uom_per_app/screens/grades_screen.dart';
import 'package:uom_per_app/screens/home_screen.dart';
import 'package:uom_per_app/screens/notes_tab.dart';
import 'package:uom_per_app/screens/resources_tab.dart';
import 'package:uom_per_app/screens/schedule_tab.dart';
import 'package:uom_per_app/screens/todo_board_tab.dart';
import 'package:uom_per_app/services/activity_log.dart';
import 'package:uom_per_app/services/bus_repository.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/theme/app_theme.dart';
import 'package:uom_per_app/widgets/desktop_shell.dart';
import 'package:uom_per_app/widgets/ui.dart';

import 'screens_overflow_test.dart' show FakeIsarService, pumpScreen, seededRecords, seededTimetable;

/// Runs a test as a Windows build (the variant resets the override after).
final windows = TargetPlatformVariant.only(TargetPlatform.windows);

Future<void> pumpShell(WidgetTester tester, {required Size size, bool dark = false, ValueChanged<int>? onSelect}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final isar = FakeIsarService();
  final sync = SyncService(isar);
  var selected = AppPage.home;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SyncService>.value(value: sync),
        ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
        ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
        ChangeNotifierProvider(create: (_) => ResourceProvider(isar, sync)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
        ChangeNotifierProvider(
          create: (ctx) => RecordProvider(sync, ctx.read<TimetableProvider>().setEndedModules)..debugSetData(records: seededRecords()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DesktopShell(
              selected: selected,
              onSelect: (i) {
                onSelect?.call(i);
                setState(() => selected = i);
              },
              body: const Center(child: Text('page body')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('phone platforms never take the desktop path', () {
    // flutter test runs as Android: the phone design must be what it tests.
    expect(isDesktopPlatform, isFalse);
  });

  testWidgets('desktop flag is on for Windows builds', (tester) async {
    expect(isDesktopPlatform, isTrue);
  }, variant: windows);

  group('desktop shell', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080), Size(760, 520)]) {
      for (final dark in [false, true]) {
        testWidgets('renders at ${size.width.toInt()}x${size.height.toInt()} (${dark ? 'dark' : 'light'})', (tester) async {
          await pumpShell(tester, size: size, dark: dark);
          expect(find.text('UOM Personal'), findsOneWidget);
          expect(find.text('page body'), findsOneWidget);

          // Collapse: animates to the icon rail without overflow.
          await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
          await tester.pumpAndSettle();
          final rail = tester.getSize(find.byType(DesktopShell)).width;
          expect(rail, size.width);
          await tester.pumpWidget(const SizedBox());
        }, variant: windows);
      }
    }

    testWidgets('sidebar navigates and Ctrl+K palette jumps to a page', (tester) async {
      final visited = <int>[];
      await pumpShell(tester, size: const Size(1280, 800), onSelect: visited.add);

      await tester.tap(find.text('Grades'));
      await tester.pump();
      expect(visited.last, AppPage.grades);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Jump to a page or run a command…'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'boa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(visited.last, AppPage.board);
      expect(find.text('Jump to a page or run a command…'), findsNothing);

      // Ctrl+1 goes home.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(visited.last, AppPage.home);
      await tester.pumpWidget(const SizedBox());
    }, variant: windows);
  });

  group('desktop screens', () {
    final screens = <String, Widget Function()>{
      'Dashboard': () => const DashboardTab(),
      'Schedule': () => const ScheduleTab(),
      'Hub': () => const AcademicTab(),
      'Board': () => const TodoBoardTab(),
      'Bus': () => const BusTab(),
      'Files': () => const ResourcesTab(),
      'Notes': () => const NotesScreen(),
      'Focus': () => const FocusScreen(),
      'Grades': () => const GradesScreen(),
    };
    // Window minus the 252px sidebar, plus a narrow window.
    const sizes = [Size(1028, 748), Size(1668, 1028), Size(700, 600)];
    for (final screen in screens.entries) {
      for (final size in sizes) {
        for (final dark in [false, true]) {
          testWidgets('${screen.key} fits ${size.width.toInt()}x${size.height.toInt()} (${dark ? 'dark' : 'light'})',
              (tester) async {
            await pumpScreen(tester, screen.value(), size: size, dark: dark);
          }, variant: windows);
        }
      }
    }

    for (final size in sizes) {
      testWidgets('Bus with routes fits ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        SharedPreferences.setMockInitialValues({SyncService.busPrefsKey: jsonEncode(BusRepository.presets)});
        await pumpScreen(tester, const BusTab(), size: size, dark: false);
      }, variant: windows);
    }

    // Wide windows put both halves of a page on screen at once.
    Future<FocusProvider> pumpPage(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final isar = FakeIsarService();
      final sync = SyncService(isar);
      final focus = FocusProvider();
      await focus.load();
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<SyncService>.value(value: sync),
          ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
          ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
          ChangeNotifierProvider(
              create: (ctx) =>
                  RecordProvider(sync, ctx.read<TimetableProvider>().setEndedModules)..debugSetData(records: seededRecords())),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: HomeNavigation(goTo: (_) {}, child: page)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      return focus;
    }

    final splits = <String, (Widget Function(), List<String>)>{
      'Grades': (() => const GradesScreen(), ['CPA calculator', 'Y1 · Semester 1']),
      'Focus': (() => const FocusScreen(), ['Time average', 'Weekly productivity']),
      'Hub': (() => const AcademicTab(), []),
      'Schedule': (() => const ScheduleTab(), ['CLASSES', 'DUE']),
    };
    for (final e in splits.entries) {
      testWidgets('${e.key} shows both panes side by side', (tester) async {
        final focus = await pumpPage(tester, e.value.$1());
        expect(find.byType(SplitPanes), findsOneWidget);
        for (final t in e.value.$2) {
          expect(find.text(t), findsWidgets, reason: t);
        }
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
      }, variant: windows);
    }

    testWidgets('Schedule opens on the week on Windows and pages with the toolbar', (tester) async {
      final focus = await pumpPage(tester, const ScheduleTab());
      String range() => tester.widget<Text>(find.textContaining(RegExp(r'^\d+ (– |\w+ – )'))).data!;
      final before = range();
      await tester.tap(find.byTooltip('Next week'));
      await tester.pump();
      expect(range(), isNot(before));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Today'));
      await tester.pump();
      expect(range(), before);
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next month'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    }, variant: windows);

    testWidgets('Schedule still opens on the day on Android', (tester) async {
      final focus = await pumpPage(tester, const ScheduleTab());
      expect(find.byType(SplitPanes), findsNothing);
      expect(find.byTooltip('Next week'), findsOneWidget); // the phone date strip's arrow
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });

    testWidgets('Notes opens new notes inline on Windows', (tester) async {
      final focus = await pumpPage(tester, const NotesScreen());
      expect(find.text('Empty canvas'), findsOneWidget);
      await tester.tap(find.text('New note').first); // header button
      await tester.pump();
      final editor = tester.widget<NoteEditorSheet>(find.byType(NoteEditorSheet));
      expect(editor.embedded, isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Save'), findsNothing); // saves as you type
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Lecture 5');
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Lecture 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    }, variant: windows);

    testWidgets('Notes keeps the editor sheet on Android', (tester) async {
      final focus = await pumpPage(tester, const NotesScreen());
      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });

    testWidgets('Board search filters cards on Windows', (tester) async {
      final focus = await pumpPage(tester, const TodoBoardTab());
      expect(find.text('Overdue quiz'), findsOneWidget);
      expect(find.text('Exam week'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Search tasks'), 'quiz');
      await tester.pump();
      expect(find.text('Overdue quiz'), findsOneWidget);
      expect(find.text('Exam week'), findsNothing);
      expect(find.text('Add task'), findsNWidgets(2)); // To do + In progress columns
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    }, variant: windows);

    testWidgets('desktop home shows the greeting and quick add', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final isar = FakeIsarService();
      final sync = SyncService(isar);
      final focus = FocusProvider();
      await focus.load();
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<SyncService>.value(value: sync),
          ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
          ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
          ChangeNotifierProvider(create: (_) => ResourceProvider(isar, sync)),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
          ChangeNotifierProvider(create: (ctx) => RecordProvider(sync, ctx.read<TimetableProvider>().setEndedModules)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: HomeNavigation(goTo: (_) {}, child: const DashboardTab())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(', there.'), findsOneWidget);
      expect(find.text('Add a deadline or task…'), findsOneWidget);
      expect(find.text('Welcome back,'), findsNothing); // phone header not shown
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    }, variant: windows);

    testWidgets('phone home is unchanged on Android', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final isar = FakeIsarService();
      final sync = SyncService(isar);
      final focus = FocusProvider();
      await focus.load();
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<SyncService>.value(value: sync),
          ChangeNotifierProvider(create: (_) => seededTimetable(sync, isar)),
          ChangeNotifierProvider(create: (_) => NoteProvider(isar, sync)),
          ChangeNotifierProvider(create: (_) => ResourceProvider(isar, sync)),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider<ActivityLog>.value(value: ActivityLog.instance),
          ChangeNotifierProvider(create: (ctx) => RecordProvider(sync, ctx.read<TimetableProvider>().setEndedModules)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: HomeNavigation(goTo: (_) {}, child: const DashboardTab())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Add a deadline or task…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });
  });

  group('desktop controls', () {
    Future<BuildContext> host(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return Center(child: child);
        })),
      ));
      return ctx;
    }

    Widget sheet(BuildContext _) => const SheetScaffold(title: 'Edit', child: Text('sheet body'));

    testWidgets('sheets open as a centred dialog on Windows', (tester) async {
      final ctx = await host(tester, const SizedBox());
      showAppSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent, builder: sheet);
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getCenter(find.byType(SheetScaffold)).dx, closeTo(640, 1));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsNothing);
    }, variant: windows);

    testWidgets('sheets stay bottom sheets on Android', (tester) async {
      final ctx = await host(tester, const SizedBox());
      showAppSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent, builder: sheet);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    Widget pill(ValueChanged<int> onChanged) => ChoicePill<int>(
          title: 'Year',
          value: 1,
          options: const [1, 2, 3],
          labelOf: (y) => 'Y$y',
          onChanged: onChanged,
        );

    testWidgets('choice pills drop down a menu on Windows', (tester) async {
      int? picked;
      await host(tester, pill((v) => picked = v));
      await tester.tap(find.text('Y1'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      // Menu opens just below the pill.
      expect(tester.getTopLeft(find.text('Y2')).dy, greaterThan(tester.getBottomLeft(find.text('Y1').first).dy));
      await tester.tap(find.text('Y3'));
      await tester.pumpAndSettle();
      expect(picked, 3);
    }, variant: windows);

    testWidgets('choice pills keep the option sheet on Android', (tester) async {
      await host(tester, pill((_) {}));
      await tester.tap(find.text('Y1'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    Future<ScrollController> sideways(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: SizedBox(
            height: 60,
            child: ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: [for (var i = 0; i < 30; i++) SizedBox(width: 80, child: Text('chip $i'))],
            ),
          ),
        ),
      ));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.text('chip 1'))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();
      return controller;
    }

    testWidgets('mouse wheel scrolls sideways rows on Windows', (tester) async {
      expect((await sideways(tester)).offset, 120);
    }, variant: windows);

    testWidgets('mouse wheel leaves sideways rows alone on Android', (tester) async {
      expect((await sideways(tester)).offset, 0);
    });

    testWidgets('segmented tabs hug their labels on Windows', (tester) async {
      var sel = 'Day';
      await host(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 900,
            child: PillSegmented<String>(
              values: const ['Day', 'Week', 'Month'],
              selected: sel,
              labelOf: (v) => v,
              onChanged: (v) => setState(() => sel = v),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.ancestor(of: find.text('Week'), matching: find.byType(AnimatedContainer))).width, lessThan(120));
      await tester.tap(find.text('Month'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sel, 'Month');
    }, variant: windows);
  });
}
