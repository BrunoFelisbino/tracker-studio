import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tracker_motion.dart';
import '../../../../core/design/tracker_theme.dart';
import '../../../../core/data/can_mapping/can_mapping_store.dart';
import '../../../../core/data/parsers/teltonika_usb/teltonika_capture_analysis.dart';
import '../../../../core/data/parsers/teltonika_usb/teltonika_usb_models.dart';
import '../../../../core/widgets/local_mode_badge.dart';
import '../../../../core/widgets/tracker_radar_background.dart';
import '../../../../core/widgets/tracker_signal_pulse.dart';
import '../../../../core/uce/registry/config_field_spec.dart';
import '../../../../core/uce/registry/uce_registry.dart';
import 'installation_profiles.dart';
import 'service_map_preview.dart';
import 'serial_diagnostics.dart';
import 'suntech_command_family.dart';
import 'suntech_handshake_engine.dart';
import 'suntech_legacy_commands.dart';
import 'suntech_newgen_commands.dart';
import '../../../../core/drivers/teltonika/teltonika_network_commands.dart';
import 'tracker_session_state.dart';
import 'tracker_studio_controller.dart';
import 'usb_serial_transport.dart';
import 'work_order_models.dart';
import 'work_order_widgets.dart';
import 'troubleshooting_engine.dart';
import 'batch_preset_manager.dart';
import 'quick_test_wizard.dart';

class TrackerStudioLiveScreen extends ConsumerStatefulWidget {
  final StudioMode initialMode;

  const TrackerStudioLiveScreen({
    super.key,
    this.initialMode = StudioMode.quickTest,
  });

  @override
  ConsumerState<TrackerStudioLiveScreen> createState() =>
      _TrackerStudioLiveScreenState();
}

class _TrackerStudioLiveScreenState
    extends ConsumerState<TrackerStudioLiveScreen> {
  bool _busy = false;
  final Set<String> _shownReminderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(trackerSessionControllerProvider.notifier)
          .setStudioMode(widget.initialMode);
    });
  }

  void _showDueReminders(TrackerSessionState session) {
    if (!mounted) return;
    for (final reminder in dueServiceReminders(
      session.todayWorkOrders,
      DateTime.now(),
    )) {
      final key =
          '${reminder.rule.id}-${reminder.scheduledAt.toIso8601String()}';
      if (!_shownReminderIds.add(key)) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reminder.message),
            action: SnackBarAction(
              label: 'Ver testes',
              onPressed: () => ref
                  .read(trackerSessionControllerProvider.notifier)
                  .setStudioMode(StudioMode.quickTest),
            ),
          ),
        );
      });
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    Future<void> Function()? retry,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    _UsbErrorAction? usbAction;
    try {
      await action();
    } catch (error) {
      if (mounted && _isUsbPermissionError(error)) {
        usbAction = await _showUsbPermissionDialog(error);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyError(error),
              style: const TextStyle(
                  color: _Studio.text, fontWeight: FontWeight.w700),
            ),
            backgroundColor: _Studio.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _Studio.border),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (usbAction == _UsbErrorAction.retry) {
      await _run(retry ?? action, retry: retry ?? action);
    } else if (usbAction == _UsbErrorAction.openPrivacy) {
      await Process.run(
        'open',
        ['x-apple.systempreferences:com.apple.preference.security?Privacy'],
      );
    }
  }

  bool _isUsbPermissionError(Object error) {
    final lower = '$error'.toLowerCase();
    return lower.contains('operation not permitted') ||
        lower.contains('permission denied') ||
        lower.contains('not permitted') ||
        lower.contains('sandbox') ||
        lower.contains('acesso usb bloqueado');
  }

  Future<_UsbErrorAction?> _showUsbPermissionDialog(Object error) {
    final diagnostic = '$error'.replaceFirst('Bad state: ', '');
    return showDialog<_UsbErrorAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acesso USB bloqueado'),
        content: const Text(
          'Acesso USB bloqueado pelo macOS. Rode o app em build debug sem sandbox ou ajuste os entitlements.\n\n'
          'Para portas seriais USB, a liberação pode depender do sandbox e dos entitlements, não apenas da tela Privacidade e Segurança.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diagnostic));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnóstico copiado.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar diagnóstico'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UsbErrorAction.openPrivacy),
            child: const Text('Abrir Privacidade e Segurança'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UsbErrorAction.retry),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = '$error'.replaceFirst('Bad state: ', '');
    if (message.contains('Conecte uma porta')) {
      return 'Conecte o equipamento em Detectar USB antes de iniciar a leitura.';
    }
    return message;
  }

  Future<void> _selectPort() async {
    final controller = ref.read(trackerSessionControllerProvider.notifier);
    final ports = await controller.scanPorts();
    if (!mounted) return;

    if (ports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nenhuma porta serial detectada. Conecte o adaptador USB serial e verifique driver CH340/CP210x/FTDI/Prolific.',
            style: TextStyle(color: _Studio.text, fontWeight: FontWeight.w700),
          ),
          backgroundColor: _Studio.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: _Studio.border),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    SerialPortInfo? commandPort;
    SerialPortInfo? readPort;
    final usbModemPorts = ports
        .where((port) => port.path.toLowerCase().contains('usbmodem'))
        .toList();
    if (usbModemPorts.length >= 2) {
      commandPort = usbModemPorts[0];
      readPort = usbModemPorts[1];
    }

    final selected = await showDialog<_SerialSelection>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _Studio.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Selecionar porta serial'),
        content: SizedBox(
          width: 520,
          height: commandPort != null && readPort != null ? 500 : 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (commandPort != null && readPort != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: _Studio.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Par TX/RX detectado',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('Comando: ${commandPort.path}',
                          style: const TextStyle(fontSize: 12)),
                      Text('Retorno: ${readPort.path}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _SerialSelection(
                              commandPortPath: commandPort!.path,
                              readPortPath: readPort!.path),
                        ),
                        child: const Text('Usar par detectado'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Ou usar uma porta',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ports.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _Studio.border),
                  itemBuilder: (_, index) {
                    final port = ports[index];
                    return ListTile(
                      leading: const Icon(Icons.usb, color: _Studio.primary),
                      title: Text(port.label),
                      subtitle: Text(port.path),
                      onTap: () => Navigator.pop(
                        context,
                        _SerialSelection(commandPortPath: port.path),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      Future<void> connect() => controller.connectUsb(
            selected.commandPortPath,
            readPortPath: selected.readPortPath,
          );
      await _run(connect, retry: connect);
    }
  }

  Future<void> _openMap(TrackerSessionState session) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          height: 650,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ServiceMapPreview(
              serviceLatitude: session.serviceLocation.latitude,
              serviceLongitude: session.serviceLocation.longitude,
              trackerLatitude: session.localitel.latitude,
              trackerLongitude: session.localitel.longitude,
              toleranceMeters: session.localitel.serviceToleranceMeters,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(
    InstallationProfile profile,
    TrackerStudioController controller,
  ) async {
    final values = await showDialog<_CustomProfileValues>(
      context: context,
      builder: (context) => _ProfileEditorDialog(profile: profile),
    );
    if (values == null) return;
    controller.updateCustomTiming(
      movingIntervalSeconds: values.moving,
      stoppedIntervalSeconds: values.stopped,
      ignitionOnIntervalSeconds: values.ignitionOn,
      ignitionOffIntervalSeconds: values.ignitionOff,
      curveAngleDegrees: values.curve,
      distanceMeters: values.distance,
      enableSleep: values.sleep,
      enableBlocking: values.blocking,
    );
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado para a área de transferência.')),
    );
  }

  Future<void> _openExternalLink(String label, String link) async {
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) await _copyText(label, link);
  }

  Future<void> _confirmCompletion(TrackerStudioController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir serviço?'),
        content: const Text(
            'Fotos pendentes serão registradas como warning e não reprovarão o rastreador.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Concluir')),
        ],
      ),
    );
    if (confirmed == true) await _run(controller.completeWorkOrder);
  }

  Future<void> _selectEvidencePhoto(
    WorkOrderPhotoType type,
    TrackerStudioController controller,
  ) async {
    const imageTypes = XTypeGroup(
      label: 'Imagens',
      extensions: ['jpg', 'jpeg', 'png', 'heic'],
    );
    final file = await openFile(acceptedTypeGroups: const [imageTypes]);
    if (file != null) {
      await _run(() => controller.attachWorkOrderPhoto(type, file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final controller = ref.read(trackerSessionControllerProvider.notifier);
    _showDueReminders(session);

    return Theme(
      data: TrackerTheme.light(),
      child: TrackerRadarBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  session: session,
                  busy: _busy,
                  onModeChanged: controller.setStudioMode,
                  onDetectUsb: _selectPort,
                  onDisconnect: () => controller.disconnectUsb(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: AnimatedSwitcher(
                        duration: TrackerMotion.deliberate,
                        switchInCurve: TrackerMotion.curve,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.018),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (session.studioMode) {
                          StudioMode.quickTest => _OperationalView(
                              key: const ValueKey(StudioMode.quickTest),
                              session: session,
                              busy: _busy,
                              onRead: () => _run(controller.autoIdentifyDevice),
                              onStatus: () => _run(controller.readStatus),
                              onPreset: () => _run(controller.readPreset),
                              onCaptureLocation: () =>
                                  _run(controller.captureServiceLocation),
                              onValidate: () => _run(() async =>
                                  controller.validateInstallation()),
                              onLocalitel: () =>
                                  _run(controller.queryLocalitel),
                              onReport: () =>
                                  _run(() async => controller.generateReport()),
                              onMap: () => _openMap(session),
                              onInstallationMode:
                                  controller.selectInstallationMode,
                              onIgnitionMode: controller.selectIgnitionMode,
                              onTimingProfile: controller.selectTimingProfile,
                              onGeneratePlan: controller.generateCommandPlan,
                              onEditProfile: () => _editProfile(
                                  session.selectedProfile, controller),
                              onOpenWorkOrder: (workOrder) => _run(
                                  () => controller.openWorkOrder(workOrder.id)),
                              onStartWorkOrder: (workOrder) => _run(() =>
                                  controller.startWorkOrder(workOrder.id)),
                              onRoute: (workOrder) => _openExternalLink(
                                'Link de rota',
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(workOrder.scheduledAddress)}',
                              ),
                              onWhatsApp: (workOrder) => _openExternalLink(
                                'Link do WhatsApp',
                                'https://wa.me/${workOrder.phoneRaw}',
                              ),
                              onPlateSubmitted: (plate) => _run(
                                  () => controller.updateWorkOrderPlate(plate)),
                              onServiceValidation:
                                  controller.runServiceValidation,
                              onCompleteWorkOrder: () =>
                                  _confirmCompletion(controller),
                              onTakePhoto: (type) =>
                                  _selectEvidencePhoto(type, controller),
                              onSelectPhoto: (type) =>
                                  _selectEvidencePhoto(type, controller),
                              onDeviceEvidenceChanged: (evidence) => _run(
                                () => controller.updateDeviceEvidence(
                                  barcodeRaw: evidence.barcodeRaw,
                                  labelSerial: evidence.labelSerial,
                                  labelImei: evidence.labelImei,
                                  labelEsn: evidence.labelEsn,
                                ),
                              ),
                            ),
                          StudioMode.lab => _LaboratoryView(
                              key: const ValueKey(StudioMode.lab),
                              session: session,
                              controller: controller,
                              busy: _busy,
                              onStatus: () => _run(controller.readStatus),
                              onPreset: () => _run(controller.readPreset),
                              onPosition: () =>
                                  _run(controller.requestPosition),
                              onFullRead: () => _run(controller.readFullDevice),
                              onRepeat: () =>
                                  _run(controller.repeatLastCommand),
                              onManualCommand: (command) => _run(
                                  () => controller.sendManualCommand(command)),
                              onBaudRate: (baudRate) => _run(
                                  () => controller.changeBaudRate(baudRate)),
                              onClearLogs: controller.clearSerialLogs,
                              onTestAt: () => _run(controller.runAtDiagnostic),
                              onTestMatrix: () =>
                                  _run(controller.runSerialDiagnosticMatrix),
                              onEnding: controller.selectSerialEnding,
                              onDtr: controller.setSerialDtr,
                              onRts: controller.setSerialRts,
                              onSuntechFamily: controller.selectSuntechFamily,
                              onMap: () => _openMap(session),
                              onCopyWorkOrderPayload: () => _copyText(
                                  'Payload da OS',
                                  controller.copyWorkOrderPayload()),
                              workOrderPayload:
                                  controller.copyWorkOrderPayload(),
                              onAutoIdentify: () =>
                                  _run(controller.autoIdentifyDevice),
                              onFullScan: () =>
                                  _run(controller.runFullSuntechScan),
                              onHandshakeProbe: (probe) => _run(
                                  () => controller.sendHandshakeProbe(probe)),
                              onClearHandshake:
                                  controller.clearHandshakeEvidence,
                              onStartCapture: controller.startTeltonikaCapture,
                              onStopCapture: controller.stopTeltonikaCapture,
                              onClearCapture: controller.clearTeltonikaCapture,
                              onSaveCapture: () => _run(
                                  controller.saveTeltonikaCaptureForAnalysis),
                            ),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _UsbErrorAction { retry, openPrivacy }

class _SerialSelection {
  final String commandPortPath;
  final String? readPortPath;

  const _SerialSelection({required this.commandPortPath, this.readPortPath});
}

class _Studio {
  static const surface = TrackerColors.surface;
  static const border = TrackerColors.line;
  static const text = TrackerColors.textPrimary;
  static const muted = TrackerColors.textSecondary;
  static const primary = TrackerColors.communicationBlue;
  static const success = TrackerColors.technicalGreen;
  static const warning = TrackerColors.attentionAmber;
  static const danger = TrackerColors.failureRed;
  static const info = TrackerColors.communicationBlue;
  static const log = TrackerColors.backgroundElevated;
}

class _TopBar extends StatelessWidget {
  final TrackerSessionState session;
  final bool busy;
  final ValueChanged<StudioMode> onModeChanged;
  final VoidCallback onDetectUsb;
  final VoidCallback onDisconnect;

  const _TopBar({
    required this.session,
    required this.busy,
    required this.onModeChanged,
    required this.onDetectUsb,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final agendaCount =
        session.todayWorkOrders.where(isActionableWorkOrder).length;
    final hasOverdue = session.todayWorkOrders
        .any((order) => isOverdueWorkOrder(order, DateTime.now()));
    final navigation = SegmentedButton<StudioMode>(
      segments: const [
        ButtonSegment(
          value: StudioMode.quickTest,
          label: Text('Teste Rápido'),
          icon: Icon(Icons.flash_on_rounded, size: 17),
        ),
        ButtonSegment(
          value: StudioMode.lab,
          label: Text('Laboratório'),
          icon: Icon(Icons.science_outlined, size: 17),
        ),
      ],
      selected: {session.studioMode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onModeChanged(selection.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
    final logo = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _Studio.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.precision_manufacturing_outlined,
          color: Colors.white),
    );
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tracker Studio',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _Studio.text)),
        Text('Simples no campo. Completo na bancada.',
            style: TextStyle(fontSize: 12, color: _Studio.muted)),
      ],
    );
    final connectionButton = session.connection.usbConnected
        ? OutlinedButton(
            onPressed: onDisconnect, child: const Text('Desconectar'))
        : FilledButton.icon(
            onPressed: busy ? null : onDetectUsb,
            icon: const Icon(Icons.usb, size: 18),
            label: const Text('Detectar USB'),
          );
    final progress = busy
        ? const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _Studio.surface,
        border: Border(bottom: BorderSide(color: _Studio.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1050) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    logo,
                    const SizedBox(width: 12),
                    const Expanded(child: title),
                    if (constraints.maxWidth >= 600) const LocalModeBadge(),
                    progress,
                    connectionButton,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (constraints.maxWidth < 600) const LocalModeBadge(),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: navigation,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              logo,
              const SizedBox(width: 12),
              const Expanded(child: title),
              const LocalModeBadge(),
              navigation,
              const SizedBox(width: 12),
              progress,
              connectionButton,
            ],
          );
        },
      ),
    );
  }
}

class _AgendaView extends StatelessWidget {
  final TrackerSessionState session;
  final ValueChanged<WorkOrder> onOpenWorkOrder;
  final ValueChanged<WorkOrder> onStartWorkOrder;
  final ValueChanged<WorkOrder> onRoute;
  final ValueChanged<WorkOrder> onWhatsApp;

  const _AgendaView({
    required this.session,
    required this.onOpenWorkOrder,
    required this.onStartWorkOrder,
    required this.onRoute,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final today = session.todayWorkOrders.where(isActionableWorkOrder).toList();
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    final weekCount =
        today.where((order) => !order.date.isAfter(weekEnd)).length;
    final monthCount = today
        .where((order) =>
            order.date.year == now.year && order.date.month == now.month)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageIntro(
          eyebrow: 'AGENDA TÉCNICA',
          title: 'Serviços programados',
          description:
              'Acompanhe horários, prioridades, serviços feitos e envios pendentes.',
        ),
        const SizedBox(height: 18),
        _ResponsiveCards(
          preferredWidth: 250,
          children: [
            _AgendaSummaryCard(
                title: 'Hoje', value: '${today.length}', icon: Icons.today),
            _AgendaSummaryCard(
                title: 'Semana',
                value: '$weekCount',
                icon: Icons.date_range_outlined),
            _AgendaSummaryCard(
                title: 'Mês',
                value: '$monthCount',
                icon: Icons.calendar_month_outlined),
            _AgendaSummaryCard(
                title: 'Serviços feitos',
                value: '${session.recentCompletedServices.length}',
                icon: Icons.task_alt),
            _AgendaSummaryCard(
                title: 'Pendentes de envio',
                value: '${session.pendingSyncServices.length}',
                icon: Icons.cloud_upload_outlined),
          ],
        ),
        const SizedBox(height: 18),
        WorkOrderAgendaSection(
          workOrders: today,
          onOpen: onOpenWorkOrder,
          onStart: onStartWorkOrder,
          onRoute: onRoute,
          onWhatsApp: onWhatsApp,
        ),
        const SizedBox(height: 18),
        CompletedServicesCard(
          records: session.recentCompletedServices,
          pendingCount: session.pendingSyncServices.length,
        ),
      ],
    );
  }
}

class _AgendaSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AgendaSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => _Panel(
        child: Row(
          children: [
            Icon(icon, color: _Studio.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _Studio.muted)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _OperationalView extends StatelessWidget {
  final TrackerSessionState session;
  final bool busy;
  final VoidCallback onRead;
  final VoidCallback onStatus;
  final VoidCallback onPreset;
  final VoidCallback onCaptureLocation;
  final VoidCallback onValidate;
  final VoidCallback onLocalitel;
  final VoidCallback onReport;
  final VoidCallback onMap;
  final ValueChanged<InstallationMode> onInstallationMode;
  final ValueChanged<IgnitionMode> onIgnitionMode;
  final ValueChanged<TimingProfile> onTimingProfile;
  final VoidCallback onGeneratePlan;
  final VoidCallback onEditProfile;
  final ValueChanged<WorkOrder> onOpenWorkOrder;
  final ValueChanged<WorkOrder> onStartWorkOrder;
  final ValueChanged<WorkOrder> onRoute;
  final ValueChanged<WorkOrder> onWhatsApp;
  final ValueChanged<String> onPlateSubmitted;
  final VoidCallback onServiceValidation;
  final VoidCallback onCompleteWorkOrder;
  final ValueChanged<WorkOrderPhotoType> onTakePhoto;
  final ValueChanged<WorkOrderPhotoType> onSelectPhoto;
  final ValueChanged<DeviceEvidence> onDeviceEvidenceChanged;

  const _OperationalView({
    super.key,
    required this.session,
    required this.busy,
    required this.onRead,
    required this.onStatus,
    required this.onPreset,
    required this.onCaptureLocation,
    required this.onValidate,
    required this.onLocalitel,
    required this.onReport,
    required this.onMap,
    required this.onInstallationMode,
    required this.onIgnitionMode,
    required this.onTimingProfile,
    required this.onGeneratePlan,
    required this.onEditProfile,
    required this.onOpenWorkOrder,
    required this.onStartWorkOrder,
    required this.onRoute,
    required this.onWhatsApp,
    required this.onPlateSubmitted,
    required this.onServiceValidation,
    required this.onCompleteWorkOrder,
    required this.onTakePhoto,
    required this.onSelectPhoto,
    required this.onDeviceEvidenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final family = session.selectedSuntechFamily;
    final canReadDevice = canReadSuntechDevice(
      usbConnected: session.connection.usbConnected,
      family: family,
      hasEsn: session.hasDeviceRead,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageIntro(
          eyebrow: 'TESTE RÁPIDO VAPT-VUPT',
          title: 'Validação e homologação automatizada de campo',
          description:
              'Sequência rápida de testes com leitura de ESN, alimentação, ignição e bloqueio.',
        ),
        const SizedBox(height: 18),
        QuickTestWizardWidget(
          session: session,
          onTriggerLockTest: () {},
          onFinishWizard: () {},
        ),
        if (session.activeWorkOrder != null) ...[
          const SizedBox(height: 18),
          ActiveWorkOrderCard(
            workOrder: session.activeWorkOrder!,
            onPlateSubmitted: onPlateSubmitted,
            onComplete: onCompleteWorkOrder,
            usbEsn: session.device.esn,
            usbImei: session.device.imei,
            validation: session.serviceValidation,
          ),
          const SizedBox(height: 18),
          _ResponsiveCards(
            preferredWidth: 520,
            children: [
              WorkOrderEvidenceCard(
                workOrder: session.activeWorkOrder!,
                physicalIgnition: session.selectedProfile.ignitionMode ==
                    IgnitionMode.physical,
                blockingEnabled: session.selectedProfile.enableBlocking,
                onTakePhoto: onTakePhoto,
                onSelectPhoto: onSelectPhoto,
                onDeviceEvidenceChanged: onDeviceEvidenceChanged,
              ),
              ServiceTripleCheckCard(
                validation: session.serviceValidation,
                localitelStatus: session.localitel.status,
                onValidate: onServiceValidation,
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _ActionBar(
          busy: busy,
          actions: [
            _ActionSpec(
              'Identificar equipamento',
              Icons.download_outlined,
              session.connection.usbConnected ? onRead : null,
              primary: true,
            ),
            _ActionSpec(
              'Ler status',
              Icons.sensors,
              canReadDevice ? onStatus : null,
            ),
            _ActionSpec(
              'Ler configuração original',
              Icons.settings_input_component,
              canReadDevice ? onPreset : null,
            ),
            _ActionSpec('Capturar local do serviço', Icons.my_location,
                onCaptureLocation),
            _ActionSpec('Validar instalação', Icons.verified_outlined,
                session.hasDeviceRead ? onValidate : null),
            _ActionSpec(
              'Double-check LocaliTel',
              Icons.map_outlined,
              session.localitel.hasValidCoordinates ? onLocalitel : null,
            ),
            _ActionSpec('Gerar relatório', Icons.description_outlined,
                session.minimumChecklistReady ? onReport : null),
          ],
        ),
        if (family == SuntechCommandFamily.newGenSt8210St8310 &&
            !session.hasDeviceRead) ...[
          const SizedBox(height: 10),
          const Text(
            'Catálogo carregado, mas ESN não foi localizado no JSON.',
            style:
                TextStyle(color: _Studio.warning, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRead,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar extrair ESN novamente'),
            ),
          ),
        ],
        if (session.manualCommand.waitingResponse) ...[
          const SizedBox(height: 10),
          const Text('Aguardando resposta...',
              style: TextStyle(
                  color: _Studio.warning, fontWeight: FontWeight.w800)),
        ] else if (session.manualCommand.lastResponse.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Resposta recebida',
              style: TextStyle(
                  color: _Studio.success, fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 18),
        _InstallationProfileCard(
          profile: session.selectedProfile,
          hasBackup: session.hasValidBackup,
          onInstallationMode: onInstallationMode,
          onIgnitionMode: onIgnitionMode,
          onTimingProfile: onTimingProfile,
          onGenerate: onGeneratePlan,
          onEdit: onEditProfile,
        ),
        const SizedBox(height: 18),
        _ResponsiveCards(
          children: [
            _StatusCard(
              title: 'Conexão USB',
              icon: Icons.usb,
              tone: session.connection.usbConnected
                  ? _Studio.success
                  : _Studio.muted,
              status: session.connection.usbConnected
                  ? 'Conectado'
                  : 'Aguardando conexão',
              rows: {
                'Comando': session.connection.usbConnected
                    ? session.connection.commandPortName
                    : 'Nenhuma porta conectada',
                'Retorno': session.connection.usbConnected
                    ? session.connection.readPortName
                    : '-',
                'Velocidade': session.connection.usbConnected
                    ? '${session.connection.baudRate} baud'
                    : '-',
              },
            ),
            _EquipmentCard(session: session),
            _StatusCard(
              title: 'Alimentação',
              icon: Icons.battery_charging_full,
              status:
                  _testDetail(session, 'main_power', 'Aguardando leitura real'),
              rows: {
                'Principal': _testDetail(session, 'main_power', '-'),
                'Backup': _testDetail(session, 'backup_power', '-'),
              },
            ),
            _StatusCard(
              title: 'GPS e Rede',
              icon: Icons.satellite_alt_outlined,
              status: session.localitel.hasValidCoordinates
                  ? 'Coordenadas recebidas'
                  : 'Sem coordenadas do rastreador',
              rows: {
                'GPS': _testDetail(session, 'gps', 'Aguardando leitura real'),
                'Rede': session.connection.networkLabel,
                'GPRS': session.connection.gprsLabel,
              },
            ),
            _ServiceCard(session: session),
            _LocationCard(session: session, onMap: onMap),
            _StatusCard(
              title: 'Configuração original',
              icon: Icons.settings_backup_restore,
              status: session.hasValidBackup
                  ? 'Backup protegido'
                  : 'Nenhuma configuração original salva',
              rows: session.configuration.original.isEmpty
                  ? const {'Servidor': '-', 'Porta': '-'}
                  : {
                      'Servidor':
                          session.configuration.original['Servidor primário'] ??
                              '-',
                      'Porta':
                          session.configuration.original['Porta primária'] ??
                              '-',
                      'APN': session.configuration.original['APN'] ?? '-',
                      'Usuário':
                          session.configuration.original['Usuário'] ?? '-',
                      'Senha': _maskedConfigurationValue('Senha',
                          session.configuration.original['Senha'] ?? ''),
                      'Protocolo':
                          session.configuration.original['Protocolo'] ?? '-',
                      'Secundário': session
                              .configuration.original['Servidor secundário'] ??
                          '-',
                      'Porta sec.':
                          session.configuration.original['Porta secundária'] ??
                              '-',
                    },
            ),
            _LocalitelCard(session: session),
            _ResultCard(session: session),
          ],
        ),
        const SizedBox(height: 18),
        _Checklist(session: session),
      ],
    );
  }
}

class _LaboratoryView extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;
  final bool busy;
  final VoidCallback onStatus;
  final VoidCallback onPreset;
  final VoidCallback onPosition;
  final VoidCallback onFullRead;
  final VoidCallback onRepeat;
  final Future<void> Function(String command) onManualCommand;
  final Future<void> Function(int baudRate) onBaudRate;
  final VoidCallback onClearLogs;
  final VoidCallback onTestAt;
  final VoidCallback onTestMatrix;
  final ValueChanged<SerialLineEnding> onEnding;
  final ValueChanged<bool> onDtr;
  final ValueChanged<bool> onRts;
  final ValueChanged<SuntechCommandFamily> onSuntechFamily;
  final VoidCallback onMap;
  final VoidCallback onCopyWorkOrderPayload;
  final String workOrderPayload;
  final VoidCallback onAutoIdentify;
  final VoidCallback onFullScan;
  final ValueChanged<SuntechHandshakeProbe> onHandshakeProbe;
  final VoidCallback onClearHandshake;
  final VoidCallback onStartCapture;
  final VoidCallback onStopCapture;
  final VoidCallback onClearCapture;
  final VoidCallback onSaveCapture;

  const _LaboratoryView({
    super.key,
    required this.session,
    required this.controller,
    required this.busy,
    required this.onStatus,
    required this.onPreset,
    required this.onPosition,
    required this.onFullRead,
    required this.onRepeat,
    required this.onManualCommand,
    required this.onBaudRate,
    required this.onClearLogs,
    required this.onTestAt,
    required this.onTestMatrix,
    required this.onEnding,
    required this.onDtr,
    required this.onRts,
    required this.onSuntechFamily,
    required this.onMap,
    required this.onCopyWorkOrderPayload,
    required this.workOrderPayload,
    required this.onAutoIdentify,
    required this.onFullScan,
    required this.onHandshakeProbe,
    required this.onClearHandshake,
    required this.onStartCapture,
    required this.onStopCapture,
    required this.onClearCapture,
    required this.onSaveCapture,
  });

  @override
  Widget build(BuildContext context) {
    final family = session.selectedSuntechFamily;
    final canReadDevice = canReadSuntechDevice(
      usbConnected: session.connection.usbConnected,
      family: family,
      hasEsn: session.hasDeviceRead,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageIntro(
          eyebrow: 'LABORATÓRIO & DIAGNÓSTICO',
          title: 'Ferramentas de bancada e análise avançada',
          description:
              'Diagnóstico inteligente de falhas, gravação de perfis em lote e inspeção serial.',
        ),
        const SizedBox(height: 18),
        TroubleshootingWidget(
          session: session,
          onFixApn: (apn) =>
              onManualCommand('AT^CMD;${session.device.esn};20;01;$apn;T1;T1;'),
          onReadStatus: onStatus,
        ),
        const SizedBox(height: 18),
        BatchPresetWidget(
          session: session,
          isConnected: session.connection.usbConnected,
          onFetchFromDevice: () {
            onPreset();
            onStatus();
          },
          onApplyPreset: (preset) {
            final esn = session.device.esn.isNotEmpty
                ? session.device.esn
                : '000000000';
            if (session.effectiveSuntechFamily ==
                SuntechCommandFamily.newGenSt8210St8310) {
              onManualCommand(
                'AT^PRG;$esn;20;01#${preset.apn};02#${preset.user};03#${preset.password};05#${preset.primaryServer};06#${preset.primaryPort}',
              );
            } else {
              onManualCommand(
                'ST300NTW;$esn;01;${preset.apn};${preset.user};${preset.password};${preset.primaryServer};${preset.primaryPort};0.0.0.0;0',
              );
            }
          },
        ),
        const SizedBox(height: 18),
        _SuntechFamilyCard(session: session, onChanged: onSuntechFamily),
        const SizedBox(height: 18),
        _HandshakeCard(
          session: session,
          busy: busy,
          onAutoIdentify: onAutoIdentify,
          onFullScan: onFullScan,
          onProbe: onHandshakeProbe,
          onClear: onClearHandshake,
        ),
        const SizedBox(height: 18),
        _EquipmentCatalogCard(session: session, controller: controller),
        const SizedBox(height: 18),
        _NewGenNetworkCard(session: session, controller: controller),
        const SizedBox(height: 18),
        _TeltonikaNetworkCard(session: session, controller: controller),
        const SizedBox(height: 18),
        _TeltonikaMovingCard(session: session, controller: controller),
        const SizedBox(height: 18),
        _TeltonikaBackupCard(session: session, controller: controller),
        const SizedBox(height: 18),
        _TeltonikaSystemCard(session: session, controller: controller),
        const SizedBox(height: 18),
        TeltonikaCanCard(session: session),
        const SizedBox(height: 18),
        _ActionBar(
          busy: busy,
          actions: [
            _ActionSpec(
                'Status STT', Icons.sensors, canReadDevice ? onStatus : null,
                primary: true),
            if (family != SuntechCommandFamily.unknown)
              _ActionSpec(
                family == SuntechCommandFamily.legacySt300St310
                    ? 'Ler configuração CMD'
                    : 'Ler PRESET New Gen',
                Icons.tune,
                canReadDevice ? onPreset : null,
                primary: true,
              ),
            _ActionSpec('Solicitar posição', Icons.my_location,
                canReadDevice ? onPosition : null),
            _ActionSpec('Status completo', Icons.download_outlined,
                canReadDevice ? onFullRead : null),
            _ActionSpec(
              'Repetir último comando',
              Icons.replay,
              session.connection.usbConnected &&
                      session.manualCommand.lastCommand.isNotEmpty
                  ? onRepeat
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'ST310/ST300 Legacy usa CMD/NTW/NTN. ST8210/ST8310 usa PRG/CMD.',
          style: TextStyle(color: _Studio.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Aplicar servidor, restaurar, bloquear e desbloquear: bloqueado até homologação com readback.',
          style: TextStyle(color: _Studio.warning, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const _ActionBar(
          busy: false,
          actions: [
            _ActionSpec('Aplicar servidor', Icons.cloud_upload_outlined, null),
            _ActionSpec('Restaurar original', Icons.restore, null),
            _ActionSpec('Bloquear', Icons.lock_outline, null),
            _ActionSpec('Desbloquear', Icons.lock_open_outlined, null),
          ],
        ),
        const SizedBox(height: 18),
        _SerialTerminal(
          session: session,
          busy: busy,
          onSend: onManualCommand,
          onPosition: onPosition,
          onFullRead: onFullRead,
          onRepeat: onRepeat,
          onBaudRate: onBaudRate,
        ),
        const SizedBox(height: 18),
        _SerialRawCard(session: session, onClear: onClearLogs),
        const SizedBox(height: 18),
        _LogCaptureCard(
          session: session,
          usbConnected: session.connection.usbConnected,
          onStart: onStartCapture,
          onStop: onStopCapture,
          onClear: onClearCapture,
          onSaveCapture: onSaveCapture,
        ),
        const SizedBox(height: 18),
        _SerialDiagnosticCard(
          session: session,
          busy: busy,
          onTestAt: onTestAt,
          onTestMatrix: onTestMatrix,
          onEnding: onEnding,
          onDtr: onDtr,
          onRts: onRts,
        ),
        const SizedBox(height: 18),
        _ResponsiveCards(
          preferredWidth: 420,
          children: [
            _LabFeatureCard(
              title: 'Configuração original',
              icon: Icons.settings_input_component,
              child: session.configuration.original.isEmpty
                  ? const _EmptyText('Nenhuma configuração original salva.')
                  : Column(
                      children: [
                        for (final entry
                            in session.configuration.original.entries)
                          _KeyValue(
                              entry.key,
                              _maskedConfigurationValue(
                                  entry.key, entry.value)),
                      ],
                    ),
            ),
            _LabFeatureCard(
              title: 'Parser e diagnóstico',
              icon: Icons.data_object,
              child: session.diagnostics.isEmpty
                  ? const _EmptyText('Aguardando linhas reais para o parser.')
                  : Column(
                      children: [
                        for (final group in session.diagnostics)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(group.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            children: [
                              for (final entry in group.values.entries)
                                _KeyValue(entry.key, entry.value)
                            ],
                          ),
                      ],
                    ),
            ),
            const _LabFeatureCard(
              title: 'Canais e rotas',
              icon: Icons.account_tree_outlined,
              child: Column(
                children: [
                  _Capability(
                      'Serial bruto', 'Ativo via libserialport', Icons.usb),
                  _Capability('SMS', 'Futuro', Icons.sms_outlined),
                  _Capability('GPRS', 'Futuro', Icons.cell_tower_outlined),
                  _Capability('Rotas', 'Futuro', Icons.route_outlined),
                  _Capability('ESP32 Bridge', 'Futuro', Icons.memory_outlined),
                  _Capability(
                      'Perfis', 'Futuro', Icons.manage_accounts_outlined),
                ],
              ),
            ),
            _MapTechnicalCard(session: session, onMap: onMap),
          ],
        ),
        const SizedBox(height: 18),
        WorkOrderPayloadCard(
          payload: workOrderPayload,
          onCopy: onCopyWorkOrderPayload,
        ),
        const SizedBox(height: 18),
        _CommandPlanSection(plan: session.generatedCommandPlan),
        const SizedBox(height: 18),
        _TechnicalLogs(logs: session.logs),
      ],
    );
  }
}

class _HandshakeCard extends StatelessWidget {
  final TrackerSessionState session;
  final bool busy;
  final VoidCallback onAutoIdentify;
  final VoidCallback onFullScan;
  final ValueChanged<SuntechHandshakeProbe> onProbe;
  final VoidCallback onClear;

  const _HandshakeCard({
    required this.session,
    required this.busy,
    required this.onAutoIdentify,
    required this.onFullScan,
    required this.onProbe,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final result = session.handshakeResult;
    final enabled = session.connection.usbConnected && !busy;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Handshake Suntech',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: enabled ? onAutoIdentify : null,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Auto identificar rápido'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onFullScan : null,
                icon: const Icon(Icons.radar),
                label: const Text('Varredura completa'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.atProbe)
                    : null,
                child: const Text('AT'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.st8Probes[0])
                    : null,
                child: const Text('ST8 PST Ready'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.st8Probes[1])
                    : null,
                child: const Text('ST8 PST Version'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.st8Probes[3])
                    : null,
                child: const Text('ST8 Get JSON'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.legacyProbes[0])
                    : null,
                child: const Text('Legacy ReqVer'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.legacyProbes[1])
                    : null,
                child: const Text('Legacy StatusReq'),
              ),
              OutlinedButton(
                onPressed: enabled
                    ? () => onProbe(SuntechHandshakeEngine.legacyProbes[2])
                    : null,
                child: const Text('Legacy Preset'),
              ),
              TextButton.icon(
                onPressed:
                    result?.rawEvidence.isNotEmpty == true ? onClear : null,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpar evidências'),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _HandshakeValue(
                  'Porta', result?.portOk == true ? 'Validada' : 'Pendente'),
              _HandshakeValue('Família',
                  familyLabel(result?.family ?? session.selectedSuntechFamily)),
              _HandshakeValue('Modelo', result?.model ?? '-'),
              _HandshakeValue('ESN', result?.esn ?? '-'),
              _HandshakeValue('IMEI', result?.imei ?? '-'),
              _HandshakeValue('Firmware', result?.firmware ?? '-'),
              _HandshakeValue('Baudrate',
                  '${result?.baudRate ?? session.connection.baudRate}'),
              _HandshakeValue(
                  'Catálogo', '${result?.commandCatalog.length ?? 0} comandos'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _HandshakeValue('AT', _probeStatus(result, 'AT')),
              _HandshakeValue(
                  'ST8 PST Ready', _probeStatus(result, r'AT^$PSTRdy')),
              _HandshakeValue(
                  'ST8 PST Version', _probeStatus(result, r'AT^$PSTVer;1416')),
              _HandshakeValue(
                  'ST8 Get JSON', _probeStatus(result, r'AT^$PSTGetJson')),
              _HandshakeValue('Legacy ReqVer',
                  _probeStatus(result, 'AT^ST300CMD;;02;ReqVer')),
              _HandshakeValue('Legacy StatusReq',
                  _probeStatus(result, 'AT^ST300CMD;;02;StatusReq')),
              _HandshakeValue('Legacy Preset',
                  _probeStatus(result, 'AT^ST300CMD;;02;Preset')),
            ],
          ),
          const SizedBox(height: 12),
          _KeyValue('Última ação',
              result?.lastAction ?? 'Aguardando auto identificação'),
          if (result?.error != null) _KeyValue('Erro', result!.error!),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(12),
            color: _Studio.log,
            child: SingleChildScrollView(
              child: SelectableText(
                result?.rawEvidence.isNotEmpty == true
                    ? result!.rawEvidence.join('\n')
                    : 'Nenhuma evidência de handshake.',
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _probeStatus(SuntechHandshakeResult? result, String command) =>
    handshakeProbeStatusLabel(result?.probeStatuses[command]);

String _groupProbeStatus(
  SuntechHandshakeResult? result,
  List<SuntechHandshakeProbe> probes,
) {
  final statuses = probes
      .map((probe) => result?.probeStatuses[probe.command])
      .whereType<HandshakeProbeStatus>()
      .toList();
  if (statuses.contains(HandshakeProbeStatus.ok)) return 'OK';
  if (statuses.contains(HandshakeProbeStatus.error)) return 'erro';
  if (statuses.contains(HandshakeProbeStatus.canceled)) return 'cancelado';
  if (statuses.isNotEmpty &&
      statuses.every((status) =>
          status == HandshakeProbeStatus.noResponse ||
          status == HandshakeProbeStatus.echo)) {
    return 'sem resposta';
  }
  return 'pendente';
}

class _HandshakeValue extends StatelessWidget {
  final String label;
  final String value;

  const _HandshakeValue(this.label, this.value);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: _Studio.muted, fontSize: 11)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _EquipmentCatalogCard extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _EquipmentCatalogCard({
    required this.session,
    required this.controller,
  });

  Future<void> _copyCommand(
    BuildContext context,
    SuntechCommandDefinition definition,
  ) async {
    String command;
    try {
      command = controller.resolveCatalogCommand(definition);
    } catch (e) {
      debugPrint('TeltonikaCanCard: failed to resolve catalog command: $e');
      command = definition.commandTemplate;
    }
    await Clipboard.setData(ClipboardData(text: command));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comando copiado.')),
      );
    }
  }

  Future<void> _sendCommand(
    BuildContext context,
    SuntechCommandDefinition definition,
  ) async {
    try {
      await controller.sendCatalogCommand(definition);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = <SuntechCommandDefinition>[
      ...?session.handshakeResult?.commandCatalog.values,
    ];
    catalog.sort((left, right) => left.label.compareTo(right.label));
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_outlined, color: _Studio.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Catálogo do equipamento',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              Chip(label: Text('${catalog.length} comandos')),
            ],
          ),
          const SizedBox(height: 10),
          if (catalog.isEmpty)
            const _EmptyText('Catálogo ainda não carregado.')
          else
            for (final definition in catalog)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(definition.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(definition.commandTemplate,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (definition.requiresEsn)
                          const Chip(label: Text('exige ESN')),
                        if (definition.critical)
                          const Chip(label: Text('crítico')),
                        if (definition.requiresBackup)
                          const Chip(label: Text('exige backup')),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(definition.notes,
                        style: const TextStyle(color: _Studio.muted)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copyCommand(context, definition),
                          icon: const Icon(Icons.copy, size: 17),
                          label: const Text('Copiar comando'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              controller.canSendCatalogCommand(definition)
                                  ? () => _sendCommand(context, definition)
                                  : null,
                          icon: const Icon(Icons.send, size: 17),
                          label: Text(
                              definition.requiresEsn && !session.hasDeviceRead
                                  ? 'ESN necessário'
                                  : definition.critical
                                      ? 'Comando crítico'
                                      : 'Enviar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
        ],
      ),
    );
  }
}

class _NewGenNetworkCard extends StatefulWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _NewGenNetworkCard({required this.session, required this.controller});

  @override
  State<_NewGenNetworkCard> createState() => _NewGenNetworkCardState();
}

class _NewGenNetworkCardState extends State<_NewGenNetworkCard> {
  final _apn = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  final _port = TextEditingController(text: '5011');
  final _agps = TextEditingController(text: 'https://example.com/agps');
  final _band = TextEditingController(text: '03');
  NewGenNetworkCommands? _commands;
  bool _busy = false;

  @override
  void dispose() {
    _apn.dispose();
    _username.dispose();
    _password.dispose();
    _server.dispose();
    _port.dispose();
    _agps.dispose();
    _band.dispose();
    super.dispose();
  }

  void _generate() {
    try {
      final commands = widget.controller.generateNewGenNetworkCommands(
        apn: _apn.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        server: _server.text.trim(),
        port: int.tryParse(_port.text) ?? 0,
        agpsUrl: _agps.text.trim(),
        scanningBand: _band.text.trim(),
      );
      setState(() => _commands = commands);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _apply() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar rede New Gen?'),
        content: const Text(
          'Entendo que este comando altera APN/servidor do rastreador e exige confirmação RPR e readback.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entendo e aplicar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.writeNewGenNetwork(
        apn: _apn.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        server: _server.text.trim(),
        port: int.tryParse(_port.text) ?? 0,
        agpsUrl: _agps.text.trim(),
        scanningBand: _band.text.trim(),
        explicitlyConfirmed: true,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApply = widget.session.selectedSuntechFamily ==
            SuntechCommandFamily.newGenSt8210St8310 &&
        widget.session.hasDeviceRead &&
        widget.session.connection.usbConnected &&
        widget.session.hasValidBackup &&
        !_busy;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Rede / APN New Gen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'PRG permanece bloqueado para Legacy. Confirmações RPR não equivalem a readback.',
            style: TextStyle(color: _Studio.warning),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _NetworkField(controller: _apn, label: 'APN'),
              _NetworkField(controller: _username, label: 'Usuário'),
              _NetworkField(
                  controller: _password, label: 'Senha', obscureText: true),
              _NetworkField(controller: _server, label: 'Servidor'),
              _NetworkField(controller: _port, label: 'Porta'),
              _NetworkField(controller: _agps, label: 'AGPS URL', width: 330),
              _NetworkField(controller: _band, label: 'Banda / scanningBand'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.session.selectedSuntechFamily ==
                            SuntechCommandFamily.newGenSt8210St8310 &&
                        widget.session.hasDeviceRead
                    ? _generate
                    : null,
                icon: const Icon(Icons.code),
                label: const Text('Gerar comando'),
              ),
              OutlinedButton.icon(
                onPressed: _commands == null
                    ? null
                    : () => Clipboard.setData(
                          ClipboardData(
                              text: '${_commands!.part1}\n${_commands!.part2}'),
                        ),
                icon: const Icon(Icons.copy),
                label: const Text('Copiar comando'),
              ),
              FilledButton.icon(
                onPressed: canApply ? _apply : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Aplicar rede New Gen'),
              ),
            ],
          ),
          if (_commands != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              '${_commands!.part1}\n\n${_commands!.part2}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
          if (widget.session.networkWriteResult != null) ...[
            const Divider(height: 28),
            Text(
              'Resultado: ${widget.session.networkWriteResult!.status.name} · readback: ${widget.session.networkWriteResult!.readbackConfirmed ? 'confirmado' : 'pendente'}',
              style: TextStyle(
                color: widget.session.networkWriteResult!.status ==
                        NetworkWriteStatus.failed
                    ? _Studio.danger
                    : _Studio.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParameterFormCard extends StatefulWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;
  final String title;
  final String hint;
  final List<int> parameterIds;
  final String applyLabel;
  final String applyTitle;
  final String applyMessage;

  const _ParameterFormCard({
    required this.session,
    required this.controller,
    required this.title,
    required this.hint,
    required this.parameterIds,
    required this.applyLabel,
    required this.applyTitle,
    required this.applyMessage,
  });

  @override
  State<_ParameterFormCard> createState() => _ParameterFormCardState();
}

class _ParameterFormCardState extends State<_ParameterFormCard> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _enumSelections = {};
  final Map<int, String> _seeded = {};
  TeltonikaNetworkCommands? _commands;
  bool _busy = false;

  Map<int, String> get _capturedValues =>
      widget.session.logCapture.analysis?.parameterValues ?? const {};

  int get _capturedCount => widget.parameterIds
      .where((parameterId) => _capturedValues.containsKey(parameterId))
      .length;

  static String _defaultFor(ConfigFieldSpec spec) {
    final value = spec.defaultValue;
    if (value == null) return '';
    if (spec.isEnum && spec.enumValues!.containsKey('$value')) return '$value';
    return '$value';
  }

  @override
  void initState() {
    super.initState();
    for (final parameterId in widget.parameterIds) {
      final spec = configFieldFor(parameterId);
      final captured = _capturedValues[parameterId];
      final seeded = captured ?? _defaultFor(spec);
      final controller = TextEditingController(text: seeded);
      _controllers[parameterId] = controller;
      _seeded[parameterId] = seeded;
      if (spec.isEnum) _enumSelections[parameterId] = seeded;
    }
  }

  @override
  void didUpdateWidget(covariant _ParameterFormCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAnalysis = oldWidget.session.logCapture.analysis;
    final newAnalysis = widget.session.logCapture.analysis;
    if (identical(oldAnalysis, newAnalysis) || newAnalysis == null) return;
    var changed = false;
    for (final parameterId in widget.parameterIds) {
      final captured = newAnalysis.parameterValues[parameterId];
      if (captured == null) continue;
      final controller = _controllers[parameterId];
      if (controller == null) continue;
      if (controller.text != _seeded[parameterId]) continue;
      controller.text = captured;
      _seeded[parameterId] = captured;
      if (configFieldFor(parameterId).isEnum) {
        _enumSelections[parameterId] = captured;
      }
      changed = true;
    }
    if (changed) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<int, String> _values() => {
        for (final parameterId in widget.parameterIds)
          parameterId: _enumSelections[parameterId] ??
              _controllers[parameterId]!.text.trim(),
      };

  String? _firstError(Map<int, String> values) {
    for (final parameterId in widget.parameterIds) {
      final spec = configFieldFor(parameterId);
      final error = spec.validate(values[parameterId] ?? '');
      if (error != null) return '${spec.label}: $error';
    }
    return null;
  }

  void _generate() {
    final values = _values();
    final firstError = _firstError(values);
    if (firstError != null) {
      _showError(firstError);
      return;
    }
    try {
      final commands = widget.controller.generateTeltonikaConfigPlan(values);
      setState(() => _commands = commands);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _apply() async {
    final values = _values();
    final firstError = _firstError(values);
    if (firstError != null) {
      _showError(firstError);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.applyTitle),
        content: Text(widget.applyMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entendo e aplicar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.writeTeltonikaConfig(
        values: values,
        explicitlyConfirmed: true,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApply = widget.session.connection.usbConnected && !_busy;
    final fields = <Widget>[];
    for (final parameterId in widget.parameterIds) {
      final spec = configFieldFor(parameterId);
      if (spec.isEnum) {
        fields.add(SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: _enumSelections[parameterId],
            decoration: InputDecoration(labelText: spec.label),
            items: [
              for (final entry in spec.enumValues!.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() {
              if (value != null) _enumSelections[parameterId] = value;
            }),
          ),
        ));
      } else {
        fields.add(_NetworkField(
          controller: _controllers[parameterId]!,
          label:
              spec.unit != null ? '${spec.label} (${spec.unit})' : spec.label,
          obscureText: spec.obscureText,
          width: 220,
        ));
      }
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(widget.hint, style: const TextStyle(color: _Studio.warning)),
          if (_capturedCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.download_done_outlined,
                    size: 15, color: _Studio.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_capturedCount de ${widget.parameterIds.length} parâmetros '
                    'preenchidos com os valores capturados no log.',
                    style: const TextStyle(
                        color: _Studio.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: fields),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.code),
                label: const Text('Gerar comando'),
              ),
              OutlinedButton.icon(
                onPressed: _commands == null
                    ? null
                    : () => Clipboard.setData(
                          ClipboardData(text: _commands!.preview),
                        ),
                icon: const Icon(Icons.copy),
                label: const Text('Copiar comando'),
              ),
              FilledButton.icon(
                onPressed: canApply ? _apply : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(widget.applyLabel),
              ),
            ],
          ),
          if (_commands != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _commands!.preview,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeltonikaNetworkCard extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _TeltonikaNetworkCard(
      {required this.session, required this.controller});

  @override
  Widget build(BuildContext context) => _ParameterFormCard(
        session: session,
        controller: controller,
        title: 'Rede / APN Teltonika',
        hint:
            'Protocolo USB Configurator: :cfg_setparam/<id>:<valor> + :cfg_save. Confirme o readback <SETPARAM_RESULT>:1.',
        parameterIds: const [2001, 2002, 2003, 2004, 2005, 2006],
        applyLabel: 'Aplicar rede Teltonika',
        applyTitle: 'Aplicar rede Teltonika?',
        applyMessage:
            'Entendo que este comando altera APN/servidor/porta do rastreador via USB Configurator e devo confirmar o readback <SETPARAM_RESULT>:1.',
      );
}

class _TeltonikaMovingCard extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _TeltonikaMovingCard({required this.session, required this.controller});

  @override
  Widget build(BuildContext context) => _ParameterFormCard(
        session: session,
        controller: controller,
        title: 'Dados de tempo / Data Acquisition',
        hint:
            'Aquisição em movimento (Home network): 10050–10055. Campos gerados do catálogo UCE.',
        parameterIds: const [10050, 10051, 10052, 10053, 10054, 10055],
        applyLabel: 'Aplicar dados de tempo',
        applyTitle: 'Aplicar dados de tempo?',
        applyMessage:
            'Entendo que estes comandos alteram período, distância, ângulo, velocidade e registros mínimos de aquisição e devo confirmar o readback <SETPARAM_RESULT>:1.',
      );
}

class _TeltonikaBackupCard extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _TeltonikaBackupCard({required this.session, required this.controller});

  @override
  Widget build(BuildContext context) => _ParameterFormCard(
        session: session,
        controller: controller,
        title: 'Servidor backup Teltonika',
        hint:
            'Segundo servidor (modo habilita o envio): 2010 = modo, 2007/2008/2009 = domínio, porta e protocolo.',
        parameterIds: const [2010, 2007, 2008, 2009],
        applyLabel: 'Aplicar servidor backup',
        applyTitle: 'Aplicar servidor backup?',
        applyMessage:
            'Entendo que estes comandos alteram o segundo servidor (domínio, porta, protocolo e modo) e devo confirmar o readback <SETPARAM_RESULT>:1.',
      );
}

class _TeltonikaSystemCard extends StatelessWidget {
  final TrackerSessionState session;
  final TrackerStudioController controller;

  const _TeltonikaSystemCard({required this.session, required this.controller});

  @override
  Widget build(BuildContext context) => _ParameterFormCard(
        session: session,
        controller: controller,
        title: 'Sistema Teltonika',
        hint:
            'Voltagem de ignição (104/105), NTP (901–903) e Low Power Mode (19500–19504). Campos gerados do catálogo UCE.',
        parameterIds: const [
          104,
          105,
          901,
          902,
          903,
          19500,
          19501,
          19502,
          19504
        ],
        applyLabel: 'Aplicar sistema',
        applyTitle: 'Aplicar sistema?',
        applyMessage:
            'Entendo que estes comandos alteram voltagem/NTP/low power do rastreador e devo confirmar o readback <SETPARAM_RESULT>:1.',
      );
}

class TeltonikaCanCard extends StatefulWidget {
  final TrackerSessionState session;
  final CanMappingStore? store;

  const TeltonikaCanCard({super.key, required this.session, this.store});

  @override
  State<TeltonikaCanCard> createState() => TeltonikaCanCardState();
}

class TeltonikaCanCardState extends State<TeltonikaCanCard> {
  late final CanMappingStore _store;
  bool _loaded = false;
  bool _busy = false;
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _unitControllers = {};
  final Map<int, TextEditingController> _noteControllers = {};

  List<TeltonikaObservedIo> get _candidates {
    final analysis = widget.session.logCapture.analysis;
    if (analysis == null) return const [];
    final candidates = analysis.observedIos
        .where((io) => io.definitionStatus == 'unknown')
        .toList()
      ..sort((a, b) => a.avlId.compareTo(b.avlId));
    return candidates;
  }

  List<TeltonikaGeneratedAvlRecord> get _records =>
      widget.session.logCapture.analysis?.avlRecords ?? const [];

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? CanMappingStore();
    _load();
  }

  Future<void> _load() async {
    await _store.load();
    for (final io in _candidates) {
      final mapping = _store.byId(io.avlId);
      _nameControllers[io.avlId] =
          TextEditingController(text: mapping?.name ?? 'IO ${io.avlId}');
      _unitControllers[io.avlId] =
          TextEditingController(text: mapping?.unit ?? '');
      _noteControllers[io.avlId] =
          TextEditingController(text: mapping?.note ?? '');
    }
    for (final mapping in _store.all) {
      _nameControllers.putIfAbsent(
          mapping.avlId, () => TextEditingController(text: mapping.name));
      _unitControllers.putIfAbsent(
          mapping.avlId, () => TextEditingController(text: mapping.unit ?? ''));
      _noteControllers.putIfAbsent(
          mapping.avlId, () => TextEditingController(text: mapping.note ?? ''));
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _unitControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _map(int avlId) async {
    final name = _nameControllers[avlId]?.text.trim() ?? '';
    if (name.isEmpty) {
      _showMessage('Informe um nome para o IO $avlId antes de mapear.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _store.upsert(CanSensorMapping(
        avlId: avlId,
        name: name,
        unit: _trimmedOrNull(_unitControllers[avlId]?.text),
        note: _trimmedOrNull(_noteControllers[avlId]?.text),
      ));
      if (mounted) {
        setState(() {});
        _showMessage('IO $avlId mapeado como "$name" e salvo em arquivo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(int avlId) async {
    setState(() => _busy = true);
    try {
      await _store.remove(avlId);
      _nameControllers[avlId]?.text = 'IO $avlId';
      _unitControllers[avlId]?.text = '';
      _noteControllers[avlId]?.text = '';
      if (mounted) {
        setState(() {});
        _showMessage('Mapeamento do IO $avlId removido.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _valueHistory(int avlId) {
    final values = <String>[];
    for (final record in _records) {
      final value = record.ioElements[avlId];
      if (value != null) values.add('$value');
    }
    return values.isEmpty ? '—' : values.join(' → ');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.memory, size: 20, color: _Studio.primary),
              SizedBox(width: 8),
              Text('CAN / Sensores mapeados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'IOs observados na captura sem definição no catálogo são candidatos a '
            'sensor CAN. Mapeie AVL ID → nome e o mapeamento é salvo em arquivo '
            'para as próximas sessões.',
            style: TextStyle(color: _Studio.warning, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (!_loaded)
            const _EmptyText('Carregando mapeamento CAN...')
          else ...[
            _buildCandidates(),
            const SizedBox(height: 16),
            _buildPersisted(),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidates() {
    final candidates = _candidates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Candidatos da última captura (${candidates.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          const _EmptyText(
              'Nenhum IO sem catálogo na última análise. Capture uma ação física '
              'para descobrir sensores CAN.')
        else
          for (final io in candidates) ...[
            _buildCandidateTile(io),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildCandidateTile(TeltonikaObservedIo io) {
    final mapped = _store.byId(io.avlId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Studio.surface,
        border: Border.all(
            color: mapped != null
                ? _Studio.success.withValues(alpha: 0.6)
                : _Studio.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('IO ${io.avlId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(width: 8),
              if (mapped != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Studio.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    mapped.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              const Spacer(),
              Text('${io.packetReferences.length} ocorrência(s)',
                  style: const TextStyle(color: _Studio.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          _KeyValue('Último valor', '${io.rawValue}'),
          _KeyValue('Histórico', _valueHistory(io.avlId)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _nameControllers[io.avlId],
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _unitControllers[io.avlId],
                  decoration: const InputDecoration(labelText: 'Unidade'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _noteControllers[io.avlId],
                  decoration: const InputDecoration(labelText: 'Observação'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _map(io.avlId),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(mapped != null ? 'Atualizar mapeamento' : 'Mapear'),
              ),
              if (mapped != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _busy ? null : () => _remove(io.avlId),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover'),
                  style: TextButton.styleFrom(foregroundColor: _Studio.danger),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersisted() {
    final mappings = _store.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mapeados (persistidos) (${mappings.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        if (mappings.isEmpty)
          const _EmptyText('Nenhum sensor CAN mapeado ainda.')
        else
          for (final mapping in mappings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('IO ${mapping.avlId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(mapping.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  if (mapping.unit != null) ...[
                    const SizedBox(width: 6),
                    Text('(${mapping.unit})',
                        style: const TextStyle(
                            color: _Studio.muted, fontSize: 11)),
                  ],
                  if (mapping.note != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(mapping.note!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _Studio.muted, fontSize: 11)),
                    ),
                  ],
                  if (mapping.note == null) const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => _remove(mapping.avlId),
                    style: TextButton.styleFrom(
                        foregroundColor: _Studio.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 6)),
                    child:
                        const Text('Remover', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _NetworkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final double width;
  final bool obscureText;

  const _NetworkField({
    required this.controller,
    required this.label,
    this.width = 220,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _InstallationProfileCard extends StatelessWidget {
  final InstallationProfile profile;
  final bool hasBackup;
  final ValueChanged<InstallationMode> onInstallationMode;
  final ValueChanged<IgnitionMode> onIgnitionMode;
  final ValueChanged<TimingProfile> onTimingProfile;
  final VoidCallback onGenerate;
  final VoidCallback onEdit;

  const _InstallationProfileCard({
    required this.profile,
    required this.hasBackup,
    required this.onInstallationMode,
    required this.onIgnitionMode,
    required this.onTimingProfile,
    required this.onGenerate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ignitionWarning = profile.ignitionMode == IgnitionMode.virtual
        ? 'Ignição virtual depende de movimento/tensão/evento. Validar comportamento em campo.'
        : 'Ignição física depende da entrada correta do fio pós-chave.';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Perfil da instalação',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<InstallationMode>(
                segments: const [
                  ButtonSegment(
                      value: InstallationMode.car, label: Text('Carro')),
                  ButtonSegment(
                      value: InstallationMode.motorcycle, label: Text('Moto')),
                  ButtonSegment(
                      value: InstallationMode.custom,
                      label: Text('Personalizado')),
                ],
                selected: {profile.mode},
                onSelectionChanged: (value) => onInstallationMode(value.first),
              ),
              SegmentedButton<IgnitionMode>(
                segments: const [
                  ButtonSegment(
                      value: IgnitionMode.physical,
                      label: Text('Ignição física')),
                  ButtonSegment(
                      value: IgnitionMode.virtual,
                      label: Text('Ignição virtual')),
                ],
                selected: {profile.ignitionMode},
                onSelectionChanged: (value) => onIgnitionMode(value.first),
              ),
              SegmentedButton<TimingProfile>(
                segments: const [
                  ButtonSegment(
                      value: TimingProfile.standard, label: Text('Padrão')),
                  ButtonSegment(
                      value: TimingProfile.economy, label: Text('Econômico')),
                  ButtonSegment(
                      value: TimingProfile.aggressive,
                      label: Text('Agressivo')),
                  ButtonSegment(
                      value: TimingProfile.custom,
                      label: Text('Personalizado')),
                ],
                selected: {profile.timingProfile},
                onSelectionChanged: (value) => onTimingProfile(value.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text('Movimento: ${profile.movingIntervalSeconds} s'),
              Text('Parado: ${profile.stoppedIntervalSeconds} s'),
              Text('Ignição ligada: ${profile.ignitionOnIntervalSeconds} s'),
              Text(
                  'Ignição desligada: ${profile.ignitionOffIntervalSeconds} s'),
              Text('Curva: ${profile.curveAngleDegrees}°'),
              Text('Distância: ${profile.distanceMeters} m'),
              Text('Sleep: ${profile.enableSleep ? 'ligado' : 'desligado'}'),
              Text(
                  'Bloqueio: ${profile.enableBlocking ? 'habilitado' : 'desabilitado'}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(ignitionWarning,
              style: const TextStyle(
                  color: _Studio.warning, fontWeight: FontWeight.w700)),
          if (profile.enableBlocking)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Bloqueio exige confirmação e readback. Não será aplicado automaticamente.',
                style: TextStyle(
                    color: _Studio.danger, fontWeight: FontWeight.w700),
              ),
            ),
          if (!hasBackup)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Leia e salve a configuração original antes de aplicar.',
                style: TextStyle(color: _Studio.warning),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text('Editar tempos')),
              FilledButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.playlist_add, size: 17),
                  label: const Text('Gerar plano')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomProfileValues {
  final int moving;
  final int stopped;
  final int ignitionOn;
  final int ignitionOff;
  final int curve;
  final int distance;
  final bool sleep;
  final bool blocking;

  const _CustomProfileValues({
    required this.moving,
    required this.stopped,
    required this.ignitionOn,
    required this.ignitionOff,
    required this.curve,
    required this.distance,
    required this.sleep,
    required this.blocking,
  });
}

class _ProfileEditorDialog extends StatefulWidget {
  final InstallationProfile profile;

  const _ProfileEditorDialog({required this.profile});

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final List<TextEditingController> _controllers;
  late bool _sleep;
  late bool _blocking;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _controllers = [
      profile.movingIntervalSeconds,
      profile.stoppedIntervalSeconds,
      profile.ignitionOnIntervalSeconds,
      profile.ignitionOffIntervalSeconds,
      profile.curveAngleDegrees,
      profile.distanceMeters,
    ].map((value) => TextEditingController(text: '$value')).toList();
    _sleep = profile.enableSleep;
    _blocking = profile.enableBlocking;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Movimento (s)',
      'Parado (s)',
      'Ignição ligada (s)',
      'Ignição desligada (s)',
      'Curva (graus)',
      'Distância (m)'
    ];
    return AlertDialog(
      title: const Text('Tempos personalizados'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < labels.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: labels[index],
                        border: const OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
              SwitchListTile(
                  title: const Text('Habilitar sleep'),
                  value: _sleep,
                  onChanged: (value) => setState(() => _sleep = value)),
              SwitchListTile(
                  title: const Text('Habilitar bloqueio'),
                  value: _blocking,
                  onChanged: (value) => setState(() => _blocking = value)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    final values = _controllers
        .map((controller) => int.tryParse(controller.text))
        .toList();
    if (values.any((value) => value == null || value <= 0)) return;
    Navigator.pop(
      context,
      _CustomProfileValues(
        moving: values[0]!,
        stopped: values[1]!,
        ignitionOn: values[2]!,
        ignitionOff: values[3]!,
        curve: values[4]!,
        distance: values[5]!,
        sleep: _sleep,
        blocking: _blocking,
      ),
    );
  }
}

class _CommandPlanSection extends StatelessWidget {
  final List<GeneratedCommandPlan> plan;

  const _CommandPlanSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Plano de comandos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (plan.isEmpty)
            const _EmptyText(
                'Gere um plano no modo Operacional para revisar os comandos.')
          else ...[
            for (final item in plan)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: _Studio.border),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(item.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                        Text(item.status.toUpperCase(),
                            style: const TextStyle(
                                color: _Studio.warning,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(item.description,
                        style: const TextStyle(color: _Studio.muted)),
                    const SizedBox(height: 5),
                    SelectableText(item.commandPreview,
                        style: const TextStyle(fontFamily: 'monospace')),
                    const SizedBox(height: 5),
                    Text(
                        'Crítico: ${item.critical ? 'sim' : 'não'} · Backup: ${item.requiresBackup ? 'obrigatório' : 'não'} · Readback: ${item.requiresReadback ? 'obrigatório' : 'não'}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: item.commandPreview)),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar comando'),
                        ),
                        const FilledButton(
                            onPressed: null, child: Text('Aplicar')),
                      ],
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () {
                final text = plan
                    .map((item) =>
                        '${item.title}\n${item.description}\n${item.commandPreview}\nStatus: ${item.status}')
                    .join('\n\n');
                Clipboard.setData(ClipboardData(text: text));
              },
              icon: const Icon(Icons.copy_all, size: 17),
              label: const Text('Copiar plano'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SerialTerminal extends StatefulWidget {
  final TrackerSessionState session;
  final bool busy;
  final Future<void> Function(String command) onSend;
  final VoidCallback onPosition;
  final VoidCallback onFullRead;
  final VoidCallback onRepeat;
  final Future<void> Function(int baudRate) onBaudRate;

  const _SerialTerminal({
    required this.session,
    required this.busy,
    required this.onSend,
    required this.onPosition,
    required this.onFullRead,
    required this.onRepeat,
    required this.onBaudRate,
  });

  @override
  State<_SerialTerminal> createState() => _SerialTerminalState();
}

class _SerialTerminalState extends State<_SerialTerminal> {
  final _commandController = TextEditingController();

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.session.connection.usbConnected && !widget.busy;
    final family = widget.session.selectedSuntechFamily;
    final serialLogs = widget.session.logs
        .where((log) =>
            log.source == 'SEND' ||
            log.source == 'READ' ||
            log.source == 'ERROR')
        .toList()
        .reversed
        .take(20);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Terminal serial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Comando: ${widget.session.connection.commandPortName}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text('Retorno: ${widget.session.connection.readPortName}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              DropdownButton<int>(
                value: widget.session.connection.baudRate,
                items: const [9600, 19200, 38400, 57600, 115200]
                    .map((baud) => DropdownMenuItem(
                        value: baud, child: Text('$baud baud')))
                    .toList(),
                onChanged: enabled
                    ? (baud) {
                        if (baud != null &&
                            baud != widget.session.connection.baudRate) {
                          widget.onBaudRate(baud);
                        }
                      }
                    : null,
              ),
              const Text('Trocar baudrate reinicia a conexão serial.',
                  style: TextStyle(color: _Studio.warning, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Comando manual',
                    hintText: 'AT^CMD;;03;01',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: enabled ? (_) => _send() : null,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: enabled ? _send : null,
                icon: const Icon(Icons.send, size: 17),
                label: const Text('Enviar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                  onPressed: enabled ? () => widget.onSend('AT') : null,
                  child: const Text('AT básico')),
              if (family == SuntechCommandFamily.legacySt300St310) ...[
                OutlinedButton(
                  onPressed: enabled
                      ? () =>
                          widget.onSend(SuntechLegacyCommands.preset.command())
                      : null,
                  child: const Text('ST300CMD Preset'),
                ),
                OutlinedButton(
                  onPressed: enabled
                      ? () =>
                          widget.onSend(SuntechLegacyCommands.status.command())
                      : null,
                  child: const Text('ST300CMD StatusReq'),
                ),
                const OutlinedButton(
                    onPressed: null, child: Text('ST300NTN Rede')),
                const OutlinedButton(
                    onPressed: null, child: Text('Comandos legados')),
              ],
              if (family == SuntechCommandFamily.newGenSt8210St8310) ...[
                OutlinedButton(
                  onPressed: enabled
                      ? () => widget.onSend(
                            SuntechNewGenCommands.status.command(
                              esn: widget.session.hasDeviceRead
                                  ? widget.session.device.esn
                                  : '',
                            ),
                          )
                      : null,
                  child: const Text('Status STT'),
                ),
                OutlinedButton(
                  onPressed: enabled
                      ? () => widget.onSend(
                            SuntechNewGenCommands.preset.command(
                              esn: widget.session.hasDeviceRead
                                  ? widget.session.device.esn
                                  : '',
                            ),
                          )
                      : null,
                  child: const Text('PRESET New Gen'),
                ),
                const OutlinedButton(
                    onPressed: null, child: Text('PRG parametrizado')),
              ],
              if (family == SuntechCommandFamily.legacySt300St310 ||
                  family == SuntechCommandFamily.newGenSt8210St8310) ...[
                OutlinedButton(
                    onPressed: enabled ? widget.onPosition : null,
                    child: const Text('Solicitar posição')),
                OutlinedButton(
                    onPressed: enabled ? widget.onFullRead : null,
                    child: const Text('Leitura segura completa')),
              ],
              OutlinedButton(
                onPressed: enabled &&
                        widget.session.manualCommand.lastCommand.isNotEmpty
                    ? widget.onRepeat
                    : null,
                child: const Text('Repetir último comando'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _Studio.log, borderRadius: BorderRadius.circular(10)),
            child: serialLogs.isEmpty
                ? const Text('Nenhuma linha serial recebida.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontFamily: 'monospace'))
                : ListView(
                    children: [
                      for (final log in serialLogs)
                        SelectableText(
                          '${log.time} ${log.source.padRight(5)} ${log.message}',
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11,
                              fontFamily: 'monospace'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    await widget.onSend(_commandController.text);
  }
}

class _SerialRawCard extends StatelessWidget {
  final TrackerSessionState session;
  final VoidCallback onClear;

  const _SerialRawCard({required this.session, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final rawLogs = session.logs
        .where((log) => log.source == 'READ_ASCII' || log.source == 'READ_HEX')
        .toList();
    final lastAscii = _lastMessage(rawLogs, 'READ_ASCII');
    final lastHex = _lastMessage(rawLogs, 'READ_HEX');
    final recent = rawLogs.reversed.take(20).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Serial RAW',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _KeyValue('ASCII', lastAscii ?? '-'),
          _KeyValue('HEX', lastHex ?? '-'),
          const SizedBox(height: 8),
          Container(
            height: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _Studio.log, borderRadius: BorderRadius.circular(10)),
            child: recent.isEmpty
                ? const Text('Nenhum byte recebido.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontFamily: 'monospace'))
                : ListView(
                    children: [
                      for (final log in recent)
                        SelectableText(
                          '${log.time} ${log.source.padRight(10)} ${log.message}',
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11,
                              fontFamily: 'monospace'),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: recent.isEmpty
                    ? null
                    : () {
                        final text = recent.reversed
                            .map((log) =>
                                '${log.time} ${log.source} ${log.message}')
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                      },
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Copiar logs'),
              ),
              OutlinedButton.icon(
                onPressed: recent.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Limpar logs'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _lastMessage(List<LogEntry> logs, String source) {
    for (final log in logs.reversed) {
      if (log.source == source) return log.message;
    }
    return null;
  }
}

class _LogCaptureCard extends StatelessWidget {
  final TrackerSessionState session;
  final bool usbConnected;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final VoidCallback onSaveCapture;

  const _LogCaptureCard({
    required this.session,
    required this.usbConnected,
    required this.onStart,
    required this.onStop,
    required this.onClear,
    required this.onSaveCapture,
  });

  @override
  Widget build(BuildContext context) {
    final capture = session.logCapture;
    final analysis = capture.analysis;
    final diff = capture.diff;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(capture.active ? Icons.radar : Icons.analytics_outlined,
                  color: capture.active ? _Studio.danger : _Studio.primary,
                  size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Captura e análise de logs',
                    style: TextStyle(
                        color: _Studio.text, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Toque em "Analisar", execute a ação física no veículo e toque em "Parar análise". '
            'O diff mostra qual pacote mudou e qual IO (sensor CAN) foi afetado.',
            style: TextStyle(color: _Studio.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: usbConnected && !capture.active ? onStart : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Analisar'),
              ),
              FilledButton.icon(
                onPressed: capture.active ? onStop : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _Studio.danger,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Parar análise'),
              ),
              OutlinedButton.icon(
                onPressed: capture.capturedLines.isNotEmpty || analysis != null
                    ? onClear
                    : null,
                icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                label: const Text('Limpar'),
              ),
              if (analysis != null)
                OutlinedButton.icon(
                  onPressed: () {
                    final text = _analysisText(capture);
                    Clipboard.setData(ClipboardData(text: text));
                  },
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Copiar análise'),
                ),
              if (analysis != null)
                OutlinedButton.icon(
                  onPressed: onSaveCapture,
                  icon: const Icon(Icons.save_outlined, size: 17),
                  label: const Text('Salvar logs para análise'),
                ),
            ],
          ),
          if (capture.active) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const TrackerSignalPulse(size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Capturando desde ${capture.startedAt} · '
                    '${capture.capturedLines.length} linha(s) capturada(s). '
                    'Execute a ação física e depois pare a análise.',
                    style: const TextStyle(
                        color: _Studio.danger, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          if (analysis != null) ...[
            const SizedBox(height: 16),
            _buildDevice(analysis.device, analysis),
            if (analysis.parameterValues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildParameters(analysis),
            ],
            if (diff != null) ...[
              const SizedBox(height: 12),
              _buildDiff(diff),
            ],
            const SizedBox(height: 12),
            _buildRawPreview(capture.capturedLines),
          ],
        ],
      ),
    );
  }

  Widget _buildDevice(
      DetectedTeltonikaDevice? device, TeltonikaCaptureAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Resumo da captura',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        _KeyValue(
          'Dispositivo',
          device == null
              ? 'Não identificado'
              : '${device.model ?? 'Teltonika'} (confiança ${device.confidence.toStringAsFixed(0)}%)',
        ),
        if (device?.imei != null) _KeyValue('IMEI', _maskImei(device!.imei!)),
        _KeyValue('Registros AVL', '${analysis.avlRecords.length}'),
        _KeyValue('IOs observados', '${analysis.observedIos.length}'),
        _KeyValue('Comandos config', '${analysis.configCommands.length}'),
        _KeyValue('Linhas', '${analysis.rawLines.length}'),
      ],
    );
  }

  Widget _buildParameters(TeltonikaCaptureAnalysis analysis) {
    final entries = analysis.parameterValues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Parâmetros vistos na captura',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Text('${entries.length}',
                style: const TextStyle(color: _Studio.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        for (final entry in entries)
          _KeyValue(
            _parameterLabel(entry.key),
            analysis.confirmedParameters.contains(entry.key)
                ? '${entry.value} (confirmado)'
                : entry.value,
          ),
      ],
    );
  }

  String _parameterLabel(int parameterId) {
    final definition = UceRegistry().parameters.getByParameterId(parameterId);
    return definition?.name ?? 'ID $parameterId';
  }

  Widget _buildDiff(TeltonikaCaptureDiff diff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Alterações identificadas',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: diff.hasChanges ? _Studio.warning : _Studio.success,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                diff.hasChanges
                    ? '${diff.ioChanges.length} IO(s) alterado(s)'
                    : 'Sem alterações',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: diff.hasChanges ? _Studio.danger : Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _KeyValue('Pacotes com alteração', '${diff.changedRecordCount}'),
        if (diff.changedPackets.isNotEmpty) ...[
          const SizedBox(height: 4),
          _packetChips(diff.changedPackets),
        ],
        const SizedBox(height: 6),
        if (diff.ioChanges.isEmpty)
          const _EmptyText(
              'Nenhum IO alterou durante a captura. Repita com outra ação física.')
        else
          for (final change in diff.ioChanges) _IoChangeTile(change: change),
        if (diff.unknownChangedIos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _Studio.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Studio.warning.withValues(alpha: 0.5)),
            ),
            child: Text(
              'IOs sem definição no catálogo foram alterados '
              '(${diff.unknownChangedIos.map((c) => c.avlId).join(', ')}) — '
              'são candidatos a sensores CAN a mapear.',
              style: const TextStyle(
                  color: _Studio.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _packetChips(List<TeltonikaChangedPacket> packets) {
    final visible = packets.take(12).toList();
    final remaining = packets.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final packet in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _Studio.surface,
              border: Border.all(color: _Studio.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pacote #${packet.recordIndex + 1} · '
              '${packet.changedIoIds.length} IO(s)',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        if (remaining > 0)
          Text('+$remaining',
              style: const TextStyle(
                  color: _Studio.muted, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildRawPreview(List<String> lines) {
    final preview = lines.reversed.take(24).toList().reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Linhas capturadas (${lines.length})',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: _Studio.muted)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _Studio.log,
            borderRadius: BorderRadius.circular(10),
          ),
          child: preview.isEmpty
              ? const Text('Nenhuma linha capturada.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11))
              : ListView(
                  children: [
                    for (final line in preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          line,
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10,
                              fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _analysisText(LogCaptureState capture) {
    final analysis = capture.analysis;
    final diff = capture.diff;
    final buffer = StringBuffer()
      ..writeln('Tracker Studio — Análise de captura')
      ..writeln('Início: ${capture.startedAt}')
      ..writeln('Linhas: ${capture.capturedLines.length}');
    if (analysis != null) {
      buffer
        ..writeln(
            'Dispositivo: ${analysis.device?.model ?? 'Não identificado'}')
        ..writeln('Registros AVL: ${analysis.avlRecords.length}')
        ..writeln('IOs observados: ${analysis.observedIos.length}')
        ..writeln('Comandos config: ${analysis.configCommands.length}');
    }
    if (diff != null) {
      buffer.writeln('Pacotes com alteração: ${diff.changedRecordCount}');
      buffer.writeln('IOs alterados: ${diff.ioChanges.length}');
      for (final change in diff.ioChanges) {
        buffer.writeln(
            ' - ${change.displayLabel}: ${_formatIoValue(change.beforeNormalized ?? change.before)}${change.unit == null ? '' : ' ${change.unit}'}'
            ' -> ${_formatIoValue(change.afterNormalized ?? change.after)}${change.unit == null ? '' : ' ${change.unit}'}'
            ' (${change.transitions} transição(ões), pacotes #${change.firstRecordIndex + 1}..#${change.lastRecordIndex + 1})');
      }
      for (final line in diff.summary) {
        buffer.writeln(' - $line');
      }
    }
    return buffer.toString();
  }

  String _maskImei(String imei) =>
      imei.length >= 15 ? '${imei.substring(0, 8)}*******' : '***';

  String _formatIoValue(dynamic value) {
    if (value is num) {
      final text = value.toStringAsFixed(2);
      return text.endsWith('.00')
          ? value.toInt().toString()
          : text
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    }
    return '$value';
  }
}

class _IoChangeTile extends StatelessWidget {
  final TeltonikaIoChange change;

  const _IoChangeTile({required this.change});

  @override
  Widget build(BuildContext context) {
    final color = change.known ? _Studio.primary : _Studio.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Studio.surface,
        border: Border.all(color: change.known ? _Studio.border : color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            change.known ? Icons.sensors : Icons.help_outline,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _valueLabel(),
                  style: TextStyle(
                    color: change.known ? _Studio.text : _Studio.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Pacotes #${change.firstRecordIndex + 1} → #${change.lastRecordIndex + 1} · '
                  '${change.transitions} transição(ões)',
                  style: const TextStyle(color: _Studio.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _valueLabel() {
    final before = _fmt(change.beforeNormalized ?? change.before);
    final after = _fmt(change.afterNormalized ?? change.after);
    final unit = change.unit == null ? '' : ' ${change.unit}';
    return '$before$unit → $after$unit';
  }

  String _fmt(dynamic value) {
    if (value is num) {
      final text = value.toStringAsFixed(2);
      return text.endsWith('.00')
          ? value.toInt().toString()
          : text
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    }
    return '$value';
  }
}

class _SerialDiagnosticCard extends StatelessWidget {
  final TrackerSessionState session;
  final bool busy;
  final VoidCallback onTestAt;
  final VoidCallback onTestMatrix;
  final ValueChanged<SerialLineEnding> onEnding;
  final ValueChanged<bool> onDtr;
  final ValueChanged<bool> onRts;

  const _SerialDiagnosticCard({
    required this.session,
    required this.busy,
    required this.onTestAt,
    required this.onTestMatrix,
    required this.onEnding,
    required this.onDtr,
    required this.onRts,
  });

  @override
  Widget build(BuildContext context) {
    final diagnostic = session.serialDiagnostic;
    final probable = diagnostic.probableChannel;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Diagnóstico automático da serial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<SerialLineEnding>(
                segments: const [
                  ButtonSegment(value: SerialLineEnding.cr, label: Text('CR')),
                  ButtonSegment(
                      value: SerialLineEnding.crlf, label: Text('CRLF')),
                  ButtonSegment(value: SerialLineEnding.lf, label: Text('LF')),
                  ButtonSegment(
                      value: SerialLineEnding.none, label: Text('NONE')),
                ],
                selected: {diagnostic.selectedEnding},
                onSelectionChanged:
                    busy ? null : (value) => onEnding(value.first),
              ),
              FilterChip(
                  label: const Text('DTR'),
                  selected: diagnostic.dtrEnabled,
                  onSelected: busy ? null : onDtr),
              FilterChip(
                  label: const Text('RTS'),
                  selected: diagnostic.rtsEnabled,
                  onSelected: busy ? null : onRts),
              FilledButton.icon(
                onPressed:
                    !busy && session.connection.usbConnected ? onTestAt : null,
                icon: const Icon(Icons.electric_bolt, size: 17),
                label: const Text('Teste AT'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onTestMatrix,
                icon: const Icon(Icons.grid_view, size: 17),
                label: const Text('Testar matriz'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KeyValue('TX', session.connection.commandPortName),
          _KeyValue('RX', session.connection.readPortName),
          _KeyValue('Baudrate', '${session.connection.baudRate}'),
          _KeyValue('Ending', diagnostic.selectedEnding.label),
          if (diagnostic.permissionFailure != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                border: Border.all(color: _Studio.warning),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Falha de acesso USB',
                    style: TextStyle(
                        color: _Studio.warning, fontWeight: FontWeight.w900),
                  ),
                  _KeyValue('Porta tentada',
                      diagnostic.permissionFailure!.attemptedPort),
                  _KeyValue(
                      'Erro bruto', diagnostic.permissionFailure!.rawError),
                  _KeyValue(
                    'Sandbox provável',
                    diagnostic.permissionFailure!.sandboxLikely ? 'sim' : 'não',
                  ),
                  _KeyValue(
                      'Sugestão', diagnostic.permissionFailure!.suggestion),
                ],
              ),
            ),
          ],
          if (diagnostic.running)
            LinearProgressIndicator(
              value: diagnostic.totalAttempts == 0
                  ? null
                  : diagnostic.completedAttempts / diagnostic.totalAttempts,
            ),
          if (probable != null) ...[
            const SizedBox(height: 10),
            const Text('Canal provável encontrado',
                style: TextStyle(
                    color: _Studio.success, fontWeight: FontWeight.w900)),
            _KeyValue('TX', probable.commandPortPath),
            _KeyValue('RX', probable.readPortPath),
            _KeyValue('Baudrate', '${probable.baudRate}'),
            _KeyValue('Ending', probable.ending.label),
            _KeyValue('Comando', probable.command),
            _KeyValue('Resposta', probable.response),
          ] else if (diagnostic.rawBinaryReceived && !diagnostic.running) ...[
            const SizedBox(height: 10),
            const Text(
              'Dados brutos recebidos, mas sem resposta Suntech ASCII. Verifique porta, baudrate, modo do dispositivo ou DTR/RTS.',
              style: TextStyle(
                  color: _Studio.warning, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TrackerSessionState session;
  final VoidCallback onMap;

  const _LocationCard({required this.session, required this.onMap});

  @override
  Widget build(BuildContext context) {
    final service = session.serviceLocation;
    final tracker = session.localitel;
    final distance = calculateServiceDistanceMeters(
      serviceLatitude: service.latitude,
      serviceLongitude: service.longitude,
      trackerLatitude: tracker.latitude,
      trackerLongitude: tracker.longitude,
    );
    final hasAnyPosition = service.isValid || tracker.hasValidCoordinates;
    final result = distance == null
        ? 'Pendente'
        : distance <= tracker.serviceToleranceMeters
            ? 'Dentro do raio'
            : 'Fora do raio';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: _Studio.info, size: 20),
              SizedBox(width: 8),
              Text('Localização',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          _KeyValue(
              'Serviço',
              service.isValid
                  ? '${service.latitude.toStringAsFixed(6)}, ${service.longitude.toStringAsFixed(6)}'
                  : 'Pendente'),
          _KeyValue(
              'Rastreador',
              tracker.hasValidCoordinates
                  ? '${tracker.latitude.toStringAsFixed(6)}, ${tracker.longitude.toStringAsFixed(6)}'
                  : 'Pendente'),
          _KeyValue('Distância',
              distance == null ? '-' : '${distance.toStringAsFixed(0)} m'),
          _KeyValue('Tolerância', '${tracker.serviceToleranceMeters} m'),
          _KeyValue('Resultado', result, warning: result == 'Fora do raio'),
          if (hasAnyPosition) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 170,
              child: ServiceMapPreview(
                serviceLatitude: service.latitude,
                serviceLongitude: service.longitude,
                trackerLatitude: tracker.latitude,
                trackerLongitude: tracker.longitude,
                toleranceMeters: tracker.serviceToleranceMeters,
                compact: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: hasAnyPosition ? onMap : null,
            icon: const Icon(Icons.map_outlined, size: 17),
            label:
                Text(hasAnyPosition ? 'Expandir mapa' : 'Aguardando posição'),
          ),
        ],
      ),
    );
  }
}

class _MapTechnicalCard extends StatelessWidget {
  final TrackerSessionState session;
  final VoidCallback onMap;

  const _MapTechnicalCard({required this.session, required this.onMap});

  @override
  Widget build(BuildContext context) {
    final service = session.serviceLocation;
    final tracker = session.localitel;
    final distance = calculateServiceDistanceMeters(
      serviceLatitude: service.latitude,
      serviceLongitude: service.longitude,
      trackerLatitude: tracker.latitude,
      trackerLongitude: tracker.longitude,
    );
    final hasCoordinates = service.isValid || tracker.hasValidCoordinates;
    return _LabFeatureCard(
      title: 'Mapa técnico',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KeyValue(
              'Serviço',
              service.isValid
                  ? '${service.latitude}, ${service.longitude}'
                  : '-'),
          _KeyValue(
              'Precisão',
              service.isValid
                  ? '${service.accuracyMeters.toStringAsFixed(1)} m'
                  : '-'),
          _KeyValue(
              'Rastreador',
              tracker.hasValidCoordinates
                  ? '${tracker.latitude}, ${tracker.longitude}'
                  : '-'),
          _KeyValue('Distância',
              distance == null ? '-' : '${distance.toStringAsFixed(1)} m'),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: hasCoordinates ? onMap : null,
                icon: const Icon(Icons.map, size: 17),
                label: const Text('Abrir mapa'),
              ),
              OutlinedButton.icon(
                onPressed: hasCoordinates
                    ? () {
                        final text =
                            'serviço=${service.latitude},${service.longitude}; rastreador=${tracker.latitude},${tracker.longitude}';
                        Clipboard.setData(ClipboardData(text: text));
                      }
                    : null,
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Copiar coordenadas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;

  const _PageIntro(
      {required this.eyebrow, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow,
            style: const TextStyle(
                color: _Studio.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4)),
        const SizedBox(height: 5),
        Text(title,
            style: const TextStyle(
                color: _Studio.text,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(description,
            style: const TextStyle(color: _Studio.muted, fontSize: 14)),
      ],
    );
  }
}

class _ActionSpec {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  const _ActionSpec(this.label, this.icon, this.onPressed,
      {this.primary = false});
}

class _ActionBar extends StatelessWidget {
  final bool busy;
  final List<_ActionSpec> actions;

  const _ActionBar({required this.busy, required this.actions});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              TrackerSignalPulse(size: 26),
              SizedBox(width: 9),
              Text('Fluxo de validação',
                  style: TextStyle(
                      color: _Studio.text, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            busy
                ? 'Processando a leitura atual. Aguarde antes de iniciar outra ação.'
                : 'Execute as etapas em ordem. Ações indisponíveis indicam a pré-condição necessária.',
            style: const TextStyle(color: _Studio.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions)
                Tooltip(
                  message: busy
                      ? 'Leitura em andamento'
                      : action.onPressed == null
                          ? 'Conclua a etapa anterior para liberar esta ação.'
                          : action.label,
                  child: action.primary
                      ? FilledButton.icon(
                          onPressed: busy ? null : action.onPressed,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                        )
                      : OutlinedButton.icon(
                          onPressed: busy ? null : action.onPressed,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveCards extends StatelessWidget {
  final List<Widget> children;
  final double preferredWidth;

  const _ResponsiveCards({required this.children, this.preferredWidth = 315});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / preferredWidth).floor().clamp(1, 4);
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child)
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TrackerMotion.standard,
      curve: TrackerMotion.curve,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Studio.surface,
        border: Border.all(color: _Studio.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _Studio.primary.withValues(alpha: 0.045),
            blurRadius: 20,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final TrackerSessionState session;

  const _EquipmentCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final family = session.selectedSuntechFamily;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.router_outlined, size: 20, color: _Studio.primary),
              SizedBox(width: 8),
              Text('Equipamento',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.hasDeviceRead
                ? session.device.model
                : 'Família não identificada',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _KeyValue('ESN', session.device.esn),
          _KeyValue('Firmware', session.device.firmware),
          _KeyValue('Porta',
              session.connection.portValidated ? 'OK' : 'Não validada'),
          _KeyValue('Família', familyLabel(family)),
          _KeyValue('AT', _probeStatus(session.handshakeResult, 'AT')),
          _KeyValue(
              'ST8',
              _groupProbeStatus(session.handshakeResult,
                  SuntechHandshakeEngine.fastSt8Probes)),
          _KeyValue(
              'Legacy',
              _groupProbeStatus(session.handshakeResult,
                  SuntechHandshakeEngine.fastLegacyProbes)),
          if (session.handshakeResult != null)
            _KeyValue('Resultado', session.handshakeResult!.compatibility),
          if (session.connection.portValidated &&
              family == SuntechCommandFamily.unknown)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Porta OK, equipamento não identificado. Use o Laboratório como fallback.',
                  style: TextStyle(color: _Studio.warning)),
            ),
        ],
      ),
    );
  }
}

class _SuntechFamilyCard extends StatelessWidget {
  final TrackerSessionState session;
  final ValueChanged<SuntechCommandFamily> onChanged;

  const _SuntechFamilyCard({required this.session, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final family = session.selectedSuntechFamily;
    final warning = switch (family) {
      SuntechCommandFamily.legacySt300St310 =>
        'Usando catálogo legado CMD / NTW / NTN. PRG fica bloqueado.',
      SuntechCommandFamily.newGenSt8210St8310 =>
        'Usando catálogo New Gen PRG / CMD. NTW/NTN ficam bloqueados.',
      SuntechCommandFamily.manual =>
        'Modo manual: somente comandos digitados explicitamente serão enviados.',
      SuntechCommandFamily.unknown =>
        'Selecione a família antes de executar leituras específicas.',
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Família do equipamento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SegmentedButton<SuntechCommandFamily>(
            segments: const [
              ButtonSegment(
                  value: SuntechCommandFamily.unknown,
                  label: Text('Desconhecida')),
              ButtonSegment(
                  value: SuntechCommandFamily.legacySt300St310,
                  label: Text('ST300/ST310 Legacy')),
              ButtonSegment(
                  value: SuntechCommandFamily.newGenSt8210St8310,
                  label: Text('ST8210/ST8310')),
              ButtonSegment(
                  value: SuntechCommandFamily.manual, label: Text('Manual')),
            ],
            selected: {family},
            onSelectionChanged: (value) => onChanged(value.first),
          ),
          const SizedBox(height: 10),
          Text(warning,
              style: const TextStyle(
                  color: _Studio.warning, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String status;
  final Map<String, String> rows;
  final Color tone;

  const _StatusCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.rows,
    this.tone = _Studio.primary,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _Studio.text, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(status,
              style: TextStyle(
                  color: tone, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final entry in rows.entries) _KeyValue(entry.key, entry.value),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final TrackerSessionState session;

  const _ServiceCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final location = session.serviceLocation;
    return _StatusCard(
      title: 'Serviço',
      icon: Icons.location_on_outlined,
      status: location.status,
      tone: location.isValid ? _Studio.success : _Studio.muted,
      rows: {
        'Localização': location.isValid
            ? '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'
            : 'Não capturada',
        'Precisão': location.isValid
            ? '${location.accuracyMeters.toStringAsFixed(1)} m'
            : '-',
        'Capturado em': location.capturedAt.isEmpty ? '-' : location.capturedAt,
      },
    );
  }
}

class _LocalitelCard extends StatelessWidget {
  final TrackerSessionState session;

  const _LocalitelCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final localitel = session.localitel;
    final warning = localitel.serviceCheck.startsWith('Fora');
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: _Studio.info, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Double-check LocaliTel',
                    style: TextStyle(
                        color: _Studio.text, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
              'Endereço, cobertura e posição do serviço. Não trava o rastreador.',
              style: TextStyle(color: _Studio.muted, fontSize: 11)),
          const SizedBox(height: 12),
          _KeyValue('Status', localitel.status),
          _KeyValue('Endereço', localitel.address),
          _KeyValue(
              'Distância',
              localitel.serviceDistanceMeters == null
                  ? '-'
                  : '${localitel.serviceDistanceMeters!.toStringAsFixed(0)} m'),
          _KeyValue('Tolerância', '${localitel.serviceToleranceMeters} m'),
          _KeyValue('Resultado', localitel.serviceCheck, warning: warning),
          const SizedBox(height: 5),
          Text(localitel.summary,
              style: const TextStyle(color: _Studio.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TrackerSessionState session;

  const _ResultCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final applicable = session.tests.where((test) => test.requiredCount > 0);
    final failed =
        applicable.where((test) => test.status == TestStatus.failed).length;
    final pending = applicable
        .where((test) =>
            test.status != TestStatus.passed &&
            test.status != TestStatus.failed)
        .length;
    final status = failed > 0
        ? 'Requer atenção'
        : pending > 0
            ? 'Validação em andamento'
            : 'Checklist concluído';
    final tone = failed > 0
        ? _Studio.danger
        : pending > 0
            ? _Studio.warning
            : _Studio.success;
    return _StatusCard(
      title: 'Resultado final',
      icon: Icons.fact_check_outlined,
      status: status,
      tone: tone,
      rows: {
        'Progresso': '${(session.progress * 100).round()}%',
        'Pendências': '$pending',
        'Falhas': '$failed',
      },
    );
  }
}

class _Checklist extends StatelessWidget {
  final TrackerSessionState session;

  const _Checklist({required this.session});

  @override
  Widget build(BuildContext context) {
    final tests =
        session.tests.where((test) => test.requiredCount > 0).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Checklist do rastreador',
              style: TextStyle(
                  color: _Studio.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Somente validações do equipamento entram no resultado.',
              style: TextStyle(color: _Studio.muted, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final test in tests) _TestChip(test: test)],
          ),
        ],
      ),
    );
  }
}

class _TestChip extends StatelessWidget {
  final TestStepState test;

  const _TestChip({required this.test});

  @override
  Widget build(BuildContext context) {
    final color = _testColor(test.status);
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_testIcon(test.status), size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.label,
                    style: const TextStyle(
                        color: _Studio.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                Text(test.detail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Studio.muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabFeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _LabFeatureCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _Studio.primary, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: _Studio.text, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  final String label;
  final String status;
  final IconData icon;

  const _Capability(this.label, this.status, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _Studio.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(status,
              style: const TextStyle(color: _Studio.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TechnicalLogs extends StatelessWidget {
  final List<LogEntry> logs;

  const _TechnicalLogs({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _Studio.log, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 19),
              SizedBox(width: 8),
              Text('Logs completos',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (_, index) {
                final log = logs[logs.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    '${log.time}  ${log.source.padRight(12)} ${log.message}',
                    style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.35),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _KeyValue(this.label, this.value, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 92,
              child: Text(label,
                  style: const TextStyle(color: _Studio.muted, fontSize: 11))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: warning ? _Studio.warning : _Studio.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style:
            const TextStyle(color: _Studio.muted, fontStyle: FontStyle.italic));
  }
}

String _testDetail(TrackerSessionState session, String id, String fallback) {
  for (final test in session.tests) {
    if (test.id == id) return test.detail;
  }
  return fallback;
}

String _maskedConfigurationValue(String key, String value) {
  if (key.toLowerCase().contains('senha') && value.isNotEmpty) {
    return '••••••••';
  }
  return value.isEmpty ? '-' : value;
}

Color _testColor(TestStatus status) => switch (status) {
      TestStatus.passed => _Studio.success,
      TestStatus.warning => _Studio.warning,
      TestStatus.failed => _Studio.danger,
      TestStatus.running => _Studio.primary,
      TestStatus.notApplicable || TestStatus.pending => _Studio.muted,
    };

IconData _testIcon(TestStatus status) => switch (status) {
      TestStatus.passed => Icons.check_circle,
      TestStatus.warning => Icons.warning_amber,
      TestStatus.failed => Icons.cancel,
      TestStatus.running => Icons.sync,
      TestStatus.notApplicable => Icons.remove_circle_outline,
      TestStatus.pending => Icons.radio_button_unchecked,
    };
