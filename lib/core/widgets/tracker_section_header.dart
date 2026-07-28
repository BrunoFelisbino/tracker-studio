import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_radius.dart';
import '../design/tracker_spacing.dart';
import '../design/tracker_text_styles.dart';

class TrackerSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData? icon;
  final Widget? trailing;
  final bool compact;

  const TrackerSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: compact
            ? const EdgeInsets.only(bottom: TrackerSpacing.sm)
            : const EdgeInsets.only(bottom: TrackerSpacing.md),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TrackerColors.communicationBlue.withValues(alpha: 0.08),
                  borderRadius: TrackerRadius.small,
                ),
                child: Icon(icon, size: 18, color: TrackerColors.communicationBlue),
              ),
              const SizedBox(width: TrackerSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TrackerTextStyles.label.copyWith(
                      color: TrackerColors.communicationBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (!compact && (subtitle != null || eyebrow != null)) ...[
                    const SizedBox(height: 2),
                    Text(
                      (eyebrow ?? subtitle)!,
                      style: TrackerTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
