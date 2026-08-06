import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import '../../../sessions/presentation/tracker_studio/usb_serial_transport.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  late Future<List<SerialPortInfo>> _portsFuture;

  @override
  void initState() {
    super.initState();
    _portsFuture = _scanPorts();
  }

  Future<List<SerialPortInfo>> _scanPorts() async {
    final controller = ref.read(trackerSessionControllerProvider.notifier);
    return await controller.scanPorts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        backgroundColor: TrackerColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar portas',
            onPressed: () {
              setState(() {
                _portsFuture = _scanPorts();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SerialPortInfo>>(
        future: _portsFuture,
        builder: (context, snapshot) {
          final ports = snapshot.data ?? [];

          final connectedPath = ref.watch(trackerSessionControllerProvider
              .select((s) => s.connection.commandPortName));
          final usbConnected = ref.watch(trackerSessionControllerProvider
              .select((s) => s.connection.usbConnected));
          final discovered = ports.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TrackerSectionHeader(title: 'Portas Serial'),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !discovered)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (discovered)
                  Expanded(
                    child: ListView.separated(
                      itemCount: ports.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: TrackerColors.lineSubtle),
                      itemBuilder: (_, index) {
                        final port = ports[index];
                        final isConnected = usbConnected &&
                            port.path == connectedPath;
                        return ListTile(
                          leading: Icon(
                            Icons.usb,
                            color: isConnected
                                ? TrackerColors.technicalGreen
                                : TrackerColors.communicationBlue,
                          ),
                          title: Text(port.label),
                          subtitle: Text(port.path),
                          trailing: isConnected
                              ? const Icon(Icons.check_circle,
                                  color: TrackerColors.technicalGreen)
                              : null,
                          onTap: () async {
                            final goRouter = GoRouter.maybeOf(context);
                            if (goRouter == null) return;
                            final connectionController =
                                ref.read(trackerSessionControllerProvider
                                    .notifier);
                            await connectionController.connectUsb(
                              port.path,
                            );
                            if (!mounted) return;
                            goRouter.go('/dashboard');
                          },
                        );
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: TrackerEmptyState(
                      icon: Icons.usb_outlined,
                      title: 'Nenhuma porta detectada',
                      message:
                          'Conecte um adaptador USB serial e verifique o driver CH340/CP210x/FTDI/Prolific.',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

