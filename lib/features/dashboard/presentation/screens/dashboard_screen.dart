import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_shadows.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import '../../../sessions/presentation/tracker_studio/suntech_command_family.dart';
import 'modals/dashboard_modals.dart';
import '../widgets/telemetry_matrix_card.dart';
import '../../../sessions/presentation/tracker_studio/report_generator.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _executedCommands = {};

  String _output1Code(String mask, String model) {
    if (mask == '-' || mask.isEmpty) return '--';
    final normalized = mask.trim();
    if (normalized.length < 2) return '--';

    String bit;
    if (model.startsWith('ST82')) {
      // No ST8210 a saida 1 costuma ser o ultimo bit da string
      bit = normalized[normalized.length - 1];
    } else {
      // Nas demais famílias (ST310, ST430, ST8300, etc.), a máscara de saída
      // geralmente mapeia a saída 1 para o primeiro bit (índice 0).
      bit = normalized[0];
    }

    return bit == '1'
        ? '01'
        : bit == '0'
            ? '00'
            : '--';
  }

  String _output1State(String mask, String model) {
    final code = _output1Code(mask, model);
    if (code == '01') return 'Ativa';
    if (code == '00') return 'Desativada';
    return 'Indefinida';
  }

  Future<void> _runQuickCommand(String label, String command) async {
    final notifier = ref.read(trackerSessionControllerProvider.notifier);
    try {
      await notifier.sendManualCommand(command);
      setState(() {
        _executedCommands.add(label);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar $label: $e')),
      );
    }
  }

  Future<void> _runBlockCommand({
    required String label,
    required Future<void> Function() action,
    required Future<void> Function() verify,
  }) async {
    try {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await verify();
      setState(() {
        _executedCommands.add(label);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao executar $label: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final connected = session.connection.usbConnected;
    final esn = session.device.esn;
    final model = session.device.model;
    final satCount = session.diagnostics
            .where((d) => d.title == 'GPS')
            .map((d) => d.values['Satelites'])
            .firstOrNull ??
        '0';
    final gpsFix = session.diagnostics
            .where((d) => d.title == 'GPS')
            .map((d) => d.values['Fix'])
            .firstOrNull ??
        'Aguardando';
    final mainVolt = session.diagnostics
            .where((d) => d.title == 'Alimentacao')
            .map((d) => d.values['Principal'])
            .firstOrNull ??
        '-';
    final backupVolt = session.diagnostics
            .where((d) => d.title == 'Alimentacao')
            .map((d) => d.values['Backup'])
            .firstOrNull ??
        '-';
    final gprsState = session.connection.gprsOnline ? 'Online' : 'Offline';
    final localitel = session.localitel;
    final outputMask = session.diagnostics
            .where((d) => d.title == 'I/O')
            .map((d) => d.values['Saida'])
            .firstOrNull ??
        '-';
    final inputMask = session.diagnostics
            .where((d) => d.title == 'I/O')
            .map((d) => d.values['Entrada'])
            .firstOrNull ??
        '-';
    final ignitionState = session.diagnostics
            .where((d) => d.title == 'I/O')
            .map((d) => d.values['Ignicao'])
            .firstOrNull ??
        'Desconhecido';
    final output1State = _output1State(outputMask, model);
    final output1Code = _output1Code(outputMask, model);
    final manualCommand = session.manualCommand;
    final lastResponse = manualCommand.lastResponse.trim();
    final lastCommand = manualCommand.lastCommand.trim();
    final responseAccepted = lastResponse.toUpperCase().contains('ACK') ||
        lastResponse.toUpperCase() == 'OK' ||
        lastResponse.toUpperCase().startsWith('RES;') ||
        lastResponse.toUpperCase().startsWith('ST300');
    final responseRejected = lastResponse.toUpperCase().contains('ERR');
    final responseColor = manualCommand.waitingResponse
        ? TrackerColors.attentionAmber
        : responseRejected
            ? TrackerColors.failureRed
            : responseAccepted
                ? TrackerColors.technicalGreen
                : TrackerColors.textMuted;
    final responseTitle = manualCommand.waitingResponse
        ? 'Aguardando resposta...'
        : lastResponse.isEmpty
            ? 'Nenhum retorno recebido'
            : responseRejected
                ? 'Comando rejeitado'
                : responseAccepted
                    ? 'Comando aceito'
                    : 'Retorno recebido';
    return TrackerScaffold(
      title: 'Tracker Studio',
      subtitle: 'Painel de campo · Telemetria e comandos',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TrackerSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionBanner(connected, model, esn, session),
            const SizedBox(height: TrackerSpacing.lg),
            _buildTelemetrySection(
              satCount: satCount,
              gpsFix: gpsFix,
              gprsState: gprsState,
              mainVolt: mainVolt,
              backupVolt: backupVolt,
              output1State: output1State,
              output1Code: output1Code,
              inputMask: inputMask,
              ignitionState: ignitionState,
              localitel: localitel,
              connected: connected,
              session: session,
            ),
            const SizedBox(height: TrackerSpacing.xl),
            _buildQuickCommandsSection(connected, esn, session),
            const SizedBox(height: TrackerSpacing.xl),
            _buildResponseSection(
              responseTitle: responseTitle,
              responseColor: responseColor,
              lastCommand: lastCommand,
              lastResponse: lastResponse,
              manualCommand: manualCommand,
            ),
            const SizedBox(height: TrackerSpacing.xl),
            // DeviceControlPanel removed
            // const SizedBox(height: TrackerSpacing.xl),
            const SizedBox(height: TrackerSpacing.xl),
            _buildToolsSection(context),
            const SizedBox(height: TrackerSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(
    bool connected,
    String model,
    String esn,
    dynamic session,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Future.microtask(() => showIdentityModal(context, session)),
        borderRadius: TrackerRadius.large,
        child: Container(
          padding: const EdgeInsets.all(TrackerSpacing.md),
          decoration: BoxDecoration(
            color: connected
                ? TrackerColors.technicalGreen.withValues(alpha: 0.06)
                : TrackerColors.surfaceMuted,
            borderRadius: TrackerRadius.large,
            border: Border.all(
              color: connected
                  ? TrackerColors.technicalGreen.withValues(alpha: 0.2)
                  : TrackerColors.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: connected
                      ? TrackerColors.technicalGreen.withValues(alpha: 0.1)
                      : TrackerColors.failureRed.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.small,
                ),
                child: Icon(
                  connected ? Icons.usb_rounded : Icons.usb_off_rounded,
                  color: connected
                      ? TrackerColors.technicalGreen
                      : TrackerColors.failureRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: TrackerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? '$model · $esn'
                          : 'Nenhum dispositivo conectado',
                      style: TrackerTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Porta: ${session.connection.commandPortName} · ${session.connection.baudRate} baud'
                          : 'Acesse Dispositivos para selecionar a porta',
                      style: TrackerTextStyles.body.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_input_component_rounded),
                onPressed: () => context.go('/devices'),
                tooltip: 'Gerenciar Portas USB',
                style: IconButton.styleFrom(
                  backgroundColor: TrackerColors.surfaceMuted,
                  shape: const RoundedRectangleBorder(
                    borderRadius: TrackerRadius.small,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetrySection({
    required String satCount,
    required String gpsFix,
    required String gprsState,
    required String mainVolt,
    required String backupVolt,
    required String output1State,
    required String output1Code,
    required String inputMask,
    required String ignitionState,
    required dynamic localitel,
    required bool connected,
    required dynamic session,
  }) {
    final isLockActive =
        output1State.toLowerCase().contains('ativ') || output1Code == '01';
    return TelemetryMatrixCard(
      satCount: satCount,
      gpsFix: gpsFix,
      gprsState: gprsState,
      mainVolt: mainVolt,
      backupVolt: backupVolt,
      output1State: output1State,
      output1Code: output1Code,
      inputMask: inputMask,
      ignitionState: ignitionState,
      localitel: localitel,
      connected: connected,
      session: session,
      onToggleLock: () {
        if (isLockActive) {
          _runBlockCommand(
            label: 'Desativar Bloqueio',
            action:
                ref.read(trackerSessionControllerProvider.notifier).disable1,
            verify:
                ref.read(trackerSessionControllerProvider.notifier).readStatus,
          );
        } else {
          _runBlockCommand(
            label: 'Ativar Bloqueio',
            action: ref.read(trackerSessionControllerProvider.notifier).enable1,
            verify:
                ref.read(trackerSessionControllerProvider.notifier).readStatus,
          );
        }
      },
    );
  }

  Widget _buildQuickCommandsSection(
      bool connected, String esn, dynamic session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrackerSectionHeader(
          title: 'Comandos Rápidos',
          eyebrow: 'Toque para executar comandos comuns',
          icon: Icons.bolt_rounded,
        ),
        Wrap(
          spacing: TrackerSpacing.sm,
          runSpacing: TrackerSpacing.sm,
          children: [
            _CommandChip(
              label: 'Ativar Saída 1',
              executed: _executedCommands.contains('Ativar Bloqueio'),
              color: TrackerColors.technicalGreen,
              icon: Icons.lock_open_rounded,
              onPressed: connected
                  ? () => _runBlockCommand(
                        label: 'Ativar Bloqueio',
                        action: ref
                            .read(trackerSessionControllerProvider.notifier)
                            .enable1,
                        verify: ref
                            .read(trackerSessionControllerProvider.notifier)
                            .readStatus,
                      )
                  : null,
            ),
            _CommandChip(
              label: 'Desativar Saída 1',
              executed: _executedCommands.contains('Desativar Bloqueio'),
              color: TrackerColors.failureRed,
              icon: Icons.lock_rounded,
              onPressed: connected
                  ? () => _runBlockCommand(
                        label: 'Desativar Bloqueio',
                        action: ref
                            .read(trackerSessionControllerProvider.notifier)
                            .disable1,
                        verify: ref
                            .read(trackerSessionControllerProvider.notifier)
                            .readStatus,
                      )
                  : null,
            ),
            _CommandChip(
              label: 'Ler Status',
              executed: _executedCommands.contains('Ler Status'),
              color: TrackerColors.communicationBlue,
              icon: Icons.info_outline_rounded,
              onPressed: connected
                  ? () => _runQuickCommand(
                        'Ler Status',
                        session.selectedSuntechFamily ==
                                SuntechCommandFamily.legacySt300St310
                            ? 'AT^ST300CMD;;02;StatusReq'
                            : 'AT^CMD;$esn;03;01',
                      )
                  : null,
            ),
            _CommandChip(
              label: 'Ler Preset',
              executed: _executedCommands.contains('Ler Preset'),
              color: TrackerColors.communicationBlue,
              icon: Icons.settings_rounded,
              onPressed: connected
                  ? () => _runQuickCommand(
                        'Ler Preset',
                        session.selectedSuntechFamily ==
                                SuntechCommandFamily.legacySt300St310
                            ? 'AT^ST300CMD;;02;Preset'
                            : 'AT^CMD;$esn;03;05',
                      )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: TrackerSpacing.sm),
        TrackerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Referência de Comandos',
                style: TrackerTextStyles.label.copyWith(
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              const _CommandReference(
                command: 'CMD;XXXX;04;01',
                description: 'Ativa Saída 1 (Bloqueio)',
              ),
              const SizedBox(height: 4),
              const _CommandReference(
                command: 'CMD;XXXX;04;02',
                description: 'Desativa Saída 1 (Desbloqueio)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponseSection({
    required String responseTitle,
    required Color responseColor,
    required String lastCommand,
    required String lastResponse,
    required dynamic manualCommand,
  }) {
    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: responseColor.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.small,
                ),
                child: Icon(Icons.terminal_rounded,
                    size: 18, color: responseColor),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              const Text('Visor de Retorno',
                  style: TrackerTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: TrackerSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TrackerSpacing.md),
            decoration: BoxDecoration(
              color: TrackerColors.background,
              borderRadius: TrackerRadius.medium,
              border: Border.all(
                color: responseColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: responseColor),
                    const SizedBox(width: 6),
                    Text(
                      responseTitle,
                      style: TrackerTextStyles.bodyStrong.copyWith(
                        color: responseColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TrackerSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: TrackerSpacing.sm),
                Text(
                  'Comando: ${lastCommand.isEmpty ? '—' : lastCommand}',
                  style: const TextStyle(
                    color: TrackerColors.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  manualCommand.waitingResponse
                      ? 'Aguardando resposta...'
                      : (lastResponse.isEmpty ? 'Sem retorno' : lastResponse),
                  style: TextStyle(
                    color: responseColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrackerSectionHeader(
          title: 'Ferramentas',
          eyebrow: 'Acesso rápido aos módulos do Studio',
          icon: Icons.grid_view_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: _ToolButton(
                label: 'Terminal',
                icon: Icons.code_rounded,
                color: TrackerColors.communicationBlue,
                onPressed: () => context.go('/lab'),
              ),
            ),
            const SizedBox(width: TrackerSpacing.sm),
            Expanded(
              child: _ToolButton(
                label: 'Catálogo',
                icon: Icons.list_alt_rounded,
                color: TrackerColors.technicalGreen,
                onPressed: () => context.go('/commands'),
              ),
            ),
            const SizedBox(width: TrackerSpacing.sm),
            Expanded(
              child: _ToolButton(
                label: 'SMS',
                icon: Icons.sms_rounded,
                color: TrackerColors.attentionAmber,
                onPressed: () => context.go('/sms'),
              ),
            ),
            const SizedBox(width: TrackerSpacing.sm),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final session = ref.watch(trackerSessionControllerProvider);
                  return _ToolButton(
                    label: 'Relatório',
                    icon: Icons.picture_as_pdf_rounded,
                    color: TrackerColors.primary,
                    onPressed: () =>
                        ReportGenerator.generateAndPrintSessionReport(session),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  }) : onTap = null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrackerColors.surface,
      borderRadius: TrackerRadius.large,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrackerRadius.large,
        child: Container(
          padding: TrackerSpacing.cardPadding,
          decoration: BoxDecoration(
            borderRadius: TrackerRadius.large,
            border: Border.all(color: TrackerColors.lineSubtle),
            boxShadow: TrackerShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: TrackerRadius.small,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: TrackerSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: TrackerTextStyles.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TrackerSpacing.sm),
              Text(
                value,
                style: TrackerTextStyles.telemetryLarge.copyWith(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TrackerTextStyles.body.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandChip extends StatelessWidget {
  final String label;
  final bool executed;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  const _CommandChip({
    required this.label,
    required this.executed,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = executed ? TrackerColors.technicalGreen : color;
    return Material(
      color: effectiveColor.withValues(alpha: executed ? 0.12 : 0.06),
      borderRadius: TrackerRadius.pill,
      child: InkWell(
        onTap: onPressed,
        borderRadius: TrackerRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: TrackerRadius.pill,
            border: Border.all(
              color: effectiveColor.withValues(alpha: executed ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                executed ? Icons.check_circle_rounded : icon,
                size: 16,
                color: effectiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandReference extends StatelessWidget {
  final String command;
  final String description;

  const _CommandReference({required this.command, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: const BoxDecoration(
            color: TrackerColors.navy800,
            borderRadius: TrackerRadius.small,
          ),
          child: Text(
            command,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: TrackerColors.technicalGreenLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TrackerTextStyles.body.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrackerColors.surface,
      borderRadius: TrackerRadius.large,
      child: InkWell(
        onTap: onPressed,
        borderRadius: TrackerRadius.large,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: TrackerRadius.large,
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: TrackerShadows.soft,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.pill,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TrackerTextStyles.cardTitle.copyWith(
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
