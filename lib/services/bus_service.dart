import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/bus_route.dart';
import 'package:isar_community/isar.dart';
import 'isar_service.dart';

class BusService {
  final IsarService isarService;

  BusService(this.isarService);

  // Parse the specific JSON format provided by user
  Future<void> fetchAndParseBusSchedule(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      final locations = data['timetable']['locations'] as List;

      final isar = await isarService.db;
      final busRoutes = <BusRoute>[];

      for (var loc in locations) {
        String destination = (loc['location_name'] ?? '').toString();
        // Extract simple destination if needed, e.g. "To L'Escalier"
        if (destination.contains("going to ")) {
          destination = destination.split("going to ")[1].replaceAll(")", "");
        }
        
        final routeNum = loc['bus_route'] ?? '';
        final schedules = loc['schedules'];
        
        // Handling weekdays for now as primary example
        if (schedules != null && schedules['weekdays'] != null) {
          final weekdays = schedules['weekdays'] as List;
          for (var trip in weekdays) {
             // prompt example: {"arrival_at_reduit": "06:14", "arrival_at_lescalier": "07:20"},
             // We want "arrival_at_reduit" as the departure/arrival time relevant to user at University
             String time = trip['arrival_at_reduit'] ?? '';
             String busName = trip['bus_name'] ?? 'Normal';
             
             if (time.isNotEmpty) {
               busRoutes.add(BusRoute(
                 routeNumber: routeNum,
                 destination: destination,
                 arrivalTime: time,
                 busName: busName
               ));
             }
          }
        }
      }

      // Clear old cache and save new
      await isar.writeTxn(() async {
        await isar.busRoutes.clear();
        await isar.busRoutes.putAll(busRoutes);
      });
      
    } catch (e) {
      print("Error parsing bus JSON: $e");
      rethrow;
    }
  }

  // Load from assets (if you put a file there)
  Future<void> loadFromAssets() async {
    // try {
    //   final jsonString = await rootBundle.loadString('assets/bus_schedule.json');
    //   await fetchAndParseBusSchedule(jsonString);
    // } catch (e) { ... }
  }
}
