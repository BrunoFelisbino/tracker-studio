import 'package:flutter/material.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../sessions/presentation/tracker_studio/tracker_session_state.dart';
import '../screens/modals/dashboard_modals.dart';

class TelemetryMatrixCard extends StatelessWidget {
  final String satCount;
  final String gpsFix;
  final String gprsState;
  final String mainVolt;
  final String backupVolt;
  final String output1State;
  final String output1Code;
  final String inputMask;
  final String ignitionState;
  final dynamic localitel;
  final bool connected;
  final TrackerSessionState session;
  final VoidCallback? onToggleLock;
  final bool lockLoading;

  const TelemetryMatrixCard({
    super.key,
    required this.satCount,
    required this.gpsFix,
    required this.gprsState,
    required this.mainVolt,
    required this.backupVolt,
    required this.output1State,
    required this.output1Code,
    required this.inputMask,
    required this.ignitionState,
    required this.localitel,
    required this.connected,
    required this.session,
    this.onToggleLock,
    this.lockLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isIgnitionOn = ignitionState.toLowerCase().contains('ligada') || ignitionState == 'ON';
    final isGprsOnline = session.connection.gprsOnline;
    final isGpsOk = (int.tryParse(satCount) ?? 0) >= 4;
    final isLockActive = output1State.toLowerCase().contains('ativ') || output1Code == '01';
    final apn = session.configuration.desired['APN'] ?? session.configuration.original['APN'];

    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header da Matriz ───────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TrackerColors.communicationBlue.withValues(alpha: 0.08),
                  borderRadius: TrackerRadius.small,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: TrackerColors.communicationBlue,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              const Text('Matriz de Diagnóstico de Campo', style: TrackerTextStyles.cardTitle),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: connected
                      ? TrackerColors.technicalGreen.withValues(alpha: 0.1)
                      : TrackerColors.surfaceMuted,
                  borderRadius: TrackerRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                      size: 14,
                      color: connected ? TrackerColors.technicalGreen : TrackerColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connected ? 'Sinal Ativo' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: connected ? TrackerColors.technicalGreen : TrackerColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: TrackerSpacing.md),

          // ── Linha 1: Alimentação e Chave de Ignição ────────────
          Row(
            children: [
              Expanded(
                child: _MatrixTile(
                  title: 'Alimentação Principal',
                  value: mainVolt,
                  subtitle: 'Bateria Interna: $backupVolt',
                  icon: Icons.electric_bolt_rounded,
                  statusColor: TrackerColors.communicationBlue,
                  onTap: () => showPowerModal(context, session),
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: _MatrixTile(
                  title: 'Chave de Ignição',
                  value: ignitionState,
                  subtitle: 'Entradas (Mask): $inputMask',
                  icon: isIgnitionOn ? Icons.key_rounded : Icons.key_off_rounded,
                  statusColor: isIgnitionOn
                      ? TrackerColors.technicalGreen
                      : TrackerColors.textMuted,
                  badgeLabel: isIgnitionOn ? 'LIGADA' : 'DESLIGADA',
                  badgeColor: isIgnitionOn
                      ? TrackerColors.technicalGreen
                      : TrackerColors.textMuted,
                  onTap: () => showIgnitionModal(context, session),
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.sm),

          // ── Linha 2: Conectividade (GPRS e GPS) ────────────────
          Row(
            children: [
              Expanded(
                child: _MatrixTile(
                  title: 'Rede GPRS / APN',
                  value: gprsState,
                  subtitle: apn != null && apn.isNotEmpty
                      ? 'APN: $apn'
                      : 'Toque p/ APN',
                  icon: Icons.signal_cellular_alt_rounded,
                  statusColor: isGprsOnline
                      ? TrackerColors.technicalGreen
                      : TrackerColors.attentionAmber,
                  badgeLabel: isGprsOnline ? 'ONLINE' : 'PENDENTE',
                  badgeColor: isGprsOnline
                      ? TrackerColors.technicalGreen
                      : TrackerColors.attentionAmber,
                  onTap: () => showGprsModal(context, session, (newApn) {
                    // APN callback
                  }),
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              Expanded(
                child: _MatrixTile(
                  title: 'Posicionamento GPS',
                  value: '$satCount Satélites',
                  subtitle: 'Fix: $gpsFix',
                  icon: Icons.satellite_alt_rounded,
                  statusColor: isGpsOk
                      ? TrackerColors.technicalGreen
                      : TrackerColors.attentionAmber,
                  badgeLabel: isGpsOk ? 'FIX OK' : 'BUSCANDO',
                  badgeColor: isGpsOk
                      ? TrackerColors.technicalGreen
                      : TrackerColors.attentionAmber,
                  onTap: () => showGpsModal(context, session),
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.sm),

          // ── Linha 3: Atuação de Saída 1 (Bloqueio) ─────────────
          _MatrixActuationBar(
            outputState: output1State,
            outputCode: output1Code,
            isLockActive: isLockActive,
            connected: connected,
            onTapHistory: () => showOutputModal(
              context,
              session,
              onToggleLock ?? () {},
              onToggleLock ?? () {},
            ),
            onToggleLock: onToggleLock,
            lockLoading: lockLoading,
          ),
        ],
      ),
    );
  }
}

class _MatrixTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color statusColor;
  final String? badgeLabel;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _MatrixTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.statusColor,
    this.badgeLabel,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrackerRadius.medium,
        child: Container(
          padding: const EdgeInsets.all(TrackerSpacing.md),
          decoration: BoxDecoration(
            color: TrackerColors.background,
            borderRadius: TrackerRadius.medium,
            border: Border.all(color: TrackerColors.lineSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TrackerTextStyles.label.copyWith(
                        color: TrackerColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeLabel != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? statusColor).withValues(alpha: 0.1),
                        borderRadius: TrackerRadius.pill,
                      ),
                      child: Text(
                        badgeLabel!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: badgeColor ?? statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TrackerSpacing.xs),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TrackerColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TrackerTextStyles.body.copyWith(
                  color: TrackerColors.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixActuationBar extends StatelessWidget {
  final String outputState;
  final String outputCode;
  final bool isLockActive;
  final bool connected;
  final VoidCallback onTapHistory;
  final VoidCallback? onToggleLock;
  final bool lockLoading;

  const _MatrixActuationBar({
    required this.outputState,
    required this.outputCode,
    required this.isLockActive,
    required this.connected,
    required this.onTapHistory,
    this.onToggleLock,
    this.lockLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isLockActive
        ? TrackerColors.failureRed
        : TrackerColors.technicalGreen;
    final statusLabel = isLockActive ? 'BLOQUEADO (Corte Ativo)' : 'Desbloqueado (Inativo)';
    final actionLabel = isLockActive ? 'Desbloquear' : 'Bloquear';
    final buttonColor = isLockActive ? TrackerColors.technicalGreen : TrackerColors.failureRed;

    return Container(
      padding: const EdgeInsets.all(TrackerSpacing.sm),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: TrackerRadius.medium,
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapHistory,
                borderRadius: TrackerRadius.small,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isLockActive ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saída 1: $statusLabel',
                              style: TrackerTextStyles.bodyStrong.copyWith(
                                fontSize: 13,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'Readback: $outputState ($outputCode) · Histórico',
                              style: TrackerTextStyles.body.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: connected && !lockLoading ? onToggleLock : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: const RoundedRectangleBorder(
                borderRadius: TrackerRadius.small,
              ),
            ),
            icon: lockLoading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    isLockActive ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 14,
                  ),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
