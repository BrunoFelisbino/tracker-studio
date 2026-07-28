import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_controller.dart';
import 'bootstrap_models.dart';

class BootstrapDiagnosticsScreen extends ConsumerWidget {
  const BootstrapDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Diagnostico disponivel apenas em debug.')),
      );
    }
    final state = ref.watch(bootstrapProvider).state;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico do bootstrap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _value('Estado', state.status.name),
          _value(
              'Versao',
              const String.fromEnvironment(
                'APP_VERSION',
                defaultValue: '0.1.0+1',
              )),
          _value('Plataforma', defaultTargetPlatform.name),
          _value('Catalogo', _status(state, BootstrapStep.suntechCatalog)),
          _value('Banco', _status(state, BootstrapStep.localDatabase)),
          _value('API', _status(state, BootstrapStep.api)),
          _value('USB', state.usbStatus.name),
          if (state.error != null) _value('Ultima excecao', state.error!),
          const Divider(height: 32),
          Text('Etapas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final result in state.steps)
            Card(
              child: ListTile(
                title: Text(result.step.label),
                subtitle: Text([
                  result.status.name,
                  if (result.duration != null)
                    '${result.duration!.inMilliseconds} ms',
                  if (result.error != null) result.error!,
                ].join(' | ')),
                trailing: Icon(_icon(result.status)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _value(String label, String value) => ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(value),
      );

  String _status(BootstrapState state, BootstrapStep step) {
    for (final result in state.steps) {
      if (result.step == step) return result.status.name;
    }
    return 'pending';
  }

  IconData _icon(BootstrapStepStatus status) => switch (status) {
        BootstrapStepStatus.success => Icons.check_circle_outline,
        BootstrapStepStatus.failed ||
        BootstrapStepStatus.timedOut =>
          Icons.error_outline,
        BootstrapStepStatus.skipped => Icons.remove_circle_outline,
        BootstrapStepStatus.running => Icons.pending,
        BootstrapStepStatus.pending => Icons.radio_button_unchecked,
      };
}
