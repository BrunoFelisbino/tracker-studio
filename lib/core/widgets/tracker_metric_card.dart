import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import 'tracker_card.dart';

class TrackerMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const TrackerMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = TrackerColors.communicationBlue,
  });

  @override
  Widget build(BuildContext context) => TrackerCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: TrackerColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          )),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
