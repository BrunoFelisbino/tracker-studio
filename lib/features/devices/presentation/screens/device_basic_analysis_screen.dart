import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sessions/device_session.dart';
import '../../../../core/sessions/device_session_provider.dart';
import '../../../../core/design/tracker_colors.dart';

/// Screens para as três experiências principais.
class DeviceBasicAnalysisScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceBasicAnalysisScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(deviceSessionProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise Básica'),
        backgroundColor: TrackerColors.surface,
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (session) => _BasicAnalysisContent(session: session),
      ),
    );
  }
}

class DeviceAdvancedAnalysisScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceAdvancedAnalysisScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(deviceSessionProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise Avançada'),
        backgroundColor: TrackerColors.surface,
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (session) => _AdvancedAnalysisContent(session: session),
      ),
    );
  }
}

class DeviceConfigurationScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceConfigurationScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(deviceSessionProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
        backgroundColor: TrackerColors.surface,
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (session) => _ConfigurationContent(session: session),
      ),
    );
  }
}

class _BasicAnalysisContent extends StatelessWidget {
  final DeviceSession session;

  const _BasicAnalysisContent({required this.session});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MapSection(session: session),
          const SizedBox(height: 24),
          _StatusCardsSection(session: session),
          const SizedBox(height: 24),
          _SystemInfoSection(session: session),
        ],
      ),
    );
  }
}

class _AdvancedAnalysisContent extends StatelessWidget {
  final DeviceSession session;

  const _AdvancedAnalysisContent({required this.session});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.code), text: 'CAN'),
              Tab(icon: Icon(Icons.data_object), text: 'IOs'),
              Tab(icon: Icon(Icons.sensors), text: 'Sensores'),
              Tab(icon: Icon(Icons.timeline), text: 'Linha do Tempo'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CanTab(session: session),
                _IoTab(session: session),
                _SensorsTab(session: session),
                _TimelineTab(session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationContent extends StatelessWidget {
  final DeviceSession session;

  const _ConfigurationContent({required this.session});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Seções'),
              Tab(icon: Icon(Icons.play_arrow), text: 'Executar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ConfigurationSectionsTab(session: session),
                _ExecuteTestsTab(session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final DeviceSession session;

  const _MapSection({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mapa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Mapa para ${session.identity.model}',
                  style: const TextStyle(color: TrackerColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCardsSection extends StatelessWidget {
  final DeviceSession session;

  const _StatusCardsSection({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.flash_on,
          title: 'Ignição',
          value:
              session.normalizedState.vehicle.ignition ? 'LIGADA' : 'DESLIGADA',
          color: session.normalizedState.vehicle.ignition
              ? TrackerColors.technicalGreen
              : TrackerColors.textSecondary,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.directions_car,
          title: 'Velocidade',
          value: '${session.normalizedState.vehicle.speedKph} km/h',
          color: TrackerColors.communicationBlue,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.gps_fixed,
          title: 'GPS',
          value: session.normalizedState.position.satellites > 0
              ? 'SAT: ${session.normalizedState.position.satellites}'
              : 'Sem sinal',
          color: session.normalizedState.position.satellites > 0
              ? TrackerColors.technicalGreen
              : TrackerColors.attentionAmber,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.wifi,
          title: 'Rede',
          value: session.normalizedState.network.status,
          color: TrackerColors.communicationBlue,
        ),
      ],
    );
  }
}

class _SystemInfoSection extends StatelessWidget {
  final DeviceSession session;

  const _SystemInfoSection({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sistema',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _SystemInfoRow(
              icon: Icons.battery_charging_full,
              label: 'Bateria',
              value: '${session.normalizedState.power.batteryPercent}%',
              subvalue: session.normalizedState.power.charging
                  ? 'Carregando'
                  : 'Parada',
            ),
            const Divider(),
            _SystemInfoRow(
              icon: Icons.thermostat,
              label: 'Voltagem',
              value:
                  '${session.normalizedState.power.externalVoltage.toStringAsFixed(1)} V',
            ),
            const Divider(),
            _SystemInfoRow(
              icon: Icons.speed,
              label: 'Odomêtro',
              value: '${session.normalizedState.vehicle.odometerKm} km',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(color: TrackerColors.textSecondary)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subvalue;

  const _SystemInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subvalue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: TrackerColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: TrackerColors.textSecondary)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (subvalue != null && subvalue!.isNotEmpty)
                Text(subvalue!,
                    style: const TextStyle(
                        fontSize: 12, color: TrackerColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// Tabs para análise avançada
class _CanTab extends StatelessWidget {
  final DeviceSession session;

  const _CanTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Módulo CAN aqui'));
  }
}

class _IoTab extends StatelessWidget {
  final DeviceSession session;

  const _IoTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Módulo IOs aqui'));
  }
}

class _SensorsTab extends StatelessWidget {
  final DeviceSession session;

  const _SensorsTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Módulo Sensores aqui'));
  }
}

class _TimelineTab extends StatelessWidget {
  final DeviceSession session;

  const _TimelineTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Linha do tempo aqui'));
  }
}

class _ConfigurationSectionsTab extends StatelessWidget {
  final DeviceSession session;

  const _ConfigurationSectionsTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Seções de configuração aqui'));
  }
}

class _ExecuteTestsTab extends StatelessWidget {
  final DeviceSession session;

  const _ExecuteTestsTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Executar testes aqui'));
  }
}
