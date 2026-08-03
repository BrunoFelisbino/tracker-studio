import 'package:flutter/foundation.dart';

/// Fabricantes suportados.
enum Manufacturer {
  suntech,
  teltonika,
  unknown,
}

/// Estados de um teste de sensor/equipamento.
enum TestStatus {
  notStarted,
  running,
  passed,
  passedWithWarning,
  failed,
  inconclusive,
  notSupported,
  notConfigured,
  skipped,
}

/// Nível de risco de um comando/teste.
enum RiskLevel { readOnly, safe, configuration, destructive }

/// Fonte de uma definição.
enum DefinitionSource {
  officialDocumentation,
  confirmedTest,
  inferred,
  unknown,
}

/// Tipo de valor de um campo.
enum FieldValueType {
  string,
  number,
  boolean,
  enumValue,
  timestamp,
  coordinate,
  hex,
  binary,
}

/// Meios de envio de um comando.
enum CommandTransport {
  usbTerminal,
  serial,
  bluetooth,
  sms,
  codec12,
  tcpCodec12,
  serverCommand,
  copyOnly,
}

/// Finalidade detectada de uma porta.
enum PortPurpose {
  commandTerminal,
  logOutput,
  modemDebug,
  configuration,
  gpsNmea,
  unknown,
}

/// Estado de conectividade de uma porta.
enum PortConnectionStatus {
  connected,
  busy,
  disconnected,
  restarting,
  reconnecting,
  noPermission,
  notConfigured,
}

/// Band de confiança de detecção.
enum DetectionConfidenceBand { confirmed, probable, inconclusive, unknown }

/// Severidade de um achado diagnóstico.
enum DiagnosticSeverity { info, warning, error, critical }

/// Estado de uma transação de comando.
enum TransactionStatus {
  pending,
  sent,
  responseReceived,
  timeout,
  error,
  cancelled,
}

@immutable
class DetectionEvidence {
  final String rule;
  final String description;
  final int weight;
  final String? matchedValue;

  const DetectionEvidence({
    required this.rule,
    required this.description,
    required this.weight,
    this.matchedValue,
  });
}

@immutable
class ManufacturerDetectionResult {
  final Manufacturer manufacturer;
  final String? protocol;
  final String? model;
  final int confidence;
  final List<DetectionEvidence> evidence;
  final bool manuallyConfirmed;

  const ManufacturerDetectionResult({
    required this.manufacturer,
    this.protocol,
    this.model,
    this.confidence = 0,
    this.evidence = const [],
    this.manuallyConfirmed = false,
  });

  DetectionConfidenceBand get band {
    if (confidence >= 90) return DetectionConfidenceBand.confirmed;
    if (confidence >= 70) return DetectionConfidenceBand.probable;
    if (confidence >= 40) return DetectionConfidenceBand.inconclusive;
    return DetectionConfidenceBand.unknown;
  }

  bool get isConclusive =>
      band == DetectionConfidenceBand.confirmed ||
      band == DetectionConfidenceBand.probable;
}

/// Chunk bruto capturado.
@immutable
class RawSerialChunk {
  final String portId;
  final DateTime timestamp;
  final List<int> bytes;
  final String? ascii;
  final String? hex;
  final String lineTerminator;
  final int baudRate;

  const RawSerialChunk({
    required this.portId,
    required this.timestamp,
    required this.bytes,
    this.ascii,
    this.hex,
    required this.lineTerminator,
    required this.baudRate,
  });
}

/// Definição de um comando de dispositivo.
@immutable
class DeviceCommandDefinition {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? modelCompatibility;
  final String title;
  final String description;
  final String command;
  final List<CommandTransport> transport;
  final String category;
  final RiskLevel risk;
  final bool requiresConfirmation;
  final int responseTimeoutMs;

  const DeviceCommandDefinition({
    required this.id,
    required this.manufacturer,
    this.modelCompatibility,
    required this.title,
    required this.description,
    required this.command,
    required this.transport,
    required this.category,
    required this.risk,
    this.requiresConfirmation = false,
    this.responseTimeoutMs = 3000,
  });

  bool isCompatibleTransport(CommandTransport t) => transport.contains(t);
  bool get isDestructive => risk == RiskLevel.destructive;
  bool get isReadOnly => risk == RiskLevel.readOnly;
}

@immutable
class CommandTransaction {
  final String id;
  final String commandId;
  final String portId;
  final DateTime sentAt;
  final DateTime? completedAt;
  final TransactionStatus status;
  final String request;
  final List<String> responseLines;
  final Map<String, dynamic>? parsedResponse;
  final String? error;
  final CommandTransport transport;

  const CommandTransaction({
    required this.id,
    required this.commandId,
    required this.portId,
    required this.sentAt,
    this.completedAt,
    this.status = TransactionStatus.pending,
    required this.request,
    this.responseLines = const [],
    this.parsedResponse,
    this.error,
    required this.transport,
  });
}

/// Identidade do equipamento detectado.
@immutable
class EquipmentIdentity {
  final Manufacturer manufacturer;
  final String? model;
  final String? imei;
  final String? esn;
  final String? iccid;
  final String? serialNumber;
  final String? firmware;
  final String? hardwareVersion;
  final String? modemVersion;
  final String? bluetoothAddress;
  final String? protocol;
  final String? codec;
  final DateTime? captureAt;
  final int confidence;
  final List<String> rawSources;
  final bool masked;

  const EquipmentIdentity({
    required this.manufacturer,
    this.model,
    this.imei,
    this.esn,
    this.iccid,
    this.serialNumber,
    this.firmware,
    this.hardwareVersion,
    this.modemVersion,
    this.bluetoothAddress,
    this.protocol,
    this.codec,
    this.captureAt,
    required this.confidence,
    this.rawSources = const [],
    this.masked = false,
  });
}

@immutable
class EquipmentFieldDefinition {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? models;
  final String category;
  final String name;
  final List<String> aliases;
  final List<String> sourceTypes;
  final String? unit;
  final num? multiplier;
  final FieldValueType valueType;
  final Map<String, String>? interpretation;
  final num? minExpected;
  final num? maxExpected;
  final num? minCritical;
  final num? maxCritical;
  final String? formatter;
  final DefinitionSource documentationStatus;

  const EquipmentFieldDefinition({
    required this.id,
    required this.manufacturer,
    this.models,
    required this.category,
    required this.name,
    this.aliases = const [],
    required this.sourceTypes,
    this.unit,
    this.multiplier,
    required this.valueType,
    this.interpretation,
    this.minExpected,
    this.maxExpected,
    this.minCritical,
    this.maxCritical,
    this.formatter,
    this.documentationStatus = DefinitionSource.confirmedTest,
  });
}

@immutable
class FieldSample {
  final DateTime timestamp;
  final dynamic rawValue;
  final dynamic normalizedValue;

  const FieldSample({
    required this.timestamp,
    required this.rawValue,
    this.normalizedValue,
  });
}

@immutable
class DetectedField {
  final String id;
  final String key;
  final String rawName;
  final String? normalizedName;
  final String category;
  final List<FieldSample> values;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int changeCount;
  final List<String> sourceLines;
  final int confidence;
  final EquipmentFieldDefinition? definition;

  const DetectedField({
    required this.id,
    required this.key,
    required this.rawName,
    this.normalizedName,
    required this.category,
    this.values = const [],
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.changeCount = 0,
    this.sourceLines = const [],
    this.confidence = 100,
    this.definition,
  });
}

@immutable
class IoDefinition {
  final Manufacturer manufacturer;
  final String? model;
  final String? firmwareRange;
  final int id;
  final String name;
  final String? description;
  final String category;
  final String? unit;
  final num? multiplier;
  final String valueType;
  final Map<String, String>? enumMap;
  final num? minExpected;
  final num? maxExpected;
  final DefinitionSource source;
  final DateTime? lastConfirmedAt;
  final num? lastValue;

  const IoDefinition({
    required this.manufacturer,
    this.model,
    this.firmwareRange,
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.unit,
    this.multiplier,
    required this.valueType,
    this.enumMap,
    this.minExpected,
    this.maxExpected,
    this.source = DefinitionSource.confirmedTest,
    this.lastConfirmedAt,
    this.lastValue,
  });
}

@immutable
class EquipmentTestDefinition {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? models;
  final String name;
  final String category;
  final String description;
  final List<String> instructions;
  final List<String> requiredFields;
  final List<String>? optionalFields;
  final int timeoutMs;
  final List<TestExpectation> expectedChanges;
  final List<String> passCriteria;
  final List<String>? warningCriteria;
  final List<String>? failCriteria;
  final RiskLevel risk;
  final bool requiresConfirmation;

  const EquipmentTestDefinition({
    required this.id,
    required this.manufacturer,
    this.models,
    required this.name,
    required this.category,
    required this.description,
    this.instructions = const [],
    this.requiredFields = const [],
    this.optionalFields,
    this.timeoutMs = 30000,
    this.expectedChanges = const [],
    this.passCriteria = const [],
    this.warningCriteria,
    this.failCriteria,
    this.risk = RiskLevel.readOnly,
    this.requiresConfirmation = false,
  });
}

@immutable
class TestExpectation {
  final String field;
  final dynamic from;
  final dynamic to;
  final num? minDelta;
  final num? maxDelta;
  final bool requiresChange;

  const TestExpectation({
    required this.field,
    this.from,
    this.to,
    this.minDelta,
    this.maxDelta,
    this.requiresChange = false,
  });
}

@immutable
class EquipmentTestResult {
  final String testId;
  final String name;
  final String category;
  final TestStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? detail;
  final Map<String, dynamic>? evidence;
  final String? error;

  const EquipmentTestResult({
    required this.testId,
    required this.name,
    required this.category,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.detail,
    this.evidence,
    this.error,
  });
}

@immutable
class DiagnosticFailureDefinition {
  final String code;
  final Manufacturer? manufacturer;
  final List<String>? models;
  final String category;
  final String title;
  final String description;
  final DiagnosticSeverity severity;
  final List<String> patterns;
  final List<String> possibleCauses;
  final List<String> suggestedChecks;
  final bool autoResolvable;

  const DiagnosticFailureDefinition({
    required this.code,
    this.manufacturer,
    this.models,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    this.patterns = const [],
    this.possibleCauses = const [],
    this.suggestedChecks = const [],
    this.autoResolvable = false,
  });
}

class DiagnosticFinding {
  final String code;
  final DiagnosticSeverity severity;
  final String title;
  final String message;
  final List<String>? possibleCauses;
  final List<String>? suggestedActions;

  const DiagnosticFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.message,
    this.possibleCauses,
    this.suggestedActions,
  });
}

@immutable
class EquipmentLabSession {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final EquipmentIdentity equipment;
  final List<DetectedField> fields;
  final Map<int, dynamic> ioValues;
  final List<EquipmentTestResult> tests;
  final List<DiagnosticFinding> findings;
  final String rawData;
  final String parserVersion;

  const EquipmentLabSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.equipment,
    this.fields = const [],
    this.ioValues = const {},
    this.tests = const [],
    this.findings = const [],
    required this.rawData,
    required this.parserVersion,
  });

  EquipmentLabSession copyWith({
    DateTime? finishedAt,
    List<DiagnosticFinding>? findings,
  }) =>
      EquipmentLabSession(
        id: id,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        equipment: equipment,
        fields: fields,
        ioValues: ioValues,
        tests: tests,
        findings: findings ?? this.findings,
        rawData: rawData,
        parserVersion: parserVersion,
      );
}

/// Resultado do probe de porta.
class PortProbeResult {
  final Manufacturer? detectedManufacturer;
  final String? model;
  final PortPurpose purpose;
  final int confidence;
  final List<String> evidence;
  final bool isReadable;
  final bool isWritable;

  const PortProbeResult({
    this.detectedManufacturer,
    this.model,
    this.purpose = PortPurpose.unknown,
    this.confidence = 0,
    this.evidence = const [],
    this.isReadable = true,
    this.isWritable = true,
  });
}

class PortProbeInput {
  final String portId;
  final String path;
  final int? baudRate;
  final String? Function()? readLine;
  final Future<bool> Function(String) writeLine;

  PortProbeInput({
    required this.portId,
    required this.path,
    this.baudRate,
    this.readLine,
    required this.writeLine,
  });
}

extension TestStatusLabel on TestStatus {
  String get label {
    switch (this) {
      case TestStatus.passed:
        return 'Passou';
      case TestStatus.passedWithWarning:
        return 'Passou com atenção';
      case TestStatus.failed:
        return 'Falhou';
      case TestStatus.inconclusive:
        return 'Inconclusivo';
      case TestStatus.notSupported:
        return 'Não suportado';
      case TestStatus.notConfigured:
        return 'Não configurado';
      case TestStatus.running:
        return 'Executando';
      case TestStatus.notStarted:
        return 'Não iniciado';
      case TestStatus.skipped:
        return 'Pulado';
    }
  }

  String get symbol {
    switch (this) {
      case TestStatus.passed:
        return '✓';
      case TestStatus.passedWithWarning:
        return '⚠';
      case TestStatus.failed:
        return '✕';
      case TestStatus.inconclusive:
        return '✰';
      case TestStatus.notSupported:
        return '—';
      case TestStatus.notConfigured:
        return '○';
      case TestStatus.running:
        return '⟳';
      case TestStatus.notStarted:
        return '○';
      case TestStatus.skipped:
        return '⊘';
    }
  }
}

extension SeverityMeta on DiagnosticSeverity {
  String get symbol {
    switch (this) {
      case DiagnosticSeverity.info:
        return 'ℹ';
      case DiagnosticSeverity.warning:
        return '⚠';
      case DiagnosticSeverity.error:
        return '✕';
      case DiagnosticSeverity.critical:
        return '✕✕';
    }
  }

  String get label {
    switch (this) {
      case DiagnosticSeverity.info:
        return 'Info';
      case DiagnosticSeverity.warning:
        return 'Alerta';
      case DiagnosticSeverity.error:
        return 'Erro';
      case DiagnosticSeverity.critical:
        return 'Crítico';
    }
  }
}
