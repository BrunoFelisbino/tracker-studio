import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/capture_logs/capture_log_store.dart';
import '../../../../core/data/parsers/teltonika_usb/teltonika_capture_analysis.dart';
import 'completed_service_repository.dart';
import 'local_service_database.dart';
import 'localitel_client.dart';
import 'installation_profiles.dart';
import 'service_location_provider.dart';
import 'serial_diagnostics.dart';
import 'suntech_parser.dart';
import 'suntech_command_family.dart';
import 'suntech_handshake_engine.dart';
import 'suntech_legacy_commands.dart';
import 'suntech_newgen_commands.dart';
import '../../../../core/drivers/teltonika/teltonika_network_commands.dart';
import 'tracker_session_state.dart';
import 'usb_serial_transport.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';

final trackerSessionControllerProvider =
    StateNotifierProvider<TrackerStudioController, TrackerSessionState>((ref) {
  final transport = LibSerialPortTransport();
  final localitel = LocalitelClient();
  final serviceLocation = ServiceLocationProvider();
  final workOrders = MemoryWorkOrderRepository();
  final serviceDatabase = LocalServiceDatabase.createDefault();
  final completedServices = CompletedServiceRepository(serviceDatabase);
  final controller = TrackerStudioController(
    parser: const SuntechParser(),
    transport: transport,
    localitel: localitel,
    serviceLocation: serviceLocation,
    workOrders: workOrders,
    completedServices: completedServices,
  );
  ref.onDispose(() {
    unawaited(serviceDatabase.close());
  });
  return controller;
});

class TrackerStudioController extends StateNotifier<TrackerSessionState> {
  final SuntechParser _parser;
  final UsbSerialTransport _transport;
  final LocalitelClient _localitel;
  final ServiceLocationProvider _serviceLocation;
  final WorkOrderRepository _workOrders;
  final SuntechHandshakeEngine _handshakeEngine;
  final CompletedServiceRepository _completedServices;
  final CaptureLogStore _captureLogs;
  final bool _serviceSyncConfigured;
  StreamSubscription<String>? _serialSubscription;
  Timer? _responseTimer;
  Timer? _statusPollingTimer;
  Completer<String>? _diagnosticResponse;
  DateTime? _lastRawAt;
  DateTime? _lastValidAt;
  DateTime? _lastParserIgnoreWarningAt;
  bool _isDisconnecting = false;
  bool _isHandshakeRunning = false;
  bool _disposed = false;

  bool get isDisconnecting => _isDisconnecting;
  bool get isHandshakeRunning => _isHandshakeRunning;

  TrackerStudioController({
    required SuntechParser parser,
    required UsbSerialTransport transport,
    required LocalitelClient localitel,
    required ServiceLocationProvider serviceLocation,
    WorkOrderRepository? workOrders,
    SuntechHandshakeEngine? handshakeEngine,
    CompletedServiceRepository? completedServices,
    CaptureLogStore? captureLogs,
    bool? serviceSyncConfigured,
  })  : _parser = parser,
        _transport = transport,
        _localitel = localitel,
        _serviceLocation = serviceLocation,
        _workOrders = workOrders ?? MemoryWorkOrderRepository(),
        _handshakeEngine = handshakeEngine ?? SuntechHandshakeEngine(),
        _completedServices = completedServices ??
            CompletedServiceRepository(LocalServiceDatabase.createDefault()),
        _captureLogs = captureLogs ?? CaptureLogStore(),
        _serviceSyncConfigured = serviceSyncConfigured ??
            const String.fromEnvironment('SERVICE_SYNC_URL').trim().isNotEmpty,
        super(TrackerSessionState.empty()) {
    _serialSubscription = _transport.lines.listen(
      _handleTransportLine,
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed || _isDisconnecting) return;
        state = _appendLog(
            state, LogEntry(_clock(), 'USB', 'Erro de leitura serial: $error'));
      },
    );
    unawaited(loadTodayWorkOrders());
    unawaited(loadCompletedServices());
  }

  Future<void> loadCompletedServices() async {
    try {
      final recent = await _completedServices.listRecentCompletedServices();
      final pending = await _completedServices.listPendingSync();
      state = _copy(
        state,
        recentCompletedServices: recent,
        pendingSyncServices: pending,
      );
    } catch (error) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'OS', 'Falha ao carregar histórico local: $error'),
      );
    }
  }

  Future<void> loadTodayWorkOrders() async {
    try {
      final workOrders = await _workOrders.listByDate(DateTime.now());
      state = _copy(state, todayWorkOrders: workOrders);
    } catch (error) {
      state = _appendLog(state,
          LogEntry(_clock(), 'OS', 'Falha ao carregar agenda local: $error'));
    }
  }

  Future<void> openWorkOrder(String id) async {
    final workOrder = await _workOrders.getById(id);
    if (workOrder == null) {
      state =
          _appendLog(state, LogEntry(_clock(), 'OS', 'OS $id não encontrada'));
      return;
    }
    state = _appendLog(
      _copy(state,
          activeWorkOrder: workOrder,
          serviceValidation: const ServiceValidation()),
      LogEntry(_clock(), 'OS',
          '${workOrder.id} aberta; dados técnicos continuam aguardando leitura real.'),
    );
  }

  Future<void> startWorkOrder(String id) async {
    final workOrder = await _workOrders.start(id);
    final recommended = workOrder.recommendedProfile.toLowerCase();
    final profile = recommended.contains('moto')
        ? InstallationProfiles.motorcycleStandard
        : recommended.contains('carro')
            ? InstallationProfiles.carStandard
            : state.selectedProfile;
    state = _appendLog(
      _copy(
        state,
        activeWorkOrder: workOrder,
        todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, workOrder),
        selectedProfile: profile,
        generatedCommandPlan: const [],
      ),
      LogEntry(_clock(), 'OS',
          '${workOrder.id} iniciada com perfil recomendado ${workOrder.recommendedProfile}.'),
    );
  }

  Future<void> updateWorkOrderPlate(String plate) async {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return;
    final normalized = plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final updated =
        await _workOrders.upsert(workOrder.copyWith(plateRead: normalized));
    state = _copy(
      state,
      activeWorkOrder: updated,
      todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, updated),
    );
    runServiceValidation();
  }

  Future<void> addWorkOrderPhoto(WorkOrderPhoto photo) async {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return;
    final photos = [
      ...workOrder.photos.where((item) => item.type != photo.type),
      photo
    ];
    final updated =
        await _workOrders.upsert(workOrder.copyWith(photos: photos));
    state = _copy(
      state,
      activeWorkOrder: updated,
      todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, updated),
    );
  }

  Future<void> attachWorkOrderPhoto(
      WorkOrderPhotoType type, String filePath) async {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null || filePath.trim().isEmpty) return;
    await addWorkOrderPhoto(WorkOrderPhoto(
      id: '${workOrder.id}-${type.name}',
      type: type,
      filePath: filePath,
      capturedAt: DateTime.now().toUtc().toIso8601String(),
      required: workOrderPhotoCatalog(
        physicalIgnition:
            state.selectedProfile.ignitionMode == IgnitionMode.physical,
        blockingEnabled: state.selectedProfile.enableBlocking,
      ).firstWhere((item) => item.type == type).required,
    ));
    if (type == WorkOrderPhotoType.deviceLabel) {
      final refreshed = state.activeWorkOrder!;
      final evidence =
          (refreshed.deviceEvidence ?? const DeviceEvidence()).copyWith(
        photoPath: filePath,
        capturedAt: DateTime.now(),
        status: 'captured',
      );
      final updated = await _workOrders
          .upsert(refreshed.copyWith(deviceEvidence: evidence));
      state = _copy(
        state,
        activeWorkOrder: updated,
        todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, updated),
      );
    }
    runServiceValidation();
  }

  Future<void> updateDeviceEvidence({
    String? barcodeRaw,
    String? labelSerial,
    String? labelImei,
    String? labelEsn,
  }) async {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return;
    final evidence =
        (workOrder.deviceEvidence ?? const DeviceEvidence()).copyWith(
      barcodeRaw: barcodeRaw,
      labelSerial: labelSerial,
      labelImei: labelImei,
      labelEsn: labelEsn,
      capturedAt: DateTime.now(),
      status: 'read',
    );
    final updated =
        await _workOrders.upsert(workOrder.copyWith(deviceEvidence: evidence));
    state = _copy(
      state,
      activeWorkOrder: updated,
      todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, updated),
    );
    runServiceValidation();
  }

  void runServiceValidation() {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return;
    state = _copy(
      state,
      serviceValidation: validateWorkOrderService(
        workOrder: workOrder,
        technicianLatitude: state.serviceLocation.latitude,
        technicianLongitude: state.serviceLocation.longitude,
        trackerLatitude: state.localitel.latitude,
        trackerLongitude: state.localitel.longitude,
        trackerEsn: state.device.esn == '-' ? '' : state.device.esn,
        trackerImei: state.device.imei == '-' ? '' : state.device.imei,
        physicalIgnition:
            state.selectedProfile.ignitionMode == IgnitionMode.physical,
        blockingEnabled: state.selectedProfile.enableBlocking,
      ),
    );
  }

  Future<void> completeWorkOrder() async {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return;
    runServiceValidation();
    var completed = await _workOrders.complete(workOrder.id);
    if (hasMissingRequiredPhotos(
      workOrder,
      physicalIgnition:
          state.selectedProfile.ignitionMode == IgnitionMode.physical,
      blockingEnabled: state.selectedProfile.enableBlocking,
    )) {
      completed = await _workOrders.upsert(
        completed.copyWith(status: WorkOrderStatus.completedWithWarning),
      );
    }
    final finishedAt =
        DateTime.tryParse(completed.finishedAt) ?? DateTime.now();
    final startedAt = DateTime.tryParse(completed.startedAt) ?? finishedAt;
    final warning = completed.status == WorkOrderStatus.completedWithWarning ||
        state.serviceValidation.result == ServiceValidationStatus.warning;
    final syncStatus = _serviceSyncConfigured ? 'pending' : 'notRequired';
    await _completedServices.saveCompletedService(
      CompletedServiceRecord(
        id: completed.id,
        workOrderId: completed.id,
        customerName: completed.customerName,
        plate: completed.plateRead.isEmpty
            ? completed.plateExpected
            : completed.plateRead,
        serviceType: completed.serviceType.name,
        vehicleBrand: completed.vehicleBrand,
        vehicleModel: completed.vehicleModel,
        startedAt: startedAt,
        finishedAt: finishedAt,
        status: warning ? 'completedWithWarning' : 'completed',
        resultSummary: warning
            ? 'Serviço concluído com pontos de atenção.'
            : 'Serviço concluído; validações sem divergência.',
        syncStatus: syncStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final recent = await _completedServices.listRecentCompletedServices();
    final pending = await _completedServices.listPendingSync();
    state = _appendLog(
      _copy(
        state,
        activeWorkOrder: completed,
        todayWorkOrders: _replaceWorkOrder(state.todayWorkOrders, completed),
        recentCompletedServices: recent,
        pendingSyncServices: pending,
      ),
      LogEntry(
        _clock(),
        'OS',
        completed.status == WorkOrderStatus.completedWithWarning
            ? 'Serviço salvo no dispositivo com pontos de atenção.'
            : syncStatus == 'pending'
                ? 'Salvo localmente. Será sincronizado depois.'
                : 'Serviço salvo no dispositivo.',
      ),
    );
  }

  String copyWorkOrderPayload() {
    final workOrder = state.activeWorkOrder;
    if (workOrder == null) return '';
    return const JsonEncoder.withIndent('  ').convert({
      'workOrder': workOrder.toJson(),
      'usbDevice': {
        'manufacturer': state.device.manufacturer,
        'model': state.device.model,
        'esn': state.device.esn,
        'imei': state.device.imei,
        'firmware': state.device.firmware,
      },
      'serviceValidation': state.serviceValidation.toJson(),
      'localitel': {
        'status': state.localitel.status,
        'summary': state.localitel.summary,
        'optional': true,
      },
      'syncDestination': workOrder.destinationServer,
    });
  }

  NewGenNetworkCommands generateNewGenNetworkCommands({
    required String apn,
    required String server,
    required int port,
    String username = '',
    String password = '',
    String agpsUrl = 'https://example.com/agps',
    String scanningBand = '03',
  }) {
    return buildNewGenNetworkCommands(
      family: state.selectedSuntechFamily,
      esn: state.hasDeviceRead ? state.device.esn : '',
      apn: apn,
      server: server,
      port: port,
      username: username,
      password: password,
      agpsUrl: agpsUrl,
      scanningBand: scanningBand,
    );
  }

  Future<void> writeNewGenNetwork({
    required String apn,
    required String server,
    required int port,
    required bool explicitlyConfirmed,
    String username = '',
    String password = '',
    String agpsUrl = 'https://example.com/agps',
    String scanningBand = '03',
  }) async {
    if (!explicitlyConfirmed) {
      throw StateError(
          'Confirmação explícita obrigatória para alterar APN/servidor.');
    }
    if (!state.hasValidBackup) {
      throw StateError('Leia e proteja a configuração original antes do PRG.');
    }
    final result = await _handshakeEngine.writeNewGenNetwork(
      apn: apn,
      server: server,
      port: port,
      username: username,
      password: password,
      agpsUrl: agpsUrl,
      scanningBand: scanningBand,
    );
    var next = _copy(state, networkWriteResult: result);
    if (result.part1Confirmed) {
      next =
          _appendLog(next, LogEntry(_clock(), 'PRG', 'APN gravada parte 1 OK'));
    }
    if (result.part2Confirmed) {
      next =
          _appendLog(next, LogEntry(_clock(), 'PRG', 'APN gravada parte 2 OK'));
      next = _appendLog(next, LogEntry(_clock(), 'PRG', 'Aguardando readback'));
    } else {
      next = _appendLog(
          next,
          LogEntry(_clock(), 'ERROR',
              'PRG sem confirmação obrigatória: ${result.part2Response.isEmpty ? result.part1Response : result.part2Response}'));
    }
    state = next;
    if (result.part2Confirmed) {
      await readStatus();
      await readPreset();
      final networkCommand = state.handshakeResult?.commandCatalog['ReqConNtw'];
      if (networkCommand != null) {
        await _sendCommand(networkCommand.command(esn: state.device.esn));
      }
    }
  }

  TeltonikaNetworkCommands generateTeltonikaNetworkCommands({
    required String apn,
    required String server,
    required int port,
    String username = '',
    String password = '',
    String protocol = '0',
  }) {
    return buildTeltonikaNetworkCommands(
      apn: apn,
      server: server,
      port: port,
      username: username,
      password: password,
      protocol: protocol,
    );
  }

  Future<void> writeTeltonikaNetwork({
    required String apn,
    required String server,
    required int port,
    required bool explicitlyConfirmed,
    String username = '',
    String password = '',
    String protocol = '0',
  }) async {
    if (!explicitlyConfirmed) {
      throw StateError(
          'Confirmação explícita obrigatória para alterar rede Teltonika.');
    }
    _requireUsb();
    final plan = generateTeltonikaNetworkCommands(
      apn: apn,
      server: server,
      port: port,
      username: username,
      password: password,
      protocol: protocol,
    );
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Teltonika',
          'Aplicando rede: ${plan.commands.length} comandos via USB Configurator.'),
    );
    for (final command in plan.commands) {
      await _transport.writeLine(command);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Teltonika',
          'Rede aplicada. Confira <SETPARAM_RESULT>:1 e <SAVE_CFG_RESULT>:1 (ou use Captura e análise).'),
    );
  }

  TeltonikaNetworkCommands generateTeltonikaConfigPlan(
      Map<int, String> values) {
    return buildTeltonikaConfigSequence(
      parameters: [
        for (final entry in values.entries) (entry.key, entry.value),
      ],
    );
  }

  Future<void> writeTeltonikaConfig({
    required Map<int, String> values,
    required bool explicitlyConfirmed,
  }) async {
    if (!explicitlyConfirmed) {
      throw StateError(
          'Confirmação explícita obrigatória para alterar a configuração Teltonika.');
    }
    _requireUsb();
    final plan = generateTeltonikaConfigPlan(values);
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Teltonika',
          'Aplicando configuração: ${plan.commands.length} comandos via USB Configurator.'),
    );
    for (final command in plan.commands) {
      await _transport.writeLine(command);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Teltonika',
          'Configuração aplicada. Confira <SETPARAM_RESULT>:1 e <SAVE_CFG_RESULT>:1 (ou use Captura e análise).'),
    );
  }

  void setStudioMode(StudioMode mode) {
    state = _copy(state, studioMode: mode);
  }

  void selectSuntechFamily(SuntechCommandFamily family) {
    state = _appendLog(
      _copy(
        state,
        selectedSuntechFamily: family,
        generatedCommandPlan: const [],
      ),
      LogEntry(
          _clock(), 'Sistema', 'Família selecionada: ${familyLabel(family)}'),
    );
  }

  Future<void> autoIdentifyDevice() async {
    await _runDeviceIdentification(fullScan: false);
  }

  Future<void> runFullSuntechScan() async {
    await _runDeviceIdentification(fullScan: true);
  }

  Future<void> _runDeviceIdentification({required bool fullScan}) async {
    if (_disposed || _isDisconnecting || _isHandshakeRunning) return;
    if (!_transport.connected) {
      _setControlledHandshakeError('USB serial não conectado.');
      return;
    }
    _isHandshakeRunning = true;
    final currentBaud = state.connection.baudRate;
    SuntechHandshakeResult result;
    try {
      result = fullScan
          ? await _handshakeEngine.runFullHandshakeScan(
              transport: _transport,
              baudRates: [currentBaud, 115200, 9600, 57600, 38400],
            )
          : await _handshakeEngine.runFastHandshake(
              transport: _transport,
              baudRate: currentBaud,
              onProgress: (partial) {
                if (_disposed || _isDisconnecting || !_isHandshakeRunning) {
                  return;
                }
                _applyHandshakeResult(partial, appendLog: false);
              },
            );
    } catch (error) {
      if (!_disposed) {
        _setControlledHandshakeError('$error'.replaceFirst('Bad state: ', ''));
      }
      return;
    } finally {
      _isHandshakeRunning = false;
    }
    if (_disposed || _isDisconnecting || result.canceled) return;
    _applyHandshakeResult(result);
    runServiceValidation();
    if (result.identified) {
      unawaited(_runPostHandshakeIdentification());
    }
  }

  void _applyHandshakeResult(
    SuntechHandshakeResult result, {
    bool appendLog = true,
  }) {
    if (_disposed) return;
    final identified = result.identified;
    final device = identified
        ? DeviceSummary(
            manufacturer: 'Suntech',
            model: result.model ?? '-',
            esn: result.esn ?? '-',
            firmware: result.firmware ?? '-',
            imei: result.imei ?? '-',
            sim: state.device.sim,
          )
        : state.device;
    final next = _copy(
      state,
      selectedSuntechFamily: result.family,
      handshakeResult: result,
      device: device,
      connection: ConnectionSummary(
        commandPortName: state.connection.commandPortName,
        readPortName: state.connection.readPortName,
        baudRate: result.baudRate,
        usbConnected: _transport.connected,
        smsReady: state.connection.smsReady,
        gprsOnline: state.connection.gprsOnline,
        portValidated: result.portOk,
        lastPacketSecondsAgo: state.connection.lastPacketSecondsAgo,
        networkCode: state.connection.networkCode,
        networkWarning: state.connection.networkWarning,
      ),
    );
    state = appendLog
        ? _appendLog(
            next,
            LogEntry(
              _clock(),
              'Handshake',
              identified
                  ? '${result.model ?? 'Suntech'} identificado em ${result.baudRate} baud.'
                  : result.compatibility,
            ),
          )
        : next;
  }

  Future<void> _runPostHandshakeIdentification() async {
    if (_disposed || _isDisconnecting || !_transport.connected) return;
    final family = state.selectedSuntechFamily;
    if (family == SuntechCommandFamily.unknown) return;

    state = _appendLog(
      state,
      LogEntry(_clock(), 'AutoID', 'Identificacao pos-handshake iniciada'),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_disposed || _isDisconnecting) return;

    await readStatus();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_disposed || _isDisconnecting) return;

    if (family == SuntechCommandFamily.newGenSt8210St8310 && state.hasDeviceRead) {
      final iccidCmd = state.handshakeResult?.commandCatalog['ReqICCID'];
      if (iccidCmd != null) {
        await _sendCommand(iccidCmd.command(esn: state.device.esn));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (_disposed || _isDisconnecting) return;
    }

    await readPreset();
    if (_disposed || _isDisconnecting) return;

    state = _appendLog(
      state,
      LogEntry(_clock(), 'AutoID', 'Identificacao pos-handshake concluida: ${familyLabel(family)}'),
    );

    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_disposed || _isDisconnecting || !_transport.connected) {
        _statusPollingTimer?.cancel();
        return;
      }
      try {
        await readStatus(silent: true);
      } catch (e) {
        debugPrint('TrackerStudioController: serial status polling failed: $e');
        // Ignora erros de desconexão da porta serial durante polling automático
      }
    });
  }

  Future<void> autoIdentifySuntech() => autoIdentifyDevice();

  Future<void> sendHandshakeProbe(SuntechHandshakeProbe probe) async {
    _requireUsb();
    final response = await _handshakeEngine.runProbe(_transport, probe);
    state = _appendLog(
      _copy(
        state,
        handshakeResult: SuntechHandshakeResult(
          family: state.handshakeResult?.family ?? state.selectedSuntechFamily,
          model: state.handshakeResult?.model,
          esn: state.handshakeResult?.esn,
          firmware: state.handshakeResult?.firmware,
          imei: state.handshakeResult?.imei,
          baudRate: state.connection.baudRate,
          protocol: state.handshakeResult?.protocol,
          compatibility: state.handshakeResult?.compatibility ?? 'Probe manual',
          portOk: state.connection.portValidated,
          commandCatalog: state.handshakeResult?.commandCatalog ?? const {},
          rawEvidence: [
            ...?state.handshakeResult?.rawEvidence,
            '[SEND] ${probe.command}',
            response
          ],
        ),
      ),
      LogEntry(_clock(), 'Handshake',
          '${probe.command}: ${response.isEmpty ? 'sem resposta' : _short(response)}'),
    );
  }

  void clearHandshakeEvidence() {
    final current = state.handshakeResult;
    if (current == null) return;
    state = _copy(
      state,
      handshakeResult: SuntechHandshakeResult(
        family: current.family,
        model: current.model,
        esn: current.esn,
        firmware: current.firmware,
        imei: current.imei,
        baudRate: current.baudRate,
        protocol: current.protocol,
        compatibility: current.compatibility,
        portOk: current.portOk,
        commandCatalog: current.commandCatalog,
        rawEvidence: const [],
      ),
    );
  }

  void selectInstallationMode(InstallationMode mode) {
    final profile = switch (mode) {
      InstallationMode.car => InstallationProfiles.carStandard,
      InstallationMode.motorcycle => InstallationProfiles.motorcycleStandard,
      InstallationMode.custom => InstallationProfiles.custom,
    };
    _setProfile(profile);
  }

  void selectIgnitionMode(IgnitionMode mode) {
    _setProfile(state.selectedProfile.copyWith(ignitionMode: mode));
  }

  void selectTimingProfile(TimingProfile profile) {
    _setProfile(state.selectedProfile.copyWith(timingProfile: profile));
  }

  void updateCustomTiming({
    int? movingIntervalSeconds,
    int? stoppedIntervalSeconds,
    int? ignitionOnIntervalSeconds,
    int? ignitionOffIntervalSeconds,
    int? curveAngleDegrees,
    int? distanceMeters,
    bool? enableSleep,
    bool? enableBlocking,
  }) {
    _setProfile(
      state.selectedProfile.copyWith(
        timingProfile: TimingProfile.custom,
        movingIntervalSeconds: movingIntervalSeconds,
        stoppedIntervalSeconds: stoppedIntervalSeconds,
        ignitionOnIntervalSeconds: ignitionOnIntervalSeconds,
        ignitionOffIntervalSeconds: ignitionOffIntervalSeconds,
        curveAngleDegrees: curveAngleDegrees,
        distanceMeters: distanceMeters,
        enableSleep: enableSleep,
        enableBlocking: enableBlocking,
      ),
    );
  }

  void generateCommandPlan() {
    final plan = generateInstallationCommandPlan(
      profile: state.selectedProfile,
      hasBackup: state.hasValidBackup,
      family: state.selectedSuntechFamily,
    );
    state = _appendLog(
      _copy(state, generatedCommandPlan: plan),
      LogEntry(
        _clock(),
        'Comando',
        state.hasValidBackup
            ? 'Plano gerado; aplicação bloqueada até homologação e readback.'
            : 'Plano bloqueado: leia e salve a configuração original antes de aplicar.',
      ),
    );
  }

  void _setProfile(InstallationProfile profile) {
    state =
        _copy(state, selectedProfile: profile, generatedCommandPlan: const []);
  }

  Future<List<SerialPortInfo>> scanPorts() async {
    final ports = await _transport.listPorts();
    final diagnostics = _transport is SerialScanDiagnosticsProvider
        ? (_transport as SerialScanDiagnosticsProvider).lastScanDiagnostics
        : SerialScanDiagnostics(
            devicesScanned: ports.length,
            candidates: ports.map((port) => port.path).toList());
    var next = _appendLog(
      state,
      LogEntry(_clock(), 'USB',
          '${diagnostics.devicesScanned} device(s) encontrados em /dev'),
    );
    for (final candidate in diagnostics.candidates) {
      next = _appendLog(
          next, LogEntry(_clock(), 'USB', 'Candidato serial: $candidate'));
    }
    for (final ignored in diagnostics.ignoredDevices) {
      next = _appendLog(next, LogEntry(_clock(), 'USB', 'Ignorado: $ignored'));
    }
    next = _appendLog(
        next,
        LogEntry(
            _clock(), 'USB', '${ports.length} porta(s) serial candidata(s)'));
    if (ports.isEmpty) {
      next = _appendLog(
        next,
        LogEntry(
          _clock(),
          'USB',
          'Conecte o adaptador USB serial e verifique driver CH340/CP210x/FTDI/Prolific.',
        ),
      );
    }
    state = next;
    return ports;
  }

  Future<void> connectUsb(
    String commandPortPath, {
    String? readPortPath,
    int baudRate = 115200,
    SerialLineEnding lineEnding = SerialLineEnding.cr,
    bool dtrEnabled = false,
    bool rtsEnabled = false,
  }) async {
    try {
      await _transport.connect(
        SerialConnectionRequest(
          commandPortPath: commandPortPath,
          readPortPath: readPortPath,
          baudRate: baudRate,
          lineTerminator: lineEnding.value,
          dtrEnabled: dtrEnabled,
          rtsEnabled: rtsEnabled,
        ),
      );
    } catch (error) {
      final rawError = '$error'.replaceFirst('Bad state: ', '');
      final lower = rawError.toLowerCase();
      final sandboxLikely = lower.contains('operation not permitted') ||
          lower.contains('permission denied') ||
          lower.contains('not permitted') ||
          lower.contains('sandbox') ||
          lower.contains('acesso usb bloqueado');
      state = _appendLog(
        _copy(
          state,
          serialDiagnostic: state.serialDiagnostic.copyWith(
            permissionFailure: UsbPermissionDiagnostic(
              attemptedPort: commandPortPath,
              rawError: rawError,
              sandboxLikely: sandboxLikely,
            ),
          ),
        ),
        LogEntry(_clock(), 'ERROR', rawError),
      );
      rethrow;
    }
    final effectiveReadPort = readPortPath ?? commandPortPath;
    state = _appendLog(
      _copy(
        state,
        connection: ConnectionSummary(
          commandPortName: commandPortPath,
          readPortName: effectiveReadPort,
          baudRate: baudRate,
          usbConnected: true,
          smsReady: state.connection.smsReady,
          gprsOnline: false,
          portValidated: false,
          lastPacketSecondsAgo: null,
          networkCode: null,
          networkWarning: null,
        ),
        serialDiagnostic:
            state.serialDiagnostic.copyWith(clearPermissionFailure: true),
        stages: const [
          SessionStage('Conectar USB', completed: true),
          SessionStage('Identificar', active: true),
          SessionStage('Ler original'),
          SessionStage('Backup'),
          SessionStage('Configurar'),
          SessionStage('Testar'),
          SessionStage('Restaurar'),
          SessionStage('Finalizar'),
        ],
      ),
      LogEntry(
        _clock(),
        'USB',
        'USB conectado. Comando: $commandPortPath · Retorno: $effectiveReadPort',
      ),
    );

    // Ao conectar uma porta valida, inicia a identificacao automaticamente
    // para reduzir passos manuais em uso de campo.
    unawaited(_autoIdentifyAfterConnect());
  }

  Future<void> _autoIdentifyAfterConnect() async {
    if (_disposed || _isDisconnecting || !_transport.connected) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_disposed || _isDisconnecting || !_transport.connected) return;

    state = _appendLog(
      state,
      LogEntry(_clock(), 'Handshake', 'Identificacao automatica iniciada apos conectar USB'),
    );

    await autoIdentifyDevice();
  }

  Future<void> disconnectUsb() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    _handshakeEngine.cancel();
    _responseTimer?.cancel();
    _responseTimer = null;
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
    final diagnostic = _diagnosticResponse;
    _diagnosticResponse = null;
    if (diagnostic?.isCompleted == false) diagnostic?.complete('');
    Object? disconnectError;
    try {
      await _transport.disconnect();
    } catch (error) {
      if (!_isExpectedClosedPortError(error)) disconnectError = error;
    } finally {
      _isHandshakeRunning = false;
      _isDisconnecting = false;
    }
    if (_disposed) return;
    state = _appendLog(
      _copy(
        state,
        connection: ConnectionSummary(
          commandPortName: '-',
          readPortName: '-',
          baudRate: state.connection.baudRate,
          usbConnected: false,
          smsReady: state.connection.smsReady,
          gprsOnline: state.connection.gprsOnline,
          portValidated: false,
          lastPacketSecondsAgo: state.connection.lastPacketSecondsAgo,
          networkCode: state.connection.networkCode,
          networkWarning: state.connection.networkWarning,
        ),
        selectedSuntechFamily: SuntechCommandFamily.unknown,
        manualCommand: const ManualCommandState(
          lastCommand: '',
          lastResponse: '',
          waitingResponse: false,
        ),
        clearHandshakeResult: true,
      ),
      LogEntry(
        _clock(),
        'USB',
        disconnectError == null
            ? 'USB desconectado'
            : 'USB desconectado com diagnóstico: $disconnectError',
      ),
    );
  }

  Future<void> readStatus({bool silent = false}) async {
    final family = state.effectiveSuntechFamily;
    if (family == SuntechCommandFamily.unknown ||
        family == SuntechCommandFamily.manual) {
      if (!silent) {
        state = _appendLog(
          state,
          LogEntry(_clock(), 'Comando',
              'Status bloqueado: identifique a família no handshake.'),
        );
      }
      return;
    }
    if (family == SuntechCommandFamily.legacySt300St310) {
      await _sendCommand(SuntechLegacyCommands.status.command(), silent: silent);
      return;
    }
    if (!state.hasDeviceRead) {
      if (!silent) throw StateError('Status New Gen bloqueado: ESN não identificado pelo JSON.');
      return;
    }
    await _sendCommand(
        SuntechNewGenCommands.status.command(esn: state.device.esn), silent: silent);
  }

  Future<void> readPreset({bool silent = false}) async {
    final family = state.effectiveSuntechFamily;
    if (family == SuntechCommandFamily.unknown ||
        family == SuntechCommandFamily.manual) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Comando',
            'Preset bloqueado: identifique a família no handshake.'),
      );
      return;
    }
    if (family == SuntechCommandFamily.legacySt300St310) {
      await _sendCommand(SuntechLegacyCommands.preset.command());
      return;
    }
    if (!state.hasDeviceRead) {
      throw StateError(
          'Preset New Gen bloqueado: ESN não identificado pelo JSON.');
    }
    await _sendCommand(
        SuntechNewGenCommands.preset.command(esn: state.device.esn));
  }

  String resolveCatalogCommand(SuntechCommandDefinition definition) {
    final esn = state.hasDeviceRead ? state.device.esn : '';
    if (definition.requiresEsn && esn.isEmpty) {
      throw StateError('ESN necessário para este comando.');
    }
    final command = definition.command(esn: esn);
    if (RegExp(r'<[^>]+>').hasMatch(command)) {
      throw StateError('Comando possui parâmetros obrigatórios pendentes.');
    }
    return command;
  }

  bool canSendCatalogCommand(SuntechCommandDefinition definition) {
    if (!_transport.connected || definition.critical) return false;
    if (definition.requiresBackup && !state.hasValidBackup) return false;
    if (definition.requiresEsn && !state.hasDeviceRead) return false;
    return _isSafeCatalogRead(definition.commandTemplate);
  }

  Future<void> sendCatalogCommand(SuntechCommandDefinition definition) async {
    final catalog = state.handshakeResult?.commandCatalog.values ?? const [];
    final belongsToCatalog = catalog.any((item) =>
        item.id == definition.id &&
        item.commandTemplate == definition.commandTemplate);
    if (!belongsToCatalog) {
      throw StateError(
          'Comando bloqueado: item não pertence ao catálogo atual.');
    }
    if (!canSendCatalogCommand(definition)) {
      throw StateError(
          'Comando bloqueado: leitura não segura ou requisito pendente.');
    }
    await _sendCommand(resolveCatalogCommand(definition));
  }

  bool _isSafeCatalogRead(String template) {
    final normalized = template.trim().toUpperCase();
    return normalized == 'AT' ||
        normalized.endsWith(';03;01') ||
        normalized.endsWith(';03;05') ||
        normalized.endsWith(';01;02') ||
        normalized.endsWith(';01;03') ||
        normalized.endsWith(';01;04') ||
        normalized.endsWith(';STATUSREQ') ||
        normalized.endsWith(';PRESET') ||
        normalized.endsWith(';REQVER');
  }

  Future<void> readFullDevice() async {
    await readStatus();
    if (state.selectedSuntechFamily == SuntechCommandFamily.unknown ||
        state.selectedSuntechFamily == SuntechCommandFamily.manual) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await readPreset();
  }

  Future<void> enable1() async {
    final family = state.selectedSuntechFamily;
    if (family == SuntechCommandFamily.unknown ||
        family == SuntechCommandFamily.manual) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Comando',
            'Enable1 bloqueado: identifique a familia no handshake.'),
      );
      return;
    }
    if (!state.hasDeviceRead) {
      throw StateError('Enable1 bloqueado: ESN nao identificado.');
    }
    if (family == SuntechCommandFamily.legacySt300St310) {
      await _sendCommand('AT^ST300CMD;;02;Enable1');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await readStatus();
      return;
    }
    await _sendCommand('AT^CMD;${state.device.esn};04;01');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await readStatus();
  }

  Future<void> disable1() async {
    final family = state.selectedSuntechFamily;
    if (family == SuntechCommandFamily.unknown ||
        family == SuntechCommandFamily.manual) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Comando',
            'Disable1 bloqueado: identifique a familia no handshake.'),
      );
      return;
    }
    if (!state.hasDeviceRead) {
      throw StateError('Disable1 bloqueado: ESN nao identificado.');
    }
    if (family == SuntechCommandFamily.legacySt300St310) {
      await _sendCommand('AT^ST300CMD;;02;Disable1');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await readStatus();
      return;
    }
    await _sendCommand('AT^CMD;${state.device.esn};04;02');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await readStatus();
  }

  Future<void> sendManualCommand(String command) async {
    if (command.trim().isEmpty) {
      throw ArgumentError('Informe um comando serial.');
    }
    final normalized = command.trim().toUpperCase();
    if (normalized.startsWith('AT^PRG') &&
        (state.selectedSuntechFamily !=
                SuntechCommandFamily.newGenSt8210St8310 ||
            !state.hasDeviceRead)) {
      throw StateError('PRG bloqueado: exige New Gen identificado com ESN.');
    }
    if ((normalized.startsWith('AT^ST300CMD') ||
            normalized.startsWith('AT^ST300NTN') ||
            normalized.startsWith('AT^ST300NTW')) &&
        state.selectedSuntechFamily != SuntechCommandFamily.legacySt300St310) {
      throw StateError('ST300CMD/NTN/NTW bloqueado fora da família Legacy.');
    }
    if (normalized.startsWith('AT^CMD') &&
        state.selectedSuntechFamily !=
            SuntechCommandFamily.newGenSt8210St8310) {
      throw StateError('AT^CMD bloqueado antes da identificação New Gen.');
    }
    await _sendCommand(command);
  }

  Future<void> requestPosition() => readStatus();

  Future<void> requestOriginalConfiguration() => readPreset();

  Future<void> repeatLastCommand() async {
    if (state.manualCommand.lastCommand.isEmpty) {
      throw StateError('Nenhum comando anterior para repetir.');
    }
    await sendManualCommand(state.manualCommand.lastCommand);
  }

  Future<void> changeBaudRate(int baudRate) async {
    _requireUsb();
    final commandPort = state.connection.commandPortName;
    final readPort = state.connection.readPortName;
    await disconnectUsb();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await connectUsb(
      commandPort,
      readPortPath: readPort == commandPort ? null : readPort,
      baudRate: baudRate,
      lineEnding: state.serialDiagnostic.selectedEnding,
      dtrEnabled: state.serialDiagnostic.dtrEnabled,
      rtsEnabled: state.serialDiagnostic.rtsEnabled,
    );
  }

  void selectSerialEnding(SerialLineEnding ending) {
    state = _copy(state,
        serialDiagnostic:
            state.serialDiagnostic.copyWith(selectedEnding: ending));
  }

  void setSerialDtr(bool enabled) {
    state = _copy(state,
        serialDiagnostic: state.serialDiagnostic.copyWith(dtrEnabled: enabled));
  }

  void setSerialRts(bool enabled) {
    state = _copy(state,
        serialDiagnostic: state.serialDiagnostic.copyWith(rtsEnabled: enabled));
  }

  Future<void> runAtDiagnostic() async {
    _requireUsb();
    await _reconnectWithDiagnosticSettings();
    final response = await _sendAndWait('AT', const Duration(seconds: 2));
    if (response != null) {
      state = _copy(
        state,
        serialDiagnostic: state.serialDiagnostic.copyWith(
          probableChannel: SerialDiagnosticResult(
            commandPortPath: state.connection.commandPortName,
            readPortPath: state.connection.readPortName,
            baudRate: state.connection.baudRate,
            ending: state.serialDiagnostic.selectedEnding,
            command: 'AT',
            response: response,
          ),
        ),
      );
    }
  }

  Future<void> runSerialDiagnosticMatrix() async {
    final ports = await scanPorts();
    final usbModemPorts = ports
        .map((port) => port.path)
        .where((path) => path.toLowerCase().contains('usbmodem'))
        .toList();
    final matrix = generateSerialDiagnosticMatrix(usbModemPorts);
    if (matrix.isEmpty) {
      throw StateError('Nenhuma porta usbmodem disponível para testar.');
    }

    state = _copy(
      state,
      serialDiagnostic: state.serialDiagnostic.copyWith(
        running: true,
        completedAttempts: 0,
        totalAttempts: matrix.length,
        rawBinaryReceived: false,
        clearProbableChannel: true,
      ),
    );

    SerialDiagnosticResult? probable;
    for (var index = 0; index < matrix.length; index++) {
      final attempt = matrix[index];
      try {
        await connectUsb(
          attempt.commandPortPath,
          readPortPath: attempt.readPortPath == attempt.commandPortPath
              ? null
              : attempt.readPortPath,
          baudRate: attempt.baudRate,
          lineEnding: attempt.ending,
          dtrEnabled: state.serialDiagnostic.dtrEnabled,
          rtsEnabled: state.serialDiagnostic.rtsEnabled,
        );
        final timeout = attempt.command == 'AT'
            ? const Duration(seconds: 2)
            : const Duration(seconds: 4);
        final response = await _sendAndWait(attempt.command, timeout);
        if (response != null) {
          probable = SerialDiagnosticResult(
            commandPortPath: attempt.commandPortPath,
            readPortPath: attempt.readPortPath,
            baudRate: attempt.baudRate,
            ending: attempt.ending,
            command: attempt.command,
            response: response,
          );
          break;
        }
      } catch (error) {
        state =
            _appendLog(state, LogEntry(_clock(), 'ERROR', 'Matriz: $error'));
      }
      state = _copy(
        state,
        serialDiagnostic:
            state.serialDiagnostic.copyWith(completedAttempts: index + 1),
      );
    }

    state = _appendLog(
      _copy(
        state,
        serialDiagnostic: state.serialDiagnostic.copyWith(
          running: false,
          probableChannel: probable,
          completedAttempts: probable == null
              ? matrix.length
              : state.serialDiagnostic.completedAttempts + 1,
        ),
      ),
      LogEntry(
        _clock(),
        'Comando',
        probable == null
            ? 'Dados brutos recebidos, mas sem resposta Suntech ASCII. Verifique porta, baudrate, modo do dispositivo ou DTR/RTS.'
            : 'Canal provável encontrado: ${probable.commandPortPath} -> ${probable.readPortPath}',
      ),
    );
  }

  Future<void> _reconnectWithDiagnosticSettings() async {
    final commandPort = state.connection.commandPortName;
    final readPort = state.connection.readPortName;
    await connectUsb(
      commandPort,
      readPortPath: readPort == commandPort ? null : readPort,
      baudRate: state.connection.baudRate,
      lineEnding: state.serialDiagnostic.selectedEnding,
      dtrEnabled: state.serialDiagnostic.dtrEnabled,
      rtsEnabled: state.serialDiagnostic.rtsEnabled,
    );
  }

  Future<String?> _sendAndWait(String command, Duration timeout) async {
    final completer = Completer<String>();
    _diagnosticResponse = completer;
    await _transport.writeLine(command);
    final response = await Future.any<String?>([
      completer.future,
      Future<String?>.delayed(timeout, () => null),
    ]);
    if (identical(_diagnosticResponse, completer)) _diagnosticResponse = null;
    return response;
  }

  void clearSerialLogs() {
    const serialSources = {
      'SEND',
      'READ',
      'READ_ASCII',
      'READ_HEX',
      'PARSER',
      'ERROR'
    };
    state = _copy(
      state,
      logs: state.logs
          .where((log) => !serialSources.contains(log.source))
          .toList(),
      manualCommand: ManualCommandState(
        lastCommand: state.manualCommand.lastCommand,
        lastResponse: '',
        waitingResponse: state.manualCommand.waitingResponse,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOG CAPTURE / DIFF WORKFLOW (Analisar → ação física → Parar análise)
  // ──────────────────────────────────────────────────────────────────────────

  /// Max captured lines kept in the session to avoid unbounded memory growth.
  static const int _maxCaptureLines = 8000;

  /// Starts a capture session. Raw Teltonika lines are accumulated until
  /// [stopTeltonikaCapture] runs the analysis.
  void startTeltonikaCapture() {
    if (state.logCapture.active) return;
    if (!_transport.connected) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Captura',
            'Conecte a porta USB/serial antes de iniciar a análise.'),
      );
      return;
    }
    state = _appendLog(
      _copy(
        state,
        logCapture: LogCaptureState(active: true, startedAt: _clock()),
      ),
      LogEntry(
        _clock(),
        'Captura',
        'Análise iniciada. Execute a ação física no veículo e depois toque em "Parar análise".',
      ),
    );
  }

  /// Stops the capture and runs the Teltonika analysis + diff on the captured
  /// lines, identifying which packets changed and which IO (sensor) moved.
  void stopTeltonikaCapture() {
    if (!state.logCapture.active) return;
    final lines = state.logCapture.capturedLines;

    final analysis = TeltonikaCaptureAnalyzer.analyze(
      lines,
      state.logCapture.hexChunks,
    );
    final diff = TeltonikaCaptureAnalyzer.diff(analysis);

    var next = _copy(
      state,
      logCapture: LogCaptureState(
        active: false,
        startedAt: state.logCapture.startedAt,
        capturedLines: lines,
        hexChunks: state.logCapture.hexChunks,
        analysis: analysis,
        diff: diff,
      ),
    );

    next = _appendLog(
      next,
      LogEntry(
        _clock(),
        'Captura',
        'Análise concluída: ${diff.totalRecords} registro(s), '
            '${diff.changedRecordCount} pacote(s) com alteração, '
            '${diff.ioChanges.length} IO(s) alterado(s).',
      ),
    );
    for (final line in diff.summary) {
      next = _appendLog(next, LogEntry(_clock(), 'Captura', line));
    }
    if (diff.unknownChangedIos.isNotEmpty) {
      next = _appendLog(
        next,
        LogEntry(
          _clock(),
          'Captura',
          'IOs sem catálogo alterados (candidatos a sensor CAN): '
              '${diff.unknownChangedIos.map((c) => c.avlId).join(', ')}. '
              'Registre o mapeamento para o fabricante.',
        ),
      );
    }
    if (analysis.parameterValues.isNotEmpty) {
      final summary = analysis.parameterValues.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      final confirmed =
          analysis.confirmedParameters.map((id) => '$id').join(', ');
      next = _appendLog(
        next,
        LogEntry(
          _clock(),
          'Captura',
          'Parâmetros de configuração vistos na captura: $summary.'
              '${confirmed.isEmpty ? '' : ' Confirmados pelo rastreador: $confirmed.'} '
              'Os formulários Teltonika foram preenchidos com esses valores.',
        ),
      );
    }
    state = next;
  }

  /// Clears the capture buffer, analysis and diff.
  void clearTeltonikaCapture() {
    state = _copy(
      state,
      logCapture: const LogCaptureState(),
    );
  }

  /// Persists the last stopped capture (lines + analysis) to the local capture
  /// log store so it survives closing the session. Only called when the user
  /// explicitly taps "Salvar logs para análise".
  Future<void> saveTeltonikaCaptureForAnalysis() async {
    final capture = state.logCapture;
    if (capture.analysis == null) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Captura',
            'Pare a análise antes de salvar os logs para análise.'),
      );
      return;
    }
    try {
      final id = '${DateTime.now().millisecondsSinceEpoch}';
      await _captureLogs.append(CaptureLogRecord(
        id: id,
        sessionCode: state.sessionCode,
        startedAt: capture.startedAt,
        stoppedAt: _clock(),
        lines: List.from(capture.capturedLines),
        analysis: capture.analysis!.toJson(),
      ));
      final params = capture.analysis!.parameterValues;
      state = _appendLog(
        state,
        LogEntry(
          _clock(),
          'Captura',
          'Logs salvos para análise '
              '(${capture.capturedLines.length} linha(s), '
              '${params.length} parâmetro(s)). '
              'Arquivo: tracker_studio_capture_logs.json.',
        ),
      );
    } catch (error) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'Captura', 'Falha ao salvar os logs: $error'),
      );
    }
  }

  /// Appends a normalized line to the active capture buffer.
  void _captureLine(String line) {
    if (!state.logCapture.active) return;

    // Always preserve `[READ_HEX]` payloads separately so the binary AVL codec
    // can be decoded even though they are excluded from normalized `capturedLines`.
    if (line.startsWith('[READ_HEX] ')) {
      final hex = line.substring('[READ_HEX] '.length).trim();
      if (hex.isNotEmpty) {
        final nextHex =
            <String>[...state.logCapture.hexChunks, hex];
        state = _copy(
          state,
          logCapture: state.logCapture.copyWith(hexChunks: nextHex),
        );
      }
      // Hex chunks are captured independently; do not enter normalized lines.
      return;
    }

    final normalized = _normalizeCaptureLine(line);
    if (normalized == null) return;

    final current = state.logCapture.capturedLines;
    var nextLines = <String>[...current, normalized];
    var overflow = false;
    if (nextLines.length > _maxCaptureLines) {
      nextLines = nextLines.sublist(nextLines.length - _maxCaptureLines);
      overflow = true;
    }
    state = _copy(
      state,
      logCapture: state.logCapture.copyWith(capturedLines: nextLines),
    );
    if (overflow) {
      state = _appendLog(
        state,
        LogEntry(
          _clock(),
          'Captura',
          'Limite de $_maxCaptureLines linhas atingido; linhas mais antegas descartadas.',
        ),
      );
    }
  }

  String? _normalizeCaptureLine(String line) {
    if (line.startsWith('[READ] ')) return line.substring(7);
    if (line.startsWith('[SEND] ')) return line.substring(7);
    if (line.startsWith('[READ_ASCII] ')) {
      return line.substring('[READ_ASCII] '.length).trim();
    }
    if (line.startsWith('[READ_HEX] ')) {
      return line.substring('[READ_HEX] '.length).trim();
    }
    if (line.startsWith('[SEND_HEX] ')) return null;
    if (line.startsWith('[SERIAL')) return null;
    if (line.startsWith('USB conectado') || line == 'USB desconectado') {
      return null;
    }
    final normalized = line.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> requestStatus() => readStatus();
  Future<void> requestPreset() => readPreset();
  Future<void> runBasicRead() => readFullDevice();

  Future<void> _sendCommand(String command, {bool silent = false}) async {
    _requireUsb();
    await _transport.writeLine(command);
    if (silent) return;
    final sentAt = DateTime.now();
    _responseTimer?.cancel();
    state = _copy(
      state,
      manualCommand: ManualCommandState(
        lastCommand: command,
        lastResponse: state.manualCommand.lastResponse,
        waitingResponse: true,
      ),
    );
    _responseTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed || _isDisconnecting) return;
      if (!state.manualCommand.waitingResponse) return;
      state = _appendLog(
        _copy(
          state,
          manualCommand: ManualCommandState(
            lastCommand: state.manualCommand.lastCommand,
            lastResponse: state.manualCommand.lastResponse,
            waitingResponse: false,
          ),
        ),
        LogEntry(
          _clock(),
          'ERROR',
          _lastRawAt != null &&
                  _lastRawAt!.isAfter(sentAt) &&
                  (_lastValidAt == null || _lastValidAt!.isBefore(sentAt))
              ? 'Recebi dados da serial, mas ainda não encontrei resposta Suntech válida. Abra o Laboratório e execute Testar matriz.'
              : 'Sem resposta após 5s. Verifique porta de retorno, baudrate ou alimentação.',
        ),
      );
    });
  }

  Future<void> captureServiceLocation() async {
    final result = await _serviceLocation.requestServiceLocation();
    if (!result.success) {
      final status = result.permissionDenied ? 'sem permissão' : 'indisponível';
      state = _appendLog(
        _copy(
          state,
          serviceLocation: ServiceLocation(
            latitude: 0,
            longitude: 0,
            accuracyMeters: 0,
            status: status,
            capturedAt: '',
          ),
        ),
        LogEntry(_clock(), 'Serviço',
            result.error ?? 'Localização do serviço indisponível'),
      );
      return;
    }

    final capturedAt = _formatDateTime(result.capturedAt!);
    state = _appendLog(
      _copy(
        state,
        serviceLocation: ServiceLocation(
          latitude: result.latitude!,
          longitude: result.longitude!,
          accuracyMeters: result.accuracyMeters!,
          status: 'capturado',
          capturedAt: capturedAt,
        ),
      ),
      LogEntry(_clock(), 'Serviço', 'Localização do serviço capturada'),
    );
    runServiceValidation();
  }

  Future<void> queryLocalitel() async {
    if (!state.localitel.hasValidCoordinates) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'LocaliTel',
            'Consulta ignorada: ainda nao ha coordenadas reais'),
      );
      return;
    }

    if (!_localitel.enabled) {
      state = _appendLog(
        state,
        LogEntry(_clock(), 'LocaliTel',
            'LocaliTel nao configurada (LOCALITEL_API_URL). Double-check opcional.'),
      );
      return;
    }

    state = _copy(
      state,
      localitel: LocalitelAnalysis(
        latitude: state.localitel.latitude,
        longitude: state.localitel.longitude,
        address: state.localitel.address,
        radiusKm: state.localitel.radiusKm,
        status: 'consultando',
        summary: 'Consultando endereco e cobertura...',
      ),
    );

    final result = await _localitel.analyze(
      latitude: state.localitel.latitude,
      longitude: state.localitel.longitude,
      radiusKm: state.localitel.radiusKm,
      deviceModel: state.device.model,
      serviceLatitude:
          state.serviceLocation.isValid ? state.serviceLocation.latitude : null,
      serviceLongitude: state.serviceLocation.isValid
          ? state.serviceLocation.longitude
          : null,
      serviceRadiusMeters: state.serviceLocation.isValid ? 150 : null,
    );

    final testStatus = switch (result.status) {
      'ok' => result.serviceWithinRadius == false
          ? TestStatus.warning
          : TestStatus.passed,
      'warning' => TestStatus.warning,
      _ => TestStatus.notApplicable,
    };
    final serviceCheck = result.serviceWithinRadius == null
        ? 'pendente'
        : result.serviceWithinRadius!
            ? 'Dentro do raio'
            : 'Fora do raio, alerta de campo';

    state = _appendLog(
      _copy(
        state,
        localitel: LocalitelAnalysis(
          latitude: result.latitude,
          longitude: result.longitude,
          address: result.address,
          radiusKm: result.radiusKm,
          status: result.status,
          summary: _localitelSummary(result),
          serviceDistanceMeters: result.serviceDistanceMeters,
          serviceToleranceMeters: result.serviceToleranceMeters ?? 150,
          serviceCheck: serviceCheck,
        ),
        tests: _upsertTest(
          state.tests,
          TestStepState(
            'localitel_doublecheck',
            'LocaliTel (double-check)',
            testStatus,
            result.status == 'ok' ? 1 : 0,
            0,
            'Double-check: ${result.summary}',
          ),
        ),
      ),
      LogEntry(_clock(), 'LocaliTel', result.summary),
    );
  }

  void validateInstallation() {
    final pending = state.tests
        .where((test) =>
            test.requiredCount > 0 && test.status != TestStatus.passed)
        .length;
    state = _appendLog(
      state,
      LogEntry(
        _clock(),
        'Validação',
        pending == 0
            ? 'Checklist operacional concluído'
            : 'Validação pendente: $pending item(ns) aguardando confirmação',
      ),
    );
  }

  void generateReport() {
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Relatório',
          'Relatório preparado com os dados reais disponíveis na sessão'),
    );
  }

  Future<void> applyTestServer() async {
    if (!state.hasValidBackup) {
      throw StateError(
          'Sem backup real. Primeiro leia a configuracao original do dispositivo.');
    }
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Configuracao',
          'Aplicacao real bloqueada nesta etapa: aguardando envio homologado e readback.'),
    );
  }

  Future<void> restoreOriginal() async {
    if (!state.hasValidBackup) {
      throw StateError('Sem backup real para restaurar.');
    }
    state = _appendLog(
      state,
      LogEntry(_clock(), 'Restauracao',
          'Restauracao real bloqueada nesta etapa: sera liberada com confirmacao por readback.'),
    );
  }

  void ingestRawLine(String rawLine, {String source = 'USB'}) {
    if (!_isKnownProtocolLine(rawLine)) {
      final now = DateTime.now();
      if (_lastParserIgnoreWarningAt == null ||
          now.difference(_lastParserIgnoreWarningAt!) >=
              const Duration(seconds: 1)) {
        _lastParserIgnoreWarningAt = now;
        state = _appendLog(
          state,
          LogEntry(_clock(), 'PARSER',
              'READ bruto recebido; parser ignorou por não corresponder ao protocolo Suntech ASCII.'),
        );
      }
      return;
    }
    _lastValidAt = DateTime.now();
    final snapshot = _parser.parseLine(rawLine);
    if (snapshot == null) return;

    final now = _clock();
    var next = _appendLog(
        state, LogEntry(now, source, 'Resposta recebida: ${_short(rawLine)}'));

    if (snapshot.manufacturer != null ||
        snapshot.model != null ||
        snapshot.esn != null ||
        snapshot.firmware != null) {
      next = _copy(
        next,
        device: DeviceSummary(
          manufacturer: snapshot.manufacturer ?? next.device.manufacturer,
          model: snapshot.model ?? next.device.model,
          esn: snapshot.esn ?? next.device.esn,
          firmware: snapshot.firmware ?? next.device.firmware,
          imei: next.device.imei,
          sim: next.device.sim,
        ),
        tests: _upsertTest(
          next.tests,
          TestStepState(
              'identity',
              'Identidade do equipamento',
              TestStatus.passed,
              1,
              1,
              'ESN ${snapshot.esn ?? next.device.esn}'),
        ),
        stages: const [
          SessionStage('Conectar USB', completed: true),
          SessionStage('Identificar', completed: true),
          SessionStage('Ler original', active: true),
          SessionStage('Backup'),
          SessionStage('Configurar'),
          SessionStage('Testar'),
          SessionStage('Restaurar'),
          SessionStage('Finalizar'),
        ],
      );
      final resolvedFamily =
          resolveSuntechFamily(snapshot.model ?? next.device.model);
      if (next.selectedSuntechFamily == SuntechCommandFamily.unknown &&
          resolvedFamily != SuntechCommandFamily.unknown) {
        next = _copy(next, selectedSuntechFamily: resolvedFamily);
      }
    }

    if (snapshot.mainVoltage != null ||
        snapshot.backupVoltage != null ||
        snapshot.gpsFix != null ||
        snapshot.satellites != null) {
      next = _applyTelemetry(next, snapshot);
    }

    if (snapshot.configuration.isNotEmpty) {
      next = _copy(
        next,
        configuration: ConfigurationSnapshot(
          original: _mergeNormalizedConfig(
              next.configuration.original, snapshot.configuration),
          desired: next.configuration.desired,
          backupProtected: true,
          backupCreatedAt: next.configuration.backupCreatedAt.isEmpty
              ? _dateTimeLabel()
              : next.configuration.backupCreatedAt,
        ),
        stages: const [
          SessionStage('Conectar USB', completed: true),
          SessionStage('Identificar', completed: true),
          SessionStage('Ler original', completed: true),
          SessionStage('Backup', completed: true),
          SessionStage('Configurar', active: true),
          SessionStage('Testar'),
          SessionStage('Restaurar'),
          SessionStage('Finalizar'),
        ],
      );
      next = _appendLog(
          next,
          LogEntry(now, source,
              'Configuracao original lida do dispositivo e backup protegido'));
    }

    for (final warning in snapshot.warnings) {
      next = _appendLog(next, LogEntry(now, 'PARSER', warning));
    }
    state = next;
    runServiceValidation();
  }

  void markGprsPacketReceived() {
    final nextConnection = ConnectionSummary(
      commandPortName: state.connection.commandPortName,
      readPortName: state.connection.readPortName,
      baudRate: state.connection.baudRate,
      usbConnected: state.connection.usbConnected,
      smsReady: state.connection.smsReady,
      gprsOnline: true,
      portValidated: state.connection.portValidated,
      lastPacketSecondsAgo: 0,
      networkCode: state.connection.networkCode,
      networkWarning: state.connection.networkWarning,
    );

    state = _appendLog(
      _copy(
        state,
        connection: nextConnection,
        tests: _upsertTest(
            state.tests,
            const TestStepState('network', 'Rede / GPRS', TestStatus.passed, 3,
                3, 'Pacote real confirmado')),
      ),
      LogEntry(_clock(), 'GPRS', 'Pacote GPRS confirmado'),
    );
  }

  void _handleTransportLine(String line) {
    if (_disposed || _isDisconnecting) return;
    _captureLine(line);
    if (line.startsWith('[SEND]')) {
      state = _appendLog(state, LogEntry(_clock(), 'SEND', line));
      return;
    }
    if (line.startsWith('[SEND_HEX]')) {
      state = _appendLog(state, LogEntry(_clock(), 'SEND', line));
      return;
    }
    if (line.startsWith('[SERIAL')) {
      state = _appendLog(state, LogEntry(_clock(), 'ERROR', line));
      return;
    }
    if (line.startsWith('USB conectado') || line == 'USB desconectado') {
      state = _appendLog(state, LogEntry(_clock(), 'USB', line));
      return;
    }
    if (line.startsWith('[READ_ASCII] ')) {
      final ascii = line.substring(13);
      _lastRawAt = DateTime.now();
      if (!_isAsciiEcho(ascii) &&
          isProbableAsciiResponse(ascii) &&
          _diagnosticResponse?.isCompleted == false) {
        _diagnosticResponse?.complete(ascii);
      }
      state = _appendLog(state, LogEntry(_clock(), 'READ_ASCII', ascii));
      return;
    }
    if (line.startsWith('[READ_HEX] ')) {
      final hex = line.substring(11);
      final bytes = bytesFromHex(hex);
      final binary = bytes.isNotEmpty && printableAsciiRatio(bytes) <= 0.70;
      state = _copy(
        _appendLog(state, LogEntry(_clock(), 'READ_HEX', hex)),
        serialDiagnostic: state.serialDiagnostic.copyWith(
          rawBinaryReceived: state.serialDiagnostic.rawBinaryReceived || binary,
        ),
      );
      return;
    }
    if (line.startsWith('[READ] ')) {
      final rawLine = line.substring(7);
      if (isCommandEcho(state.manualCommand.lastCommand, rawLine)) {
        state = _appendLog(state, LogEntry(_clock(), 'ECHO', rawLine));
        return;
      }
      _responseTimer?.cancel();
      if (isProbableAsciiResponse(rawLine) &&
          _diagnosticResponse?.isCompleted == false) {
        _diagnosticResponse?.complete(rawLine);
      }
      _responseTimer?.cancel();
      if (rawLine.trim().toUpperCase() == 'OK' &&
          state.manualCommand.lastCommand.trim().toUpperCase() == 'AT') {
        state = _appendLog(
          _copy(
            state,
            connection: ConnectionSummary(
              commandPortName: state.connection.commandPortName,
              readPortName: state.connection.readPortName,
              baudRate: state.connection.baudRate,
              usbConnected: state.connection.usbConnected,
              smsReady: state.connection.smsReady,
              gprsOnline: state.connection.gprsOnline,
              portValidated: true,
              lastPacketSecondsAgo: state.connection.lastPacketSecondsAgo,
              networkCode: state.connection.networkCode,
              networkWarning: state.connection.networkWarning,
            ),
            manualCommand: ManualCommandState(
              lastCommand: state.manualCommand.lastCommand,
              lastResponse: rawLine,
              waitingResponse: false,
            ),
          ),
          LogEntry(_clock(), 'READ',
              'OK — porta serial validada; equipamento ainda não identificado.'),
        );
        return;
      }
      final isSilentResponse = _statusPollingTimer?.isActive == true &&
          (rawLine.contains('STT;') || rawLine.contains(';STT;'));

      final nextState = _copy(
        state,
        manualCommand: ManualCommandState(
          lastCommand: state.manualCommand.lastCommand,
          lastResponse: rawLine,
          waitingResponse: false,
        ),
      );

      state = isSilentResponse
          ? nextState
          : _appendLog(nextState, LogEntry(_clock(), 'READ', rawLine));
      ingestRawLine(rawLine, source: 'PARSER');
      return;
    }
    ingestRawLine(line);
  }

  void _requireUsb() {
    if (!_transport.connected) {
      throw StateError(
          'Conecte uma porta USB/serial real antes de enviar comandos.');
    }
  }

  void _setControlledHandshakeError(String message) {
    if (_disposed) return;
    final result = SuntechHandshakeResult(
      family: SuntechCommandFamily.unknown,
      model: null,
      esn: null,
      firmware: null,
      imei: null,
      baudRate: state.connection.baudRate,
      protocol: null,
      compatibility: _transport.connected
          ? 'Porta OK, mas família não identificada.'
          : 'USB serial não conectado.',
      portOk: state.connection.portValidated,
      commandCatalog: const {},
      rawEvidence: ['[HANDSHAKE ERROR] $message'],
      error: message,
    );
    state = _appendLog(
      _copy(state, handshakeResult: result),
      LogEntry(_clock(), 'Handshake', 'Erro controlado: $message'),
    );
  }

  bool _isExpectedClosedPortError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('already closed') ||
        message.contains('bad file descriptor') ||
        message.contains('port closed') ||
        message.contains('não conectado') ||
        message.contains('not connected');
  }

  bool _isKnownProtocolLine(String line) {
    final normalized = line.trimLeft().toUpperCase();
    final prefixes = switch (state.selectedSuntechFamily) {
      SuntechCommandFamily.legacySt300St310 => const [
          'ST300STT',
          'ST300CMD',
          'ST300NTN',
          'ST300NTW',
          'OK',
          'ACK',
          'ERR'
        ],
      SuntechCommandFamily.newGenSt8210St8310 => const [
          'RES;',
          'OK',
          'ACK',
          'ERR',
          'STT',
          'ALV',
          'PRG'
        ],
      SuntechCommandFamily.unknown || SuntechCommandFamily.manual => const [
          'OK',
          'ACK',
          'ERR'
        ],
    };
    return prefixes.any(normalized.startsWith);
  }

  bool _isAsciiEcho(String ascii) {
    final normalized = ascii.replaceAll(r'\r', '').replaceAll(r'\n', '').trim();
    return isCommandEcho(state.manualCommand.lastCommand, normalized);
  }

  TrackerSessionState _applyTelemetry(
      TrackerSessionState current, NormalizedTrackerSnapshot snapshot) {
    final gprsOnline =
        snapshot.gprsOnline == true || current.connection.gprsOnline;
    final lastPacket = gprsOnline ? 0 : current.connection.lastPacketSecondsAgo;
    final networkWarning = snapshot.networkCode == '255'
        ? 'Codigo 255 observado no STT; pacote recente/GPRS online mantem rede conectada.'
        : current.connection.networkWarning;

    var next = _copy(
      current,
      connection: ConnectionSummary(
        commandPortName: current.connection.commandPortName,
        readPortName: current.connection.readPortName,
        baudRate: current.connection.baudRate,
        usbConnected: current.connection.usbConnected,
        smsReady: current.connection.smsReady,
        gprsOnline: gprsOnline,
        portValidated: current.connection.portValidated,
        lastPacketSecondsAgo: lastPacket,
        networkCode: snapshot.networkCode ?? current.connection.networkCode,
        networkWarning: networkWarning,
      ),
      localitel: snapshot.hasPosition
          ? LocalitelAnalysis(
              latitude: snapshot.latitude!,
              longitude: snapshot.longitude!,
              address: current.localitel.address,
              radiusKm: current.localitel.radiusKm,
              status: current.localitel.status,
              summary: current.localitel.summary,
              serviceDistanceMeters: current.localitel.serviceDistanceMeters,
              serviceToleranceMeters: current.localitel.serviceToleranceMeters,
              serviceCheck: current.localitel.serviceCheck,
            )
          : current.localitel,
    );

    final nowDateTime = DateTime.now();
    final newVoltageHistory = List<TelemetryDataPoint>.from(current.voltageHistory);
    final newBackupVoltageHistory = List<TelemetryDataPoint>.from(current.backupVoltageHistory);
    final newIgnitionHistory = List<EventRecord>.from(current.ignitionHistory);
    final newCommandHistory = List<EventRecord>.from(current.commandHistory);

    if (snapshot.mainVoltage != null) {
      newVoltageHistory.add(TelemetryDataPoint(nowDateTime, snapshot.mainVoltage!));
    }
    if (snapshot.backupVoltage != null) {
      newBackupVoltageHistory.add(TelemetryDataPoint(nowDateTime, snapshot.backupVoltage!));
    }

    final tests = [...next.tests];
    if (snapshot.mainVoltage != null) {
      tests.replaceById(TestStepState(
        'main_power',
        'Alimentacao principal',
        snapshot.mainVoltage! >= 9 ? TestStatus.passed : TestStatus.failed,
        snapshot.mainVoltage! >= 9 ? 3 : 0,
        3,
        '${snapshot.mainVoltage!.toStringAsFixed(2)} V',
      ));
    }
    if (snapshot.backupVoltage != null) {
      tests.replaceById(TestStepState(
        'backup_power',
        'Bateria de backup',
        snapshot.backupPresent ? TestStatus.passed : TestStatus.warning,
        snapshot.backupPresent ? 3 : 0,
        3,
        snapshot.backupPresent
            ? '${snapshot.backupVoltage!.toStringAsFixed(1)} V presente'
            : 'Backup zerado ou desligado',
      ));
    }
    if (gprsOnline) {
      tests.replaceById(const TestStepState('network', 'Rede / GPRS',
          TestStatus.passed, 3, 3, 'GPRS online; pacote recente recebido'));
    }
    if (snapshot.satellites != null || snapshot.gpsFix != null) {
      final passed = snapshot.gpsFix == true && (snapshot.satellites ?? 0) >= 4;
      tests.replaceById(TestStepState(
        'gps',
        'GPS e satelites',
        passed ? TestStatus.passed : TestStatus.running,
        passed ? 3 : 1,
        3,
        '${snapshot.gpsFix == true ? 'Fix' : 'Sem fix'} · ${snapshot.satellites ?? 0} satelites',
      ));
    }
    if (snapshot.ignitionOn != null || snapshot.inputMask != null) {
      tests.replaceById(TestStepState(
        'ignition',
        'Ignicao',
        TestStatus.passed,
        3,
        3,
        snapshot.ignitionOn == true ? 'Ligada' : 'Desligada ou entrada mapeada',
      ));
    }

    final changes = _detectBehaviorChanges(current, snapshot);
    if (changes.isNotEmpty) {
      for (final change in changes) {
        if (change.field == 'ignicao') {
          newIgnitionHistory.add(EventRecord(
            timestamp: nowDateTime,
            event: change.newValue,
            detail: change.description,
          ));
        } else if (change.field == 'saida') {
          newCommandHistory.add(EventRecord(
            timestamp: nowDateTime,
            event: 'Saída alterada',
            detail: change.description,
          ));
        }
      }
      
      next = _copy(
        next,
        behaviorChanges: [...current.behaviorChanges, ...changes],
      );
      for (final change in changes) {
        next = _appendLog(
          next,
          LogEntry(_clock(), 'Comportamento', change.description),
        );
      }
    }

    next = _copy(
      next,
      tests: tests,
      diagnostics: _diagnosticsFrom(next, snapshot),
      voltageHistory: newVoltageHistory,
      backupVoltageHistory: newBackupVoltageHistory,
      ignitionHistory: newIgnitionHistory,
      commandHistory: newCommandHistory,
    );
    return next;
  }

  List<BehaviorChange> _detectBehaviorChanges(
      TrackerSessionState current, NormalizedTrackerSnapshot snapshot) {
    final changes = <BehaviorChange>[];
    final now = _clock();

    if (snapshot.ignitionOn != null) {
      final previousIgnition = current.tests
          .where((t) => t.id == 'ignition')
          .map((t) => t.detail)
          .firstOrNull;
      final newIgnition = snapshot.ignitionOn! ? 'Ligada' : 'Desligada';
      if (previousIgnition != null && !previousIgnition.contains(newIgnition)) {
        changes.add(BehaviorChange(
          timestamp: now,
          field: 'ignicao',
          previousValue: previousIgnition,
          newValue: newIgnition,
          description: 'Ignicao mudou: $previousIgnition -> $newIgnition',
        ));
      }
    }

    if (snapshot.outputMask != null) {
      final previousOutput = current.diagnostics
          .where((d) => d.title == 'I/O')
          .map((d) => d.values['Saida'])
          .firstOrNull;
      if (previousOutput != null && previousOutput != snapshot.outputMask) {
        changes.add(BehaviorChange(
          timestamp: now,
          field: 'saida',
          previousValue: previousOutput,
          newValue: snapshot.outputMask!,
          description: 'Saida mudou: $previousOutput -> ${snapshot.outputMask}',
        ));
      }
    }

    if (snapshot.gprsOnline != null) {
      final wasOnline = current.connection.gprsOnline;
      final isOnline = snapshot.gprsOnline!;
      if (wasOnline != isOnline) {
        changes.add(BehaviorChange(
          timestamp: now,
          field: 'gprs',
          previousValue: wasOnline ? 'Online' : 'Offline',
          newValue: isOnline ? 'Online' : 'Offline',
          description: 'GPRS mudou: ${wasOnline ? 'Online' : 'Offline'} -> ${isOnline ? 'Online' : 'Offline'}',
        ));
      }
    }

    return changes;
  }

  List<DiagnosticGroup> _diagnosticsFrom(
      TrackerSessionState current, NormalizedTrackerSnapshot snapshot) {
    return [
      DiagnosticGroup('Identidade', {
        'Modelo': current.device.model,
        'ESN': current.device.esn.isEmpty ? '-' : current.device.esn,
        'Firmware': current.device.firmware
      }),
      DiagnosticGroup('GPS', {
        'Fix': snapshot.gpsFix == true ? 'OK' : 'Aguardando',
        'Satelites': '${snapshot.satellites ?? '-'}',
        'Latitude': snapshot.latitude == null ? '-' : '${snapshot.latitude}',
        'Longitude': snapshot.longitude == null ? '-' : '${snapshot.longitude}',
      }),
      DiagnosticGroup('Alimentacao', {
        'Principal': snapshot.mainVoltage == null
            ? '-'
            : '${snapshot.mainVoltage!.toStringAsFixed(2)} V',
        'Backup': snapshot.backupVoltage == null
            ? '-'
            : '${snapshot.backupVoltage!.toStringAsFixed(1)} V',
        'Estado backup': snapshot.backupPresent ? 'presente' : 'nao confirmado',
      }),
      DiagnosticGroup('Rede', {
        'GPRS': current.connection.gprsOnline ? 'OK' : 'Aguardando',
        'Ultimo pacote': current.connection.lastPacketSecondsAgo == null
            ? '-'
            : '${current.connection.lastPacketSecondsAgo} s',
        if (current.connection.networkWarning != null)
          'Aviso': current.connection.networkWarning!,
      }),
      DiagnosticGroup('I/O', {
        'Entrada': snapshot.inputMask ?? '-',
        'Saida': snapshot.outputMask ?? '-',
        'Ignicao': snapshot.ignitionOn == true ? 'ON' : 'OFF / nao mapeada'
      }),
    ];
  }

  TrackerSessionState _copy(
    TrackerSessionState current, {
    String? sessionCode,
    String? profileName,
    DeviceSummary? device,
    ConnectionSummary? connection,
    ConfigurationSnapshot? configuration,
    LocalitelAnalysis? localitel,
    ServiceLocation? serviceLocation,
    ManualCommandState? manualCommand,
    InstallationProfile? selectedProfile,
    List<GeneratedCommandPlan>? generatedCommandPlan,
    SerialDiagnosticState? serialDiagnostic,
    SuntechCommandFamily? selectedSuntechFamily,
    StudioMode? studioMode,
    List<SessionStage>? stages,
    List<TestStepState>? tests,
    List<CommandItem>? commands,
    List<DiagnosticGroup>? diagnostics,
    List<LogEntry>? logs,
    WorkOrder? activeWorkOrder,
    bool clearActiveWorkOrder = false,
    List<WorkOrder>? todayWorkOrders,
    ServiceValidation? serviceValidation,
    SuntechHandshakeResult? handshakeResult,
    bool clearHandshakeResult = false,
    NetworkWriteResult? networkWriteResult,
    List<CompletedServiceRecord>? recentCompletedServices,
    List<CompletedServiceRecord>? pendingSyncServices,
    List<BehaviorChange>? behaviorChanges,
    List<TelemetryDataPoint>? voltageHistory,
    List<TelemetryDataPoint>? backupVoltageHistory,
    List<EventRecord>? ignitionHistory,
    List<EventRecord>? commandHistory,
    LogCaptureState? logCapture,
  }) {
    return TrackerSessionState(
      sessionCode: sessionCode ?? current.sessionCode,
      profileName: profileName ?? current.profileName,
      device: device ?? current.device,
      connection: connection ?? current.connection,
      configuration: configuration ?? current.configuration,
      localitel: localitel ?? current.localitel,
      serviceLocation: serviceLocation ?? current.serviceLocation,
      manualCommand: manualCommand ?? current.manualCommand,
      selectedProfile: selectedProfile ?? current.selectedProfile,
      generatedCommandPlan:
          generatedCommandPlan ?? current.generatedCommandPlan,
      serialDiagnostic: serialDiagnostic ?? current.serialDiagnostic,
      selectedSuntechFamily:
          selectedSuntechFamily ?? current.selectedSuntechFamily,
      studioMode: studioMode ?? current.studioMode,
      stages: stages ?? current.stages,
      tests: tests ?? current.tests,
      commands: commands ?? current.commands,
      diagnostics: diagnostics ?? current.diagnostics,
      logs: logs ?? current.logs,
      activeWorkOrder: clearActiveWorkOrder
          ? null
          : activeWorkOrder ?? current.activeWorkOrder,
      todayWorkOrders: todayWorkOrders ?? current.todayWorkOrders,
      serviceValidation: serviceValidation ?? current.serviceValidation,
      handshakeResult: clearHandshakeResult
          ? null
          : handshakeResult ?? current.handshakeResult,
      networkWriteResult: networkWriteResult ?? current.networkWriteResult,
      recentCompletedServices:
          recentCompletedServices ?? current.recentCompletedServices,
      pendingSyncServices: pendingSyncServices ?? current.pendingSyncServices,
      behaviorChanges: behaviorChanges ?? current.behaviorChanges,
      voltageHistory: voltageHistory ?? current.voltageHistory,
      backupVoltageHistory: backupVoltageHistory ?? current.backupVoltageHistory,
      ignitionHistory: ignitionHistory ?? current.ignitionHistory,
      commandHistory: commandHistory ?? current.commandHistory,
      logCapture: logCapture ?? current.logCapture,
    );
  }

  List<WorkOrder> _replaceWorkOrder(
      List<WorkOrder> workOrders, WorkOrder replacement) {
    return [
      for (final workOrder in workOrders)
        if (workOrder.id == replacement.id) replacement else workOrder
    ];
  }

  TrackerSessionState _appendLog(TrackerSessionState current, LogEntry entry) =>
      _copy(current, logs: [...current.logs, entry]);

  List<TestStepState> _upsertTest(
      List<TestStepState> tests, TestStepState replacement) {
    final copy = [...tests];
    copy.replaceById(replacement);
    return copy;
  }

  Map<String, String> _mergeNormalizedConfig(
      Map<String, String> current, Map<String, String> incoming) {
    final result = Map<String, String>.from(current);
    for (final entry in incoming.entries) {
      result[_displayConfigKey(entry.key)] = entry.value;
    }
    return result;
  }

  String _displayConfigKey(String key) => switch (key) {
        'Servidor primario' => 'Servidor primário',
        'Porta primaria' => 'Porta primária',
        'Servidor secundario' => 'Servidor secundário',
        'Porta secundaria' => 'Porta secundária',
        'Usuario' => 'Usuário',
        _ => key,
      };

  String _localitelSummary(LocalitelCoverageResult result) {
    final details = <String>[result.summary];
    if (result.erbCount != null) details.add('${result.erbCount} ERBs no raio');
    if (result.recommendedOperator != null) {
      details.add(
          'recomendacao: ${result.recommendedOperator}${result.recommendedTechnology == null ? '' : ' ${result.recommendedTechnology}'}');
    }
    return details.join(' · ');
  }

  String _short(String raw) =>
      raw.length <= 120 ? raw : '${raw.substring(0, 120)}...';

  String _clock() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _dateTimeLabel() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _handshakeEngine.cancel();
    _responseTimer?.cancel();
    _serialSubscription?.cancel();
    _statusPollingTimer?.cancel();
    if (_diagnosticResponse?.isCompleted == false) {
      _diagnosticResponse?.complete('');
    }
    unawaited(_transport.disconnect());
    super.dispose();
  }
}

extension _TestListMutation on List<TestStepState> {
  void replaceById(TestStepState replacement) {
    final index = indexWhere((step) => step.id == replacement.id);
    if (index < 0) {
      add(replacement);
      return;
    }
    final current = this[index];
    if (current.status == TestStatus.passed &&
        replacement.status != TestStatus.failed) {
      // A aprovação é persistente durante a sessão. A leitura mais recente
      // continua registrada nos logs; concatená-la aqui fazia o texto da UI
      // crescer a cada refresh ("última leitura" repetida indefinidamente).
      this[index] = TestStepState(
        current.id,
        current.label,
        current.status,
        current.successCount,
        current.requiredCount,
        current.detail,
      );
      return;
    }
    this[index] = replacement;
  }
}
