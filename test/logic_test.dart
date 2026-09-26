import 'package:flutter_test/flutter_test.dart';
import 'package:uom_per_app/models/academic_task.dart';
import 'package:uom_per_app/models/group_models.dart';
import 'package:uom_per_app/services/group_service.dart';
import 'package:uom_per_app/services/sync_service.dart';
import 'package:uom_per_app/utils/bus_utils.dart';
import 'package:uom_per_app/utils/day_layout.dart';
import 'package:uom_per_app/utils/meeting_links.dart';
import 'package:uom_per_app/utils/time_utils.dart';

void main() {
  group('time utils', () {
    test('parses the formats found in real data', () {
      expect(parseMinutes('09:00'), 540);
      expect(parseMinutes('9:00'), 540);
      expect(parseMinutes('9.30'), 570);
      expect(parseMinutes('09:00:00'), 540);
      expect(parseMinutes('1:15 PM'), 13 * 60 + 15);
      expect(parseMinutes('12:05 AM'), 5);
      expect(parseMinutes('~14:20'), 14 * 60 + 20);
      expect(parseMinutes(''), isNull);
      expect(parseMinutes('TBD'), isNull);
      expect(parseMinutes('10:75'), isNull);
    });

    test('sorts chronologically, not alphabetically ("9:00" before "10:00")', () {
      final times = ['10:00', '9:00', '13:30', '08:15'];
      times.sort(compareTimes);
      expect(times, ['08:15', '9:00', '10:00', '13:30']);
    });

    test('normalises to HH:mm and leaves junk untouched', () {
      expect(normalizeTime('9:5'), '09:05');
      expect(normalizeTime('2:00 pm'), '14:00');
      expect(normalizeTime('TBD'), 'TBD');
    });

    test('countdown text', () {
      expect(formatCountdown(5), '5 min');
      expect(formatCountdown(60), '1h');
      expect(formatCountdown(95), '1h 35m');
    });
  });

  group('day layout', () {
    test('overlapping classes go side by side', () {
      final items = [(540, 600), (570, 630), (660, 720)];
      final laid = layoutDayBlocks(items, startOf: (i) => i.$1, endOf: (i) => i.$2);
      final a = laid.firstWhere((b) => b.item == items[0]);
      final b = laid.firstWhere((b) => b.item == items[1]);
      final c = laid.firstWhere((b) => b.item == items[2]);
      expect(a.laneCount, 2);
      expect(b.laneCount, 2);
      expect({a.lane, b.lane}, {0, 1});
      expect(c.laneCount, 1, reason: 'a later, non-overlapping class uses the full width');
    });

    test('back-to-back classes do not overlap', () {
      final items = [(540, 600), (600, 660)];
      final laid = layoutDayBlocks(items, startOf: (i) => i.$1, endOf: (i) => i.$2);
      expect(laid.every((b) => b.laneCount == 1), isTrue);
    });

    test('zero-length or inverted blocks still get a height', () {
      final laid = layoutDayBlocks([(600, 600)], startOf: (i) => i.$1, endOf: (i) => i.$2);
      expect(laid.single.end, greaterThan(laid.single.start));
    });
  });

  group('bus utils', () {
    test('trips are sorted, normalised and de-duplicated', () {
      final sorted = sortTrips([
        {'departure': '17:00', 'arrival': '18:20'},
        {'departure': '6:00', 'arrival': '7:20'},
        {'departure': '17:00', 'arrival': '18:20'}, // duplicate in the seed data
        {'departure': '', 'arrival': ''}, // incomplete row
        {'departure': '13:18', 'arrival': '~14:20', 'bus_name': 'UBS'},
      ]);
      expect(sorted.map((t) => t['departure']), ['06:00', '13:18', '17:00']);
      expect(sorted[1]['arrival'], '~14:20', reason: 'approximate arrivals keep their ~');
    });

    test('a newly added time lands in chronological order, not at the end', () {
      final route = normalizeRoute({
        'schedules': {
          'weekdays': [
            {'departure': '06:14'},
            {'departure': '08:05'},
            {'departure': '07:10'}, // just added
          ],
        },
      });
      expect((route['schedules']['weekdays'] as List).map((t) => t['departure']), ['06:14', '07:10', '08:05']);
    });

    test('next trip is the first strictly after now', () {
      final trips = sortTrips([
        {'departure': '06:14'},
        {'departure': '07:28'},
        {'departure': '08:05'},
      ]);
      expect(nextTripIndex(trips, 7 * 60), 1);
      expect(nextTripIndex(trips, 7 * 60 + 28), 2);
      expect(nextTripIndex(trips, 9 * 60), -1);
    });

    test('day type for date', () {
      expect(busDayIndexFor(DateTime(2026, 9, 25)), 0); // Friday
      expect(busDayIndexFor(DateTime(2026, 9, 26)), 1); // Saturday
      expect(busDayIndexFor(DateTime(2026, 9, 27)), 2); // Sunday
    });
  });

  group('academic tasks', () {
    test('spanning events occur on every covered day', () {
      final t = AcademicTask(dueDate: DateTime(2026, 10, 3, 17), startDate: DateTime(2026, 10, 1));
      expect(t.isSpanning, isTrue);
      expect(t.occursOn(DateTime(2026, 9, 30)), isFalse);
      expect(t.occursOn(DateTime(2026, 10, 1)), isTrue);
      expect(t.occursOn(DateTime(2026, 10, 2, 23, 59)), isTrue);
      expect(t.occursOn(DateTime(2026, 10, 3)), isTrue);
      expect(t.occursOn(DateTime(2026, 10, 4)), isFalse);
    });

    test('single-day items only occur on the due date', () {
      final t = AcademicTask(dueDate: DateTime(2026, 10, 3, 9));
      expect(t.isSpanning, isFalse);
      expect(t.occursOn(DateTime(2026, 10, 3)), isTrue);
      expect(t.occursOn(DateTime(2026, 10, 2)), isFalse);
    });

    test('board status for legacy records', () {
      expect(AcademicTask(dueDate: DateTime(2026)).effectiveStatus, TaskStatus.todo);
      expect(AcademicTask(dueDate: DateTime(2026), isCompleted: true).effectiveStatus, TaskStatus.done);
      expect(AcademicTask(dueDate: DateTime(2026), status: TaskStatus.doing).effectiveStatus, TaskStatus.doing);
      // "done" without isCompleted (e.g. un-ticked) goes back to To Do.
      expect(AcademicTask(dueDate: DateTime(2026), status: TaskStatus.done).effectiveStatus, TaskStatus.todo);
    });

    test('json round-trip keeps the new fields', () {
      final t = AcademicTask(
        title: 'Hackathon',
        dueDate: DateTime(2026, 10, 3),
        startDate: DateTime(2026, 10, 1),
        colorValue: 0xFF7C4DFF,
        meetingLink: 'https://meet.google.com/abc-defg-hij',
        status: TaskStatus.doing,
        priority: 2,
      )..syncId = 'abc';
      final back = AcademicTask.fromJson(t.toJson());
      expect(back.startDate, t.startDate);
      expect(back.colorValue, t.colorValue);
      expect(back.meetingLink, t.meetingLink);
      expect(back.status, TaskStatus.doing);
      expect(back.priority, 2);
      expect(back.syncId, 'abc');
    });
  });

  group('meeting links', () {
    test('detects platforms and fixes bare links', () {
      expect(MeetingLinks.normalize('meet.google.com/abc'), 'https://meet.google.com/abc');
      expect(MeetingLinks.platformOf('https://meet.google.com/abc'), MeetingPlatform.googleMeet);
      expect(MeetingLinks.platformOf('https://teams.microsoft.com/l/meetup-join/x'), MeetingPlatform.teams);
      expect(MeetingLinks.platformOf('https://uom.zoom.us/j/1'), MeetingPlatform.zoom);
      expect(MeetingLinks.label('https://teams.microsoft.com/x'), 'Join Teams');
      expect(MeetingLinks.isValid('not a link'), isFalse);
      expect(MeetingLinks.isValid(''), isFalse);
    });
  });

  group('sync', () {
    test('last write wins; unknown timestamps never overwrite local edits', () {
      final older = DateTime(2026, 9, 1);
      final newer = DateTime(2026, 9, 2);
      expect(SyncService.remoteWins(newer, older), isTrue);
      expect(SyncService.remoteWins(older, newer), isFalse);
      expect(SyncService.remoteWins(older, older), isFalse);
      expect(SyncService.remoteWins(null, older), isFalse);
      expect(SyncService.remoteWins(newer, null), isTrue);
    });
  });

  group('groups', () {
    GroupSession s(String id, String day, String start, String end) =>
        GroupSession(id: id, subject: id, day: day, startTime: start, endTime: end);

    test('next shared class: in-progress, later today, then next week', () {
      final sessions = [s('Stats', 'Friday', '09:00', '11:00'), s('ML', 'Friday', '13:00', '15:00'), s('DB', 'Monday', '10:00', '12:00')];
      final friday = DateTime(2026, 9, 25); // a Friday

      final during = GroupService.nextSession(sessions, friday.add(const Duration(hours: 10)))!;
      expect(during.session.id, 'Stats');
      expect(during.inProgress, isTrue);

      final lunch = GroupService.nextSession(sessions, friday.add(const Duration(hours: 12)))!;
      expect(lunch.session.id, 'ML');
      expect(lunch.inProgress, isFalse);

      final evening = GroupService.nextSession(sessions, friday.add(const Duration(hours: 18)))!;
      expect(evening.session.id, 'DB');
      expect(evening.start, DateTime(2026, 9, 28, 10));
    });

    test('leaderboard ignores stats from previous weeks', () {
      const current = '2026-09-21';
      const fresh = GroupMember(uid: 'a', displayName: 'A', statsWeek: current, weeklyFocusMinutes: 120, tasksDone: 2, streak: 3);
      const stale = GroupMember(uid: 'b', displayName: 'B', statsWeek: '2026-09-14', weeklyFocusMinutes: 999);
      expect(fresh.scoreFor(current), 120 + 40 + 30);
      expect(stale.scoreFor(current), 0);
    });

    test('week key is the Monday of the week', () {
      expect(GroupService.weekKey(DateTime(2026, 9, 26)), '2026-09-21');
      expect(GroupService.weekKey(DateTime(2026, 9, 21)), '2026-09-21');
    });
  });
}
