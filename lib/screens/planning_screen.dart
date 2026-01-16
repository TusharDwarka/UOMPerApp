import 'package:flutter/material.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black), onPressed: () {})
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Planning", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
            const SizedBox(height: 5),
            Text("June 28th", style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            
            const SizedBox(height: 40),

            // Details Rows
            _buildDetailRow(
              icon: Icons.calendar_today,
              color: const Color(0xFFE3F2FD), // Blue bg
              iconColor: const Color(0xFF448AFF),
              title: "June 31th, 2020",
              subtitle: "08:00 - 14:30",
            ),
            _buildDetailRow(
              icon: Icons.near_me, // Navigation arrow roughly matches
              color: const Color(0xFFF3E5F5), // Purple bg
              iconColor: const Color(0xFFAB47BC),
              title: "Location",
              subtitle: "zoom.com/?call=John",
              isLink: true,
            ),
            _buildDetailRow(
              icon: Icons.link,
              color: const Color(0xFFE8F5E9), // Green bg
              iconColor: const Color(0xFF66BB6A),
              title: "Shareable link",
              subtitle: "Everyone",
              trailing: Switch(
                value: true, 
                activeColor: const Color(0xFF66BB6A),
                onChanged: (val) {},
              ),
            ),

            const SizedBox(height: 40),

            // Classmates
            const Text("Classmates", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildAvatar("https://i.pravatar.cc/150?u=1", false),
                const SizedBox(width: 15),
                _buildAvatar("https://i.pravatar.cc/150?u=2", true), // Highlighted
                const SizedBox(width: 15),
                _buildAvatar("https://i.pravatar.cc/150?u=3", false),
                const SizedBox(width: 15),
                _buildAvatar("https://i.pravatar.cc/150?u=4", false),
              ],
            ),

            const SizedBox(height: 40),

            // Activity Chart
            const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(20, (index) {
                   // Random heights for bars to mimic the image
                   final height = (index % 3 == 0) ? 40.0 : (index % 2 == 0 ? 25.0 : 15.0);
                   final color = (index % 4 == 0) ? const Color(0xFF448AFF) : (index % 3 == 0 ? const Color(0xFFFF5252) : Colors.grey[300]);
                   return Container(
                     width: 4,
                     height: height,
                     decoration: BoxDecoration(
                       color: color,
                       borderRadius: BorderRadius.circular(2),
                     ),
                   );
                }),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon, 
    required Color color, 
    required Color iconColor, 
    required String title, 
    required String subtitle,
    bool isLink = false,
    Widget? trailing
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: isLink ? const Color(0xFF448AFF) : Colors.black87
                  )
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: const Color(0xFF448AFF), width: 2) : null,
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(url),
      ),
    );
  }
}
