import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../models/bus_route.dart';
import '../services/isar_service.dart';
import 'package:isar_community/isar.dart';

class BusTab extends StatefulWidget {
  const BusTab({super.key});

  @override
  State<BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<BusTab> {
  List<BusRoute> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final isarService = Provider.of<IsarService>(context, listen: false);
    final isar = await isarService.db;
    final routes = await isar.busRoutes.where().findAll();
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  // Temporary function to allow user to paste JSON (since we don't have the file yet)
  Future<void> _importJson(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Import Bus JSON"),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(hintText: "Paste JSON here..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<BusService>(context, listen: false).fetchAndParseBusSchedule(controller.text);
                Navigator.pop(context);
                _loadRoutes(); // Reload to show new data
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importJson(context),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const Center(child: Text("No bus schedules found. Tap + to import."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.directions_bus, color: Color(0xFF1A237E)),
                        ),
                        title: Text(route.destination, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Bus ${route.routeNumber} • ${route.busName ?? 'Normal'}"),
                        trailing: Text(
                          route.arrivalTime,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
