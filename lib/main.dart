import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/isar_service.dart';
import 'providers/timetable_provider.dart';
import 'providers/theme_provider.dart';

import 'providers/note_provider.dart';
import 'screens/home_screen.dart';

import 'services/bus_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isarService = IsarService();

  runApp(
    MultiProvider(
      providers: [
        Provider<IsarService>.value(value: isarService),
        Provider<BusService>(create: (_) => BusService(isarService)),
        ChangeNotifierProvider(
          create: (_) => TimetableProvider(isarService),
        ),
        ChangeNotifierProvider(
          create: (_) => NoteProvider(isarService),
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
      home: const HomeScreen(),
    );
  }
}
