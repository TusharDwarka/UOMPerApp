import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/isar_service.dart';
import 'providers/timetable_provider.dart';

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
      ],
      child: const UOMPerApp(),
    ),
  );
}

class UOMPerApp extends StatelessWidget {
  const UOMPerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UOMPerApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1A237E), // Deep Indigo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          secondary: const Color(0xFF00C853), // Success Green
          error: const Color(0xFFFF3D00),     // Warning range
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Light clean background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
