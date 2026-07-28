import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'tracker_status_pill.dart';

class LocalModeBadge extends ConsumerWidget {
  const LocalModeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authEnabledProvider)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: TrackerStatusPill(
        key: Key('local-mode-badge'),
        label: 'Modo local',
        icon: Icons.developer_mode_outlined,
        tone: TrackerStatusTone.attention,
      ),
    );
  }
}
