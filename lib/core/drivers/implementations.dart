import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'driver_contracts.dart';
import '../sessions/device_session.dart';

/// Provider para o driver por sessão.
final deviceDriverProvider = Provider.family<ManufacturerDriver, String>(
  (ref, deviceId) {
    // Factory method para obter driver baseado na identidade do dispositivo
    return _DeviceDriverResolver(ref, deviceId).driver;
  },
);

/// Gerenciador de drivers com cache de sessão.
class _DeviceDriverResolver {
  final Ref _ref;
  final String _deviceId;

  _DeviceDriverResolver(this._ref, this._deviceId);

  ManufacturerDriver get driver {
    // Default para novos dispositivos
    return DefaultDriver();
  }
}

/// Driver padrão para fabricantes desconhecidos/desenvolvimento.
class DefaultDriver implements ManufacturerDriver {
  @override
  Manufacturer get manufacturer => Manufacturer.unknown;

  @override
  DetectionResult detect(RawInput input) {
    return DetectionResult(
      manufacturer: Manufacturer.unknown,
      confidence: 0,
    );
  }

  @override
  DeviceIdentity identify(RawInput input) {
    return DeviceIdentity(
      id: const Uuid().v4(),
      manufacturer: Manufacturer.unknown,
      confidence: 0,
    );
  }

  @override
  DeviceCapabilities capabilities(DeviceContext context) {
    return const DeviceCapabilities(
      can: false,
      ble: false,
      hasCan: false,
      obd2: false,
      cellular: false,
      gps: false,
    );
  }

  @override
  List<NormalizedMeasurement> normalize(
    RawInput input,
    DeviceContext context,
  ) {
    return const [];
  }

  @override
  List<CommandDefinition> commands(DeviceContext context) {
    return const [];
  }

  @override
  List<ConfigurationSection> configuration(DeviceContext context) {
    return const [];
  }

  @override
  EncodedCommand encodeCommand(
    CommandRequest request,
    DeviceContext context,
  ) {
    throw UnimplementedError();
  }

  @override
  ParsedResponse parseResponse(
    RawResponse response,
    DeviceContext context,
  ) {
    throw UnimplementedError();
  }

  @override
  DiagnosticResult diagnose(DeviceSession session) {
    return const DiagnosticResult();
  }
}

/// Driver Suntech (mínimo viável).
class SuntechDriver implements ManufacturerDriver {
  @override
  Manufacturer get manufacturer => Manufacturer.suntech;

  @override
  DetectionResult detect(RawInput input) {
    if (input.asciiLine != null) {
      final text = input.asciiLine!.toLowerCase();
      if (text.contains('at^') || text.contains('^st8') || text.contains('esn')) {
        return DetectionResult(
          manufacturer: Manufacturer.suntech,
          confidence: 90,
          evidence: [
            DetectionEvidence(
              rule: 'at_command',
              description: 'Comando AT SunTech detectado',
              weight: 30,
              matchedValue: input.asciiLine,
            ),
          ],
        );
      }
    }
    return DetectionResult(
      manufacturer: Manufacturer.suntech,
      confidence: 10,
    );
  }

  @override
  DeviceIdentity identify(RawInput input) {
    return DeviceIdentity(
      id: const Uuid().v4(),
      manufacturer: Manufacturer.suntech,
      model: _extractModel(input),
      esn: _extractEsn(input),
      confidence: 80,
    );
  }

  @override
  DeviceCapabilities capabilities(DeviceContext context) {
    return const DeviceCapabilities(
      can: false,
      ble: false,
      hasCan: false,
      obd2: false,
      cellular: false,
      gps: false,
      sensors: ['tempratura', 'pressao'],
      ioTypes: ['digital', 'analógico'],
    );
  }

  @override
  List<NormalizedMeasurement> normalize(
    RawInput input,
    DeviceContext context,
  ) {
    final measurements = <NormalizedMeasurement>[];

    if (input.asciiLine != null) {
      final line = input.asciiLine!;

      void add(String key, String rawKey, String name, String? unit, dynamic val, [String cat = 'vehicle']) {
        measurements.add(
          NormalizedMeasurement(
            key: key,
            rawKey: rawKey,
            category: cat,
            name: name,
            unit: unit,
            multiplier: 1,
            value: val,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('IGNO=') || line.contains('IGN=')) {
        final val = _extractNumeric(line, 'IGNO', 'IGN') ?? 0;
        add('ignition', 'IGNO', 'Ignição', null, val == 1);
      }
      if (line.contains('MOV=')) {
        final val = _extractNumeric(line, 'MOV=') ?? 0;
        add('movement', 'MOV', 'Movimento', null, val == 1);
      }
      if (line.contains('SPEED=')) {
        final val = _extractNumeric(line, 'SPEED=') ?? 0;
        add('speedKph', 'SPEED', 'Velocidade', 'km/h', val);
      }
      if (line.contains('GPS=')) {
        final val = _extractNumeric(line, 'GPS=') ?? 0;
        add('position', 'GPS', 'Posição GPS', null, val == 1, 'position');
      }
      if (line.contains('NET=')) {
        final val = _extractNumeric(line, 'NET=') ?? 0;
        add('network', 'NET', 'Rede', null, val, 'network');
      }
      if (line.contains('PWR=')) {
        final val = _extractNumeric(line, 'PWR=') ?? 0;
        add('power', 'PWR', 'Alimentação', 'V', val, 'power');
      }
      if (line.contains('BATT=')) {
        final val = _extractNumeric(line, 'BATT=') ?? 0;
        add('battery', 'BATT', 'Bateria', '%', val, 'power');
      }
    }

    return measurements;
  }

  @override
  List<CommandDefinition> commands(DeviceContext context) {
    return [
      CommandDefinition(
        id: 'suntech.identity',
        manufacturer: Manufacturer.suntech,
        title: 'Identificação',
        description: 'Lê identidade via comando AT.',
        category: 'identification',
        risk: RiskLevel.readOnly,
      ),
      CommandDefinition(
        id: 'suntech.status',
        manufacturer: Manufacturer.suntech,
        title: 'Status',
        description: 'Lê status do dispositivo.',
        category: 'status',
        risk: RiskLevel.readOnly,
      ),
    ];
  }

  @override
  List<ConfigurationSection> configuration(DeviceContext context) {
    return [
      ConfigurationSection(
        id: 'suntech.general',
        title: 'Geral',
        description: 'Configurações gerais SunTech',
        fields: [
          ConfigurationField(
            id: 'suntech.apn',
            name: 'APN',
            description: 'Nome do ponto de acesso',
            currentValue: 'teste.apn',
            pendingValue: null,
            valueType: FieldValueType.string,
            enumValues: null,
            requiresSave: true,
          ),
        ],
      ),
    ];
  }

  @override
  EncodedCommand encodeCommand(
    CommandRequest request,
    DeviceContext context,
  ) {
    final commandId = request.commandId;
    switch (commandId) {
      case 'suntech.identity':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'AT^GSN;<ESN>;03;01',
          transport: CommandTransport.usb,
        );
      case 'suntech.status':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'AT^ST300CMD;;02;Status',
          transport: CommandTransport.usb,
        );
      default:
        throw ArgumentError('Comando desconhecido: $commandId');
    }
  }

  @override
  ParsedResponse parseResponse(
    RawResponse response,
    DeviceContext context,
  ) {
    return ParsedResponse(
      responseId: const Uuid().v4(),
      timestamp: response.timestamp,
      fields: {'raw': response.ascii},
    );
  }

  @override
  DiagnosticResult diagnose(DeviceSession session) {
    final findings = <DiagnosticFinding>{};

    if (session.normalizedState.vehicle.speedKph <= 0) {
      findings.add(
        DiagnosticFinding(
          id: 'ST-VEH-001',
          code: 'ST-VEH-001',
          severity: RiskLevel.safe,
          title: 'Sem movimento detectado',
          message: 'O veículo não está se movendo.',
        ),
      );
    }

    return DiagnosticResult(
      findings: findings.toList(),
      warnings: const [],
      errors: const [],
    );
  }

  String? _extractModel(RawInput input) {
    if (input.asciiLine != null) {
      final text = input.asciiLine!;
      if (text.contains('ST8210') || text.contains('ST8310')) {
        return text.contains('ST8210') ? 'ST8210' : 'ST8310';
      }
    }
    return null;
  }

  String? _extractEsn(RawInput input) {
    if (input.asciiLine != null) {
      final match = RegExp(r'ESN[=:]?\s*([0-9A-Fa-f]{8,16})').firstMatch(input.asciiLine!);
      return match?.group(1);
    }
    return null;
  }

  num? _extractNumeric(String line, [String? p1, String? p2, String? p3, String? p4]) {
    final patterns = [p1, p2, p3, p4].whereType<String>();
    for (final pattern in patterns) {
      if (line.contains(pattern)) {
        final regex = RegExp(r'\d+');
        final match = regex.firstMatch(line);
        final numStr = match?.group(0);
        if (numStr != null) {
          return num.tryParse(numStr);
        }
      }
    }
    return null;
  }
}

/// Driver Teltonika (mínimo viável).
class TeltonikaDriver implements ManufacturerDriver {
  @override
  Manufacturer get manufacturer => Manufacturer.teltonika;

  @override
  DetectionResult detect(RawInput input) {
    if (input.asciiLine != null) {
      final text = input.asciiLine!.toLowerCase();
      if (text.contains('teltonika') || text.contains('fmb140') || text.contains('fmb150')) {
        return DetectionResult(
          manufacturer: Manufacturer.teltonika,
          confidence: 90,
          evidence: [
            DetectionEvidence(
              rule: 'header_detect',
              description: 'Header Teltonika detectado',
              weight: 40,
              matchedValue: input.asciiLine,
            ),
          ],
        );
      }
    }
    return DetectionResult(
      manufacturer: Manufacturer.teltonika,
      confidence: 10,
    );
  }

  @override
  DeviceIdentity identify(RawInput input) {
    return DeviceIdentity(
      id: const Uuid().v4(),
      manufacturer: Manufacturer.teltonika,
      model: _extractModel(input),
      esn: _extractEsn(input),
      confidence: 80,
    );
  }

  @override
  DeviceCapabilities capabilities(DeviceContext context) {
    return const DeviceCapabilities(
      can: true,
      ble: false,
      hasCan: true,
      obd2: true,
      cellular: true,
      gps: true,
      sensors: ['temperatura', 'pressao', 'umidade'],
      ioTypes: ['digital', 'analógico', 'can'],
    );
  }

  @override
  List<NormalizedMeasurement> normalize(
    RawInput input,
    DeviceContext context,
  ) {
    final measurements = <NormalizedMeasurement>[];

    if (input.asciiLine != null) {
      final line = input.asciiLine!;

      void add(String key, String rawKey, String name, String? unit, dynamic val, [String cat = 'vehicle']) {
        measurements.add(
          NormalizedMeasurement(
            key: key,
            rawKey: rawKey,
            category: cat,
            name: name,
            unit: unit,
            multiplier: 1,
            value: val,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('RPM=') || line.contains('rpm')) {
        final val = _extractNumeric(line, 'RPM=', 'rpm') ?? 0;
        add('rpm', 'RPM', 'RPM', 'rpm', val);
      }
      if (line.contains('OBD_SPEED=') || line.contains('speed')) {
        final val = _extractNumeric(line, 'OBD_SPEED=', 'speed') ?? 0;
        add('obd-speed', 'OBD_SPEED', 'Velocidade CAN', 'km/h', val);
      }
      if (line.contains('OBD_ODOMETER=')) {
        final val = _extractNumeric(line, 'OBD_ODOMETER=') ?? 0;
        add('obd-odometer', 'OBD_ODOMETER', 'Odômetro CAN', 'km', val);
      }
      if (line.contains('FUEL_LEVEL=')) {
        final val = _extractNumeric(line, 'FUEL_LEVEL=') ?? 0;
        add('fuelLevelPercentage', 'FUEL_LEVEL', 'Nível de combustível', '%', val);
      }
      if (line.contains('THROTTLE=')) {
        final val = _extractNumeric(line, 'THROTTLE=') ?? 0;
        add('throttle', 'THROTTLE', 'Acelerador', '%', val);
      }
      if (line.contains('FUEL_USED=')) {
        final val = _extractNumeric(line, 'FUEL_USED=') ?? 0;
        add('fuelUsed', 'FUEL_USED', 'Combustível Usado', 'L', val);
      }
      if (line.contains('IO89=')) {
        final val = _extractNumeric(line, 'IO89=') ?? 0;
        add('io89', 'IO89', 'IO 89', null, val, 'io');
      }
      if (line.contains('IO105=')) {
        final val = _extractNumeric(line, 'IO105=') ?? 0;
        add('io105', 'IO105', 'IO 105', null, val, 'io');
      }
      if (line.contains('IO107=')) {
        final val = _extractNumeric(line, 'IO107=') ?? 0;
        add('io107', 'IO107', 'IO 107', null, val, 'io');
      }

      if (line.contains('IGN=')) {
        final value = _extractNumeric(line, 'IGN=') ?? 0;
        add('ignition', 'IGN', 'Ignição', null, value == 1);
      }
    }

    return measurements;
  }

  @override
  List<CommandDefinition> commands(DeviceContext context) {
    return [
      CommandDefinition(
        id: 'teltonika.identity',
        manufacturer: Manufacturer.teltonika,
        title: 'Identificação',
        description: 'Lê identidade via comando.',
        category: 'identification',
        risk: RiskLevel.readOnly,
      ),
      CommandDefinition(
        id: 'teltonika.status',
        manufacturer: Manufacturer.teltonika,
        title: 'Status',
        description: 'Lê status do dispositivo.',
        category: 'status',
        risk: RiskLevel.readOnly,
      ),
    ];
  }

  @override
  List<ConfigurationSection> configuration(DeviceContext context) {
    return [
      ConfigurationSection(
        id: 'teltonika.network',
        title: 'Rede',
        description: 'Configurações de rede Teltonika',
        fields: [
          ConfigurationField(
            id: 'teltonika.apn',
            name: 'APN',
            description: 'Nome do ponto de acesso',
            currentValue: 'teltonika.apn',
            pendingValue: null,
            valueType: FieldValueType.string,
            enumValues: null,
            requiresSave: true,
          ),
        ],
      ),
    ];
  }

  @override
  EncodedCommand encodeCommand(
    CommandRequest request,
    DeviceContext context,
  ) {
    final commandId = request.commandId;
    switch (commandId) {
      case 'teltonika.identity':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'IDENTITY;ESN',
          transport: CommandTransport.tcp,
        );
      case 'teltonika.status':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'STATUS',
          transport: CommandTransport.tcp,
        );
      default:
        throw ArgumentError('Comando desconhecido: $commandId');
    }
  }

  @override
  ParsedResponse parseResponse(
    RawResponse response,
    DeviceContext context,
  ) {
    return ParsedResponse(
      responseId: const Uuid().v4(),
      timestamp: response.timestamp,
      fields: {'raw': response.ascii},
    );
  }

  @override
  DiagnosticResult diagnose(DeviceSession session) {
    final findings = <DiagnosticFinding>{};

    if (session.normalizedState.vehicle.speedKph > 120) {
      findings.add(
        DiagnosticFinding(
          id: 'TLT-VEH-001',
          code: 'TLT-VEH-001',
          severity: RiskLevel.safe,
          title: 'Velocidade alta detectada',
          message: 'Velocidade acima do limite recomendado.',
        ),
      );
    }

    return DiagnosticResult(
      findings: findings.toList(),
      warnings: const [],
      errors: const [],
    );
  }

  String? _extractModel(RawInput input) {
    if (input.asciiLine != null) {
      final text = input.asciiLine!;
      if (text.contains('FMB140') || text.contains('FMB150')) {
        return text.contains('FMB140') ? 'FMB140' : 'FMB150';
      }
    }
    return null;
  }

  String? _extractEsn(RawInput input) {
    if (input.asciiLine != null) {
      final match = RegExp(r'AVL\s+ID:\s+(\d+)').firstMatch(input.asciiLine!);
      return match?.group(1);
    }
    return null;
  }

  num? _extractNumeric(String line, [String? p1, String? p2, String? p3, String? p4]) {
    final patterns = [p1, p2, p3, p4].whereType<String>();
    for (final pattern in patterns) {
      if (line.contains(pattern)) {
        final regex = RegExp(r'\d+(\.\d+)?');
        final match = regex.firstMatch(line);
        final numStr = match?.group(0);
        if (numStr != null) {
          return num.tryParse(numStr);
        }
      }
    }
    return null;
  }
}
