import 'package:flutter/foundation.dart';

enum SupportedManufacturer { suntech, teltonika, unknown }

enum InputDataType {
  serialLog,
  ascii,
  hex,
  binary,
  commandResponse,
  protocolFrame,
  mixed
}

enum DiagnosticSeverity { success, info, warning, error, critical }

enum DiagnosticCategory {
  network,
  server,
  gps,
  power,
  battery,
  ignition,
  movement,
  can,
  accelerometer,
  modem,
  avl,
  system,
  unknown,
}

enum OverallStatus { healthy, attention, critical, unknown }

enum SessionSource { serial, file, paste, bluetooth, other }

enum DetectionConfidenceBand { confirmed, probable, inconclusive, unknown }

@immutable
class RawDiagnosticInput {
  final String text;
  final List<int>? bytes;
  final InputDataType type;
  final String source;

  const RawDiagnosticInput({
    required this.text,
    this.bytes,
    this.type = InputDataType.mixed,
    this.source = 'other',
  });

  int get lineCount {
    if (text.isEmpty) return 0;
    return '\n'.allMatches(text).length + 1;
  }
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

  Map<String, dynamic> toJson() => {
        'rule': rule,
        'description': description,
        'weight': weight,
        if (matchedValue != null) 'matchedValue': matchedValue,
      };
}

@immutable
class DetectionAlternative {
  final SupportedManufacturer manufacturer;
  final String? protocol;
  final int confidence;

  const DetectionAlternative({
    required this.manufacturer,
    this.protocol,
    required this.confidence,
  });
}

@immutable
class ProtocolDetectionResult {
  final SupportedManufacturer manufacturer;
  final String? protocol;
  final String? model;
  final int confidence;
  final List<DetectionEvidence> evidence;
  final List<DetectionAlternative> alternatives;
  final bool manuallyConfirmed;

  const ProtocolDetectionResult({
    required this.manufacturer,
    this.protocol,
    this.model,
    required this.confidence,
    this.evidence = const [],
    this.alternatives = const [],
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

  ProtocolDetectionResult withManualConfirmation(SupportedManufacturer m) {
    return ProtocolDetectionResult(
      manufacturer: m,
      protocol: protocol,
      model: model,
      confidence: confidence,
      evidence: evidence,
      alternatives: alternatives,
      manuallyConfirmed: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'manufacturer': manufacturer.name,
        if (protocol != null) 'protocol': protocol,
        if (model != null) 'model': model,
        'confidence': confidence,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'alternatives': alternatives
            .map((a) => {
                  'manufacturer': a.manufacturer.name,
                  if (a.protocol != null) 'protocol': a.protocol,
                  'confidence': a.confidence,
                })
            .toList(),
        'manuallyConfirmed': manuallyConfirmed,
      };
}

@immutable
class DetectedDeviceIdentity {
  final SupportedManufacturer manufacturer;
  final String? model;
  final String? imei;
  final String? esn;
  final String? serialNumber;
  final String? iccid;
  final String? firmware;
  final String? protocol;
  final int confidence;

  const DetectedDeviceIdentity({
    required this.manufacturer,
    this.model,
    this.imei,
    this.esn,
    this.serialNumber,
    this.iccid,
    this.firmware,
    this.protocol,
    required this.confidence,
  });

  bool get isEmpty =>
      model == null &&
      imei == null &&
      esn == null &&
      serialNumber == null &&
      iccid == null &&
      firmware == null;

  Map<String, dynamic> toJson() => {
        'manufacturer': manufacturer.name,
        if (model != null) 'model': model,
        if (imei != null) 'imei': imei,
        if (esn != null) 'esn': esn,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (iccid != null) 'iccid': iccid,
        if (firmware != null) 'firmware': firmware,
        if (protocol != null) 'protocol': protocol,
        'confidence': confidence,
      };
}

@immutable
class DiagnosticSegment {
  final String id;
  final int startLine;
  final int endLine;
  final SupportedManufacturer detectedManufacturer;
  final String? protocol;
  final String? model;
  final int confidence;
  final String? deviceIdentifier;
  final String rawContent;

  const DiagnosticSegment({
    required this.id,
    required this.startLine,
    required this.endLine,
    required this.detectedManufacturer,
    this.protocol,
    this.model,
    required this.confidence,
    this.deviceIdentifier,
    required this.rawContent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startLine': startLine,
        'endLine': endLine,
        'detectedManufacturer': detectedManufacturer.name,
        if (protocol != null) 'protocol': protocol,
        if (model != null) 'model': model,
        'confidence': confidence,
        if (deviceIdentifier != null) 'deviceIdentifier': deviceIdentifier,
      };
}

@immutable
class NormalizedEventRaw {
  final String original;
  final String? ascii;
  final String? hex;
  final int? line;

  const NormalizedEventRaw({
    required this.original,
    this.ascii,
    this.hex,
    this.line,
  });

  Map<String, dynamic> toJson() => {
        'original': original,
        if (ascii != null) 'ascii': ascii,
        if (hex != null) 'hex': hex,
        if (line != null) 'line': line,
      };
}

@immutable
class NormalizedDiagnosticEvent {
  final String id;
  final DateTime? timestamp;
  final String? deviceTimestamp;
  final DiagnosticSeverity severity;
  final DiagnosticCategory category;
  final String source;
  final String event;
  final String title;
  final String message;
  final num? value;
  final String? unit;
  final Map<String, dynamic> details;
  final NormalizedEventRaw raw;
  final int repeatCount;
  final SupportedManufacturer manufacturer;
  final Map<String, dynamic> manufacturerSpecific;

  const NormalizedDiagnosticEvent({
    required this.id,
    this.timestamp,
    this.deviceTimestamp,
    required this.severity,
    required this.category,
    required this.source,
    required this.event,
    required this.title,
    required this.message,
    this.value,
    this.unit,
    this.details = const {},
    required this.raw,
    this.repeatCount = 1,
    required this.manufacturer,
    this.manufacturerSpecific = const {},
  });

  String get key => '$manufacturer|$source|$event';

  Map<String, dynamic> toJson() => {
        'id': id,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        if (deviceTimestamp != null) 'deviceTimestamp': deviceTimestamp,
        'severity': severity.name,
        'category': category.name,
        'source': source,
        'event': event,
        'title': title,
        'message': message,
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        'details': details,
        'raw': raw.toJson(),
        'repeatCount': repeatCount,
        'manufacturer': manufacturer.name,
        'manufacturerSpecific': manufacturerSpecific,
      };
}

@immutable
class NormalizedTelemetryPoint {
  final DateTime? timestamp;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? speedKph;
  final double? heading;
  final int? satellites;
  final double? hdop;
  final bool? ignition;
  final bool? movement;
  final double? externalVoltage;
  final double? backupBatteryVoltage;
  final double? backupBatteryLevel;
  final int? gsmSignal;
  final bool? gpsFix;
  final num? odometer;
  final Object? eventCode;
  final String? eventName;
  final String sourceProtocol;
  final SupportedManufacturer manufacturer;
  final String rawReference;
  final Map<String, dynamic> manufacturerSpecific;

  const NormalizedTelemetryPoint({
    this.timestamp,
    this.latitude,
    this.longitude,
    this.altitude,
    this.speedKph,
    this.heading,
    this.satellites,
    this.hdop,
    this.ignition,
    this.movement,
    this.externalVoltage,
    this.backupBatteryVoltage,
    this.backupBatteryLevel,
    this.gsmSignal,
    this.gpsFix,
    this.odometer,
    this.eventCode,
    this.eventName,
    required this.sourceProtocol,
    required this.manufacturer,
    required this.rawReference,
    this.manufacturerSpecific = const {},
  });

  Map<String, dynamic> toJson() => {
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speedKph != null) 'speedKph': speedKph,
        if (heading != null) 'heading': heading,
        if (satellites != null) 'satellites': satellites,
        if (hdop != null) 'hdop': hdop,
        if (ignition != null) 'ignition': ignition,
        if (movement != null) 'movement': movement,
        if (externalVoltage != null) 'externalVoltage': externalVoltage,
        if (backupBatteryVoltage != null)
          'backupBatteryVoltage': backupBatteryVoltage,
        if (backupBatteryLevel != null)
          'backupBatteryLevel': backupBatteryLevel,
        if (gsmSignal != null) 'gsmSignal': gsmSignal,
        if (gpsFix != null) 'gpsFix': gpsFix,
        if (odometer != null) 'odometer': odometer,
        if (eventCode != null) 'eventCode': eventCode,
        if (eventName != null) 'eventName': eventName,
        'sourceProtocol': sourceProtocol,
        'manufacturer': manufacturer.name,
        'rawReference': rawReference,
        'manufacturerSpecific': manufacturerSpecific,
      };
}

@immutable
class DiagnosticFinding {
  final String code;
  final DiagnosticSeverity severity;
  final String title;
  final String message;

  const DiagnosticFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'severity': severity.name,
        'title': title,
        'message': message,
      };
}

@immutable
class DiagnosticParseResult {
  final RawDiagnosticInput input;
  final ProtocolDetectionResult detection;
  final List<DiagnosticSegment> segments;
  final DetectedDeviceIdentity device;
  final List<NormalizedDiagnosticEvent> events;
  final List<NormalizedTelemetryPoint> telemetry;
  final List<DiagnosticFinding> findings;
  final String parserVersion;

  const DiagnosticParseResult({
    required this.input,
    required this.detection,
    required this.segments,
    required this.device,
    required this.events,
    required this.telemetry,
    this.findings = const [],
    required this.parserVersion,
  });

  DiagnosticParseResult copyWith({
    List<DiagnosticFinding>? findings,
  }) {
    return DiagnosticParseResult(
      input: input,
      detection: detection,
      segments: segments,
      device: device,
      events: events,
      telemetry: telemetry,
      findings: findings ?? this.findings,
      parserVersion: parserVersion,
    );
  }
}

@immutable
class NormalizedDiagnosticSession {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final SessionSource source;
  final ProtocolDetectionResult detection;
  final DetectedDeviceIdentity device;
  final List<DiagnosticSegment> segments;
  final List<NormalizedDiagnosticEvent> events;
  final List<NormalizedTelemetryPoint> telemetry;
  final List<DiagnosticFinding> findings;
  final RawDiagnosticInput rawData;
  final String parserVersion;
  final SupportedManufacturer? manuallyConfirmedManufacturer;

  const NormalizedDiagnosticSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.source,
    required this.detection,
    required this.device,
    required this.segments,
    required this.events,
    required this.telemetry,
    required this.findings,
    required this.rawData,
    required this.parserVersion,
    this.manuallyConfirmedManufacturer,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
        'source': source.name,
        'detection': detection.toJson(),
        'device': device.toJson(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'telemetry': telemetry.map((t) => t.toJson()).toList(),
        'findings': findings.map((f) => f.toJson()).toList(),
        'parserVersion': parserVersion,
        if (manuallyConfirmedManufacturer != null)
          'manuallyConfirmedManufacturer': manuallyConfirmedManufacturer!.name,
      };
}
