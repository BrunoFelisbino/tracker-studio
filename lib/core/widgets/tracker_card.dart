import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_radius.dart';
import '../design/tracker_shadows.dart';
import '../design/tracker_spacing.dart';

enum TrackerCardVariant { surface, elevated, dark, ghost }

class TrackerCard extends StatelessWidget {
  final Widget child;
  final TrackerCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isSelected;

  const TrackerCard({
    super.key,
    required this.child,
    this.variant = TrackerCardVariant.surface,
    this.padding,
    this.margin,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? TrackerSpacing.cardPadding;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: _backgroundColor,
        borderRadius: TrackerRadius.large,
        child: InkWell(
          onTap: onTap,
          borderRadius: TrackerRadius.large,
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              borderRadius: TrackerRadius.large,
              border: _border,
              boxShadow: _shadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor => switch (variant) {
        TrackerCardVariant.surface => TrackerColors.surface,
        TrackerCardVariant.elevated => TrackerColors.backgroundElevated,
        TrackerCardVariant.dark => TrackerColors.navy800,
        TrackerCardVariant.ghost => Colors.transparent,
      };

  Border? get _border => switch (variant) {
        TrackerCardVariant.surface => Border.all(
            color: isSelected
                ? TrackerColors.communicationBlue.withValues(alpha: 0.4)
                : TrackerColors.lineSubtle,
          ),
        TrackerCardVariant.elevated => Border.all(
            color: isSelected
                ? TrackerColors.communicationBlue.withValues(alpha: 0.4)
                : TrackerColors.line,
          ),
        TrackerCardVariant.dark => Border.all(
            color: TrackerColors.navy600.withValues(alpha: 0.5),
          ),
        TrackerCardVariant.ghost => null,
      };

  List<BoxShadow> get _shadow => switch (variant) {
        TrackerCardVariant.surface => TrackerShadows.soft,
        TrackerCardVariant.elevated => TrackerShadows.medium,
        TrackerCardVariant.dark => TrackerShadows.raised,
        TrackerCardVariant.ghost => TrackerShadows.none,
      };
}
