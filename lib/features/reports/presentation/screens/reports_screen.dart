import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final completed = session.recentCompletedServices;
    return TrackerScaffold(
      title: 'Relatórios',
      subtitle: 'Resumo técnico gerado a partir de sessões reais.',
      body: completed.isEmpty
          ? const Center(
              child: TrackerEmptyState(
                icon: Icons.description_outlined,
                title: 'Nenhum relatório real',
                message:
                    'Finalize sessões técnicas reais para gerar relatórios.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: completed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = completed[index];
                return Card(
                  child: ListTile(
                    title: Text(report.customerName),
                    subtitle: Text(
                      '${report.plate} · ${report.serviceType} · ${report.status}',
                    ),
                    trailing: Text(report.syncStatus),
                  ),
                );
              },
            ),
    );
  }
}
