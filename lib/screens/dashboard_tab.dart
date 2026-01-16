import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/class_session.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),
          const SizedBox(height: 20),
          _buildNextClassCard(context),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildInfoCard(context, "Next Bus", "12:15", Icons.directions_bus, Colors.orange)),
              const SizedBox(width: 15),
              Expanded(child: _buildInfoCard(context, "Quick Note", "+ Add", Icons.edit_note, Colors.blue)),
            ],
          ),
          const SizedBox(height: 25),
          const Text("Upcoming Deadlines", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          _buildDeadlineTile("Mobile Computing Test", "Tomorrow, 10:00 AM", Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Good Morning,", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const Text("Student", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
      ],
    );
  }

  Widget _buildNextClassCard(BuildContext context) {
    // In real app, fetch from TimetableProvider
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("Next Class", style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const Icon(Icons.access_time_filled, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 15),
          const Text("Scientific Writing", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("Room G3 (The Core)", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.timer, color: Colors.white, size: 16),
              SizedBox(width: 5),
              Text("Starts in 45 mins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeadlineTile(String title, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
          Icon(Icons.warning_amber_rounded, color: color),
        ],
      ),
    );
  }
}
