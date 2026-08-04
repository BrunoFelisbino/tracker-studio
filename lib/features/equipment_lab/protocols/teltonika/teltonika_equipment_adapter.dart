import '../../../diagnostics/core/diagnostic_types.dart' as diag;
import '../../../diagnostics/protocols/teltonika/teltonika_detector.dart';
import '../../../diagnostics/protocols/teltonika/teltonika_event_classifier.dart';
import '../../../diagnostics/protocols/teltonika/teltonika_line_normalizer.dart';
import '../../core/equipment_lab_types.dart';
import '../../core/protocol_adapter.dart';
import 'teltonika_commands.dart';

/// Adaptador Teltonika (FMB140/...) para o Laboratório de Equipamentos.
///
/// Reaproveita o normalizador (`TeltonikaLineNormalizer`), classificador
/// (`TeltonikaEventClassifier`) e detector (`TeltonikaDetector`) existentes,
/// mapeando os eventos normalizados para campos e IOs do contrato.
class TeltonikaAdapter implements EquipmentProtocolAdapter {
  const TeltonikaAdapter();

  static const _detector = TeltonikaDetector();
  static const _normalizer = TeltonikaLineNormalizer();
  static const _classifier = TeltonikaEventClassifier();
  static const _version = 'teltonika-parser@1.0.0';

  @override
  Manufacturer get manufacturer => Manufacturer.teltonika;

  @override
  String get displayName => 'Teltonika';

  @override
  String get parserVersion => _version;

  @override
  bool get supportsCommands => true;

  // ---- Detecção -----------------------------------------------------------

  @override
  ManufacturerDetectionResult detect(String text) {
    final result = _detector.detect(diag.RawDiagnosticInput(text: text));
    return ManufacturerDetectionResult(
      manufacturer: Manufacturer.teltonika,
      protocol: result.protocol,
      model: result.model,
      confidence: result.confidence,
      evidence: result.evidence
          .map((e) => DetectionEvidence(
                rule: e.rule,
                description: e.description,
                weight: e.weight,
                matchedValue: e.matchedValue,
              ))
          .toList(),
      manuallyConfirmed: false,
    );
  }

  // ---- Identidade ---------------------------------------------------------

  String? _extractIedi(String text) {
    final m =
        RegExp(r'(?:IMEI[=:]\s*)(\d{15}|[\dA-F]{14})', caseSensitive: false)
            .firstMatch(text);
    if (m != null) return m.group(1);
    final mTel =
        RegExp(r'(?:Tel[#:]\s*)(\d+)', caseSensitive: false).firstMatch(text);
    return mTel?.group(1);
  }

  String? _extractModel(String text) {
    final m = _detector.detect(diag.RawDiagnosticInput(text: text)).model;
    if (m != null && m.isNotEmpty) return m;
    final m2 = RegExp(r'\bFMB\d{3}\b').firstMatch(text);
    return m2?.group(0);
  }

  @override
  EquipmentIdentity identify(String text) {
    final detection = detect(text);
    return EquipmentIdentity(
      manufacturer: Manufacturer.teltonika,
      model: _extractModel(text),
      imei: _extractIedi(text),
      protocol: detection.protocol,
      captureAt: DateTime.now(),
      confidence: detection.confidence,
      rawSources: _splitLines(text),
    );
  }

  // ---- Parse --------------------------------------------------------------

  @override
  EquipmentParseResult parseLines(String text) {
    final identity = identify(text);
    final normalized = _normalizer.normalize(text);
    final fields = <DetectedField>[];
    final ioValues = <int, dynamic>{};

    for (var i = 0; i < normalized.length; i++) {
      final line = normalized[i];
      final event = _classifier.classify(
        line,
        i,
        manufacturer: diag.SupportedManufacturer.teltonika,
      );
      final seenAt = event.timestamp ?? DateTime.now();

      _classifyToField(event, line, seenAt, fields);
      _classifyToIo(event, ioValues);
    }

    // Extract and preserve unknown IOs from raw text
    final rawIoValues = extractIoFromRawText(text);
    rawIoValues.forEach((id, value) {
      if (!ioValues.containsKey(id)) {
        ioValues[id] = value;
      }
    });

    return EquipmentParseResult(
      identity: identity,
      fields: fields,
      ioValues: ioValues,
      rawChunks: [],
    );
  }

  static void _classifyToField(
    diag.NormalizedDiagnosticEvent event,
    NormalizedTeltonikaLine line,
    DateTime seenAt,
    List<DetectedField> out,
  ) {
    void add({
      required String id,
      required String rawName,
      required String category,
      required dynamic value,
    }) {
      if (value == null) return;
      out.add(DetectedField(
        id: id,
        key: id.split('.').last,
        rawName: rawName,
        category: category,
        values: [
          FieldSample(
              timestamp: seenAt, rawValue: value, normalizedValue: value)
        ],
        firstSeenAt: seenAt,
        lastSeenAt: seenAt,
      ));
    }

    final details = event.details;
    final value = event.value;
    final unit = event.unit;

    switch (line.category) {
      case 'GPS.API':
        if (details['latitude'] != null) {
          add(
              id: 'teltonika.gps.latitude',
              rawName: 'Latitude',
              category: 'gps',
              value: details['latitude']);
        }
        if (details['longitude'] != null) {
          add(
              id: 'teltonika.gps.longitude',
              rawName: 'Longitude',
              category: 'gps',
              value: details['longitude']);
        }
        if (details['altitude'] != null) {
          add(
              id: 'teltonika.gps.altitude',
              rawName: 'Altitude',
              category: 'gps',
              value: details['altitude']);
        }
        if (details['hdop'] != null) {
          add(
              id: 'teltonika.gps.hdop',
              rawName: 'HDOP',
              category: 'gps',
              value: details['hdop']);
        }
        if (details['satellites'] != null) {
          add(
              id: 'teltonika.gps.satellites',
              rawName: 'Satélites',
              category: 'gps',
              value: details['satellites']);
        }
        if (details['speed'] != null) {
          add(
              id: 'teltonika.gps.speed',
              rawName: 'Velocidade',
              category: 'gps',
              value: details['speed']);
        }
        if (details['fixStatus'] != null) {
          add(
              id: 'teltonika.gps.fix',
              rawName: 'GPS Fix',
              category: 'gps',
              value: details['fixStatus']);
        }
        break;
      case 'LiPo':
        if (value != null && unit == 'V') {
          final content = event.message.toLowerCase();
          if (content.contains('batt')) {
            add(
                id: 'teltonika.power.battery',
                rawName: 'Bateria interna',
                category: 'power',
                value: value);
          } else {
            add(
                id: 'teltonika.power.external',
                rawName: 'Tensão externa',
                category: 'power',
                value: value);
          }
        }
        break;
      case 'ACC':
        add(
            id: 'teltonika.ignition',
            rawName: 'Ignição',
            category: 'vehicle',
            value: event.event == 'ignition_on');
        break;
      case 'NETWORK':
        if (details['ip'] != null) {
          add(
              id: 'teltonika.network.ip',
              rawName: 'IP',
              category: 'network',
              value: details['ip']);
        }
        if (details['port'] != null) {
          add(
              id: 'teltonika.network.port',
              rawName: 'Porta',
              category: 'network',
              value: details['port']);
        }
        if (details['protocol'] != null) {
          add(
              id: 'teltonika.network.protocol',
              rawName: 'Protocolo',
              category: 'network',
              value: details['protocol']);
        }
        if (details['domain'] != null) {
          add(
              id: 'teltonika.network.domain',
              rawName: 'Domínio',
              category: 'network',
              value: details['domain']);
        }
        if (details['timeoutSeconds'] != null) {
          add(
              id: 'teltonika.network.timeout',
              rawName: 'Timeout',
              category: 'network',
              value: details['timeoutSeconds']);
        }
        break;
      case 'REC.SEND.1':
      case 'REC.SEND.2':
        if (event.message.contains('answer')) {
          add(
              id: 'teltonika.avl.server_answer',
              rawName: 'Resposta servidor',
              category: 'avl',
              value: event.message);
        }
        if (details['recordAddress'] != null) {
          add(
              id: 'teltonika.avl.record_address',
              rawName: 'Endereço registro',
              category: 'avl',
              value: details['recordAddress']);
        }
        if (event.message.contains('imei send OK')) {
          add(
              id: 'teltonika.avl.imei_sent',
              rawName: 'IMEI enviado',
              category: 'avl',
              value: true);
        }
        break;
      case 'REC.GEN':
        add(
            id: 'teltonika.avl.record_generated',
            rawName: 'Registro AVL gerado',
            category: 'avl',
            value: line.content);
        break;
      case 'REC.BLK':
        add(
            id: 'teltonika.avl.block',
            rawName: 'Bloco de registros',
            category: 'avl',
            value: line.content);
        break;
      case 'REC.NEW':
        add(
            id: 'teltonika.avl.new_record',
            rawName: 'Novo registro AVL',
            category: 'avl',
            value: line.content);
        break;
      case 'LVCAN':
        add(
            id: 'teltonika.can.raw',
            rawName: 'CAN raw',
            category: 'can',
            value: line.content);
        break;
      case 'AXL.CLBR':
        add(
            id: 'teltonika.accelerometer.calibration',
            rawName: 'Calibração acelerômetro',
            category: 'accelerometer',
            value: line.content);
        break;
      case 'TSYNC':
      case 'TSYNC.SWITCH':
        add(
            id: 'teltonika.system.time_sync',
            rawName: 'Sincronização horário',
            category: 'system',
            value: line.content);
        break;
      case 'MODEM.STATUS':
        add(
            id: 'teltonika.modem.status',
            rawName: 'Estado modem',
            category: 'modem',
            value: line.content);
        break;
      case 'MODEM.ACTION':
        add(
            id: 'teltonika.modem.action',
            rawName: 'Ação modem',
            category: 'modem',
            value: line.content);
        break;
      case 'ATCMD':
        add(
            id: 'teltonika.modem.at_command',
            rawName: 'Comando AT',
            category: 'modem',
            value: line.content);
        break;
      case 'GPRS':
        add(
            id: 'teltonika.network.gprs',
            rawName: 'Sessão GPRS',
            category: 'network',
            value: line.content);
        break;
      case 'SLEEP':
        add(
            id: 'teltonika.system.sleep',
            rawName: 'Modo sleep',
            category: 'system',
            value: line.content);
        break;
      case 'UNPLUG':
        add(
            id: 'teltonika.power.unplugged',
            rawName: 'Alimentação removida',
            category: 'power',
            value: true);
        break;
      case 'OVERSPD':
        add(
            id: 'teltonika.movement.overspeed',
            rawName: 'Excesso velocidade',
            category: 'movement',
            value: line.content);
        break;
      case 'WD.FUNC':
        add(
            id: 'teltonika.system.watchdog',
            rawName: 'Watchdog',
            category: 'system',
            value: line.content);
        break;
      case 'MTHL':
        add(
            id: 'teltonika.system.health',
            rawName: 'Health check',
            category: 'system',
            value: line.content);
        break;
      case 'SCH':
        add(
            id: 'teltonika.system.scheduler',
            rawName: 'Agendamento',
            category: 'system',
            value: line.content);
        break;
      case 'FC.CALC':
        add(
            id: 'teltonika.movement.fuel_calc',
            rawName: 'Cálculo combustível',
            category: 'movement',
            value: line.content);
        break;
      case 'TRACK':
        add(
            id: 'teltonika.movement.track',
            rawName: 'Rastreamento periódico',
            category: 'movement',
            value: line.content);
        break;
      case 'IO':
        add(
            id: 'teltonika.io.event',
            rawName: 'Evento IO',
            category: 'io',
            value: line.content);
        break;
      default:
        add(
            id: 'teltonika.event.${line.category.toLowerCase()}',
            rawName: line.category,
            category: 'system',
            value: line.content);
    }
  }

  static void _classifyToIo(
    diag.NormalizedDiagnosticEvent event,
    Map<int, dynamic> ioValues,
  ) {
    final value = event.value;
    if (value == null) return;

    int? id;
    switch (event.source) {
      case 'LiPo':
        if (event.event == 'power_state') {
          final content = event.message.toLowerCase();
          id = content.contains('batt') ? 1 : 0;
        }
        break;
      case 'ACC':
        id = 3;
        break;
      default:
        // Try to extract IO ID from message (format: "IO ID[xxx]")
        final ioMatch = RegExp(r'IO\s+ID\[(\d+)\]', caseSensitive: false)
            .firstMatch(event.message);
        if (ioMatch != null) {
          id = int.tryParse(ioMatch.group(1)!);
        }
        break;
    }
    if (id != null) ioValues[id] = value;
  }

  /// Extrai todos os IOs do texto bruto, preservando os não mapeados.
  static Map<int, dynamic> extractIoFromRawText(String text) {
    final ioValues = <int, dynamic>{};
    final lines = _splitLines(text);

    // Pattern: "IO ID[123]: value" or "IO ID[123]=value"
    final ioPattern =
        RegExp(r'IO\s+ID\[(\d+)\]\s*[:=]\s*([^\s,;]+)', caseSensitive: false);

    for (final line in lines) {
      final matches = ioPattern.allMatches(line);
      for (final match in matches) {
        final id = int.tryParse(match.group(1)!);
        final valueStr = match.group(2)!.trim();
        if (id != null) {
          // Try to parse as number, otherwise keep as string
          final numValue = num.tryParse(valueStr);
          ioValues[id] = numValue ?? valueStr;
        }
      }
    }
    return ioValues;
  }

  // ---- Catálogos ----------------------------------------------------------

  @override
  List<DeviceCommandDefinition> get commands => TeltonikaCommandCatalog.catalog;

  @override
  List<EquipmentFieldDefinition> get fieldDefinitions => _fieldDefinitions;

  static final List<EquipmentFieldDefinition> _fieldDefinitions = [
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.latitude',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'Latitude',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.coordinate,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.longitude',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'Longitude',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.coordinate,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.altitude',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'Altitude',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.number,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.hdop',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'HDOP',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.number,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.satellites',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'Satélites',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.number,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.speed',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'Velocidade',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.number,
        unit: 'km/h',
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.gps.fix',
        manufacturer: Manufacturer.teltonika,
        category: 'gps',
        name: 'GPS Fix',
        sourceTypes: ['GPS.API'],
        valueType: FieldValueType.number,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.power.external',
        manufacturer: Manufacturer.teltonika,
        category: 'power',
        name: 'Tensão externa',
        sourceTypes: ['LiPo'],
        valueType: FieldValueType.number,
        unit: 'V',
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.power.battery',
        manufacturer: Manufacturer.teltonika,
        category: 'power',
        name: 'Bateria interna',
        sourceTypes: ['LiPo'],
        valueType: FieldValueType.number,
        unit: 'V',
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.power.unplugged',
        manufacturer: Manufacturer.teltonika,
        category: 'power',
        name: 'Alimentação removida',
        sourceTypes: ['UNPLUG'],
        valueType: FieldValueType.boolean,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.ignition',
        manufacturer: Manufacturer.teltonika,
        category: 'vehicle',
        name: 'Ignição',
        sourceTypes: ['ACC'],
        valueType: FieldValueType.boolean,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.ip',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'IP',
        sourceTypes: ['NETWORK'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.port',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'Porta',
        sourceTypes: ['NETWORK'],
        valueType: FieldValueType.number,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.protocol',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'Protocolo',
        sourceTypes: ['NETWORK'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.domain',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'Domínio',
        sourceTypes: ['NETWORK'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.timeout',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'Timeout',
        sourceTypes: ['NETWORK'],
        valueType: FieldValueType.number,
        unit: 's',
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.network.gprs',
        manufacturer: Manufacturer.teltonika,
        category: 'network',
        name: 'Sessão GPRS',
        sourceTypes: ['GPRS'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.server_answer',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'Resposta servidor',
        sourceTypes: ['REC.SEND.1', 'REC.SEND.2'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.record_address',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'Endereço registro',
        sourceTypes: ['REC.SEND.1', 'REC.SEND.2'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.imei_sent',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'IMEI enviado',
        sourceTypes: ['REC.SEND.1'],
        valueType: FieldValueType.boolean,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.record_generated',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'Registro AVL gerado',
        sourceTypes: ['REC.GEN'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.confirmedTest),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.block',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'Bloco de registros',
        sourceTypes: ['REC.BLK'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.avl.new_record',
        manufacturer: Manufacturer.teltonika,
        category: 'avl',
        name: 'Novo registro AVL',
        sourceTypes: ['REC.NEW'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.can.raw',
        manufacturer: Manufacturer.teltonika,
        category: 'can',
        name: 'CAN raw',
        sourceTypes: ['LVCAN'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.accelerometer.calibration',
        manufacturer: Manufacturer.teltonika,
        category: 'accelerometer',
        name: 'Calibração acelerômetro',
        sourceTypes: ['AXL.CLBR'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.system.time_sync',
        manufacturer: Manufacturer.teltonika,
        category: 'system',
        name: 'Sincronização horário',
        sourceTypes: ['TSYNC', 'TSYNC.SWITCH'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.modem.status',
        manufacturer: Manufacturer.teltonika,
        category: 'modem',
        name: 'Estado modem',
        sourceTypes: ['MODEM.STATUS'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.modem.action',
        manufacturer: Manufacturer.teltonika,
        category: 'modem',
        name: 'Ação modem',
        sourceTypes: ['MODEM.ACTION'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.modem.at_command',
        manufacturer: Manufacturer.teltonika,
        category: 'modem',
        name: 'Comando AT',
        sourceTypes: ['ATCMD'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.system.sleep',
        manufacturer: Manufacturer.teltonika,
        category: 'system',
        name: 'Modo sleep',
        sourceTypes: ['SLEEP'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.movement.overspeed',
        manufacturer: Manufacturer.teltonika,
        category: 'movement',
        name: 'Excesso velocidade',
        sourceTypes: ['OVERSPD'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.system.watchdog',
        manufacturer: Manufacturer.teltonika,
        category: 'system',
        name: 'Watchdog',
        sourceTypes: ['WD.FUNC'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.system.health',
        manufacturer: Manufacturer.teltonika,
        category: 'system',
        name: 'Health check',
        sourceTypes: ['MTHL'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.system.scheduler',
        manufacturer: Manufacturer.teltonika,
        category: 'system',
        name: 'Agendamento',
        sourceTypes: ['SCH'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.movement.fuel_calc',
        manufacturer: Manufacturer.teltonika,
        category: 'movement',
        name: 'Cálculo combustível',
        sourceTypes: ['FC.CALC'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.movement.track',
        manufacturer: Manufacturer.teltonika,
        category: 'movement',
        name: 'Rastreamento periódico',
        sourceTypes: ['TRACK'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
    const EquipmentFieldDefinition(
        id: 'teltonika.io.event',
        manufacturer: Manufacturer.teltonika,
        category: 'io',
        name: 'Evento IO',
        sourceTypes: ['IO'],
        valueType: FieldValueType.string,
        documentationStatus: DefinitionSource.inferred),
  ];

  @override
  List<IoDefinition> get ioDefinitions => _ioDefinitions;

  static final List<IoDefinition> _ioDefinitions = [
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 0,
        name: 'DUTY',
        category: 'power',
        valueType: 'analog',
        unit: 'V',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 1,
        name: 'BATT',
        category: 'battery',
        valueType: 'analog',
        unit: 'V',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 3,
        name: 'IGN',
        category: 'ignition',
        valueType: 'digital',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 4,
        name: 'IN1',
        category: 'input',
        valueType: 'digital',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 10,
        name: 'OUT1',
        category: 'output',
        valueType: 'digital',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 11,
        name: 'OUT2',
        category: 'output',
        valueType: 'digital',
        source: DefinitionSource.confirmedTest),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 66,
        name: 'GPS_ACCEL',
        category: 'accelerometer',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 67,
        name: 'GPS_STAG',
        category: 'gps',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 68,
        name: 'GSM_SIG',
        category: 'signal',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 69,
        name: 'ROAM',
        category: 'network',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 70,
        name: 'SMS_EV',
        category: 'system',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 71,
        name: 'SMS_EV2',
        category: 'system',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 72,
        name: 'SIM_ST',
        category: 'network',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 73,
        name: 'ECALL',
        category: 'emergency',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 74,
        name: 'MILE',
        category: 'odometer',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 75,
        name: 'ODOM',
        category: 'odometer',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 76,
        name: 'PROF',
        category: 'driver',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 77,
        name: 'DRVR',
        category: 'driver',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 80,
        name: 'CAN_BATT',
        category: 'can',
        valueType: 'analog',
        unit: 'V',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 81,
        name: 'CAN_ENGN',
        category: 'can',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 82,
        name: 'CAN_ACCL',
        category: 'can',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 83,
        name: 'CAN_RPM',
        category: 'can',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 84,
        name: 'CAN_SPD',
        category: 'can',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 140,
        name: 'DYN01',
        category: 'can',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 141,
        name: 'DYN02',
        category: 'can',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 241,
        name: 'TRIP',
        category: 'trip',
        valueType: 'binary',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 242,
        name: 'TRIP_AVG',
        category: 'trip',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 243,
        name: 'TRIP_MAX',
        category: 'trip',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 244,
        name: 'TRIP_DIST',
        category: 'trip',
        valueType: 'analog',
        source: DefinitionSource.inferred),
    const IoDefinition(
        manufacturer: Manufacturer.teltonika,
        model: 'FMB140',
        id: 245,
        name: 'TRIP_DUR',
        category: 'trip',
        valueType: 'analog',
        source: DefinitionSource.inferred),
  ];

  @override
  List<EquipmentTestDefinition> get testDefinitions => _testDefinitions;

  static final List<EquipmentTestDefinition> _testDefinitions = [
    const EquipmentTestDefinition(
      id: 'teltonika.test.identification',
      manufacturer: Manufacturer.teltonika,
      name: 'Identificação do equipamento',
      category: 'identification',
      description: 'Extrai IMEI, modelo (FMBxxx) e firmware via log/handshake.',
      instructions: ['Conectar via USB; coletar handshake inicial.'],
      requiredFields: ['teltonika.model'],
      passCriteria: ['IMEI 15 dígitos capturado', 'Modelo FMBxxx identificado'],
      risk: RiskLevel.readOnly,
    ),
    const EquipmentTestDefinition(
      id: 'teltonika.test.gps',
      manufacturer: Manufacturer.teltonika,
      name: 'Posição e qualidade GPS',
      category: 'gps',
      description: 'Verifica fix, satélites, HDOP e posição válida.',
      instructions: ['Posicionar ao ar livre; aguardar GNSS fix.'],
      requiredFields: ['teltonika.gps.latitude', 'teltonika.gps.longitude'],
      passCriteria: ['GPS fix ativo (fix >= 1)', 'Satélites >= 4', 'HDOP <= 5'],
      warningCriteria: ['HDOP entre 5 e 10', 'Satélites entre 3-4'],
      failCriteria: ['HDOP > 10', 'Sem satélites', 'Lat/Lon = 0'],
      risk: RiskLevel.readOnly,
    ),
    const EquipmentTestDefinition(
      id: 'teltonika.test.ignition',
      manufacturer: Manufacturer.teltonika,
      name: 'Ignição e IOs',
      category: 'vehicle',
      description: 'Verifica IGN, IN1, OUT1/OUT2 e acionamento de saída.',
      instructions: [
        'Ligar/desligar ignição; observar IO ID 3.',
        'Acionar saída manual.'
      ],
      requiredFields: ['teltonika.ignition'],
      passCriteria: ['IGN reflete estado da ignição.'],
      risk: RiskLevel.readOnly,
    ),
    const EquipmentTestDefinition(
      id: 'teltonika.test.power',
      manufacturer: Manufacturer.teltonika,
      name: 'Alimentação e bateria',
      category: 'power',
      description: 'Verifica tensão externa e bateria LiPo dentro da faixa.',
      instructions: ['Medir com fonte 10-36V.'],
      requiredFields: ['teltonika.power.external'],
      passCriteria: ['Tensão externa 10-36V', 'Bateria entre 3.3-4.3V'],
      failCriteria: ['Tensão externa fora da faixa.', 'Bateria < 3.3V.'],
      risk: RiskLevel.readOnly,
    ),
    const EquipmentTestDefinition(
      id: 'teltonika.test.network',
      manufacturer: Manufacturer.teltonika,
      name: 'Rede e conectividade',
      category: 'network',
      description:
          'Verifica socket TCP, resolução DNS e envio de registros AVL.',
      instructions: ['Aguardar conexão APN/server.'],
      requiredFields: ['teltonika.network.ip'],
      passCriteria: ['Socket TCP aberto.', '"imei send OK".'],
      failCriteria: ['Socket não aberto.', 'Timeout de conexão.'],
      risk: RiskLevel.readOnly,
    ),
    const EquipmentTestDefinition(
      id: 'teltonika.test.can',
      manufacturer: Manufacturer.teltonika,
      name: 'CAN J1939/CANopen',
      category: 'can',
      description: 'Verifica comunicação CAN (engine/bateria/RPM/velocidade).',
      instructions: ['Conectar à central CAN.'],
      requiredFields: [],
      passCriteria: ['CAN_ENG ATIVO.', 'CAN_BATT dentro de 10-16V.'],
      warningCriteria: ['CAN inativo no repouso (pode ser normal)'],
      risk: RiskLevel.readOnly,
    ),
  ];

  @override
  List<DiagnosticFailureDefinition> get failureDefinitions =>
      _failureDefinitions;

  static final List<DiagnosticFailureDefinition> _failureDefinitions = [
    const DiagnosticFailureDefinition(
      code: 'TLK-GPS-001',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      title: 'GPS sem fix',
      description: 'Nenhum satélite ou fix inativo.',
      severity: DiagnosticSeverity.error,
      patterns: ['GPS.API', 'Sat: 0'],
      possibleCauses: [
        'Antena GPS desconectada',
        'Ambiente com cobertura reduzida'
      ],
      suggestedChecks: ['Verificar antena', 'Testar ao ar livre'],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-GPS-HDOP',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      title: 'HDOP elevado',
      description: 'HDOP > 10: posição imprecisa.',
      severity: DiagnosticSeverity.critical,
      patterns: ['HDOP'],
      possibleCauses: ['Atenuação de sinal', 'Alta ionosfera'],
      suggestedChecks: [
        'Realizar teste ao ar livre',
        'Verificar firmware AGPS'
      ],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-PWR-001',
      manufacturer: Manufacturer.teltonika,
      category: 'power',
      title: 'Alimentação fora da faixa',
      description: 'Tensão externa fora de 10-36V.',
      severity: DiagnosticSeverity.critical,
      patterns: ['LiPo'],
      possibleCauses: [
        'Fonte irregular',
        'Cabo de alimentação com resistência'
      ],
      suggestedChecks: ['Medir com multímetro', 'Conferir cabo de alimentação'],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-NET-001',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      title: 'Falha de conexão',
      description: 'Socket TCP não aberto ou sem resposta do servidor.',
      severity: DiagnosticSeverity.error,
      patterns: ['Socket', 'timeout', 'fail', 'error'],
      possibleCauses: ['APN incorreto', 'Server IP/porta bloqueados'],
      suggestedChecks: ['Conferir APN/firmware', 'Verificar server logs'],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-IMU-001',
      manufacturer: Manufacturer.teltonika,
      category: 'accelerometer',
      title: 'IMU sem resposta',
      description: 'Acelerômetro não responde ou não calibrado.',
      severity: DiagnosticSeverity.warning,
      patterns: ['AXL.CLBR', 'IMU'],
      possibleCauses: ['Calibração perdida', 'Hardware IMU com defeito'],
      suggestedChecks: ['Recalibrar acelerômetro'],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-CAN-001',
      manufacturer: Manufacturer.teltonika,
      category: 'can',
      title: 'CAN sem comunicação',
      description: 'LVCAN inativo.',
      severity: DiagnosticSeverity.warning,
      patterns: ['LVCAN'],
      suggestedChecks: ['Verificar cabo CAN', 'Conferir central compatível'],
    ),
    const DiagnosticFailureDefinition(
      code: 'TLK-CODEC-001',
      manufacturer: Manufacturer.teltonika,
      category: 'system',
      title: 'Codec 12 sem suporte na serial',
      description: 'Comandos Codec 12 não são aceitos via terminal serial USB.',
      severity: DiagnosticSeverity.warning,
      patterns: ['codec12', 'getparam'],
      suggestedChecks: ['Usar SMS ou servidor FOTA para Codec 12.'],
    ),
  ];

  // ---- Probe de porta -----------------------------------------------------

  @override
  Future<PortProbeResult> probePort(PortProbeInput input) async {
    final line = input.readLine?.call();
    if (line == null) {
      return const PortProbeResult(
          isReadable: false, confidence: 0, purpose: PortPurpose.unknown);
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
    final cmd = TeltonikaCommandCatalog.catalog
        .firstWhere((c) => c.id == commandId, orElse: () => _fallback());
    final compatible = cmd.transport.contains(tx.transport);
    final parsedLines = lines.where((l) => l.trim().isNotEmpty).toList();
    TransactionStatus status;
    if (!compatible) {
      status = TransactionStatus.error;
    } else if (parsedLines.isEmpty) {
      status = TransactionStatus.timeout;
    } else {
      status = TransactionStatus.responseReceived;
    }
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

  static DeviceCommandDefinition _fallback() => const DeviceCommandDefinition(
        id: 'fallback',
        manufacturer: Manufacturer.teltonika,
        title: 'Comando desconhecido',
        description: 'Comando sem definição de adaptador.',
        command: '',
        transport: [],
        category: '',
        risk: RiskLevel.readOnly,
      );

  // ---- Diagnóstico --------------------------------------------------------

  @override
  List<DiagnosticFinding> diagnose(
    EquipmentParseResult parsed,
    List<CommandTransaction> transactions,
  ) {
    final findings = <DiagnosticFinding>[];
    final byId = {for (final f in parsed.fields) f.id: f};
    final gps = byId['teltonika.gps.hdop'];
    if (gps != null && gps.values.last.rawValue is num) {
      final hdop = (gps.values.last.rawValue as num).toDouble();
      if (hdop > 10) {
        findings.add(DiagnosticFinding(
          code: 'TLK-GPS-HDOP',
          severity: DiagnosticSeverity.critical,
          title: 'HDOP elevado',
          message: 'HDOP $hdop > 10.',
          suggestedActions: ['Testar ao ar livre.'],
        ));
      } else if (hdop > 5) {
        findings.add(DiagnosticFinding(
          code: 'TLK-GPS-HDOP',
          severity: DiagnosticSeverity.warning,
          title: 'HDOP reduzido',
          message: 'HDOP $hdop entre 5-10.',
        ));
      }
    }

    final pwr = byId['teltonika.power.external'];
    if (pwr != null && pwr.values.last.rawValue is num) {
      final v = (pwr.values.last.rawValue as num).toDouble();
      if (v < 10 || v > 36) {
        findings.add(DiagnosticFinding(
          code: 'TLK-PWR-001',
          severity: DiagnosticSeverity.critical,
          title: 'Alimentação fora da faixa',
          message: 'Tensão externa ${v}V.',
          suggestedActions: ['Conferir fonte.'],
        ));
      }
    }

    final net = byId['teltonika.network.ip'];
    if (net == null) {
      findings.add(const DiagnosticFinding(
        code: 'TLK-NET-001',
        severity: DiagnosticSeverity.error,
        title: 'Conexão de rede não detectada',
        message: 'Nenhum evento NETWORK com IP capturado.',
      ));
    }

    for (final t in transactions) {
      if (t.status == TransactionStatus.error) {
        findings.add(DiagnosticFinding(
          code: 'TLK-CMD-001',
          severity: DiagnosticSeverity.warning,
          title: 'Comando incompatível com transporte',
          message:
              'Comando ${t.commandId} rejeitado no transporte ${t.transport}.',
        ));
      }
    }

    return findings;
  }

  static List<String> _splitLines(String text) =>
      text.split(RegExp(r'[\r\n]+'));
}
