import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/class_session.dart';
import '../providers/timetable_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import 'add_edit_class_sheet.dart';
import 'add_edit_task_sheet.dart';
import 'ui.dart';

/// Stable pastel/strong colour pair for a module name.
(Color bg, Color fg) moduleColors(String subject, bool isDark) {
  const pairs = [
    (Color(0xFFE3EBFF), Color(0xFF2962FF)),
    (Color(0xFFEDE7FF), Color(0xFF6A3DE8)),
    (Color(0xFFDDF6F2), Color(0xFF00897B)),
    (Color(0xFFFFEEDD), Color(0xFFE65100)),
    (Color(0xFFFFE4EC), Color(0xFFD81B60)),
    (Color(0xFFE4F5E6), Color(0xFF2E7D32)),
  ];
  var h = 0;
  for (final c in subject.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final pair = pairs[h % pairs.length];
  return isDark ? (pair.$2.withValues(alpha: 0.22), pair.$2.withValues(alpha: 0.95)) : pair;
}

/// Opens the add/edit class sheet and saves the result.
Future<void> editClass(BuildContext context, {ClassSession? session, DateTime? forDate}) async {
  final provider = context.read<TimetableProvider>();
  Map<String, dynamic> initialData;
  if (session != null) {
    initialData = {
      'id': session.id,
      'moduleName': session.subject,
      'moduleCode': session.moduleCode,
      'location': session.room,
      'day': session.day,
      'startTime': session.startTime,
      'endTime': session.endTime,
      'weeks': session.weeks,
      'specificDate': session.specificDate?.toIso8601String(),
      'isTemporary': session.specificDate != null,
      'meetingLink': session.meetingLink,
    };
  } else {
    final d = forDate ?? DateTime.now();
    initialData = {'day': DateFormat('EEEE').format(d), 'specificDate': d.toIso8601String(), 'isTemporary': false};
  }

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddEditClassSheet(initialData: initialData, isEditing: session != null),
  );
  if (result == null) return;

  if (result['delete'] == true && session != null) {
    await provider.deleteSession(session.id);
    return;
  }

  final updated = ClassSession(
    subject: result['moduleName'] ?? '',
    startTime: result['startTime'] ?? '',
    endTime: result['endTime'] ?? '',
    day: result['day'] ?? '',
    room: result['location'] ?? 'TBD',
    moduleCode: result['moduleCode'] ?? '',
    isUser: true,
    weeks: result['weeks'] != null ? List<int>.from(result['weeks']) : null,
    specificDate: result['specificDate'] != null ? DateTime.tryParse(result['specificDate']) : null,
    meetingLink: result['meetingLink'],
  );
  if (session != null) {
    updated.id = session.id;
    updated.syncId = session.syncId;
    updated.cancelledDates = session.cancelledDates;
  }
  await provider.addSession(updated);
}

Future<void> showClassDetailsSheet(BuildContext context, ClassSession session, {DateTime? date}) {
  final day = dateOnly(date ?? DateTime.now());
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ClassDetails(session: session, date: day, hostContext: context),
  );
}

class _ClassDetails extends StatelessWidget {
  final ClassSession session;
  final DateTime date;
  final BuildContext hostContext;
  const _ClassDetails({required this.session, required this.date, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final timetable = context.watch<TimetableProvider>();
    final colors = moduleColors(session.subject, p.isDark);
    final cancelled = timetable.isCancelled(session, date);

    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => Expanded(
          child: SoftCard(
            color: p.surfaceAlt,
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            onTap: onTap,
            child: Column(
              children: [
                Icon(icon, color: color ?? p.textPrimary),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? p.textPrimary)),
              ],
            ),
          ),
        );

    return SheetScaffold(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(40)),
                  child: Text(session.moduleCode.isEmpty ? 'Class' : session.moduleCode,
                      style: TextStyle(color: colors.$2, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Spacer(),
                Text(DateFormat('EEE d MMM').format(date), style: TextStyle(color: p.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Text(session.subject,
                style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    color: p.textPrimary,
                    decoration: cancelled ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 8),
            Text('${session.startTime} – ${session.endTime}  ·  ${session.room}',
                style: TextStyle(fontSize: 15, color: p.textSecondary, fontWeight: FontWeight.w500)),
            if (session.meetingLink != null) ...[
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: JoinMeetingButton(url: session.meetingLink!)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                action(Icons.assignment_add, 'Homework', () {
                  Navigator.pop(context);
                  showTaskSheet(hostContext, initialType: 'Homework', initialModule: session.subject);
                }),
                const SizedBox(width: 10),
                action(Icons.notifications_active_outlined, 'Remind me', () async {
                  final messenger = ScaffoldMessenger.of(hostContext);
                  final minutes = timetable.reminderMinutes;
                  Navigator.pop(context);
                  if (!NotificationService().isSupported) {
                    messenger.showSnackBar(const SnackBar(content: Text('Reminders are available on the phone app')));
                    return;
                  }
                  final start = date.add(Duration(minutes: session.startMinutes));
                  if (start.subtract(Duration(minutes: minutes)).isBefore(DateTime.now())) {
                    messenger.showSnackBar(const SnackBar(content: Text('Too late for a reminder — this class starts soon')));
                    return;
                  }
                  await NotificationService().scheduleClassReminder(
                    id: NotificationService.reminderIdFor(date, session),
                    subject: session.subject,
                    room: session.room,
                    classStartTime: start,
                    minutesBefore: minutes,
                    force: true,
                  );
                  messenger.showSnackBar(SnackBar(content: Text('Reminder set $minutes min before')));
                }),
                const SizedBox(width: 10),
                action(Icons.edit_outlined, 'Edit', () {
                  Navigator.pop(context);
                  editClass(hostContext, session: session);
                }),
              ],
            ),
            const SizedBox(height: 10),
            // Lecturer won't hold this one: crossed out on the schedule and
            // skipped by reminders, "next class" and the widget.
            OutlinedButton.icon(
              icon: Icon(cancelled ? Icons.undo_rounded : Icons.event_busy_rounded),
              label: Text(cancelled
                  ? 'Class is back on · ${DateFormat('EEE d MMM').format(date)}'
                  : 'Lecturer cancelled it · ${DateFormat('EEE d MMM').format(date)}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cancelled ? p.textPrimary : AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await timetable.setCancelled(session, date, !cancelled);
              },
            ),
          ],
        ),
      ),
    );
  }
}
