import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/end_semester_dialog.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _remindersEnabled = true;
  String? _portalUrl;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _remindersEnabled = prefs.getBool('class_reminders_enabled') ?? true;
      _portalUrl = prefs.getString('student_portal_url');
    });
  }

  Future<void> _toggleReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value && NotificationService().isSupported) {
      final granted = await NotificationService().requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission denied')));
        }
        return;
      }
    }
    await prefs.setBool('class_reminders_enabled', value);
    setState(() => _remindersEnabled = value);
    if (mounted) await context.read<TimetableProvider>().rescheduleReminders();
  }

  Future<void> _editName() async {
    final user = FirebaseAuth.instance.currentUser;
    final controller = TextEditingController(text: user?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(helperText: 'Shown to people in your groups'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await AuthService().updateDisplayName(name);
    if (mounted) await context.read<GroupService>().ensureProfile();
    if (mounted) setState(() {});
  }

  Future<void> _editCourse(TimetableProvider tp) async {
    final controller = TextEditingController(text: tp.courseName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Programme / course'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) await tp.setCourseName(name);
  }

  Future<void> _editSemester(TimetableProvider tp, {required bool start}) async {
    final initial = start ? tp.semesterStart : (tp.semesterEnd ?? tp.semesterStart.add(const Duration(days: 105)));
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked == null) return;
    if (start) {
      await tp.setSemesterDates(picked, tp.semesterEnd);
    } else {
      await tp.setSemesterDates(tp.semesterStart, picked);
    }
    await tp.loadSessions();
  }

  Future<void> _editPortal() async {
    final controller = TextEditingController(text: _portalUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student portal link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'Paste your portal / e-learning URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (url == null) return;
    final prefs = await SharedPreferences.getInstance();
    final normalized = url.isEmpty ? null : (url.startsWith('http') ? url : 'https://$url');
    if (normalized == null) {
      await prefs.remove('student_portal_url');
    } else {
      await prefs.setString('student_portal_url', normalized);
    }
    setState(() => _portalUrl = normalized);
  }

  Future<void> _signOut() async {
    final user = FirebaseAuth.instance.currentUser;
    final guest = user?.isAnonymous ?? false;
    final ok = await confirmDestructive(
      context,
      title: 'Sign out?',
      message: guest
          ? 'You are using a guest account. If you sign out, this guest account and its cloud copy can\'t be recovered. Create an account first to keep your data.'
          : 'Your data stays safe in the cloud. Sign back in on any device to get it.',
      action: 'Sign out',
    );
    if (!ok || !mounted) return;
    context.read<SyncService>().stopRealtime();
    await AuthService().signOut();
  }

  Widget _group(Palette p, String title, List<Widget> children, {Color? titleColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.3, color: titleColor ?? p.textMuted)),
        ),
        SoftCard(
          radius: 26,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _icon(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sync = context.read<SyncService>();

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snap) {
            final user = snap.data ?? FirebaseAuth.instance.currentUser;
            final guest = user?.isAnonymous ?? true;
            final name = (user?.displayName?.isNotEmpty ?? false) ? user!.displayName! : (guest ? 'Guest' : (user?.email ?? 'Student'));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const ScreenHeader(title: 'Settings', eyebrow: 'UOMPerApp 2.0', padding: EdgeInsets.fromLTRB(0, 12, 0, 8)),
                // ── Profile ──
                SoftCard(
                  radius: 32,
                  color: p.ink,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: p.accent,
                            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: p.onInk, fontSize: 20, fontWeight: FontWeight.w600)),
                                Text(guest ? 'Guest · this device only' : (user?.email ?? ''),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: p.onInk.withValues(alpha: 0.7), fontSize: 13)),
                              ],
                            ),
                          ),
                          if (!guest)
                            IconButton(
                              tooltip: 'Edit name',
                              icon: Icon(Icons.edit_rounded, color: p.onInk),
                              onPressed: _editName,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (guest)
                        InkPillButton(
                          label: 'Create account to sync phone & PC',
                          icon: Icons.cloud_upload_rounded,
                          accent: true,
                          expand: true,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(upgradeGuest: true))),
                        )
                      else
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: sync.lastSynced,
                          builder: (context, last, _) => ValueListenableBuilder<bool>(
                            valueListenable: sync.isSyncing,
                            builder: (context, syncing, _) => Row(
                              children: [
                                Icon(syncing ? Icons.sync_rounded : Icons.cloud_done_rounded, color: p.onInk.withValues(alpha: 0.8), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    syncing
                                        ? 'Syncing…'
                                        : last == null
                                            ? 'Live sync on'
                                            : 'Synced ${DateFormat('HH:mm').format(last)} · live',
                                    style: TextStyle(color: p.onInk.withValues(alpha: 0.8)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: syncing
                                      ? null
                                      : () async {
                                          await sync.syncAll();
                                          if (context.mounted) await context.read<TimetableProvider>().loadSessions();
                                        },
                                  child: Text('Sync now', style: TextStyle(color: p.isDark ? AppColors.accent : const Color(0xFF8FB0FF))),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                _group(p, 'Appearance', [
                  ListTile(
                    leading: _icon(Icons.dark_mode_rounded, Colors.purple),
                    title: const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Consumer<ThemeProvider>(
                      builder: (context, provider, _) => DropdownButton<ThemeMode>(
                        value: provider.themeMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                        onChanged: (m) => m == null ? null : provider.setTheme(m),
                      ),
                    ),
                  ),
                ]),

                Consumer<TimetableProvider>(
                  builder: (context, tp, _) => _group(p, 'Class reminders', [
                    SwitchListTile(
                      secondary: _icon(Icons.notifications_active_rounded, Colors.orange),
                      title: const Text('Remind me before class', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(NotificationService().isSupported ? 'On this device' : 'Available on the phone app',
                          style: const TextStyle(fontSize: 12)),
                      value: _remindersEnabled,
                      onChanged: NotificationService().isSupported ? _toggleReminders : null,
                    ),
                    ListTile(
                      leading: _icon(Icons.timer_outlined, Colors.orange),
                      title: const Text('How early', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: DropdownButton<int>(
                        value: const [5, 10, 15, 20, 30, 45, 60].contains(tp.reminderMinutes) ? tp.reminderMinutes : 15,
                        underline: const SizedBox(),
                        items: [for (final m in const [5, 10, 15, 20, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m min'))],
                        onChanged: (m) => m == null ? null : tp.setReminderMinutes(m),
                      ),
                    ),
                  ]),
                ),

                Consumer<TimetableProvider>(
                  builder: (context, tp, _) => _group(p, 'Academic', [
                    ListTile(
                      leading: _icon(Icons.school_rounded, AppColors.accent),
                      title: const Text('Programme', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tp.courseName.isNotEmpty ? tp.courseName : 'Not set'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editCourse(tp),
                    ),
                    ListTile(
                      leading: _icon(Icons.first_page_rounded, AppColors.accent),
                      title: const Text('Semester starts', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('EEE d MMM yyyy').format(tp.semesterStart)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editSemester(tp, start: true),
                    ),
                    ListTile(
                      leading: _icon(Icons.last_page_rounded, AppColors.accent),
                      title: const Text('Semester ends', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tp.semesterEnd == null ? 'Not set (15 weeks assumed)' : DateFormat('EEE d MMM yyyy').format(tp.semesterEnd!)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editSemester(tp, start: false),
                    ),
                    ListTile(
                      leading: _icon(Icons.upload_file_rounded, Colors.teal),
                      title: const Text('Re-import timetable', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Scan a new timetable with AI'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final ok = await confirmDestructive(context,
                            title: 'Change timetable?',
                            message: 'This restarts setup so you can upload a new timetable. Your current classes will be replaced.',
                            action: 'Continue');
                        if (ok && context.mounted) await context.read<TimetableProvider>().resetForNewSetup();
                      },
                    ),
                  ]),
                ),

                _group(p, 'University', [
                  ListTile(
                    leading: _icon(Icons.language_rounded, Colors.blue),
                    title: const Text('University website', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('uom.ac.mu'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => launchUrl(Uri.parse('https://www.uom.ac.mu'), mode: LaunchMode.externalApplication),
                  ),
                  ListTile(
                    leading: _icon(Icons.badge_rounded, Colors.teal),
                    title: const Text('Student portal', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_portalUrl ?? 'Tap to add your portal link'),
                    trailing: _portalUrl == null
                        ? const Icon(Icons.add_link_rounded)
                        : IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: _editPortal),
                    onTap: _portalUrl == null
                        ? _editPortal
                        : () => launchUrl(Uri.parse(_portalUrl!), mode: LaunchMode.externalApplication),
                  ),
                ]),

                _group(p, 'Account', [
                  ListTile(
                    leading: _icon(Icons.shield_outlined, Colors.green),
                    title: const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Your timetable, tasks and notes are private to your account. Only what you post in a group is shared with that group.',
                        style: TextStyle(fontSize: 12)),
                  ),
                  ListTile(
                    leading: _icon(Icons.logout_rounded, Colors.red),
                    title: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: _signOut,
                  ),
                ]),

                _group(p, 'Danger zone', titleColor: Colors.redAccent, [
                  ListTile(
                    leading: _icon(Icons.warning_rounded, Colors.red),
                    title: const Text('End semester', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                    subtitle: const Text('Archive modules and start fresh'),
                    onTap: () => showDialog(context: context, builder: (_) => const EndSemesterDialog()),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
