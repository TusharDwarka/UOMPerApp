import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/isar_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/group_service.dart';
import 'providers/timetable_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/note_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/focus_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();

  await NotificationService().init();

  final isarService = IsarService();
  final syncService = SyncService(isarService);

  runApp(
    MultiProvider(
      providers: [
        Provider<IsarService>.value(value: isarService),
        Provider<SyncService>.value(value: syncService),
        Provider<GroupService>(create: (_) => GroupService()),
        ChangeNotifierProvider(create: (_) => TimetableProvider(isarService, syncService)..loadSetupState()),
        ChangeNotifierProvider(create: (_) => NoteProvider(isarService, syncService)),
        ChangeNotifierProvider(create: (_) => ResourceProvider(isarService, syncService)),
        ChangeNotifierProvider(create: (_) => FocusProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const UOMPerApp(),
    ),
  );
}

/// App Check proves requests come from the genuine app. Phone builds only:
/// Windows has no real attestation provider. Debug (USB) builds use the
/// debug provider, which prints a token to register in Firebase → App Check
/// → Manage debug tokens. Nothing is blocked until "Enforce" is turned on.
Future<void> _activateAppCheck() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

class UOMPerApp extends StatelessWidget {
  const UOMPerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'UOMPerApp',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) return const _Splash();
          final user = authSnapshot.data;
          if (user == null) return const LoginScreen();
          // Keyed by uid so switching accounts re-runs the bootstrap.
          return SignedInGate(key: ValueKey(user.uid), user: user);
        },
      ),
    );
  }
}

/// Prepares local data for the signed-in user, then shows the app.
class SignedInGate extends StatefulWidget {
  final User user;
  const SignedInGate({super.key, required this.user});

  @override
  State<SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<SignedInGate> {
  bool _ready = false;
  late final SyncService _sync;
  late final GroupService _groups = context.read<GroupService>();
  StreamSubscription<Set<String>>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncService>();
    _bootstrap();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _sync.stopRealtime();
    _groups.stopAnnouncementWatcher();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final timetable = context.read<TimetableProvider>();
    final notes = context.read<NoteProvider>();
    final resources = context.read<ResourceProvider>();
    final groups = context.read<GroupService>();

    // Wait for SharedPreferences-backed setup state.
    while (!timetable.isSetupLoaded) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    // Settings edited on another device (course, semester dates, folder
    // sections) arrive through the realtime listener.
    _settingsSub = _sync.changes.listen((cols) async {
      if (!cols.contains('settings')) return;
      final remote = await _sync.fetchSettingsIfNewer();
      if (remote == null) return;
      await timetable.applyCloudSettings(remote);
      await resources.applyCloudSettings(remote);
    });

    final wiped = await _sync.prepareForUser(widget.user.uid);
    if (wiped) await timetable.loadSetupState();

    Future<void> pullSettings() async {
      final remote = await _sync.fetchSettingsIfNewer();
      if (remote != null && remote['hasCompletedSetup'] == true) {
        await timetable.applyCloudSettings(remote);
        await resources.applyCloudSettings(remote);
      } else if (timetable.hasCompletedSetup) {
        // First sign-in from a device that already had data: seed the cloud.
        await _sync.pushSettings({...timetable.settingsSnapshot(), ...resources.settingsSnapshot()});
      }
    }

    Future<void> fullSync() async {
      await _sync.syncAll();
      await timetable.loadSessions();
      await notes.loadNotes();
      _sync.startRealtime();
      groups.ensureProfile();
      groups.startAnnouncementWatcher();
    }

    if (timetable.hasCompletedSetup) {
      // Known device: open instantly, sync in the background.
      await timetable.loadSessions();
      await notes.loadNotes();
      if (mounted) setState(() => _ready = true);
      unawaited(pullSettings().then((_) => fullSync()));
    } else {
      // Fresh device (e.g. first launch on Windows): wait briefly for the
      // cloud so we can skip onboarding if the account is already set up.
      try {
        await pullSettings().timeout(const Duration(seconds: 10));
        if (timetable.hasCompletedSetup) await fullSync().timeout(const Duration(seconds: 20));
      } catch (_) {
        // Offline — fall through to local state.
      }
      if (mounted) setState(() => _ready = true);
      if (!timetable.hasCompletedSetup) unawaited(fullSync());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Splash(message: 'Syncing your timetable…');
    final setupDone = context.select<TimetableProvider, bool>((t) => t.hasCompletedSetup);
    return setupDone ? const HomeScreen() : const OnboardingScreen();
  }
}

class _Splash extends StatelessWidget {
  final String? message;
  const _Splash({this.message});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
              child: Icon(Icons.school_rounded, color: p.onInk, size: 34),
            ),
            const SizedBox(height: 20),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent)),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(message!, style: TextStyle(color: p.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
