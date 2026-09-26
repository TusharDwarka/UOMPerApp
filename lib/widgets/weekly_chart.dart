import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The dark "Weekly Productivity" card from the design references: white
/// pill bars per weekday with a gradient trend line across them.
class WeeklyBarsChart extends StatelessWidget {
  final List<int> values; // Monday-first, 7 entries (minutes)
  final int todayIndex;
  final double height;

  const WeeklyBarsChart({super.key, required this.values, required this.todayIndex, this.height = 190});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final maxV = math.max(values.fold<int>(0, math.max), 30);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF050506) : const Color(0xFF111318),
        borderRadius: BorderRadius.circular(32),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final barAreaH = c.maxHeight;
        final slot = c.maxWidth / 7;
        final barW = math.min(slot - 6, 44.0);
        const minBar = 44.0; // room for the day label

        double barHeight(int v) => minBar + (barAreaH - minBar) * (v / maxV).clamp(0.0, 1.0);

        final tops = [for (var i = 0; i < 7; i++) Offset(slot * i + slot / 2, barAreaH - barHeight(values[i]))];

        return Stack(
          children: [
            // Fill the card so bars stand on the bottom edge (a bare Row
            // shrank to the tallest bar and floated in the middle).
            Positioned.fill(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: slot,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _Bar(
                        width: barW,
                        height: barHeight(values[i]),
                        label: _days[i],
                        empty: values[i] == 0,
                        isToday: i == todayIndex,
                        future: i > todayIndex,
                      ),
                    ),
                  ),
              ],
            ),
            ),
            if (values.any((v) => v > 0))
              IgnorePointer(child: CustomPaint(size: Size(c.maxWidth, barAreaH), painter: _TrendPainter(tops, todayIndex)))
            else
              const Positioned(
                left: 12,
                top: 8,
                right: 12,
                child: Text('Start a focus session to fill your week',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
          ],
        );
      }),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final bool empty;
  final bool isToday;
  final bool future;

  const _Bar({required this.width, required this.height, required this.label, required this.empty, required this.isToday, required this.future});

  @override
  Widget build(BuildContext context) {
    final dashed = empty && (isToday || future);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: dashed ? _DashedPillPainter() : null,
        child: Container(
          decoration: dashed
              ? null
              : BoxDecoration(
                  color: isToday ? AppColors.accent : Colors.white,
                  borderRadius: BorderRadius.circular(width),
                ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(
                  color: dashed ? Colors.white70 : (isToday ? Colors.white : Colors.black),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                )),
          ),
        ),
      ),
    );
  }
}

class _DashedPillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width / 2));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrendPainter extends CustomPainter {
  final List<Offset> points;
  final int todayIndex;
  _TrendPainter(this.points, this.todayIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = points.take(todayIndex + 1).toList();
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy + 14);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1].translate(0, 14);
      final b = pts[i].translate(0, 14);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final paint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF80D8FF), Color(0xFF2962FF), Color(0xFF7C4DFF)])
          .createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.points != points || old.todayIndex != todayIndex;
}
