import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../equipment_lab/core/equipment_lab_types.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

/// Card that shows monitored IOs / normalized fields from the connected device.
///
/// The user can select which fields to monitor (ignition, speed, position,
/// network, power, etc.) and see all observed IOs listed for real-time
/// identification — e.g. if the user toggles the parking brake, the IO that
/// changes can be renamed in-place.
class ResponseViewerCard extends ConsumerStatefulWidget {
  /// Keys that the user has chosen to monitor.
  final Set<String> monitoredKeys;

  /// Callback when the monitored key set changes.
  final ValueChanged<Set<String>> onMonitoredChanged;

  const ResponseViewerCard({
    super.key,
    required this.monitoredKeys,
    required this.onMonitoredChanged,
  });

  /// Builds equipment-specific field definitions based on manufacturer.
  static Map<String, List<(String key, String label, IconData icon)>>
      getAvailableFields(Manufacturer manufacturer) {
    final baseFields = <String, List<(String, String, IconData)>>{
      'vehicle': [
        ('ignition', 'Ignição', Icons.flash_on),
        ('speedKph', 'Velocidade', Icons.speed),
        ('movement', 'Movimento', Icons.directions_car),
        ('rpm', 'RPM', Icons.settings),
        ('fuelLevelPercentage', 'Nível de Combustível', Icons.local_gas_station),
        ('throttle', 'Acelerador', Icons.spa),
      ],
      'power': [
        ('externalVoltage', 'Alimentação', Icons.power),
        ('internalVoltage', 'Bateria Interna', Icons.battery_unknown),
        ('batteryPercent', 'Bateria %', Icons.battery_std),
        ('charging', 'Carregando', Icons.power),
      ],
      'network': [
        ('networkStatus', 'Status Rede', Icons.network_cell),
        ('signalLevel', 'Sinal (dBm)', Icons.signal_cellular_alt),
        ('operatorName', 'Operadora', Icons.business),
        ('technology', 'Tecnologia', Icons.wifi),
        ('roaming', 'Roaming', Icons.public),
      ],
      'io': [
        ('io_1', 'IO Digital 1', Icons.toggle_on),
        ('io_2', 'IO Digital 2', Icons.toggle_on),
        ('io_3', 'IO Digital 3', Icons.toggle_on),
      ],
    };

    // GPS fields vary by manufacturer
    switch (manufacturer) {
      case Manufacturer.teltonika:
        baseFields['position'] = [
          ('teltonika.gps.latitude', 'Latitude', Icons.place),
          ('teltonika.gps.longitude', 'Longitude', Icons.place),
          ('teltonika.gps.altitude', 'Altitude', Icons.height),
          ('teltonika.gps.speed', 'Velocidade GPS', Icons.speed),
          ('teltonika.gps.satellites', 'Satélites', Icons.satellite),
          ('teltonika.gps.hdop', 'HDOP', Icons.gps_fixed),
          ('teltonika.gps.fix', 'Fix GPS', Icons.gps_fixed),
        ];
        break;
      case Manufacturer.suntech:
        baseFields['position'] = [
          ('suntech.gps.latitude', 'Latitude', Icons.place),
          ('suntech.gps.longitude', 'Longitude', Icons.place),
          ('suntech.gps.altitude', 'Altitude', Icons.height),
          ('suntech.gps.speed', 'Velocidade GPS', Icons.speed),
          ('suntech.gps.satellites', 'Satélites', Icons.satellite),
          ('suntech.gps.hdop', 'HDOP', Icons.gps_fixed),
          ('suntech.gps.fix', 'Fix GPS', Icons.gps_fixed),
        ];
        break;
      default:
        baseFields['position'] = [
          ('latitude', 'Latitude', Icons.place),
          ('longitude', 'Longitude', Icons.place),
          ('altitude', 'Altitude', Icons.height),
          ('heading', 'Direção', Icons.navigation),
          ('satellites', 'Satélites', Icons.satellite),
          ('hdop', 'HDOP', Icons.gps_fixed),
          ('gpsFix', 'Fix GPS', Icons.gps_fixed),
        ];
    }

    return baseFields;
  }

  @override
  ConsumerState<ResponseViewerCard> createState() => _ResponseViewerCardState();
}

class _ResponseViewerCardState extends ConsumerState<ResponseViewerCard> {
  bool _showSelection = false;

  void _toggleField(String key) {
    final next = Set<String>.from(widget.monitoredKeys);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    widget.onMonitoredChanged(next);
  }

  Manufacturer _getManufacturer(String manufacturerName) {
    final lower = manufacturerName.toLowerCase();
    if (lower.contains('teltonika')) return Manufacturer.teltonika;
    if (lower.contains('suntech')) return Manufacturer.suntech;
    return Manufacturer.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final analysis = session.logCapture.analysis;
    final observedIos = analysis?.observedIos ?? [];
    final manufacturer = _getManufacturer(session.device.manufacturerName);
    final availableFields = ResponseViewerCard.getAvailableFields(manufacturer);

    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TrackerColors.communicationBlue.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.small,
                ),
                child: const Icon(
                  Icons.visibility,
                  size: 18,
                  color: TrackerColors.communicationBlue,
                ),
              ),
              const SizedBox(width: TrackerSpacing.sm),
              const Text(
                'Visor de Retorno',
                style: TrackerTextStyles.cardTitle,
              ),
              const Spacer(),
              if (observedIos.isNotEmpty)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          TrackerColors.attentionAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${observedIos.length} IO(s) detectado(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: TrackerColors.attentionAmber,
                      ),
                    )),
              const SizedBox(width: TrackerSpacing.sm),
              IconButton(
                icon: Icon(
                  _showSelection ? Icons.close : Icons.tune,
                  size: 18,
                  color: TrackerColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _showSelection = !_showSelection),
              ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.sm),
          if (_showSelection) ...[
            const Text(
              'Selecione os campos para monitorar:',
              style: TextStyle(
                fontSize: 12,
                color: TrackerColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in availableFields.entries)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TrackerColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final (ioKey, ioLabel, _) in entry.value)
                              FilterChip(
                                label: Text(
                                  ioLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.monitoredKeys.contains(ioKey)
                                        ? Colors.white
                                        : TrackerColors.textSecondary,
                                  ),
                                ),
                                selected: widget.monitoredKeys.contains(ioKey),
                                onSelected: (_) => _toggleField(ioKey),
                                selectedColor: TrackerColors.communicationBlue,
                                backgroundColor: TrackerColors.surface,
                                side: BorderSide(
                                  color: widget.monitoredKeys.contains(ioKey)
                                      ? TrackerColors.communicationBlue
                                      : TrackerColors.line,
                                  width: 1,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: TrackerSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: TrackerSpacing.sm),
          ],
          // Monitored fields display
          if (widget.monitoredKeys.isNotEmpty)
            Wrap(
              spacing: TrackerSpacing.sm,
              runSpacing: TrackerSpacing.sm,
              children: [
                for (final key in widget.monitoredKeys) ...[
                  _MonitoredFieldCard(
                    fieldKey: key,
                    label: availableFields.entries
                        .expand((e) => e.value)
                        .firstWhere((v) => v.$1 == key,
                            orElse: () => (key, key, Icons.info_outline))
                        .$2,
                  ),
                ],
              ],
            )
          else
            const Text(
              'Toque em ⚙️ para selecionar campos para monitorar.',
              style: TextStyle(
                fontSize: 12,
                color: TrackerColors.textSecondary,
              ),
            ),
          // Observed IOs for identification (when capture is active)
          if (observedIos.isNotEmpty) ...[
            const SizedBox(height: TrackerSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: TrackerSpacing.sm),
            const Text(
              'IOs Observados (clique para renomear)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TrackerColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: observedIos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final io = observedIos[index];
                final isKnown = io.definition != null;
                return _ObservedIoRow(
                  io: io,
                  isKnown: isKnown,
                  isLocked: session.logCapture.lockedIoId == io.avlId,
                  onLock: () {
                    ref
                        .read(trackerSessionControllerProvider.notifier)
                        .lockTeltonikaIo(
                          io.avlId == session.logCapture.lockedIoId
                              ? null
                              : io.avlId,
                        );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MonitoredFieldCard extends StatelessWidget {
  final String fieldKey;
  final String label;

  const _MonitoredFieldCard({
    required this.fieldKey,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TrackerColors.background,
        borderRadius: TrackerRadius.medium,
        border: Border.all(color: TrackerColors.lineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: TrackerColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fieldKey,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: TrackerColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservedIoRow extends StatelessWidget {
  final dynamic io;
  final bool isKnown;
  final bool isLocked;
  final VoidCallback onLock;

  const _ObservedIoRow({
    required this.io,
    required this.isKnown,
    required this.isLocked,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final rawValue = io.rawValue?.toString() ?? '--';
    final displayName = io.definition?.name ?? 'IO ${io.avlId} (sem catálogo)';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isLocked
            ? TrackerColors.communicationBlue.withValues(alpha: 0.08)
            : TrackerColors.surface,
        borderRadius: TrackerRadius.small,
        border: Border.all(
          color: isLocked
              ? TrackerColors.communicationBlue
              : TrackerColors.lineSubtle,
          width: isLocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isKnown ? Icons.check_circle : Icons.help_outline,
            size: 14,
            color: isKnown
                ? TrackerColors.technicalGreen
                : TrackerColors.attentionAmber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isKnown ? FontWeight.normal : FontWeight.w600,
                    color: isKnown
                        ? TrackerColors.textSecondary
                        : TrackerColors.textPrimary,
                  ),
                ),
                Text(
                  'Valor: $rawValue',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: TrackerColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              size: 14,
              color: isLocked
                  ? TrackerColors.communicationBlue
                  : TrackerColors.textSecondary,
            ),
            onPressed: onLock,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
