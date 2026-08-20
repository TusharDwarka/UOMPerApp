import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/isar_service.dart';
import 'services/firestore_service.dart';
import 'services/sync_service.dart';
import 'providers/timetable_provider.dart';
import 'providers/theme_provider.dart';

import 'providers/note_provider.dart';
import 'providers/resource_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';

import 'services/bus_service.dart';
import 'services/notification_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  
  final notificationService = NotificationService();
  await notificationService.init();

  final isarService = IsarService();
  final firestoreService = FirestoreService();
  final syncService = SyncService(isarService);

  runApp(
    MultiProvider(
      providers: [
        Provider<IsarService>.value(value: isarService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<SyncService>.value(value: syncService),
        Provider<BusService>(create: (_) => BusService(isarService, syncService)),
        ChangeNotifierProvider(
          create: (_) => TimetableProvider(isarService, syncService)..loadSetupState(),
        ),
        ChangeNotifierProvider(
          create: (_) => NoteProvider(isarService, syncService),
        ),
        ChangeNotifierProvider(
          create: (_) => ResourceProvider(isarService),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const UOMPerApp(),
    ),
  );
}

class UOMPerApp extends StatelessWidget {
  const UOMPerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final timetableProvider = Provider.of<TimetableProvider>(context);

    return MaterialApp(
      title: 'UOMPerApp',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1A237E), // Deep Indigo
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Light clean background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          secondary: const Color(0xFF00C853),
          error: const Color(0xFFFF3D00),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3949AB), 
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3949AB),
          secondary: const Color(0xFF00E676),
          error: const Color(0xFFFF5252),
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E), // Dark header
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF1E1E1E),
        dialogBackgroundColor: const Color(0xFF1E1E1E),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          modalBackgroundColor: Color(0xFF1E1E1E),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF5C6BC0),
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // Still checking auth state
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: themeProvider.themeMode == ThemeMode.dark
                  ? const Color(0xFF121212)
                  : const Color(0xFF1A237E),
              body: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          // Not logged in → show login screen
          if (authSnapshot.data == null) {
            return const LoginScreen();
          }

          // Logged in → show the normal app flow
          if (!timetableProvider.isSetupLoaded) {
            return Scaffold(
              backgroundColor: themeProvider.themeMode == ThemeMode.dark
                  ? const Color(0xFF121212)
                  : const Color(0xFF1A237E),
              body: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          return timetableProvider.hasCompletedSetup
              ? const HomeScreen()
              : const OnboardingScreen();
        },
      ),
    );
  }
}
