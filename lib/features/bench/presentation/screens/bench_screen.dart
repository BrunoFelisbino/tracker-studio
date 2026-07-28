import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_metric_card.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../sessions/presentation/tracker_studio/quick_test_wizard.dart';
import '../../../sessions/presentation/tracker_studio/tracker_session_state.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class BenchScreen extends ConsumerWidget {
  const BenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final notifier = ref.read(trackerSessionControllerProvider.notifier);

    return TrackerScaffold(
      title: 'Teste Rápido (Vapt-Vupt)',
      subtitle: 'Homologação automatizada e validação rápida em campo.',
      body: ListView(
        padding: const EdgeInsets.all(TrackerSpacing.lg),
        children: [
          // ── WIZARD AUTOMÁTICO VAPT-VUPT ────────────────────────────
          QuickTestWizardWidget(
            session: session,
            onTriggerLockTest: () {
              notifier.enable1();
            },
            onFinishWizard: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Laudo de Instalação concluído com sucesso!'),
                  backgroundColor: TrackerColors.technicalGreen,
                ),
              );
            },
          ),

          const SizedBox(height: TrackerSpacing.lg),

          // ── DETALHES DE CONEXÃO E DISPOSITIVO ───────────────────────
          Row(
            children: [
              Expanded(
                child: TrackerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TrackerSectionHeader(
                        title: 'Conexão',
                        icon: Icons.cable,
                        eyebrow: 'Status USB/Serial',
                      ),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(label: 'Porta', value: session.connection.commandPortName),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(label: 'Baud Rate', value: '${session.connection.baudRate}'),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(
                        label: 'Status',
                        value: session.connection.usbConnected ? 'Conectado' : 'Desconectado',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: TrackerSpacing.md),
              Expanded(
                child: TrackerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TrackerSectionHeader(
                        title: 'Dispositivo',
                        icon: Icons.info_outline,
                        eyebrow: 'Identidade identificada',
                      ),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(label: 'Modelo', value: session.device.model),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(label: 'Firmware', value: session.device.firmware),
                      const SizedBox(height: TrackerSpacing.xs),
                      _InfoRow(label: 'ESN', value: session.device.esn),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.lg),

          // ── EVIDÊNCIAS & RESULTADOS ──────────────────────────────────
          const TrackerSectionHeader(
            title: 'Resultado do Teste',
            icon: Icons.assessment,
            eyebrow: 'Resumo da última execução',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TrackerMetricCard(
                  label: 'Passaram',
                  value: '${session.approvedTests}',
                  icon: Icons.check_circle,
                  color: TrackerColors.technicalGreen,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: TrackerMetricCard(
                  label: 'Falharam',
                  value: '${session.failedTests}',
                  icon: Icons.cancel,
                  color: TrackerColors.failureRed,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: TrackerMetricCard(
                  label: 'Pendentes',
                  value: '${session.tests.where((t) => t.status == TestStatus.pending || t.status == TestStatus.running).length}',
                  icon: Icons.hourglass_empty,
                  color: TrackerColors.attentionAmber,
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.lg),

          const TrackerSectionHeader(
            title: 'Logs & Evidências',
            icon: Icons.folder_open,
            eyebrow: 'Histórico de eventos da sessão',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: session.logs.isEmpty
                ? const TrackerEmptyState(
                    icon: Icons.folder_open,
                    title: 'Nenhuma evidência',
                    message: 'As evidências técnicas aparecerão durante os testes.',
                  )
                : Column(
                    children: session.logs.reversed.take(6).map((log) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: TrackerSpacing.xs),
                        child: _InfoRow(
                          label: '${log.source} ${log.time}',
                          value: log.message,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: TrackerSpacing.xxl),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: TrackerColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(width: TrackerSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TrackerColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
