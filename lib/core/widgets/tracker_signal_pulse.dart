import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';

class TrackerSignalPulse extends StatelessWidget {
  final Color color;
  final double size;

  const TrackerSignalPulse({
    super.key,
    this.color = TrackerColors.communicationBlue,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: TrackerSignalPulsePainter(color: color)),
      );
}

class TrackerSignalPulsePainter extends CustomPainter {
  final Color color;

  const TrackerSignalPulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var ring = 1; ring <= 3; ring++) {
      final radius = size.shortestSide * (0.11 + ring * 0.1);
      paint
        ..strokeWidth = ring == 1 ? 1.6 : 1
        ..color = color.withValues(alpha: 0.8 - ring * 0.17);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.78,
        math.pi * 0.56,
        false,
        paint,
      );
    }

    canvas.drawCircle(
      center,
      size.shortestSide * 0.07,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant TrackerSignalPulsePainter oldDelegate) =>
      oldDelegate.color != color;
}
