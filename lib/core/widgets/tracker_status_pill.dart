import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_radius.dart';
import '../design/tracker_spacing.dart';

enum TrackerStatusTone { neutral, ok, communication, attention, failure }

class TrackerStatusPill extends StatelessWidget {
  final String label;
  final TrackerStatusTone tone;
  final IconData? icon;

  const TrackerStatusPill({
    super.key,
    required this.label,
    this.tone = TrackerStatusTone.neutral,
    this.icon,
  });

  Color get _color => switch (tone) {
        TrackerStatusTone.ok => TrackerColors.technicalGreen,
        TrackerStatusTone.communication => TrackerColors.communicationBlue,
        TrackerStatusTone.attention => TrackerColors.attentionAmber,
        TrackerStatusTone.failure => TrackerColors.failureRed,
        TrackerStatusTone.neutral => TrackerColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TrackerSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.09),
          borderRadius: TrackerRadius.pill,
          border: Border.all(color: _color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: _color),
              const SizedBox(width: 5),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: _color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
}
