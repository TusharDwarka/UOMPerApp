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
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          return BusRouteCard(
            data: _locations[index],
            isExpanded: _expandedIndex == index,
            onExpand: () {
               setState(() {
                 _expandedIndex = (_expandedIndex == index) ? -1 : index;
               });
            },
          );
        },
      ),
    );
  }
}

class BusRouteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isExpanded;
  final VoidCallback onExpand;

  const BusRouteCard({super.key, required this.data, required this.isExpanded, required this.onExpand});

  @override
  State<BusRouteCard> createState() => _BusRouteCardState();
}

class _BusRouteCardState extends State<BusRouteCard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    // Default to current day: 0=Mon-Fri, 1=Sat, 2=Sun
    int initialIndex = 0;
    final weekday = DateTime.now().weekday;
    if (weekday == 7) initialIndex = 2; // Sunday
    else if (weekday == 6) initialIndex = 1; // Saturday
    else initialIndex = 0; // Weekday

    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: widget.isExpanded 
          ? [BoxShadow(color: Colors.blue.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))]
          : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: widget.isExpanded ? Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1.5) : Border.all(color: Colors.transparent),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: widget.onExpand,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.isExpanded ? Colors.blueAccent : Colors.grey[50], 
                      borderRadius: BorderRadius.circular(18)
                    ),
                    child: Icon(Icons.directions_bus_filled_rounded, color: widget.isExpanded ? Colors.white : Colors.blueGrey, size: 26),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                           decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                           child: Text("Bus ${widget.data['bus_route']}", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w800, fontSize: 11)),
                         ),
                         const SizedBox(height: 6),
                         Text(widget.data['location_name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87, height: 1.2)),
                      ],
                    ),
                  ),
                  Icon(widget.isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey[400])
                ],
              ),
            ),
          ),

          // Content
          if (widget.isExpanded) ...[
            Container(height: 1, color: Colors.grey[100]),
            // Tabs
            Container(
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                ),
                labelColor: Colors.blue[800],
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: "Weekdays"),
                  Tab(text: "Saturday"),
                  Tab(text: "Sunday"),
                ],
              ),
            ),
            
            // Tab View (using AnimatedBuilder to rebuild on tab change or just setState)
            // But TabBarView has size issues in Column. Use AnimatedBuilder on controller.
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                 final index = _tabController.index;
                 final schedules = widget.data['schedules'];
                 List<dynamic> list = [];
                 if (index == 0) list = schedules['weekdays'] ?? [];
                 else if (index == 1) list = schedules['saturdays'] ?? [];
                 else list = schedules['sundays_public_holidays'] ?? [];
                 
                 // Check if this is TODAY relative to real time to verify "Next Bus" logic
                 // Only highlight "Next Bus" if the selected tab matches TODAY's real day.
                 final now = DateTime.now();
                 final weekday = now.weekday;
                 bool isTodayTab = false;
                 if (weekday <= 5 && index == 0) isTodayTab = true;
                 else if (weekday == 6 && index == 1) isTodayTab = true;
                 else if (weekday == 7 && index == 2) isTodayTab = true;

                 return _buildTimeGrid(list, isTodayTab);
              }
            ),
            const SizedBox(height: 20),
          ]
        ],
      ),
    );
  }

  Widget _buildTimeGrid(List<dynamic> times, bool isTodayTab) {
    if (times.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("No schedule available.", style: TextStyle(color: Colors.grey)),
      );
    }
    
    // Find next bus for highlighting
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    String? nextBusTime;

    if (isTodayTab) {
      for (var bus in times) {
         // Flexible key extraction
         String timeKey = bus.keys.firstWhere((k) => k != "bus_name", orElse: () => "");
         String timeStr = bus[timeKey]?.toString() ?? "00:00";
         if (_toMinutes(timeStr) > currentMinutes) {
           nextBusTime = timeStr;
           break;
         }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.start,
        children: times.map<Widget>((bus) {
           String timeKey = bus.keys.firstWhere((k) => k != "bus_name", orElse: () => "");
           String timeStr = bus[timeKey]?.toString() ?? "";
           String? busName = bus["bus_name"];
           
           bool isNext = (timeStr == nextBusTime);
           bool isPast = isTodayTab && (_toMinutes(timeStr) <= currentMinutes);

           return _buildBusChip(timeStr, busName, isNext, isPast);
        }).toList(),
      ),
    );
  }

  Widget _buildBusChip(String time, String? name, bool isNext, bool isPast) {
    // Style
    Color bg = Colors.white;
    Color border = Colors.grey[200]!;
    Color text = Colors.black87;

    if (isNext) {
      bg = const Color(0xFF2962FF); // Premium Blue
      border = const Color(0xFF2962FF);
      text = Colors.white;
    } else if (isPast) {
      bg = Colors.grey[50]!;
      text = Colors.grey[400]!;
    } else {
      // Future but not next
      border = Colors.blue.withOpacity(0.3);
      text = Colors.blue[900]!;
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
                 color: isNext ? Colors.white.withOpacity(0.2) : Colors.orange.withOpacity(0.1),
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
