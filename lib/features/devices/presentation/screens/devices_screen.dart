import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import '../../../sessions/presentation/tracker_studio/usb_serial_transport.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  String? _selectedPort;
  String _selectedBaudRate = '115200';
  List<SerialPortInfo> _ports = const [];
  bool _loading = false;

  final List<String> _baudRates = ['9600', '19200', '38400', '57600', '115200'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPorts());
  }

  Future<void> _refreshPorts() async {
    setState(() => _loading = true);
    final controller = ref.read(trackerSessionControllerProvider.notifier);
    final ports = await controller.scanPorts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ports = ports;
      if (_selectedPort != null &&
          ports.every((port) => port.path != _selectedPort)) {
        _selectedPort = null;
      }
    });
  }

  Future<void> _connect() async {
    if (_selectedPort == null) return;
    await ref.read(trackerSessionControllerProvider.notifier).connectUsb(
          _selectedPort!,
          baudRate: int.parse(_selectedBaudRate),
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final connected = session.connection.usbConnected;
    return TrackerScaffold(
      title: 'Dispositivos',
      subtitle: 'Portas reais e conexão serial ativa',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TrackerSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const TrackerSectionHeader(
            title: 'Conexão',
            icon: Icons.cable,
            eyebrow: 'Status da interface de comunicação',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: connected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: TrackerSpacing.sm),
                Flexible(
                  child: Text(
                    connected
                        ? 'USB/Serial — Conectado'
                        : 'USB/Serial — Desconectado',
                    style: const TextStyle(color: TrackerColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Configuração da Porta',
            icon: Icons.settings,
            eyebrow: 'Selecione a porta e velocidade',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedPort,
                  isExpanded: true,
                  items: _ports
                      .map((p) => DropdownMenuItem(value: p.path, child: Text(p.label)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPort = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Porta',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Nenhuma porta detectada',
                  ),
                ),
                const SizedBox(height: TrackerSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBaudRate,
                  isExpanded: true,
                  items: _baudRates
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedBaudRate = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Baud Rate',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: TrackerSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _refreshPorts,
                        icon: const Icon(Icons.refresh),
                        label: Text(_loading ? 'Atualizando...' : 'Atualizar portas'),
                      ),
                    ),
                    const SizedBox(width: TrackerSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connected
                            ? () => ref
                                .read(trackerSessionControllerProvider.notifier)
                                .disconnectUsb()
                            : _selectedPort == null
                                ? null
                                : _connect,
                        icon: Icon(connected ? Icons.link_off : Icons.link),
                        label: Text(connected ? 'Desconectar' : 'Conectar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Dispositivo Conectado',
            icon: Icons.device_hub,
            eyebrow: 'Informações identificadas',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: Column(
              children: [
                _InfoRow(
                    label: 'Modelo',
                    value: session.hasDeviceRead
                        ? session.device.model
                        : 'Nenhum dispositivo conectado'),
                const SizedBox(height: TrackerSpacing.xs),
                _InfoRow(label: 'ESN', value: session.device.esn),
                const SizedBox(height: TrackerSpacing.xs),
                _InfoRow(label: 'Firmware', value: session.device.firmware),
              ],
            ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          if (_ports.isEmpty && !_loading)
            const TrackerCard(
              child: TrackerEmptyState(
                icon: Icons.usb_off,
                title: 'Nenhuma porta detectada',
                message: 'Conecte um adaptador USB/serial real para continuar.',
              ),
            ),
          const SizedBox(height: TrackerSpacing.xxl),
        ],
        ),
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
          child: Text(label,
              style: const TextStyle(color: TrackerColors.textSecondary)),
        ),
        const SizedBox(width: TrackerSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TrackerColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
