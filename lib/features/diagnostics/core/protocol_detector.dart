import 'diagnostic_types.dart';
import 'parser_registry.dart';

class ProtocolDetector {
  final ParserRegistry registry;
  final int inconclusiveThreshold;

  const ProtocolDetector({
    required this.registry,
    this.inconclusiveThreshold = 40,
  });

  /// Avalia todos os adaptadores registrados e escolhe o mais provável.
  ProtocolDetectionResult detect(RawDiagnosticInput input) {
    final results = <ProtocolDetectionResult>[];
    for (final adapter in registry.adapters) {
      if (adapter.manufacturer == SupportedManufacturer.unknown) continue;
      results.add(adapter.detect(input));
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (results.isEmpty) {
      return const ProtocolDetectionResult(
        manufacturer: SupportedManufacturer.unknown,
        confidence: 0,
      );
    }

    final best = results.first;
    final alternatives = results
        .skip(1)
        .map((result) => DetectionAlternative(
              manufacturer: result.manufacturer,
              protocol: result.protocol,
              confidence: result.confidence,
            ))
        .toList();

    if (best.confidence < inconclusiveThreshold) {
      return ProtocolDetectionResult(
        manufacturer: SupportedManufacturer.unknown,
        confidence: best.confidence,
        protocol: null,
        evidence: best.evidence,
        alternatives: alternatives,
      );
    }
    return ProtocolDetectionResult(
      manufacturer: best.manufacturer,
      protocol: best.protocol,
      model: best.model,
      confidence: best.confidence,
      evidence: best.evidence,
      alternatives: alternatives,
    );
  }

  /// Separa o conteúdo em segmentos por fabricante usando evidências locais.
  List<DiagnosticSegment> segment(RawDiagnosticInput input) {
    final lines = input.text.split('\n');
    final segments = <DiagnosticSegment>[];
    var startLine = 1;
    SupportedManufacturer current = SupportedManufacturer.unknown;
    var protocol = <String>[];
    final buffer = <String>[];

    void flush(int endLine) {
      if (buffer.isEmpty) return;
      final rawContent = buffer.join('\n');
      final detection = detect(RawDiagnosticInput(
        text: rawContent,
        type: input.type,
        source: input.source,
      ));
      if (detection.manufacturer != current ||
          detection.confidence >= 70 ||
          current == SupportedManufacturer.unknown) {
        segments.add(DiagnosticSegment(
          id: 'seg-${segments.length + 1}',
          startLine: startLine,
          endLine: endLine,
          detectedManufacturer: detection.manufacturer,
          protocol: detection.protocol,
          model: detection.model,
          confidence: detection.confidence,
          deviceIdentifier: _deviceIdentifier(detection),
          rawContent: rawContent,
        ));
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final detection = detect(RawDiagnosticInput(
        text: line,
        type: input.type,
        source: input.source,
      ));
      final detected = detection.manufacturer;
      if (detected != current && current != SupportedManufacturer.unknown) {
        flush(i);
        current = detected;
        protocol = [];
        startLine = i + 1;
        buffer.clear();
      } else if (current == SupportedManufacturer.unknown &&
          detected != current) {
        current = detected;
        startLine = i + 1;
        buffer.clear();
      }
      buffer.add(line);
      protocol.add(detection.protocol ?? '');
    }
    flush(lines.length);

    return List.unmodifiable(segments);
  }

  String? _deviceIdentifier(ProtocolDetectionResult detection) {
    if (detection.manufacturer == SupportedManufacturer.teltonika) {
      return 'IMEI identificado';
    }
    if (detection.manufacturer == SupportedManufacturer.suntech) {
      return 'ESN identificado';
    }
    return null;
  }
}
