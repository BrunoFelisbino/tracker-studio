import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tracker_colors.dart';
import '../../../core/design/tracker_radius.dart';
import '../../../core/design/tracker_spacing.dart';
import '../../../core/design/tracker_text_styles.dart';
import '../../../core/widgets/tracker_card.dart';
import '../../../core/widgets/tracker_empty_state.dart';
import '../../../core/widgets/tracker_scaffold.dart';
import '../../sessions/presentation/tracker_studio/service_map_preview.dart';
import '../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class TrackerMapScreen extends ConsumerWidget {
  const TrackerMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackerSessionControllerProvider);
    final service = session.serviceLocation;
    final tracker = session.localitel;
    final hasPosition = service.isValid || tracker.hasValidCoordinates;
    final isGprsOnline = session.connection.gprsOnline;
    final isCompact = MediaQuery.sizeOf(context).width < 850;

    final distanceMeters = calculateServiceDistanceMeters(
      serviceLatitude: service.latitude,
      serviceLongitude: service.longitude,
      trackerLatitude: tracker.latitude,
      trackerLongitude: tracker.longitude,
    );

    final isWithinTolerance = distanceMeters != null &&
        distanceMeters <= tracker.serviceToleranceMeters;

    return TrackerScaffold(
      title: 'Mapa Técnico',
      subtitle: 'Computador/técnico, rastreador e cobertura LocaliTel.',
      body: hasPosition
          ? Padding(
              padding: const EdgeInsets.all(TrackerSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── MAPA INTERATIVO DA METADE SUPERIOR ───────────────────────
                  Expanded(
                    flex: 5,
                    child: TrackerCard(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: TrackerRadius.medium,
                        child: ServiceMapPreview(
                          serviceLatitude: service.latitude,
                          serviceLongitude: service.longitude,
                          trackerLatitude: tracker.latitude,
                          trackerLongitude: tracker.longitude,
                          toleranceMeters: tracker.serviceToleranceMeters,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: TrackerSpacing.md),

                  // ── PAINEIS DE ANÁLISE DA METADE INFERIOR ────────────────────
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (isCompact) ...[
                            _buildLocaliTelCard(tracker),
                            const SizedBox(height: TrackerSpacing.sm),
                            _buildComparisonCard(service, tracker,
                                distanceMeters, isWithinTolerance),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLocaliTelCard(tracker)),
                                const SizedBox(width: TrackerSpacing.md),
                                Expanded(
                                    child: _buildComparisonCard(
                                        service,
                                        tracker,
                                        distanceMeters,
                                        isWithinTolerance)),
                              ],
                            ),
                          ],

                          const SizedBox(height: TrackerSpacing.sm),

                          // ── PAINEL 3: TELEMETRIA DO EQUIPAMENTO ──────────────
                          TrackerCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTile(
                                    'Equipamento / ESN',
                                    '${session.device.model} (${session.device.esn.isNotEmpty ? session.device.esn : "-"})',
                                    Icons.developer_board_rounded,
                                    TrackerColors.communicationBlue,
                                  ),
                                ),
                                Container(
                                    height: 30,
                                    width: 1,
                                    color: TrackerColors.lineSubtle),
                                Expanded(
                                  child: _buildTile(
                                    'Rede GPRS',
                                    isGprsOnline ? 'ONLINE' : 'PENDENTE',
                                    Icons.signal_cellular_alt_rounded,
                                    isGprsOnline
                                        ? TrackerColors.technicalGreen
                                        : TrackerColors.attentionAmber,
                                  ),
                                ),
                                Container(
                                    height: 30,
                                    width: 1,
                                    color: TrackerColors.lineSubtle),
                                Expanded(
                                  child: _buildTile(
                                    'Cartão SIM (ICCID)',
                                    session.device.sim.isNotEmpty
                                        ? session.device.sim
                                        : '-',
                                    Icons.sim_card_rounded,
                                    TrackerColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: TrackerEmptyState(
                icon: Icons.location_off_outlined,
                title: 'Posição indisponível',
                message:
                    'Capture a posição do computador/técnico e leia a posição do rastreador.',
              ),
            ),
    );
  }

  Widget _buildLocaliTelCard(dynamic tracker) {
    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cell_tower_rounded,
                size: 18,
                color: TrackerColors.communicationBlue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Análise de Cobertura LocaliTel',
                  style: TrackerTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tracker.hasValidCoordinates
                      ? TrackerColors.technicalGreen.withValues(alpha: 0.1)
                      : TrackerColors.surfaceMuted,
                  borderRadius: TrackerRadius.pill,
                ),
                child: Text(
                  tracker.hasValidCoordinates ? 'ATIVO' : 'SEM SINAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tracker.hasValidCoordinates
                        ? TrackerColors.technicalGreen
                        : TrackerColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: TrackerSpacing.sm),
          _buildInfoRow('Endereço', tracker.address),
          _buildInfoRow('Raio Estimado', '${tracker.radiusKm} km'),
          _buildInfoRow('Validação de Serviço',
              tracker.serviceCheck.toString().toUpperCase()),
          _buildInfoRow(
              'Status Integração', tracker.status.toString().toUpperCase()),
          _buildInfoRow('Resumo Cobertura', tracker.summary),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(dynamic service, dynamic tracker,
      double? distanceMeters, bool isWithinTolerance) {
    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pin_drop_rounded,
                size: 18,
                color: TrackerColors.technicalGreen,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comparativo de Coordenadas',
                  style: TrackerTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (distanceMeters != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isWithinTolerance
                        ? TrackerColors.technicalGreen.withValues(alpha: 0.1)
                        : TrackerColors.attentionAmber.withValues(alpha: 0.1),
                    borderRadius: TrackerRadius.pill,
                  ),
                  child: Text(
                    isWithinTolerance ? 'TOLERÂNCIA OK' : 'FORA DA ZONA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isWithinTolerance
                          ? TrackerColors.technicalGreen
                          : TrackerColors.attentionAmber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: TrackerSpacing.sm),
          _buildInfoRow(
            'Posição Técnico',
            service.isValid
                ? '${service.latitude.toStringAsFixed(5)}, ${service.longitude.toStringAsFixed(5)}'
                : 'Não capturada',
          ),
          _buildInfoRow(
            'Posição Rastreador',
            tracker.hasValidCoordinates
                ? '${tracker.latitude.toStringAsFixed(5)}, ${tracker.longitude.toStringAsFixed(5)}'
                : 'Aguardando GPS',
          ),
          _buildInfoRow(
            'Distância Relativa',
            distanceMeters != null
                ? '${distanceMeters.toStringAsFixed(0)} metros'
                : '-',
          ),
          _buildInfoRow(
            'Tolerância Máxima',
            '${tracker.serviceToleranceMeters} metros',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TrackerTextStyles.label),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TrackerTextStyles.bodyStrong.copyWith(fontSize: 12),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TrackerTextStyles.label,
                    overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: TrackerTextStyles.bodyStrong.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
