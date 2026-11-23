import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/class_session.dart';
import 'package:uom_per_app/models/group_models.dart';
import 'package:uom_per_app/models/module_record.dart';
import 'package:uom_per_app/providers/record_provider.dart';
import 'package:uom_per_app/providers/timetable_provider.dart';
import 'package:uom_per_app/screens/activity_screen.dart';
import 'package:uom_per_app/services/activity_log.dart';
import 'package:uom_per_app/services/group_service.dart';
import 'package:uom_per_app/services/isar_service.dart';
import 'package:uom_per_app/services/notification_service.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/utils/time_utils.dart';
import 'package:uom_per_app/widgets/share_event.dart';

class _FakeIsar implements IsarService {
  @override
  Future<Isar> db = Completer<Isar>().future;
  @override
  Future<Isar> openDB() => db;
  @override
  Future<void> cleanDb() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('grading & CPA', () {
    test('letters follow the A/B/C/D/F bands', () {
      expect(Grading.letter(70), 'A');
      expect(Grading.letter(69.9), 'B');
      expect(Grading.letter(50), 'C');
      expect(Grading.letter(40), 'D');
      expect(Grading.letter(39.5), 'F');
    });

    test('CPA is credit-weighted', () {
      // (72*3 + 58*6) / 9 = 62.666…
      expect(Grading.weightedAverage([(3.0, 72.0), (6.0, 58.0)]), closeTo(62.667, 0.001));
      expect(Grading.weightedAverage(const []), isNull);
      expect(Grading.weightedAverage([(0.0, 90.0)]), isNull);
    });

    test('mark needed on the remaining credits to hit a target', () {
      // 60 over 6 credits done; 6 credits left; target 65 → need 70.
      expect(Grading.neededAverage(cpa: 60, doneCredits: 6, remainingCredits: 6, target: 65), closeTo(70, 0.001));
      expect(Grading.neededAverage(cpa: 60, doneCredits: 6, remainingCredits: 0, target: 65), isNull);
    });

    test('a resit replaces the first mark, optionally capped at 40', () {
      final r = ModuleRecord(name: 'Maths', mark: 30, resitMark: 62);
      expect(r.effectiveMark(), 62);
      expect(r.effectiveMark(capResit: true), 40);
      expect(ModuleRecord(name: 'X', mark: 55).effectiveMark(), 55);
    });

    test('records survive a JSON round trip (settings sync)', () {
      final r = ModuleRecord(name: 'Databases', code: 'CS201', credits: 4, year: 2, semester: 2,
          status: ModuleStatus.resit, mark: 35, resitMark: 58, resitDate: DateTime(2027, 1, 10), endedAt: DateTime(2026, 11, 20));
      final back = ModuleRecord.fromJson(r.toJson());
      expect(back.toJson(), r.toJson());
    });
  });

  group('record provider', () {
    test('ending a module reports it to the timetable; CPA uses resits', () async {
      Map<String, DateTime>? reported;
      final rp = RecordProvider(null, (m) => reported = m);
      await rp.load();
      await rp.endModule('Databases', year: 2, semester: 1, mark: 72);
      await rp.saveRecord(ModuleRecord(name: 'Stats', credits: 6, year: 2, semester: 1, status: ModuleStatus.resit, mark: 30, resitMark: 60));
      await Future<void>.delayed(Duration.zero);
      expect(reported!.keys, containsAll(['databases', 'stats']));
      // (72*3 + 60*6) / 9 = 64
      expect(rp.cpa, closeTo(64, 0.001));
      await rp.setCapResit(true);
      // (72*3 + 40*6) / 9 = 50.67
      expect(rp.cpa, closeTo(50.667, 0.001));
    });

    test('a module taken again later gets its own record and is not hidden', () async {
      final rp = RecordProvider();
      await rp.load();
      await rp.endModule('Programming', year: 1, semester: 1, mark: 35);
      expect(rp.isEnded('Programming'), isTrue);
      await rp.importModules(['Programming'], year: 1, semester: 2);
      expect(rp.records.where((r) => r.key == 'programming'), hasLength(2));
      expect(rp.recordFor('Programming')!.isActive, isTrue);
      expect(rp.endedModules.containsKey('programming'), isFalse);
    });

    test('end semester ends every ongoing module and turns on holiday mode', () async {
      final rp = RecordProvider();
      await rp.load();
      await rp.endSemester(['A', 'B'], year: 2, semester: 1);
      expect(rp.holidayMode, isTrue);
      expect(rp.records.every((r) => r.isEnded), isTrue);
      await rp.setHolidayMode(false);
      expect(rp.holidayMode, isFalse);
    });
  });

  group('timetable with ended modules', () {
    TimetableProvider tp() {
      final isar = _FakeIsar();
      final now = DateTime.now();
      return TimetableProvider(isar, SyncService(isar))
        ..debugSetData(
          sessions: [
            for (final d in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) ...[
              ClassSession(subject: 'Databases', day: d, startTime: '09:00', endTime: '10:00'),
              ClassSession(subject: 'Stats', day: d, startTime: '11:00', endTime: '12:00'),
            ],
          ],
          semesterStart: now.subtract(const Duration(days: 20)),
        );
    }

    test('classes of an ended module stop after its end day', () {
      final t = tp();
      final today = dateOnly(DateTime.now());
      t.setEndedModules({'databases': today});
      expect(t.getClassesForDate(today).map((s) => s.subject), containsAll(['Databases', 'Stats']));
      final tomorrow = today.add(const Duration(days: 1));
      expect(t.getClassesForDate(tomorrow).map((s) => s.subject), ['Stats']);
      expect(t.isModuleEnded('Databases'), isTrue);
    });

    test('an end from before this semester never hides the new timetable', () {
      final t = tp();
      t.setEndedModules({'databases': dateOnly(DateTime.now()).subtract(const Duration(days: 200))});
      expect(t.getClassesForDate(DateTime.now()).map((s) => s.subject), contains('Databases'));
    });
  });

  group('activity', () {
    test('counts take the larger of the log and live data; focus adds per 25 min', () {
      final log = ActivityLog.instance..debugSet({DateFormat('yyyy-MM-dd').format(DateTime(2026, 11, 2)): {ActivityLog.tasks: 3}});
      final data = buildActivity(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 3),
        log: log,
        doneTaskDays: [DateTime(2026, 11, 2, 10), DateTime(2026, 11, 3, 8)],
        noteDays: [DateTime(2026, 11, 3, 9)],
        focusMinutesOn: (d) => d.day == 1 ? 50 : 0,
      );
      expect(data[DateTime(2026, 11, 1)]!.score, 2); // 50 min focus
      expect(data[DateTime(2026, 11, 2)]!.tasks, 3); // log kept the cleared ones
      expect(data[DateTime(2026, 11, 3)]!.score, 2); // 1 task + 1 note
      expect(DayActivity.level(0), 0);
      expect(DayActivity.level(9), 4);
    });

    test('merging two devices keeps the higher count per day', () async {
      final log = ActivityLog.instance..debugSet({'2026-11-02': {'tasks': 1, 'notes': 4}});
      await log.merge({'2026-11-02': {'tasks': 5}, '2026-11-03': {'notes': 1}});
      expect(log.days['2026-11-02'], {'tasks': 5, 'notes': 4});
      expect(log.days['2026-11-03'], {'notes': 1});
    });
  });

  group('reminders & sharing', () {
    test('lead times read naturally', () {
      expect(NotificationService.describeLead(0), 'At the time');
      expect(NotificationService.describeLead(60), '1 hour');
      expect(NotificationService.describeLead(4320), '3 days');
      expect(NotificationService.describeLead(10080), '1 week');
      expect(NotificationService.describeLead(90), '90 min');
    });

    test('task reminders sync and count back from the start of multi-day events', () {
      final t = AcademicTask(title: 'Trip', dueDate: DateTime(2026, 12, 5, 18), startDate: DateTime(2026, 12, 3))
        ..remindBefore = [1440, 4320];
      final back = AcademicTask.fromJson(t.toJson());
      expect(back.remindBefore, [1440, 4320]);
      expect(t.reminderAnchor, DateTime(2026, 12, 3, 9));
      expect(AcademicTask(title: 'x', dueDate: DateTime(2026, 12, 5, 18)).reminderAnchor, DateTime(2026, 12, 5, 18));
    });

    test('group events: my choice beats the poster\'s suggestion, which beats the class setting', () {
      final e = GroupEvent(id: 'e1', title: 'Quiz', start: DateTime(2026, 12, 1), remindBefore: const [2880]);
      expect(GroupService.leadsFor(e, {}, 15), [2880]);
      expect(GroupService.leadsFor(e, {'e1': [60]}, 15), [60]);
      expect(GroupService.leadsFor(e, {'e1': []}, 15), isEmpty);
      expect(GroupService.leadsFor(GroupEvent(id: 'e2', title: 'Old', start: DateTime(2026, 12, 1)), {}, 15), [15]);
    });

    test('shared text has the essentials', () {
      final t = AcademicTask(title: 'Lab report', subject: 'Databases', type: 'Assignment', dueDate: DateTime(2026, 12, 4, 23, 59),
          description: 'Section B\n---ROOM---\nLab 3')
        ..remindBefore = [4320];
      final text = shareText(t);
      expect(text, contains('Lab report'));
      expect(text, contains('Databases'));
      expect(text, contains('Lab 3'));
      expect(text, contains('3 days before'));
    });
  });
}
