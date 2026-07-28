import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import 'tracker_card.dart';

class TrackerModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color color;

  const TrackerModuleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color = TrackerColors.communicationBlue,
  });

  @override
  Widget build(BuildContext context) => TrackerCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: TrackerColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
