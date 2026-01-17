import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class BusTab extends StatefulWidget {
  const BusTab({super.key});

  @override
  State<BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<BusTab> {
  // Parsing the JSON structure provided by user
  final List<Map<String, dynamic>> _locations = [
    {
      "location_name": "At Réduit (going to L'Escalier)",
      "bus_route": "200",
      "schedules": {
        "weekdays": [
          {"arrival_at_reduit": "06:14", "arrival_at_lescalier": "07:20"},
          {"arrival_at_reduit": "06:51", "arrival_at_lescalier": "07:57", "bus_name": "Dakar"},
          {"arrival_at_reduit": "07:28", "arrival_at_lescalier": "08:34"},
          {"arrival_at_reduit": "08:05", "arrival_at_lescalier": "09:11"},
          {"arrival_at_reduit": "08:42", "arrival_at_lescalier": "09:48"},
          {"arrival_at_reduit": "09:22", "arrival_at_lescalier": "10:28"},
          {"arrival_at_reduit": "10:25", "arrival_at_lescalier": "11:28", "bus_name": "Private"},
          {"arrival_at_reduit": "10:42", "arrival_at_lescalier": "11:48", "bus_name": "UBS"},
          {"arrival_at_reduit": "11:22", "arrival_at_lescalier": "12:28", "bus_name": "Napoleon"},
          {"arrival_at_reduit": "11:40", "arrival_at_lescalier": "12:46", "bus_name": "Perle de Mahebourg"},
          {"arrival_at_reduit": "12:02", "arrival_at_lescalier": "13:08", "bus_name": "Private"},
          {"arrival_at_reduit": "12:42", "arrival_at_lescalier": "13:48", "bus_name": "Dakar"},
          {"arrival_at_reduit": "13:05", "arrival_at_lescalier": "14:28", "bus_name": "Perle de Mahebourg"},
          {"arrival_at_reduit": "14:02", "arrival_at_lescalier": "15:08", "bus_name": "Napoleon"},
          {"arrival_at_reduit": "14:42", "arrival_at_lescalier": "15:48", "bus_name": "UBS"},
          {"arrival_at_reduit": "16:02", "arrival_at_lescalier": "17:08"},
          {"arrival_at_reduit": "16:42", "arrival_at_lescalier": "17:48"},
          {"arrival_at_reduit": "17:22", "arrival_at_lescalier": "18:28"},
          {"arrival_at_reduit": "18:04", "arrival_at_lescalier": "19:10"}
        ],
        "saturdays": [
          {"arrival_at_reduit": "06:14", "arrival_at_lescalier": "07:20"},
          {"arrival_at_reduit": "06:54", "arrival_at_lescalier": "08:00"},
          {"arrival_at_reduit": "07:34", "arrival_at_lescalier": "08:40"},
          {"arrival_at_reduit": "08:14", "arrival_at_lescalier": "09:20"},
          {"arrival_at_reduit": "08:54", "arrival_at_lescalier": "10:00"},
          {"arrival_at_reduit": "09:34", "arrival_at_lescalier": "10:40"},
          {"arrival_at_reduit": "10:14", "arrival_at_lescalier": "11:20"},
          {"arrival_at_reduit": "10:54", "arrival_at_lescalier": "12:00"},
          {"arrival_at_reduit": "11:34", "arrival_at_lescalier": "12:40"},
          {"arrival_at_reduit": "12:14", "arrival_at_lescalier": "13:20"},
          {"arrival_at_reduit": "12:54", "arrival_at_lescalier": "14:00"},
          {"arrival_at_reduit": "13:34", "arrival_at_lescalier": "14:40"},
          {"arrival_at_reduit": "14:14", "arrival_at_lescalier": "15:20"},
          {"arrival_at_reduit": "14:54", "arrival_at_lescalier": "16:00"},
          {"arrival_at_reduit": "15:34", "arrival_at_lescalier": "16:40"},
          {"arrival_at_reduit": "16:14", "arrival_at_lescalier": "17:20"},
          {"arrival_at_reduit": "16:54", "arrival_at_lescalier": "18:00"},
          {"arrival_at_reduit": "17:34", "arrival_at_lescalier": "18:40"},
          {"arrival_at_reduit": "18:04", "arrival_at_lescalier": "19:10"}
        ],
        "sundays_public_holidays": [
          {"arrival_at_reduit": "06:44", "arrival_at_lescalier": "07:50"},
          {"arrival_at_reduit": "07:44", "arrival_at_lescalier": "08:50"},
          {"arrival_at_reduit": "08:44", "arrival_at_lescalier": "09:50"},
          {"arrival_at_reduit": "09:44", "arrival_at_lescalier": "10:50"},
          {"arrival_at_reduit": "10:44", "arrival_at_lescalier": "11:50"},
          {"arrival_at_reduit": "11:44", "arrival_at_lescalier": "12:50"},
          {"arrival_at_reduit": "12:44", "arrival_at_lescalier": "13:50"},
          {"arrival_at_reduit": "13:44", "arrival_at_lescalier": "14:50"},
          {"arrival_at_reduit": "14:44", "arrival_at_lescalier": "15:50"},
          {"arrival_at_reduit": "15:44", "arrival_at_lescalier": "16:50"},
          {"arrival_at_reduit": "16:44", "arrival_at_lescalier": "17:50"},
          {"arrival_at_reduit": "17:44", "arrival_at_lescalier": "18:50"},
          {"arrival_at_reduit": "18:44", "arrival_at_lescalier": "19:50"}
        ]
      }
    },
    {
      "location_name": "At L'Escalier (going to Réduit)",
      "bus_route": "200",
      "schedules": {
        "weekdays": [
          {"departure_from_lescalier": "05:30", "arrival_at_reduit": "06:50"},
          {"departure_from_lescalier": "05:52", "arrival_at_reduit": "07:12"},
          {"departure_from_lescalier": "06:14", "arrival_at_reduit": "07:34"},
          {"departure_from_lescalier": "06:36", "arrival_at_reduit": "07:56"},
          {"departure_from_lescalier": "06:58", "arrival_at_reduit": "08:18"},
          {"departure_from_lescalier": "07:20", "arrival_at_reduit": "08:40"},
          {"departure_from_lescalier": "07:42", "arrival_at_reduit": "09:02"},
          {"departure_from_lescalier": "08:04", "arrival_at_reduit": "09:24"},
          {"departure_from_lescalier": "08:26", "arrival_at_reduit": "09:46"},
          {"departure_from_lescalier": "09:14", "arrival_at_reduit": "10:34"},
          {"departure_from_lescalier": "10:02", "arrival_at_reduit": "11:22"},
          {"departure_from_lescalier": "10:50", "arrival_at_reduit": "12:10"},
          {"departure_from_lescalier": "11:38", "arrival_at_reduit": "12:58"},
          {"departure_from_lescalier": "12:26", "arrival_at_reduit": "13:46"},
          {"departure_from_lescalier": "13:14", "arrival_at_reduit": "14:34"},
          {"departure_from_lescalier": "14:02", "arrival_at_reduit": "15:22"},
          {"departure_from_lescalier": "14:50", "arrival_at_reduit": "16:10"},
          {"departure_from_lescalier": "15:38", "arrival_at_reduit": "16:58"},
          {"departure_from_lescalier": "16:26", "arrival_at_reduit": "17:46"},
          {"departure_from_lescalier": "17:18", "arrival_at_reduit": "18:38"}
        ],
        "saturdays": [
            {"departure_from_lescalier": "05:30", "arrival_at_reduit": "06:50"},
            {"departure_from_lescalier": "06:18", "arrival_at_reduit": "07:38"},
            {"departure_from_lescalier": "07:06", "arrival_at_reduit": "08:26"},
            {"departure_from_lescalier": "07:54", "arrival_at_reduit": "09:14"},
            {"departure_from_lescalier": "08:42", "arrival_at_reduit": "10:02"},
            {"departure_from_lescalier": "09:30", "arrival_at_reduit": "10:50"},
            {"departure_from_lescalier": "10:18", "arrival_at_reduit": "11:38"},
            {"departure_from_lescalier": "11:06", "arrival_at_reduit": "12:26"},
            {"departure_from_lescalier": "11:54", "arrival_at_reduit": "13:14"},
            {"departure_from_lescalier": "12:42", "arrival_at_reduit": "14:02"},
            {"departure_from_lescalier": "13:30", "arrival_at_reduit": "14:50"},
            {"departure_from_lescalier": "14:18", "arrival_at_reduit": "15:38"},
            {"departure_from_lescalier": "15:06", "arrival_at_reduit": "16:26"},
            {"departure_from_lescalier": "15:54", "arrival_at_reduit": "17:14"},
            {"departure_from_lescalier": "16:42", "arrival_at_reduit": "18:02"},
            {"departure_from_lescalier": "17:18", "arrival_at_reduit": "18:38"}
        ],
        "sundays_public_holidays": [
          {"departure_from_lescalier": "06:00", "arrival_at_reduit": "07:20"},
          {"departure_from_lescalier": "07:00", "arrival_at_reduit": "08:20"},
          {"departure_from_lescalier": "08:00", "arrival_at_reduit": "09:20"},
          {"departure_from_lescalier": "09:00", "arrival_at_reduit": "10:20"},
          {"departure_from_lescalier": "10:00", "arrival_at_reduit": "11:20"},
          {"departure_from_lescalier": "11:00", "arrival_at_reduit": "12:20"},
          {"departure_from_lescalier": "12:00", "arrival_at_reduit": "13:20"},
          {"departure_from_lescalier": "13:00", "arrival_at_reduit": "14:20"},
          {"departure_from_lescalier": "14:00", "arrival_at_reduit": "15:20"},
          {"departure_from_lescalier": "15:00", "arrival_at_reduit": "16:20"},
          {"departure_from_lescalier": "16:00", "arrival_at_reduit": "17:20"},
          {"departure_from_lescalier": "17:00", "arrival_at_reduit": "18:20"},
          {"departure_from_lescalier": "17:00", "arrival_at_reduit": "18:20"}
        ]
      }
    }
    // ... Curepipe routes can be added later or user can add them
  ];

  int _expandedIndex = -1; // -1 means none expanded

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Minimalist background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Bus Schedule", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: _locations.length,
        separatorBuilder: (c, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final loc = _locations[index];
          final isExpanded = _expandedIndex == index;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isExpanded 
                ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              border: isExpanded ? Border.all(color: Colors.blueAccent.withOpacity(0.3)) : null,
            ),
            child: Column(
              children: [
                // Header (Click to expand)
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? -1 : index;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isExpanded ? Colors.blueAccent : Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.directions_bus_rounded, color: isExpanded ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc["bus_route"]!, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(loc["location_name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            ],
                          ),
                        ),
                        Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey)
                      ],
                    ),
                  ),
                ),

                // Expanded Content (Schedule)
                if (isExpanded)
                  _buildScheduleView(loc["schedules"])
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleView(Map<String, dynamic> schedules) {
    // Determine day type
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    List<dynamic> todaysSchedule = [];
    String dayLabel = "";

    if (day == "Saturday") {
      todaysSchedule = schedules["saturdays"] ?? [];
      dayLabel = "Saturday Schedule";
    } else if (day == "Sunday") {
      todaysSchedule = schedules["sundays_public_holidays"] ?? [];
      dayLabel = "Sunday/Holiday Schedule";
    } else {
      todaysSchedule = schedules["weekdays"] ?? [];
      dayLabel = "Weekday Schedule";
    }

    // Find next bus
    final timeFormat = DateFormat("HH:mm");
    final currentTimeStr = timeFormat.format(now);
    // Convert to minutes for comparison
    int currentMinutes = _toMinutes(currentTimeStr);
    
    Map<String, dynamic>? nextBus;
    String nextBusTime = "";
    
    for (var bus in todaysSchedule) {
      // Keys might differ: "arrival_at_reduit" or "departure_from_lescalier"
      // We assume the FIRST key is the start time of interest for sorting? 
      // Or we check the "departure" key explicitly if possible, but the JSON uses varied keys.
      // Let's just grab the first value as "time" for simplicity or try to parse keys.
      String timeKey = bus.keys.firstWhere((k) => k != "bus_name", orElse: () => "");
      String timeStr = bus[timeKey] ?? "00:00";
      
      if (_toMinutes(timeStr) > currentMinutes) {
        nextBus = bus;
        nextBusTime = timeStr;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 10),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(dayLabel, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 12)),
               if (nextBus != null)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                   child: Text("Next: $nextBusTime", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)),
                 )
             ],
          ),
          const SizedBox(height: 15),
          
          // List of times (Horizontal scroll or wrapped)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: todaysSchedule.map<Widget>((bus) {
               String timeKey = bus.keys.firstWhere((k) => k != "bus_name", orElse: () => "");
               String timeStr = bus[timeKey] ?? "";
               bool isPast = _toMinutes(timeStr) < currentMinutes;
               bool isNext = timeStr == nextBusTime;
               
               return Container(
                 width: 80,
                 padding: const EdgeInsets.symmetric(vertical: 10),
                 decoration: BoxDecoration(
                   color: isNext ? Colors.blueAccent : (isPast ? Colors.grey[100] : Colors.white),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: isNext ? Colors.blueAccent : Colors.grey[300]!),
                 ),
                 child: Column(
                   children: [
                     Text(timeStr, style: TextStyle(
                       fontWeight: FontWeight.bold, 
                       color: isNext ? Colors.white : (isPast ? Colors.grey : Colors.black87)
                     )),
                     if (bus["bus_name"] != null)
                       Text(bus["bus_name"], style: TextStyle(fontSize: 9, color: isNext ? Colors.white70 : Colors.grey))
                   ],
                 ),
               );
            }).toList(),
          )
        ],
      ),
    );
  }

  int _toMinutes(String time) {
    try {
      final parts = time.split(":");
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }
}
