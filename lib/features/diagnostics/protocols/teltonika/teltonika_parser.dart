import '../../core/diagnostic_types.dart';
import 'teltonika_event_classifier.dart';
import 'teltonika_line_normalizer.dart';
import 'teltonika_hex_timestamp.dart';

class TeltonikaParser {
  const TeltonikaParser();

  static const _normalizer = TeltonikaLineNormalizer();
  static const _classifier = TeltonikaEventClassifier();
  static const _timestampParser = TimestampParser();

  DiagnosticParseResult parse(
    RawDiagnosticInput input,
    ProtocolDetectionResult detection,
  ) {
    final normalized = _normalizer.normalize(input.text);
    final events = <NormalizedDiagnosticEvent>[];
    final telemetry = <NormalizedTelemetryPoint>[];

    for (var i = 0; i < normalized.length; i++) {
      final line = normalized[i];
      if (line.isEmpty) continue;
      final deviceTimestamp = _timestampParser.parseDeviceTimestamp(
        line.deviceTimestamp ?? '',
      );
      final event = _classifier.classify(
        line,
        i,
        manufacturer: SupportedManufacturer.teltonika,
        manufacturerSpecific: {
          'deviceTimestamp': deviceTimestamp?.toIso8601String(),
          'rawHex': line.rawHex,
        },
      );
      events.add(event);

      final point = _toTelemetry(line, event, i);
      if (point != null) telemetry.add(point);
    }

    final device = DetectedDeviceIdentity(
      manufacturer: SupportedManufacturer.teltonika,
      model: detection.model ?? _modelFromText(input.text),
      imei: _imeiFromText(input.text),
      firmware: _firmwareFromText(input.text),
      protocol: detection.protocol,
      confidence: detection.confidence,
    );

    return DiagnosticParseResult(
      input: input,
      detection: detection,
      segments: const [],
      device: device,
      events: events,
      telemetry: telemetry,
      parserVersion: 'teltonika-parser@1.0.0',
    );
  }

  NormalizedTelemetryPoint? _toTelemetry(
    NormalizedTeltonikaLine line,
    NormalizedDiagnosticEvent event,
    int index,
  ) {
    final d = event.details;
    final hasPosition = d['latitude'] != null || d['longitude'] != null;
    final hasSignal =
        d['hdop'] != null || d['satellites'] != null || d['speed'] != null;
    if (!hasPosition && !hasSignal && event.value == null) return null;

    return NormalizedTelemetryPoint(
      timestamp: event.timestamp,
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      altitude: (d['altitude'] as num?)?.toDouble(),
      hdop: (d['hdop'] as num?)?.toDouble(),
      satellites: d['satellites'] as int?,
      speedKph: (d['speed'] as num?)?.toDouble(),
      gpsFix: d['fixStatus'] != null ? d['fixStatus'] == 1 : null,
      externalVoltage: event.source == 'LiPo' &&
              event.value != null &&
              event.value!.toDouble() >= 5
          ? event.value!.toDouble()
          : null,
      backupBatteryVoltage: event.source == 'LiPo' &&
              event.value != null &&
              event.value!.toDouble() < 5
          ? event.value!.toDouble()
          : null,
      sourceProtocol: 'teltonika-log',
      manufacturer: SupportedManufacturer.teltonika,
      rawReference: line.original,
      manufacturerSpecific: {
        'category': line.category,
        'deviceTimestamp': line.deviceTimestamp,
        'rawHex': line.rawHex,
      },
    );
  }

  String? _modelFromText(String text) {
    final match = RegExp(r'\bFMB\d{3}\b').firstMatch(text);
    return match?.group(0);
  }

  String? _imeiFromText(String text) {
    final match = RegExp(r'\b(\d{15})\b').firstMatch(text);
    return match?.group(1);
  }

  String? _firmwareFromText(String text) {
    final match = RegExp(r'(fw version:\s*([^\s]+))').firstMatch(text);
    return match?.group(2);
  }
}
