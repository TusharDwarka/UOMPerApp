import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import 'onboarding_screen.dart';

class EndSemesterCelebrationScreen extends StatefulWidget {
  const EndSemesterCelebrationScreen({super.key});

  @override
  State<EndSemesterCelebrationScreen> createState() => _EndSemesterCelebrationScreenState();
}

class _EndSemesterCelebrationScreenState extends State<EndSemesterCelebrationScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Play confetti immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });

    // Reset app state and transition after a few seconds
    _transitionToOnboarding();
  }

  Future<void> _transitionToOnboarding() async {
    // Wait for the user to enjoy the confetti
    await Future.delayed(const Duration(seconds: 4));
    
    if (!mounted) return;
    
    // Reset the backend
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    await provider.resetForNewSetup();

    if (!mounted) return;
    
    // Go back to onboarding
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // Center message
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration_rounded, color: Colors.green, size: 80),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Congratulations!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You've successfully finished this semester. Your modules and grades have been archived.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(color: Colors.green),
                  const SizedBox(height: 16),
                  Text("Preparing for the next semester...", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ),
          
          // Confetti emitter at the top center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14159 / 2, // Straight down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }
}
