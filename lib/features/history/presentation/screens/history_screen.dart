import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final items = session.recentCompletedServices;
    return TrackerScaffold(
      title: 'Histórico',
      subtitle: 'Sessões técnicas reais gravadas localmente.',
      body: items.isEmpty
          ? const Center(
              child: TrackerEmptyState(
                icon: Icons.history,
                title: 'Nenhuma sessão real',
                message: 'Conclua uma sessão para registrar histórico técnico.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${item.customerName} · ${item.plate}'),
                    subtitle: Text(item.resultSummary),
                    trailing: Text(item.status),
                  ),
                );
              },
            ),
    );
  }
}
