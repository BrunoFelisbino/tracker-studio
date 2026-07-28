import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_shadows.dart';
import '../design/tracker_spacing.dart';
import '../design/tracker_text_styles.dart';

enum TrackerScaffoldHeaderStyle { flat, gradient }

class TrackerScaffoldHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final TrackerScaffoldHeaderStyle style;

  const TrackerScaffoldHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.style = TrackerScaffoldHeaderStyle.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isGradient = style == TrackerScaffoldHeaderStyle.gradient;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        TrackerSpacing.lg,
        TrackerSpacing.lg,
        TrackerSpacing.lg,
        TrackerSpacing.md,
      ),
      decoration: isGradient
          ? const BoxDecoration(
              gradient: TrackerColors.gradientHeader,
              boxShadow: TrackerShadows.medium,
            )
          : const BoxDecoration(
              color: TrackerColors.surface,
              border: Border(
                bottom: BorderSide(color: TrackerColors.lineSubtle),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TrackerTextStyles.sectionTitle.copyWith(
                    color: isGradient ? Colors.white : TrackerColors.textPrimary,
                    fontSize: 22,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TrackerTextStyles.body.copyWith(
                      color: isGradient
                          ? const Color(0xFF94A3B8)
                          : TrackerColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
