import '../../core/equipment_lab_types.dart';
import '../../core/protocol_adapter.dart';

/// Adaptador SunTech para o Laboratório de Equipamentos.
///
/// Detecção básica por padrões AT/ST8/ESN e catálogos ainda reduzidos. O foco
/// inicial deste projeto é Teltonika; este adaptador garante que o engine
/// permaneça multi-fabricante sem condicionais espalhadas.
class SunTechAdapter implements EquipmentProtocolAdapter {
  const SunTechAdapter();

  static const _version = 'suntech-adapter@0.1.0';

  @override
  Manufacturer get manufacturer => Manufacturer.suntech;

  @override
  String get displayName => 'SunTech';

  @override
  String get parserVersion => _version;

  @override
  bool get supportsCommands => true;

  // ---- Detecção -----------------------------------------------------------

  @override
  ManufacturerDetectionResult detect(String text) {
    final evidence = <DetectionEvidence>[];
    var score = 0;

    final lines = _splitLines(text);
    String? model;
    String? protocol;

    for (final line in lines) {
      if (line.contains('AT^') || line.contains('^ST8')) {
        evidence.add(DetectionEvidence(
          rule: 'at_command',
          description: 'Comando AT SunTech detectado',
          weight: 30,
          matchedValue: line.trim(),
        ));
        score += 30;
        protocol = 'ST8';
      }
      if (line.contains('ST8 PST') || line.contains('^PST')) {
        evidence.add(DetectionEvidence(
          rule: 'st8_pst',
          description: 'Resposta ST8 PST detectada',
          weight: 30,
          matchedValue: line.trim(),
        ));
        score += 30;
        protocol = 'ST8';
      }
      final esnMatch =
          RegExp(r'\b(ESN[=:]?\s*)([0-9A-Fa-f]{8,16})\b').firstMatch(line);
      if (esnMatch != null) {
        evidence.add(DetectionEvidence(
          rule: 'esn',
          description: 'ESN detectado',
          weight: 40,
          matchedValue: esnMatch.group(2),
        ));
        score += 40;
      }
      final modelMatch =
          RegExp(r'\b(ST30\d|ST31\d|ST8210|ST8310)\b', caseSensitive: false)
              .firstMatch(line);
      if (modelMatch != null) {
        model = modelMatch.group(1)!.toUpperCase();
        evidence.add(DetectionEvidence(
          rule: 'model',
          description: 'Modelo SunTech identificado',
          weight: 20,
          matchedValue: model,
        ));
        score += 20;
      }
    }

    if (score == 0) {
      return const ManufacturerDetectionResult(
        manufacturer: Manufacturer.unknown,
        confidence: 0,
      );
    }

    return ManufacturerDetectionResult(
      manufacturer: Manufacturer.suntech,
      protocol: protocol,
      model: model,
      confidence: score > 100 ? 100 : score,
      evidence: evidence,
    );
  }

  // ---- Identidade ---------------------------------------------------------

  @override
  EquipmentIdentity identify(String text) {
    final detection = detect(text);
    String? esn;
    String? imei;
    String? model;

    for (final line in _splitLines(text)) {
      final esnMatch =
          RegExp(r'\b(ESN[=:]?\s*)([0-9A-Fa-f]{8,16})\b').firstMatch(line);
      if (esnMatch != null && esn == null) {
        esn = esnMatch.group(2);
      }
      final imeiMatch = RegExp(r'\b(IMEI[=:]?\s*)(\d{15})\b').firstMatch(line);
      if (imeiMatch != null && imei == null) {
        imei = imeiMatch.group(2);
      }
      final modelMatch =
          RegExp(r'\b(ST30\d|ST31\d|ST8210|ST8310)\b', caseSensitive: false)
              .firstMatch(line);
      if (modelMatch != null && model == null) {
        model = modelMatch.group(1)!.toUpperCase();
      }
    }

    return EquipmentIdentity(
      manufacturer: Manufacturer.suntech,
      model: model,
      imei: imei,
      esn: esn,
      protocol: detection.protocol,
      captureAt: DateTime.now(),
      confidence: detection.confidence,
      rawSources: _splitLines(text),
    );
  }

  // ---- Parse --------------------------------------------------------------

  @override
  EquipmentParseResult parseLines(String text) {
    return EquipmentParseResult(
      identity: identify(text),
      fields: const [],
      ioValues: const {},
    );
  }

  // ---- Catálogos ----------------------------------------------------------

  @override
  List<DeviceCommandDefinition> get commands => _commands;

  static final List<DeviceCommandDefinition> _commands = [
    const DeviceCommandDefinition(
      id: 'suntech.identity',
      manufacturer: Manufacturer.suntech,
      title: 'Identificação',
      description: 'Lê identidade via comando AT.',
      command: 'AT^GSN;<ESN>;03;01',
      transport: [CommandTransport.usbTerminal, CommandTransport.serial],
      category: 'identification',
      risk: RiskLevel.readOnly,
    ),
  ];

  @override
  List<EquipmentFieldDefinition> get fieldDefinitions => const [];

  @override
  List<IoDefinition> get ioDefinitions => const [];

  @override
  List<EquipmentTestDefinition> get testDefinitions => const [];

  @override
  List<DiagnosticFailureDefinition> get failureDefinitions => const [];

  // ---- Probe de porta -----------------------------------------------------

  @override
  Future<PortProbeResult> probePort(PortProbeInput input) async {
    final line = input.readLine?.call();
    if (line == null) {
      return const PortProbeResult(
        isReadable: false,
        confidence: 0,
        purpose: PortPurpose.unknown,
      );
    }
    final result = detect(line);
    return PortProbeResult(
      detectedManufacturer: result.manufacturer,
      model: result.model,
      purpose: PortPurpose.commandTerminal,
      confidence: result.confidence,
      evidence: result.evidence.map((e) => e.description).toList(),
    );
  }

  // ---- Parse de resposta --------------------------------------------------

  @override
  CommandTransaction parseResponse(
    CommandTransaction tx,
    String commandId,
    List<String> lines,
  ) {
    final cmd = commands.where((c) => c.id == commandId).firstOrNull;
    final compatible = cmd?.isCompatibleTransport(tx.transport) ?? false;
    final parsedLines = lines.where((l) => l.trim().isNotEmpty).toList();
    final status = !compatible
        ? TransactionStatus.error
        : (parsedLines.isEmpty
            ? TransactionStatus.timeout
            : TransactionStatus.responseReceived);
    return CommandTransaction(
      id: tx.id,
      commandId: commandId,
      portId: tx.portId,
      sentAt: tx.sentAt,
      completedAt: DateTime.now(),
      status: status,
      request: tx.request,
      responseLines: parsedLines,
      parsedResponse: compatible ? {'lines': parsedLines.length} : null,
      transport: tx.transport,
    );
  }

  // ---- Diagnóstico --------------------------------------------------------

  @override
  List<DiagnosticFinding> diagnose(
    EquipmentParseResult parsed,
    List<CommandTransaction> transactions,
  ) {
    final findings = <DiagnosticFinding>[];
    if (parsed.fields.isEmpty) {
      findings.add(const DiagnosticFinding(
        code: 'ST-IDENT-001',
        severity: DiagnosticSeverity.warning,
        title: 'Sem campos identificados',
        message: 'Nenhum campo pôde ser extraído do log SunTech.',
      ));
    }
    return findings;
  }

  static List<String> _splitLines(String text) =>
      text.split(RegExp(r'[\r\n]+'));
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final e in this) {
      return e;
    }
    return null;
  }
}
