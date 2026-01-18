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

  int _expandedIndex = -1; 

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
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: _locations.length,
        separatorBuilder: (c, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return BusRouteCard(
            data: _locations[index],
          );
        },
      ),
    );
  }
}

class BusRouteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const BusRouteCard({super.key, required this.data});

  @override
  State<BusRouteCard> createState() => _BusRouteCardState();
}

class _BusRouteCardState extends State<BusRouteCard> {
  bool _isExpanded = false;
  int _selectedTabIndex = 0; // 0: Weekday, 1: Sat, 2: Sun

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday;
    if (weekday == 7) _selectedTabIndex = 2; // Sunday
    else if (weekday == 6) _selectedTabIndex = 1; // Saturday
    else _selectedTabIndex = 0; // Weekday
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF1565C0);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final locationName = widget.data['location_name'] ?? 'Unknown Location';
    final busRoute = widget.data['bus_route'] ?? 'N/A';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF1565C0).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.directions_bus_filled_rounded, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A1D1E)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                "Route $busRoute",
                                style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[400],
                  )
                ],
              ),
            ),
          ),

          // Expanded Content
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Column(
              children: [
                Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[100]),
                // Tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                       _buildTabButton("Weekdays", 0, isDark),
                       const SizedBox(width: 10),
                       _buildTabButton("Sat", 1, isDark),
                       const SizedBox(width: 10),
                       _buildTabButton("Sun", 2, isDark),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildScheduleGrid(isDark),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    final activeColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : (isDark ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: FontWeight.bold,
              fontSize: 13
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleGrid(bool isDark) {
    final schedules = widget.data['schedules'];
    List<dynamic> trips = []; // List of Maps
    
    if (_selectedTabIndex == 0) trips = schedules['weekdays'] ?? [];
    else if (_selectedTabIndex == 1) trips = schedules['saturdays'] ?? [];
    else trips = schedules['sundays_public_holidays'] ?? [];

    if (trips.isEmpty) {
      return Center(child: Text("No buses scheduled.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey)));
    }

    // Time Check for Highlighting
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    String? nextBusTime;
    
    // Determine if we should highlight (is it today?)
    final weekday = now.weekday;
    bool isTodayTab = false;
    if (weekday <= 5 && _selectedTabIndex == 0) isTodayTab = true;
    else if (weekday == 6 && _selectedTabIndex == 1) isTodayTab = true;
    else if (weekday == 7 && _selectedTabIndex == 2) isTodayTab = true;

    // Helper to get time string from trip map
    String getTime(Map<String, dynamic> trip) {
       // We'll take the first key that is not 'bus_name'
       for (var key in trip.keys) {
         if (key != 'bus_name') return trip[key].toString();
       }
       return "";
    }

    if (isTodayTab) {
      for (var trip in trips) {
         final tStr = getTime(trip);
         if (tStr.isNotEmpty && _toMinutes(tStr) > currentMinutes) {
           nextBusTime = tStr;
           break;
         }
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: trips.map<Widget>((trip) {
         final timeStr = getTime(trip);
         final busName = trip['bus_name'];
         
         bool isNext = (timeStr == nextBusTime);
         bool isPast = isTodayTab && (_toMinutes(timeStr) <= currentMinutes);
         
         return _buildBusChip(timeStr, busName, isNext, isPast, isDark);
      }).toList(),
    );
  }

  Widget _buildBusChip(String time, String? name, bool isNext, bool isPast, bool isDark) {
    // Style
    Color bg;
    Color border;
    Color text;

    if (isNext) {
      bg = const Color(0xFF2962FF); // Premium Blue
      border = const Color(0xFF2962FF);
      text = Colors.white;
    } else if (isPast) {
      bg = isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]!;
      border = isDark ? Colors.transparent : Colors.grey[200]!;
      text = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    } else {
      // Future
      bg = isDark ? Colors.grey[800]! : Colors.white;
      border = isDark ? Colors.white10 : Colors.grey[200]!;
      text = isDark ? Colors.white : Colors.black87;
    }

    return Container(
      width: name != null ? 100 : 80, // Wider if has name
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isNext ? [BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : null
      ),
      child: Column(
        children: [
          Text(time, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text)),
          if (name != null) ...[
             const SizedBox(height: 4),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
               decoration: BoxDecoration(
                 color: isNext ? Colors.white.withOpacity(0.2) : (isDark ? Colors.amber.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                 borderRadius: BorderRadius.circular(8)
               ),
               child: Text(
                 name, 
                 textAlign: TextAlign.center,
                 maxLines: 1, overflow: TextOverflow.ellipsis,
                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isNext ? Colors.white : Colors.amber[900])
               ),
             )
          ]
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
