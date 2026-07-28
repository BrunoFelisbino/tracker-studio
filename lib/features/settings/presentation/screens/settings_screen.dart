import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../sessions/presentation/tracker_studio/serial_diagnostics.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final serial = session.serialDiagnostic;
    return TrackerScaffold(
      title: 'Configurações',
      subtitle: 'Parâmetros técnicos ativos e integrações do Studio.',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Serial',
            rows: {
              'Porta de comando': session.connection.commandPortName,
              'Porta de retorno': session.connection.readPortName,
              'Baud rate': '${session.connection.baudRate}',
              'Line ending': serial.selectedEnding.label,
              'DTR': serial.dtrEnabled ? 'Ligado' : 'Desligado',
              'RTS': serial.rtsEnabled ? 'Ligado' : 'Desligado',
            },
          ),
          _Section(
            title: 'Logging',
            rows: {
              'Entradas em memória': '${session.logs.length}',
              'Última resposta manual': session.manualCommand.lastResponse.isEmpty
                  ? 'Não executado'
                  : session.manualCommand.lastResponse,
            },
          ),
          _Section(
            title: 'Localização',
            rows: {
              'Serviço': session.serviceLocation.status,
              'LocaliTel': session.localitel.status,
              'Rastreador': session.localitel.hasValidCoordinates
                  ? 'Coordenadas recebidas'
                  : 'Posição indisponível',
            },
          ),
          const _Section(
            title: 'Segurança e exportação',
            rows: {
              'Comandos destrutivos': 'Exigem confirmação explícita',
              'Preset / APN / servidor': 'Readback obrigatório',
              'Exportação': 'Baseada apenas em sessões reais salvas localmente',
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(entry.key)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
