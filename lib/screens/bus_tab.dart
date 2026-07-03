import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/scroll_time_picker.dart';

class BusTab extends StatefulWidget {
  const BusTab({super.key});

  @override
  State<BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<BusTab> {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusData();
  }

  Future<void> _loadBusData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('bus_locations_json');

    if (jsonStr != null) {
      final decoded = jsonDecode(jsonStr) as List;
      setState(() {
        _locations = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      // First launch — seed default data
      _locations = _getDefaultData();
      await _saveData();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bus_locations_json', jsonEncode(_locations));
  }

  void _addRoute() async {
    final result = await _showAddEditRouteSheet(context);
    if (result != null) {
      setState(() => _locations.add(result));
      await _saveData();
    }
  }

  void _editRoute(int index) async {
    final result = await _showAddEditRouteSheet(context, existingData: _locations[index]);
    if (result != null) {
      setState(() => _locations[index] = result);
      await _saveData();
    }
  }

  void _deleteRoute(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Route"),
        content: Text("Delete \"${_locations[index]['location_name']}\"?\nThis cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _locations.removeAt(index));
      await _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text("Bus Schedule", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoute,
        backgroundColor: isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_bus_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No bus routes yet", style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text("Tap + to add one", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[600] : Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: _locations.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return BusRouteCard(
                      data: _locations[index],
                      onEdit: () => _editRoute(index),
                      onDelete: () => _deleteRoute(index),
                    );
                  },
                ),
    );
  }

  // ─── Default seed data ───────────────────────────────────────
  List<Map<String, dynamic>> _getDefaultData() {
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

// ─── Add/Edit Route Bottom Sheet ─────────────────────────────
Future<Map<String, dynamic>?> _showAddEditRouteSheet(
  BuildContext context, {
  Map<String, dynamic>? existingData,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddEditRouteSheet(existingData: existingData),
  );
}

class _AddEditRouteSheet extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  const _AddEditRouteSheet({this.existingData});

  @override
  State<_AddEditRouteSheet> createState() => _AddEditRouteSheetState();
}

class _AddEditRouteSheetState extends State<_AddEditRouteSheet> {
  late TextEditingController _nameController;
  late TextEditingController _routeController;
  int _selectedDayTab = 0; // 0=weekdays, 1=sat, 2=sun

  // Trips per day type
  late List<Map<String, String>> _weekdayTrips;
  late List<Map<String, String>> _saturdayTrips;
  late List<Map<String, String>> _sundayTrips;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    _nameController = TextEditingController(text: d?['location_name'] ?? '');
    _routeController = TextEditingController(text: d?['bus_route'] ?? '');

    _weekdayTrips = _parseTrips(d?['schedules']?['weekdays']);
    _saturdayTrips = _parseTrips(d?['schedules']?['saturdays']);
    _sundayTrips = _parseTrips(d?['schedules']?['sundays_public_holidays']);
  }

  List<Map<String, String>> _parseTrips(List<dynamic>? trips) {
    if (trips == null || trips.isEmpty) return [];
    return trips.map<Map<String, String>>((t) {
      final m = Map<String, dynamic>.from(t);
      return {
        'departure': (m['departure'] ?? '').toString(),
        'arrival': (m['arrival'] ?? '').toString(),
        'bus_name': (m['bus_name'] ?? '').toString(),
      };
    }).toList();
  }

  List<Map<String, String>> get _activeTrips {
    if (_selectedDayTab == 0) return _weekdayTrips;
    if (_selectedDayTab == 1) return _saturdayTrips;
    return _sundayTrips;
  }

  void _addTrip() {
    setState(() {
      _activeTrips.add({'departure': '', 'arrival': '', 'bus_name': ''});
    });
  }

  void _removeTrip(int index) {
    setState(() {
      _activeTrips.removeAt(index);
    });
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a location name")),
      );
      return;
    }

    // Build the result map — filter out empty trips
    List<Map<String, dynamic>> cleanTrips(List<Map<String, String>> trips) {
      return trips
          .where((t) => (t['departure'] ?? '').isNotEmpty)
          .map<Map<String, dynamic>>((t) {
        final m = <String, dynamic>{
          'departure': t['departure'] ?? '',
          'arrival': t['arrival'] ?? '',
        };
        if ((t['bus_name'] ?? '').isNotEmpty) m['bus_name'] = t['bus_name'];
        return m;
      }).toList();
    }

    final result = <String, dynamic>{
      'location_name': _nameController.text.trim(),
      'bus_route': _routeController.text.trim(),
      'schedules': {
        'weekdays': cleanTrips(_weekdayTrips),
        'saturdays': cleanTrips(_saturdayTrips),
        'sundays_public_holidays': cleanTrips(_sundayTrips),
      }
    };

    Navigator.pop(context, result);
  }

  Future<String?> _pickTime(String? current) async {
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    if (current != null && current.contains(':')) {
      try {
        final parts = current.split(':');
        initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    final picked = await showScrollTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingData != null ? "Edit Route" : "Add Route",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                ),
                TextButton(
                  onPressed: _save,
                  child: Text("Save", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Route Info Fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "Location / Direction",
                    hintText: "e.g. At Réduit (going to L'Escalier)",
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _routeController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "Route Number",
                    hintText: "e.g. 200",
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Day type tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildDayTab("Weekdays", 0, isDark, accent),
                const SizedBox(width: 10),
                _buildDayTab("Sat", 1, isDark, accent),
                const SizedBox(width: 10),
                _buildDayTab("Sun/Hol", 2, isDark, accent),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Trip list
          Expanded(
            child: _activeTrips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text("No trips", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _activeTrips.length,
                    itemBuilder: (ctx, i) => _buildTripRow(i, isDark, accent, cardBg),
                  ),
          ),
          // Add Trip Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _addTrip,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Add Trip"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTab(String label, int index, bool isDark, Color accent) {
    final isSelected = _selectedDayTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDayTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent : (isDark ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripRow(int index, bool isDark, Color accent, Color cardBg) {
    final trip = _activeTrips[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Trip number
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "${index + 1}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Departure
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final t = await _pickTime(trip['departure']);
                if (t != null) setState(() => trip['departure'] = t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text("DEP", style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        trip['departure']?.isEmpty ?? true ? "--:--" : trip['departure']!,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
          // Arrival
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final t = await _pickTime(trip['arrival']);
                if (t != null) setState(() => trip['arrival'] = t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text("ARR", style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        trip['arrival']?.isEmpty ?? true ? "--:--" : trip['arrival']!,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bus Name
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final controller = TextEditingController(text: trip['bus_name']);
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Bus Name"),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: "e.g. UBS, Dakar..."),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("OK")),
                    ],
                  ),
                );
                if (name != null) setState(() => trip['bus_name'] = name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: (trip['bus_name'] ?? '').isNotEmpty
                      ? Colors.amber.withOpacity(isDark ? 0.15 : 0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (trip['bus_name'] ?? '').isEmpty ? "Bus" : trip['bus_name']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (trip['bus_name'] ?? '').isNotEmpty
                        ? (isDark ? Colors.amber[200] : Colors.amber[900])
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                ),
              ),
            ),
          ),
          // Delete Trip
          IconButton(
            onPressed: () => _removeTrip(index),
            icon: Icon(Icons.close_rounded, size: 18, color: Colors.red[300]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

// ─── Bus Route Display Card ─────────────────────────────────
class BusRouteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const BusRouteCard({super.key, required this.data, required this.onEdit, required this.onDelete});

  @override
  State<BusRouteCard> createState() => _BusRouteCardState();
}

class _BusRouteCardState extends State<BusRouteCard> {
  int _selectedTabIndex = 0;
  final ScrollController _timelineScrollController = ScrollController();
  Timer? _countdownTimer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday;
    if (weekday == 7) _selectedTabIndex = 2;
    else if (weekday == 6) _selectedTabIndex = 1;
    else _selectedTabIndex = 0;

    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateCountdown();
    });
  }

  void _updateCountdown() {
    final trips = _getTrips();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final isTodayTab = _isTodayTab();

    if (!isTodayTab || trips.isEmpty) {
      if (mounted) setState(() => _countdownText = '');
      return;
    }

    for (var trip in trips) {
      final tMap = Map<String, dynamic>.from(trip);
      final depStr = (tMap['departure'] ?? '').toString();
      final depMin = _toMinutes(depStr);
      if (depMin > currentMinutes) {
        final diff = depMin - currentMinutes;
        if (mounted) {
          setState(() {
            if (diff < 60) {
              _countdownText = 'in $diff min';
            } else {
              final h = diff ~/ 60;
              final m = diff % 60;
              _countdownText = 'in ${h}h ${m}m';
            }
          });
        }
        return;
      }
    }
    if (mounted) setState(() => _countdownText = 'No more buses');
  }

  List<dynamic> _getTrips() {
    final schedules = widget.data['schedules'];
    if (_selectedTabIndex == 0) return schedules['weekdays'] ?? [];
    if (_selectedTabIndex == 1) return schedules['saturdays'] ?? [];
    return schedules['sundays_public_holidays'] ?? [];
  }

  bool _isTodayTab() {
    final weekday = DateTime.now().weekday;
    if (weekday <= 5 && _selectedTabIndex == 0) return true;
    if (weekday == 6 && _selectedTabIndex == 1) return true;
    if (weekday == 7 && _selectedTabIndex == 2) return true;
    return false;
  }

  int _toMinutes(String time) {
    try {
      final clean = time.replaceAll('~', '');
      final parts = clean.split(":");
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  void _scrollToNextBus(List<dynamic> trips) {
    if (!_isTodayTab()) return;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (int i = 0; i < trips.length; i++) {
      final tMap = Map<String, dynamic>.from(trips[i]);
      final depStr = (tMap['departure'] ?? '').toString();
      if (_toMinutes(depStr) > currentMinutes) {
        // Scroll so that the next bus is roughly centered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_timelineScrollController.hasClients) {
            final targetOffset = (i * 88.0) - 100.0; // each item ~88px wide, offset to center
            _timelineScrollController.animateTo(
              targetOffset.clamp(0.0, _timelineScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }
        });
        return;
      }
    }
  }

  void _showContextMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: isDark ? Colors.white70 : Colors.black87),
              title: Text("Edit Route", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () { Navigator.pop(ctx); widget.onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text("Delete Route", style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); widget.onDelete(); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final locationName = widget.data['location_name'] ?? 'Unknown Location';
    final busRoute = widget.data['bus_route'] ?? '';

    final trips = _getTrips();
    final isTodayTab = _isTodayTab();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Find the next bus index
    int nextBusIndex = -1;
    if (isTodayTab) {
      for (int i = 0; i < trips.length; i++) {
        final tMap = Map<String, dynamic>.from(trips[i]);
        final depStr = (tMap['departure'] ?? '').toString();
        if (_toMinutes(depStr) > currentMinutes) {
          nextBusIndex = i;
          break;
        }
      }
    }

    // Auto-scroll to next bus
    _scrollToNextBus(trips);

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, isDark),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : accent.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  // Route Badge
                  if (busRoute.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        busRoute,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (busRoute.isNotEmpty) const SizedBox(width: 14),
                  // Location Name
                  Expanded(
                    child: Text(
                      locationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1D1E),
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Edit & Delete
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 18),
                    onPressed: widget.onEdit,
                    tooltip: "Edit Route",
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 18),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          title: const Text("Delete Route?", style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text("Are you sure? This cannot be undone."),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            ),
                            TextButton(
                              onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: "Delete Route",
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Day Tabs ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDayPill("Weekdays", 0, isDark, accent),
                  _buildDayPill("Sat", 1, isDark, accent),
                  _buildDayPill("Sun/Hol", 2, isDark, accent),
                  // Countdown badge
                  if (_countdownText.isNotEmpty && isTodayTab)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _countdownText == 'No more buses'
                            ? (isDark ? Colors.grey[800] : Colors.grey[200])
                            : accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _countdownText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _countdownText == 'No more buses'
                              ? (isDark ? Colors.grey[400] : Colors.grey[600])
                              : accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Horizontal Timeline ──
            if (trips.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Center(
                  child: Text(
                    "No buses scheduled.",
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 140,
                child: ListView.builder(
                  controller: _timelineScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: trips.length,
                  itemBuilder: (context, i) {
                    final tripMap = Map<String, dynamic>.from(trips[i]);
                    final depStr = (tripMap['departure'] ?? '').toString();
                    final arrStr = (tripMap['arrival'] ?? '').toString();
                    final busName = (tripMap['bus_name'] ?? '').toString();
                    final depMin = _toMinutes(depStr);

                    final bool isNext = i == nextBusIndex;
                    final bool isPast = isTodayTab && depMin <= currentMinutes && !isNext;

                    return Container(
                      width: 95,
                      margin: EdgeInsets.only(right: i < trips.length - 1 ? 8 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Bus Icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isNext ? 48 : 36,
                            height: isNext ? 48 : 36,
                            decoration: BoxDecoration(
                              color: isNext
                                  ? accent
                                  : isPast
                                      ? (isDark ? Colors.grey[800] : Colors.grey[200])
                                      : accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(isNext ? 16 : 12),
                              boxShadow: isNext
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.directions_bus_rounded,
                              size: isNext ? 24 : 18,
                              color: isNext
                                  ? Colors.white
                                  : isPast
                                      ? (isDark ? Colors.grey[600] : Colors.grey[400])
                                      : accent,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Departure Time
                          Text(
                            depStr,
                            style: TextStyle(
                              fontSize: isNext ? 15 : 13,
                              fontWeight: isNext ? FontWeight.w900 : FontWeight.w600,
                              color: isNext
                                  ? accent
                                  : isPast
                                      ? (isDark ? Colors.grey[600] : Colors.grey[400])
                                      : (isDark ? Colors.white : Colors.black87),
                              decoration: isPast ? TextDecoration.lineThrough : null,
                              letterSpacing: 0.3,
                            ),
                          ),

                          // Arrival (smaller)
                          if (arrStr.isNotEmpty)
                            Text(
                              '→ $arrStr',
                              style: TextStyle(
                                fontSize: 9,
                                color: isPast
                                    ? (isDark ? Colors.grey[700] : Colors.grey[300])
                                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
                                decoration: isPast ? TextDecoration.lineThrough : null,
                              ),
                            ),

                          // Bus Name
                          if (busName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isPast
                                    ? Colors.transparent
                                    : (isDark ? Colors.amber.withOpacity(0.12) : Colors.amber.withOpacity(0.15)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                busName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: isPast
                                      ? (isDark ? Colors.grey[700] : Colors.grey[300])
                                      : (isDark ? Colors.amber[200] : Colors.amber[800]),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPill(String label, int index, bool isDark, Color accent) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTabIndex = index);
        _updateCountdown();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accent : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
