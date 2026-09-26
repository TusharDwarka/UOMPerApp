import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/bus_utils.dart';
import 'sync_service.dart';

/// Bus routes live in SharedPreferences as JSON (the Android home-screen
/// widget reads the same key) and sync to Firestore via [SyncService].
class BusRepository {
  static const _selectedKey = 'bus_selected_route';

  /// Loads routes, seeding defaults on first launch. Every schedule is
  /// returned sorted by departure (older data was stored in insertion order,
  /// which is why new timings always appeared at the end).
  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(SyncService.busPrefsKey);
    if (jsonStr == null) {
      final seeded = defaultData().map(normalizeRoute).toList();
      await prefs.setString(SyncService.busPrefsKey, jsonEncode(seeded));
      return seeded;
    }
    final decoded = jsonDecode(jsonStr) as List;
    final routes = decoded.map((e) => normalizeRoute(Map<String, dynamic>.from(e as Map))).toList();
    final normalized = jsonEncode(routes);
    if (normalized != jsonStr) await prefs.setString(SyncService.busPrefsKey, normalized);
    return routes;
  }

  static Future<void> save(List<Map<String, dynamic>> routes, SyncService? sync) async {
    final sorted = routes.map(normalizeRoute).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SyncService.busPrefsKey, jsonEncode(sorted));
    if (sync != null) {
      await sync.pushBus(sorted);
    } else {
      await prefs.setString(SyncService.busUpdatedKey, DateTime.now().toIso8601String());
    }
  }

  static Future<int> selectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedKey) ?? 0;
  }

  static Future<void> setSelectedIndex(int i) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedKey, i);
  }

  static List<Map<String, dynamic>> defaultData() {
    return [
      {
        "location_name": "At Réduit (going to L'Escalier)",
        "bus_route": "200",
        "schedules": {
          "weekdays": [
            {"departure": "06:14", "arrival": "07:20"},
            {"departure": "06:51", "arrival": "07:57", "bus_name": "Dakar"},
            {"departure": "07:28", "arrival": "08:34"},
            {"departure": "08:05", "arrival": "09:11"},
            {"departure": "08:42", "arrival": "09:48"},
            {"departure": "09:22", "arrival": "10:28"},
            {"departure": "10:05", "arrival": "11:11", "bus_name": "L'express"},
            {"departure": "10:25", "arrival": "11:28", "bus_name": "Private"},
            {"departure": "10:42", "arrival": "11:48", "bus_name": "UBS"},
            {"departure": "11:22", "arrival": "12:28", "bus_name": "Napoleon"},
            {"departure": "11:40", "arrival": "12:46", "bus_name": "Perle de Mahebourg"},
            {"departure": "12:02", "arrival": "13:08", "bus_name": "Private"},
            {"departure": "12:42", "arrival": "13:48", "bus_name": "Dakar"},
            {"departure": "13:05", "arrival": "14:28", "bus_name": "Perle de Mahebourg"},
            {"departure": "14:02", "arrival": "15:08", "bus_name": "Napoleon"},
            {"departure": "14:42", "arrival": "15:48", "bus_name": "UBS"},
            {"departure": "16:02", "arrival": "17:08"},
            {"departure": "16:42", "arrival": "17:48"},
            {"departure": "17:22", "arrival": "18:28"},
            {"departure": "18:04", "arrival": "19:10"}
          ],
          "saturdays": [
            {"departure": "06:14", "arrival": "07:20"},
            {"departure": "06:54", "arrival": "08:00"},
            {"departure": "07:34", "arrival": "08:40"},
            {"departure": "08:14", "arrival": "09:20"},
            {"departure": "08:54", "arrival": "10:00"},
            {"departure": "09:34", "arrival": "10:40"},
            {"departure": "10:14", "arrival": "11:20"},
            {"departure": "10:54", "arrival": "12:00"},
            {"departure": "11:34", "arrival": "12:40"},
            {"departure": "12:14", "arrival": "13:20"},
            {"departure": "12:54", "arrival": "14:00"},
            {"departure": "13:34", "arrival": "14:40"},
            {"departure": "14:14", "arrival": "15:20"},
            {"departure": "14:54", "arrival": "16:00"},
            {"departure": "15:34", "arrival": "16:40"},
            {"departure": "16:14", "arrival": "17:20"},
            {"departure": "16:54", "arrival": "18:00"},
            {"departure": "17:34", "arrival": "18:40"},
            {"departure": "18:04", "arrival": "19:10"}
          ],
          "sundays_public_holidays": [
            {"departure": "06:44", "arrival": "07:50"},
            {"departure": "07:44", "arrival": "08:50"},
            {"departure": "08:44", "arrival": "09:50"},
            {"departure": "09:44", "arrival": "10:50"},
            {"departure": "10:44", "arrival": "11:50"},
            {"departure": "11:44", "arrival": "12:50"},
            {"departure": "12:44", "arrival": "13:50"},
            {"departure": "13:44", "arrival": "14:50"},
            {"departure": "14:44", "arrival": "15:50"},
            {"departure": "15:44", "arrival": "16:50"},
            {"departure": "16:44", "arrival": "17:50"},
            {"departure": "17:44", "arrival": "18:50"},
            {"departure": "18:44", "arrival": "19:50"}
          ]
        }
      },
      {
        "location_name": "At L'Escalier (going to Réduit)",
        "bus_route": "200",
        "schedules": {
          "weekdays": [
            {"departure": "05:30", "arrival": "06:50"},
            {"departure": "05:52", "arrival": "07:12"},
            {"departure": "06:14", "arrival": "07:34"},
            {"departure": "06:36", "arrival": "07:56"},
            {"departure": "06:58", "arrival": "08:18", "bus_name": "L'express"},
            {"departure": "07:20", "arrival": "08:40"},
            {"departure": "07:42", "arrival": "09:02"},
            {"departure": "08:04", "arrival": "09:24"},
            {"departure": "08:26", "arrival": "09:46"},
            {"departure": "09:14", "arrival": "10:34"},
            {"departure": "10:02", "arrival": "11:22", "bus_name": "Rosa"},
            {"departure": "10:50", "arrival": "12:10"},
            {"departure": "11:38", "arrival": "12:58"},
            {"departure": "12:26", "arrival": "13:46"},
            {"departure": "13:14", "arrival": "14:34"},
            {"departure": "14:02", "arrival": "15:22"},
            {"departure": "14:50", "arrival": "16:10"},
            {"departure": "15:38", "arrival": "16:58"},
            {"departure": "16:26", "arrival": "17:46"},
            {"departure": "17:18", "arrival": "18:38"}
          ],
          "saturdays": [
            {"departure": "05:30", "arrival": "06:50"},
            {"departure": "06:18", "arrival": "07:38"},
            {"departure": "07:06", "arrival": "08:26"},
            {"departure": "07:54", "arrival": "09:14"},
            {"departure": "08:42", "arrival": "10:02"},
            {"departure": "09:30", "arrival": "10:50"},
            {"departure": "10:18", "arrival": "11:38"},
            {"departure": "11:06", "arrival": "12:26"},
            {"departure": "11:54", "arrival": "13:14"},
            {"departure": "12:42", "arrival": "14:02"},
            {"departure": "13:30", "arrival": "14:50"},
            {"departure": "14:18", "arrival": "15:38"},
            {"departure": "15:06", "arrival": "16:26"},
            {"departure": "15:54", "arrival": "17:14"},
            {"departure": "16:42", "arrival": "18:02"},
            {"departure": "17:18", "arrival": "18:38"}
          ],
          "sundays_public_holidays": [
            {"departure": "06:00", "arrival": "07:20"},
            {"departure": "07:00", "arrival": "08:20"},
            {"departure": "08:00", "arrival": "09:20"},
            {"departure": "09:00", "arrival": "10:20"},
            {"departure": "10:00", "arrival": "11:20"},
            {"departure": "11:00", "arrival": "12:20"},
            {"departure": "12:00", "arrival": "13:20"},
            {"departure": "13:00", "arrival": "14:20"},
            {"departure": "14:00", "arrival": "15:20"},
            {"departure": "15:00", "arrival": "16:20"},
            {"departure": "16:00", "arrival": "17:20"},
            {"departure": "17:00", "arrival": "18:20"},
            {"departure": "17:00", "arrival": "18:20"}
          ]
        }
      },
      {
        "location_name": "Réduit → Mahebourg / L'Escalier",
        "bus_route": "198",
        "schedules": {
          "weekdays": [
            {"departure": "13:18", "arrival": "~14:20", "bus_name": "UBS"},
            {"departure": "14:43", "arrival": "~15:45", "bus_name": "UBS"},
            {"departure": "15:45", "arrival": "~16:45", "bus_name": "UBS"},
          ],
          "saturdays": [],
          "sundays_public_holidays": []
        }
      }
    ];
  }
}
