import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Full-screen confetti moment (module finished, semester finished).
/// Runs [work] while the confetti plays, then closes itself.
class CelebrationScreen extends StatefulWidget {
  final String emoji;
  final String title;
  final String message;
  final String? footer;
  final Future<void> Function()? work;
  final Duration showFor;

  const CelebrationScreen({
    super.key,
    this.emoji = '🎉',
    required this.title,
    required this.message,
    this.footer,
    this.work,
    this.showFor = const Duration(seconds: 4),
  });

  /// Pushes the screen with a fade and resolves when it has closed.
  static Future<void> show(
    BuildContext context, {
    String emoji = '🎉',
    required String title,
    required String message,
    String? footer,
    Future<void> Function()? work,
    Duration showFor = const Duration(seconds: 4),
  }) {
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) =>
          CelebrationScreen(emoji: emoji, title: title, message: message, footer: footer, work: work, showFor: showFor),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> {
  late final ConfettiController _left = ConfettiController(duration: const Duration(seconds: 3));
  late final ConfettiController _right = ConfettiController(duration: const Duration(seconds: 3));
  late final ConfettiController _top = ConfettiController(duration: const Duration(seconds: 3));
  bool _done = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _left.play();
      _right.play();
      _top.play();
    });
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    try {
      await widget.work?.call();
    } catch (e) {
      debugPrint('Celebration work failed: $e');
    }
    final left = widget.showFor - DateTime.now().difference(started);
    if (left > Duration.zero) await Future.delayed(left);
    if (!mounted) return;
    setState(() => _done = true);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    _top.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const colors = [AppColors.accent, Colors.lightBlueAccent, Colors.pink, Colors.orange, Colors.purple, Color(0xFF00C853)];
    return PopScope(
      canPop: _done,
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (_, s, child) => Transform.scale(scale: s, child: child),
                          child: Container(
                            width: 120,
                            height: 120,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, boxShadow: p.softShadow),
                            child: Text(widget.emoji, style: const TextStyle(fontSize: 60)),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: p.textPrimary)),
                        const SizedBox(height: 12),
                        Text(widget.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.45, color: p.textSecondary)),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _done
                              ? InkPillButton(key: const ValueKey('go'), label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: _close)
                              : SizedBox(
                                  key: const ValueKey('wait'),
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent),
                                ),
                        ),
                        if (widget.footer != null) ...[
                          const SizedBox(height: 14),
                          Text(widget.footer!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _top,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.06,
                numberOfParticles: 30,
                maxBlastForce: 6,
                minBlastForce: 2,
                gravity: 0.2,
                colors: colors,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ConfettiWidget(
                confettiController: _left,
                blastDirection: -math.pi / 4,
                emissionFrequency: 0.04,
                numberOfParticles: 18,
                maxBlastForce: 30,
                minBlastForce: 12,
                gravity: 0.25,
                colors: colors,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ConfettiWidget(
                confettiController: _right,
                blastDirection: -3 * math.pi / 4,
                emissionFrequency: 0.04,
                numberOfParticles: 18,
                maxBlastForce: 30,
                minBlastForce: 12,
                gravity: 0.25,
                colors: colors,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
