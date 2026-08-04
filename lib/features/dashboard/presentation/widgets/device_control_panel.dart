import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_shadows.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class DeviceControlPanel extends ConsumerWidget {
  const DeviceControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final connected = session.connection.usbConnected;

    return Container(
      decoration: BoxDecoration(
        color: TrackerColors.surface,
        borderRadius: TrackerRadius.large,
        border: Border.all(color: TrackerColors.lineSubtle),
        boxShadow: TrackerShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, connected),
          const Divider(height: 1),
          if (!connected)
            _buildDisconnectedState()
          else
            _buildConnectedState(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool connected) {
    return Padding(
      padding: TrackerSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TrackerColors.communicationBlue.withValues(alpha: 0.08),
              borderRadius: TrackerRadius.small,
            ),
            child: const Icon(
              Icons.settings_input_component,
              size: 20,
              color: TrackerColors.communicationBlue,
            ),
          ),
          const SizedBox(width: TrackerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Controle do Equipamento',
                  style: TrackerTextStyles.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? 'Equipamento conectado e pronto'
                      : 'Nenhum equipamento conectado',
                  style: TrackerTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: connected ? 'CONECTADO' : 'DESCONECTADO',
            color: connected
                ? TrackerColors.technicalGreen
                : TrackerColors.failureRed,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: TrackerColors.surfaceMuted,
                borderRadius: TrackerRadius.pill,
              ),
              child: const Icon(
                Icons.usb_off_rounded,
                size: 32,
                color: TrackerColors.textMuted,
              ),
            ),
            const SizedBox(height: TrackerSpacing.md),
            Text(
              'Conecte um equipamento via USB',
              style: TrackerTextStyles.cardTitle.copyWith(
                color: TrackerColors.textSecondary,
              ),
            ),
            const SizedBox(height: TrackerSpacing.xs),
            Text(
              'O painel de controle ficará disponível\napós a conexão com o dispositivo.',
              style: TrackerTextStyles.body.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedState(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: TrackerSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildControlSection(
            context: context,
            title: 'Saídas',
            icon: Icons.toggle_on_rounded,
            children: [
              _ControlButton(
                label: 'Ativar Saída 1',
                subtitle: 'Bloqueio',
                icon: Icons.lock_open_rounded,
                color: TrackerColors.technicalGreen,
                onPressed: () => ref
                    .read(trackerSessionControllerProvider.notifier)
                    .enable1(),
              ),
              _ControlButton(
                label: 'Desativar Saída 1',
                subtitle: 'Desbloqueio',
                icon: Icons.lock_rounded,
                color: TrackerColors.failureRed,
                onPressed: () => ref
                    .read(trackerSessionControllerProvider.notifier)
                    .disable1(),
              ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.lg),
          _buildControlSection(
            context: context,
            title: 'Leituras',
            icon: Icons.quiz_rounded,
            children: [
              _ControlButton(
                label: 'Ler Status',
                subtitle: 'StatusReq',
                icon: Icons.info_outline_rounded,
                color: TrackerColors.communicationBlue,
                onPressed: () => ref
                    .read(trackerSessionControllerProvider.notifier)
                    .readStatus(),
              ),
              _ControlButton(
                label: 'Ler Preset',
                subtitle: 'Configuração',
                icon: Icons.settings_rounded,
                color: TrackerColors.communicationBlue,
                onPressed: () => ref
                    .read(trackerSessionControllerProvider.notifier)
                    .readPreset(),
              ),
              _ControlButton(
                label: 'Ler Dispositivo',
                subtitle: 'Completo',
                icon: Icons.devices_rounded,
                color: TrackerColors.attentionAmber,
                onPressed: () => ref
                    .read(trackerSessionControllerProvider.notifier)
                    .readFullDevice(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: TrackerColors.textMuted),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TrackerTextStyles.label.copyWith(
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: TrackerSpacing.sm),
        ...children,
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TrackerSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: TrackerRadius.medium,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: TrackerColors.background,
              borderRadius: TrackerRadius.medium,
              border: Border.all(
                color: onPressed != null
                    ? color.withValues(alpha: 0.2)
                    : TrackerColors.lineSubtle,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: onPressed != null
                        ? color.withValues(alpha: 0.1)
                        : TrackerColors.surfaceMuted,
                    borderRadius: TrackerRadius.small,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: onPressed != null ? color : TrackerColors.textMuted,
                  ),
                ),
                const SizedBox(width: TrackerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TrackerTextStyles.cardTitle.copyWith(
                          fontSize: 14,
                          color: onPressed != null
                              ? TrackerColors.textPrimary
                              : TrackerColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TrackerTextStyles.body.copyWith(
                          fontSize: 12,
                          color: TrackerColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onPressed != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: color.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: TrackerRadius.pill,
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
