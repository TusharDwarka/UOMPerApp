import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/academic_task.dart';
import '../models/group_models.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Plain-text version of a task/event for WhatsApp, email, etc.
String shareText(AcademicTask t) {
  final when = t.isSpanning
      ? '${DateFormat('EEE d MMM').format(t.startDate!)} – ${DateFormat('EEE d MMM').format(t.dueDate)}'
      : DateFormat('EEE d MMM yyyy, HH:mm').format(t.dueDate);
  final room = t.description.contains('\n---ROOM---\n') ? t.description.split('\n---ROOM---\n')[1].trim() : '';
  final note = t.description.split('\n---ROOM---\n').first.trim();
  final leads = t.remindBefore ?? const [];
  return [
    '📅 ${t.type}: ${t.title}',
    if (t.subject != 'General') '📘 ${t.subject}',
    '🕒 $when',
    if (room.isNotEmpty) '📍 $room',
    if (t.meetingLink != null) '🔗 ${t.meetingLink}',
    if (note.isNotEmpty) note,
    if (leads.isNotEmpty) '⏰ Set a reminder: ${leads.map(NotificationService.describeLead).join(', ')} before',
  ].join('\n');
}

/// "Share" on a task/event: send it as a message, or post it to a study
/// group's shared calendar (members are reminded before it).
Future<void> shareTask(BuildContext context, AcademicTask task) async {
  final p = Palette.of(context);
  final groups = context.read<GroupService>();
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SheetScaffold(
      title: 'Share',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Send as a message'),
            subtitle: const Text('WhatsApp, email… with the date and reminder'),
            onTap: () => Navigator.pop(ctx, 'text'),
          ),
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: const Text('Post to a study group'),
            subtitle: Text(groups.canUseGroups ? 'Adds it to the group calendar and reminds members' : 'Sign in with an account to use groups',
                style: TextStyle(color: p.textSecondary)),
            enabled: groups.canUseGroups,
            onTap: () => Navigator.pop(ctx, 'group'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'text') {
    await Share.share(shareText(task), subject: task.title);
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  List<StudyGroup> mine;
  try {
    mine = await groups.myGroups().first.timeout(const Duration(seconds: 10));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t load your groups — check your connection')));
    return;
  }
  if (!context.mounted) return;
  if (mine.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Join or create a group first (Groups page)')));
    return;
  }
  final group = await showChoiceSheet<StudyGroup>(
    context,
    title: 'Post to which group?',
    options: mine,
    selected: null,
    labelOf: (g) => g.name,
    subtitleOf: (g) => g.subtitle,
    iconOf: (_) => Icons.groups_rounded,
  );
  if (group == null) return;

  final room = task.description.contains('\n---ROOM---\n') ? task.description.split('\n---ROOM---\n')[1].trim() : '';
  final note = task.description.split('\n---ROOM---\n').first.trim();
  try {
    await groups.saveEvent(
      group.id,
      GroupEvent(
        id: '',
        title: task.title,
        type: task.type,
        start: task.isSpanning ? task.startDate! : task.dueDate,
        end: task.isSpanning ? task.dueDate : null,
        room: room,
        meetingLink: task.meetingLink,
        colorValue: task.colorValue,
        notes: [if (task.subject != 'General') task.subject, if (note.isNotEmpty) note].join(' · '),
        remindBefore: task.remindBefore,
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text('Posted to ${group.name}')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text(e.toString().contains('permission')
            ? 'Only leaders can post in ${group.name}'
            : 'Couldn\'t post: $e')));
  }
}
