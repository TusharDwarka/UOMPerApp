import 'package:flutter/material.dart';

class TimetableTab extends StatelessWidget {
  const TimetableTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeColumn(),
                    const SizedBox(width: 20),
                    Expanded(child: _buildEventColumn()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back_ios, size: 18)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text("+ Add task", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Today", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text("June 28th", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTab("This week", true),
              _buildTab("Next week", false),
              _buildTab("Month", false), // Cut off in image, guessing
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          if (isSelected)
            Container(width: 20, height: 3, color: const Color(0xFF0066FF))
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Column(
      children: [
        for (int i = 7; i <= 16; i++)
          Container(
            height: 100, // Grid height
            alignment: Alignment.topCenter,
            child: Text(
              "${i.toString().padLeft(2, '0')}:00",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildEventColumn() {
    return Stack(
      children: [
        // Grid lines (optional, kept subtle)
        // Events
        Column(
          children: [
             const SizedBox(height: 100), // Gap for 7-8
             _buildEventCard("How to grow...", const Color(0xFF69F0AE), 100), // 8-9
             const SizedBox(height: 0),
             _buildEventCard("Code Review...", const Color(0xFFFFD180), 80), // 9-10ish
             const SizedBox(height: 20),
             Stack(
               children: [
                 _buildEventCard("Grow your...", const Color(0xFFEA80FC), 120),
                 Positioned(
                   right: -10,
                   top: 20,
                   child: _buildFloatingBubble(),
                 )
               ]
             ),
             const SizedBox(height: 20),
             _buildEventCard("Instagram...", const Color(0xFFFF5252), 100, isStriped: true),
          ],
        )
      ],
    );
  }

  Widget _buildEventCard(String title, Color color, double height, {bool isStriped = false}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(isStriped ? 0.2 : 0.4), // Soft pastel
        borderRadius: BorderRadius.circular(24),
        // If striped, we would add a CustomPaint or DecorationImage, simplified here to plain
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(isStriped ? Icons.camera_alt : Icons.chat_bubble_outline, color: Colors.white, size: 20),
           const SizedBox(width: 10),
           Expanded(
             child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
           ),
           const Icon(Icons.more_horiz, color: Colors.white),
        ],
      )
    );
  }

  Widget _buildFloatingBubble() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 10, child: Icon(Icons.person, size: 12)),
          const SizedBox(height: 5),
          const Text("Don't forget to\ncall John...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
