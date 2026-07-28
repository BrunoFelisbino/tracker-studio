import 'installation_profiles.dart';
import 'completed_service_repository.dart';
import 'serial_diagnostics.dart';
import 'suntech_command_family.dart';
import 'suntech_handshake_engine.dart';
import 'work_order_models.dart';

enum TransportChannel { usbSerial, sms, gprs }

enum StudioMode { quickTest, lab }

enum TestStatus { pending, running, passed, warning, failed, notApplicable }

bool canReadSuntechDevice({
  required bool usbConnected,
  required SuntechCommandFamily family,
  required bool hasEsn,
}) =>
    usbConnected &&
    (family == SuntechCommandFamily.legacySt300St310 ||
        (family == SuntechCommandFamily.newGenSt8210St8310 && hasEsn));

class TrackerSessionState {
  final String sessionCode;
  final String profileName;
  final DeviceSummary device;
  final ConnectionSummary connection;
  final ConfigurationSnapshot configuration;
  final LocalitelAnalysis localitel;
  final ServiceLocation serviceLocation;
  final ManualCommandState manualCommand;
  final InstallationProfile selectedProfile;
  final List<GeneratedCommandPlan> generatedCommandPlan;
  final SerialDiagnosticState serialDiagnostic;
  final SuntechCommandFamily selectedSuntechFamily;
  final StudioMode studioMode;
  final List<SessionStage> stages;
  final List<TestStepState> tests;
  final List<CommandItem> commands;
  final List<DiagnosticGroup> diagnostics;
  final List<LogEntry> logs;
  final WorkOrder? activeWorkOrder;
  final List<WorkOrder> todayWorkOrders;
  final ServiceValidation serviceValidation;
  final SuntechHandshakeResult? handshakeResult;
  final NetworkWriteResult? networkWriteResult;
  final List<CompletedServiceRecord> recentCompletedServices;
  final List<CompletedServiceRecord> pendingSyncServices;
  final List<BehaviorChange> behaviorChanges;
  final List<TelemetryDataPoint> voltageHistory;
  final List<TelemetryDataPoint> backupVoltageHistory;
  final List<EventRecord> ignitionHistory;
  final List<EventRecord> commandHistory;

  const TrackerSessionState({
    required this.sessionCode,
    required this.profileName,
    required this.device,
    required this.connection,
    required this.configuration,
    required this.localitel,
    required this.serviceLocation,
    required this.manualCommand,
    required this.selectedProfile,
    required this.generatedCommandPlan,
    required this.serialDiagnostic,
    required this.selectedSuntechFamily,
    this.studioMode = StudioMode.quickTest,
    required this.stages,
    required this.tests,
    required this.commands,
    required this.diagnostics,
    required this.logs,
    required this.activeWorkOrder,
    required this.todayWorkOrders,
    required this.serviceValidation,
    required this.handshakeResult,
    required this.networkWriteResult,
    required this.recentCompletedServices,
    required this.pendingSyncServices,
    this.behaviorChanges = const [],
    this.voltageHistory = const [],
    this.backupVoltageHistory = const [],
    this.ignitionHistory = const [],
    this.commandHistory = const [],
  });

  int get approvedTests =>
      tests.where((step) => step.status == TestStatus.passed).length;
  int get warningTests =>
      tests.where((step) => step.status == TestStatus.warning).length;
  int get failedTests =>
      tests.where((step) => step.status == TestStatus.failed).length;
  int get activeTests =>
      tests.where((step) => step.status == TestStatus.running).length;

  double get progress {
    final applicable = tests.where((step) => step.requiredCount > 0).length;
    if (applicable == 0) return 0;
    final approved = tests
        .where((step) =>
            step.requiredCount > 0 && step.status == TestStatus.passed)
        .length;
    return approved / applicable;
  }

  bool get hasValidBackup => configuration.backupProtected;
  bool get hasDeviceRead => device.esn.isNotEmpty && device.esn != '-';

  SuntechCommandFamily get effectiveSuntechFamily {
    final fromModel = resolveSuntechFamily(device.model);
    if (fromModel != SuntechCommandFamily.unknown) return fromModel;
    if (handshakeResult != null && handshakeResult!.family != SuntechCommandFamily.unknown) {
      return handshakeResult!.family;
    }
    return selectedSuntechFamily;
  }

  bool get minimumChecklistReady {
    if (!hasDeviceRead) return false;
    const requiredIds = {'main_power', 'backup_power', 'network', 'gps'};
    final minimum =
        tests.where((test) => requiredIds.contains(test.id)).toList();
    return minimum.length == requiredIds.length &&
        minimum.every((test) =>
            test.status != TestStatus.pending &&
            test.status != TestStatus.running);
  }

  static TrackerSessionState empty() {
    return const TrackerSessionState(
      sessionCode: 'Sessão local',
      profileName: 'Aguardando conexão',
      device: DeviceSummary(
        manufacturer: '-',
        model: '-',
        esn: '-',
        firmware: '-',
        imei: '-',
        sim: '-',
      ),
      connection: ConnectionSummary(
        commandPortName: '-',
        readPortName: '-',
        baudRate: 115200,
        usbConnected: false,
        smsReady: false,
        gprsOnline: false,
      ),
      configuration: ConfigurationSnapshot(
        original: {},
        desired: {},
        backupProtected: false,
        backupCreatedAt: '',
      ),
      localitel: LocalitelAnalysis(
        latitude: 0,
        longitude: 0,
        address: 'Sem coordenadas do rastreador',
        radiusKm: 5,
        status: 'opcional',
        summary:
            'LocaliTel e apenas double-check: nunca trava aprovacao do rastreador.',
      ),
      serviceLocation: ServiceLocation(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 0,
        status: 'pendente',
        capturedAt: '',
      ),
      manualCommand: ManualCommandState(
        lastCommand: '',
        lastResponse: '',
        waitingResponse: false,
      ),
      selectedProfile: InstallationProfiles.carStandard,
      generatedCommandPlan: [],
      serialDiagnostic: SerialDiagnosticState(),
      selectedSuntechFamily: SuntechCommandFamily.unknown,
      stages: [
        SessionStage('Identificar'),
        SessionStage('Backup'),
        SessionStage('Configurar'),
        SessionStage('Aguardar'),
        SessionStage('Testar'),
        SessionStage('Restaurar'),
        SessionStage('Finalizar'),
      ],
      tests: [
        TestStepState('main_power', 'Alimentação principal', TestStatus.pending,
            0, 3, 'Aguardando leitura'),
        TestStepState('backup_power', 'Bateria de backup', TestStatus.pending,
            0, 3, 'Aguardando leitura'),
        TestStepState('network', 'Rede / GPRS', TestStatus.pending, 0, 3,
            'Aguardando leitura'),
        TestStepState('gps', 'GPS e satélites', TestStatus.pending, 0, 3,
            'Aguardando leitura'),
        TestStepState('ignition', 'Ignição', TestStatus.pending, 0, 3,
            'Aguardando leitura'),
        TestStepState('block_on', 'Ativar bloqueio', TestStatus.pending, 0, 3,
            'Aguardando leitura'),
        TestStepState('block_off', 'Desativar bloqueio', TestStatus.pending, 0,
            3, 'Aguardando leitura'),
        TestStepState('localitel_doublecheck', 'LocaliTel (double-check)',
            TestStatus.notApplicable, 0, 0, 'Opcional - nunca afeta aprovacao'),
      ],
      commands: [
        CommandItem('Status completo', 'CMD;ESN;03;01', [
          TransportChannel.usbSerial,
          TransportChannel.sms,
          TransportChannel.gprs
        ]),
        CommandItem('Ler configuração PRESET', 'CMD;ESN;03;05', [
          TransportChannel.usbSerial,
          TransportChannel.sms,
          TransportChannel.gprs
        ]),
        CommandItem('Ativar bloqueio', 'CMD;ESN;04;02',
            [TransportChannel.sms, TransportChannel.gprs],
            destructive: true),
        CommandItem('Desativar bloqueio', 'CMD;ESN;04;01',
            [TransportChannel.sms, TransportChannel.gprs]),
        CommandItem('Aplicar servidor de teste',
            'Comando varia por família Suntech', [TransportChannel.sms],
            destructive: true),
        CommandItem(
            'Restaurar original',
            'gerado a partir do backup',
            [
              TransportChannel.usbSerial,
              TransportChannel.sms,
              TransportChannel.gprs
            ],
            destructive: true),
      ],
      diagnostics: [],
      logs: [
        LogEntry('--:--:--', 'Sistema',
            'Aguardando conexão USB/serial para identificar o rastreador.'),
      ],
      activeWorkOrder: null,
      todayWorkOrders: [],
      serviceValidation: ServiceValidation(),
      handshakeResult: null,
      networkWriteResult: null,
      recentCompletedServices: const [],
      pendingSyncServices: const [],
      behaviorChanges: const [],
      voltageHistory: const [],
      backupVoltageHistory: const [],
      ignitionHistory: const [],
      commandHistory: const [],
    );
  }

  /// Mantido como alias temporario para compatibilidade com chamadas antigas.
  static TrackerSessionState demo() => empty();
}

class DeviceSummary {
  final String manufacturer;
  final String model;
  final String esn;
  final String firmware;
  final String imei;
  final String sim;

  const DeviceSummary({
    required this.manufacturer,
    required this.model,
    required this.esn,
    required this.firmware,
    required this.imei,
    required this.sim,
  });

  bool get hasIdentity =>
      esn.trim().isNotEmpty || model != '-' || firmware != '-';
}

class ConnectionSummary {
  final String commandPortName;
  final String readPortName;
  final int baudRate;
  final bool usbConnected;
  final bool smsReady;
  final bool gprsOnline;
  final bool portValidated;
  final int? lastPacketSecondsAgo;
  final String? networkCode;
  final String? networkWarning;

  const ConnectionSummary({
    required this.commandPortName,
    required this.readPortName,
    required this.baudRate,
    required this.usbConnected,
    required this.smsReady,
    required this.gprsOnline,
    this.portValidated = false,
    this.lastPacketSecondsAgo,
    this.networkCode,
    this.networkWarning,
  });

  bool get networkOk =>
      gprsOnline ||
      (lastPacketSecondsAgo != null && lastPacketSecondsAgo! <= 120);
  String get networkLabel => networkOk ? 'Conectada' : 'Aguardando';
  String get gprsLabel => gprsOnline ? 'Online' : 'Offline';
}

class ConfigurationSnapshot {
  final Map<String, String> original;
  final Map<String, String> desired;
  final bool backupProtected;
  final String backupCreatedAt;

  const ConfigurationSnapshot({
    required this.original,
    required this.desired,
    required this.backupProtected,
    required this.backupCreatedAt,
  });

  Iterable<String> get changedKeys =>
      desired.keys.where((key) => original[key] != desired[key]);
}

class LocalitelAnalysis {
  final double latitude;
  final double longitude;
  final String address;
  final int radiusKm;
  final String status;
  final String summary;
  final double? serviceDistanceMeters;
  final int serviceToleranceMeters;
  final String serviceCheck;

  const LocalitelAnalysis({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.radiusKm,
    required this.status,
    required this.summary,
    this.serviceDistanceMeters,
    this.serviceToleranceMeters = 150,
    this.serviceCheck = 'pendente',
  });

  bool get hasValidCoordinates => latitude.abs() > 0 && longitude.abs() > 0;
  bool get isOk => status == 'ok';
  bool get isOptional => status == 'opcional' || status == 'disabled';
}

class ServiceLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String status;
  final String capturedAt;

  const ServiceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.status,
    required this.capturedAt,
  });

  bool get isValid => latitude.abs() > 0 && longitude.abs() > 0;
}

class ManualCommandState {
  final String lastCommand;
  final String lastResponse;
  final bool waitingResponse;

  const ManualCommandState({
    required this.lastCommand,
    required this.lastResponse,
    required this.waitingResponse,
  });
}

class SessionStage {
  final String label;
  final bool completed;
  final bool active;

  const SessionStage(this.label, {this.completed = false, this.active = false});
}

class TestStepState {
  final String id;
  final String label;
  final TestStatus status;
  final int successCount;
  final int requiredCount;
  final String detail;

  const TestStepState(this.id, this.label, this.status, this.successCount,
      this.requiredCount, this.detail);

  bool get completed =>
      status == TestStatus.passed ||
      status == TestStatus.warning ||
      status == TestStatus.notApplicable;
}

class CommandItem {
  final String name;
  final String preview;
  final List<TransportChannel> channels;
  final bool destructive;

  const CommandItem(this.name, this.preview, this.channels,
      {this.destructive = false});
}

class DiagnosticGroup {
  final String title;
  final Map<String, String> values;

  const DiagnosticGroup(this.title, this.values);
}

class LogEntry {
  final String time;
  final String source;
  final String message;

  const LogEntry(this.time, this.source, this.message);
}

class BehaviorChange {
  final String timestamp;
  final String field;
  final String previousValue;
  final String newValue;
  final String description;

  const BehaviorChange({
    required this.timestamp,
    required this.field,
    required this.previousValue,
    required this.newValue,
    required this.description,
  });
}

class TelemetryDataPoint {
  final DateTime timestamp;
  final double value;

  const TelemetryDataPoint(this.timestamp, this.value);
}

class EventRecord {
  final DateTime timestamp;
  final String event;
  final String detail;

  const EventRecord({
    required this.timestamp,
    required this.event,
    this.detail = '',
  });
}
