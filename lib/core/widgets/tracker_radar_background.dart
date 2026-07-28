import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';

class TrackerRadarBackground extends StatelessWidget {
  final Widget child;

  const TrackerRadarBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: TrackerColors.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
                child: CustomPaint(painter: TrackerRadarPainter())),
            child,
          ],
        ),
      );
}

class TrackerRadarPainter extends CustomPainter {
  const TrackerRadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = TrackerColors.communicationBlue.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    const gridStep = 32.0;
    for (var x = 0.0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final center = Offset(size.width * 0.82, size.height * 0.13);
    final radius = math.min(size.width, size.height) * 0.3;
    final radarPaint = Paint()
      ..color = TrackerColors.communicationBlue.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(center, radius * ring / 3, radarPaint);
    }
    canvas.drawLine(
      center - Offset(radius, 0),
      center + Offset(radius, 0),
      radarPaint,
    );
    canvas.drawLine(
      center - Offset(0, radius),
      center + Offset(0, radius),
      radarPaint,
    );

    final telemetryPaint = Paint()
      ..color = TrackerColors.technicalGreen.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..moveTo(0, size.height * 0.82);
    final baseline = size.height * 0.82;
    for (var x = 0.0; x <= size.width; x += 12) {
      final pulse = x % 72 == 0 ? -8.0 : 0.0;
      path.lineTo(x, baseline + pulse);
    }
    canvas.drawPath(path, telemetryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
