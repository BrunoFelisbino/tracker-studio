import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_metric_card.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../sessions/presentation/tracker_studio/suntech_command_family.dart';
import '../../../sessions/presentation/tracker_studio/tracker_session_state.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class ValidationsScreen extends ConsumerWidget {
  const ValidationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final tests =
        session.tests.where((test) => test.requiredCount > 0).toList();
    final connected = session.connection.usbConnected;
    final family = session.selectedSuntechFamily;
    final hasEsn = session.hasDeviceRead;
    return TrackerScaffold(
      title: 'Validações',
      subtitle: 'Estados do motor de execução',
      body: ListView(
        padding: const EdgeInsets.all(TrackerSpacing.lg),
        children: [
          const TrackerSectionHeader(
            title: 'Timeline de Execução',
            icon: Icons.timeline,
            eyebrow: 'Progresso do fluxo de validação',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: _ExecutionTimeline(stages: session.stages),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Execução Atual',
            icon: Icons.play_circle,
            eyebrow: 'Status da validação em andamento',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: tests.isEmpty
                ? const TrackerEmptyState(
                    icon: Icons.hourglass_empty,
                    title: 'Nenhuma execução ativa',
                    message:
                        'Inicie uma validação para acompanhar o progresso.',
                  )
                : Column(
                    children: tests.map((test) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(test.label),
                        subtitle: Text(test.detail),
                        trailing: Text(test.status.name),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Comandos Rapidos',
            icon: Icons.flash_on,
            eyebrow: 'Bloqueio e desbloqueio do dispositivo',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CommandButton(
                        label: 'Ativar Bloqueio',
                        subtitle: 'Enable1 - Saida 1 ON',
                        icon: Icons.lock_open,
                        color: Colors.orange,
                        enabled: connected &&
                            (family == SuntechCommandFamily.legacySt300St310 ||
                                (family ==
                                        SuntechCommandFamily
                                            .newGenSt8210St8310 &&
                                    hasEsn)),
                        onPressed: () => _sendEnable1(ref),
                      ),
                    ),
                    const SizedBox(width: TrackerSpacing.sm),
                    Expanded(
                      child: _CommandButton(
                        label: 'Desativar Bloqueio',
                        subtitle: 'Disable1 - Saida 1 OFF',
                        icon: Icons.lock,
                        color: Colors.blue,
                        enabled: connected &&
                            (family == SuntechCommandFamily.legacySt300St310 ||
                                (family ==
                                        SuntechCommandFamily
                                            .newGenSt8210St8310 &&
                                    hasEsn)),
                        onPressed: () => _sendDisable1(ref),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TrackerSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _CommandButton(
                        label: 'Status',
                        subtitle: 'StatusReq',
                        icon: Icons.info_outline,
                        color: TrackerColors.technicalGreen,
                        enabled:
                            connected && family != SuntechCommandFamily.unknown,
                        onPressed: () => _sendStatus(ref),
                      ),
                    ),
                    const SizedBox(width: TrackerSpacing.sm),
                    Expanded(
                      child: _CommandButton(
                        label: 'Preset',
                        subtitle: 'Leitura config',
                        icon: Icons.settings_outlined,
                        color: TrackerColors.communicationBlue,
                        enabled:
                            connected && family != SuntechCommandFamily.unknown,
                        onPressed: () => _sendPreset(ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Historico',
            icon: Icons.history,
            eyebrow: 'Validacoes anteriores',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: session.logs.isEmpty
                ? const TrackerEmptyState(
                    icon: Icons.history,
                    title: 'Nenhuma validação registrada',
                    message: 'O histórico aparecerá aqui após execuções.',
                  )
                : Column(
                    children: session.logs.reversed.take(8).map((log) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${log.source} · ${log.time}'),
                        subtitle: Text(log.message),
                      );
                    }).toList(),
                  ),
          ),
          if (session.behaviorChanges.isNotEmpty) ...[
            const SizedBox(height: TrackerSpacing.lg),
            const TrackerSectionHeader(
              title: 'Mudancas de Comportamento',
              icon: Icons.trending_up,
              eyebrow: 'Alteracoes detectadas automaticamente',
            ),
            const SizedBox(height: TrackerSpacing.sm),
            TrackerCard(
              child: Column(
                children:
                    session.behaviorChanges.reversed.take(10).map((change) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _changeIcon(change.field),
                      color: _changeColor(change.field),
                      size: 20,
                    ),
                    title: Text(
                      change.description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      change.timestamp,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TrackerColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Resumo',
            icon: Icons.assessment,
            eyebrow: 'Metricas acumuladas',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TrackerMetricCard(
                  label: 'Aprovadas',
                  value: '${session.approvedTests}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: TrackerMetricCard(
                  label: 'Reprovadas',
                  value: '${session.failedTests}',
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: TrackerMetricCard(
                  label: 'Pendentes',
                  value:
                      '${session.tests.where((test) => test.status == TestStatus.pending || test.status == TestStatus.running).length}',
                  icon: Icons.schedule,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.xxl),
        ],
      ),
    );
  }
}

class _ExecutionTimeline extends StatelessWidget {
  final List<SessionStage> stages;

  const _ExecutionTimeline({required this.stages});

  @override
  Widget build(BuildContext context) {
    final states = stages
        .map((stage) => _TimelineState(
              stage.label,
              stage.completed
                  ? Icons.check_circle
                  : stage.active
                      ? Icons.play_circle
                      : Icons.radio_button_unchecked,
              stage.completed || stage.active,
            ))
        .toList();

    return Column(
      children: List.generate(states.length * 2 - 1, (index) {
        if (index.isOdd) {
          return const Padding(
            padding: EdgeInsets.only(left: 11),
            child: SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 2,
                color: TrackerColors.line,
              ),
            ),
          );
        }
        final stateIndex = index ~/ 2;
        final state = states[stateIndex];
        final isLast = stateIndex == states.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  state.icon,
                  size: 24,
                  color: state.active
                      ? TrackerColors.communicationBlue
                      : TrackerColors.textSecondary,
                ),
                if (!isLast) const SizedBox(height: 4),
              ],
            ),
            const SizedBox(width: TrackerSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  state.label,
                  style: TextStyle(
                    color: state.active
                        ? TrackerColors.textPrimary
                        : TrackerColors.textSecondary,
                    fontWeight:
                        state.active ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineState {
  final String label;
  final IconData icon;
  final bool active;

  const _TimelineState(this.label, this.icon, this.active);
}

class _CommandButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;

  const _CommandButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color.withValues(alpha: 0.08) : TrackerColors.surface,
      borderRadius: BorderRadius.circular(TrackerSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(TrackerSpacing.sm),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(TrackerSpacing.md),
          child: Column(
            children: [
              Icon(
                icon,
                color: enabled ? color : TrackerColors.textSecondary,
                size: 28,
              ),
              const SizedBox(height: TrackerSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: enabled
                      ? TrackerColors.textPrimary
                      : TrackerColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled
                      ? TrackerColors.textSecondary
                      : TrackerColors.textSecondary.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _sendEnable1(WidgetRef ref) async {
  try {
    await ref.read(trackerSessionControllerProvider.notifier).enable1();
  } catch (e) {
    // Error logged by controller
  }
}

Future<void> _sendDisable1(WidgetRef ref) async {
  try {
    await ref.read(trackerSessionControllerProvider.notifier).disable1();
  } catch (e) {
    // Error logged by controller
  }
}

Future<void> _sendStatus(WidgetRef ref) async {
  try {
    await ref.read(trackerSessionControllerProvider.notifier).readStatus();
  } catch (e) {
    // Error logged by controller
  }
}

Future<void> _sendPreset(WidgetRef ref) async {
  try {
    await ref.read(trackerSessionControllerProvider.notifier).readPreset();
  } catch (e) {
    // Error logged by controller
  }
}

IconData _changeIcon(String field) {
  switch (field) {
    case 'ignicao':
      return Icons.power;
    case 'saida':
      return Icons.output;
    case 'gprs':
      return Icons.signal_cellular_alt;
    default:
      return Icons.change_circle;
  }
}

Color _changeColor(String field) {
  switch (field) {
    case 'ignicao':
      return Colors.orange;
    case 'saida':
      return Colors.blue;
    case 'gprs':
      return TrackerColors.communicationBlue;
    default:
      return TrackerColors.textSecondary;
  }
}
