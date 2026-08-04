import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../driver_contracts.dart';

/// Provider para o driver por sessão.
final deviceDriverProvider = Provider.family<ManufacturerDriver, String>(
  (ref, deviceId) {
    // Factory method para obter driver baseado na identidade do dispositivo
    return _DeviceDriverResolver(ref, deviceId);
  },
);

/// Gerenciador de drivers com cache de sessão.
class _DeviceDriverResolver {
  final Ref _ref;
  final String _deviceId;

  _DeviceDriverResolver(this._ref, this._deviceId);

  ManufacturerDriver get driver {
    // Em produção real, isto consultaria a session store/remote API
    // Para demonstração, retorna um driver mock
    final deviceState = _ref.read(deviceSessionProvider(_deviceId));
    if (deviceState != null && deviceState.identity.manufacturer != Manufacturer.unknown) {
      switch (deviceState.identity.manufacturer) {
        case Manufacturer.suntech:
          return const SuntechDriver();
        case Manufacturer.teltonika:
          return const TeltonikaDriver();
        default:
          return const DefaultDriver();
      }
    }
    // Default para novos dispositivos
    return const DefaultDriver();
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

      if (line.contains('IGNO=') || line.contains('IGN=')) {
        final value = _extractNumeric(line, 'IGNO', 'IGN') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'ignition',
            rawKey: 'IGNO',
            category: 'vehicle',
            name: 'Ignição',
            unit: null,
            multiplier: null,
            value: value == 1,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('RPM=') || line.contains('RPM')) {
        final value = _extractNumeric(line, 'RPM=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'rpm',
            rawKey: 'RPM',
            category: 'vehicle',
            name: 'RPM',
            unit: 'rpm',
            multiplier: 1,
            value: value,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('SPEED=')) {
        final value = _extractNumeric(line, 'SPEED=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'speed',
            rawKey: 'SPEED',
            category: 'vehicle',
            name: 'Velocidade',
            unit: 'km/h',
            multiplier: 1,
            value: value,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('ODOMETER=') || line.contains('OD')) {
        final value = _extractNumeric(line, 'ODOMETER=', 'OD') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'odometer',
            rawKey: 'ODOMETER',
            category: 'vehicle',
            name: 'Odômetro',
            unit: 'km',
            multiplier: 1,
            value: value,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
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
          transport: CommandTransport.usbTerminal,
        );
      case 'suntech.status':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'AT^ST300CMD;;02;Status',
          transport: CommandTransport.usbTerminal,
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
          code: 'ST-VEH-001',
          severity: DiagnosticSeverity.warning,
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

  num? _extractNumeric(String line, ...String patterns) {
    for (final pattern in patterns) {
      if (line.contains(pattern)) {
        final regex = RegExp(r'\d+');
        final match = regex.firstMatch(line);
        return match?.group(0)?.toNum();
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

      if (line.contains('IGN=')) {
        final value = _extractNumeric(line, 'IGN=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'ignition',
            rawKey: 'IGN',
            category: 'vehicle',
            name: 'Ignição',
            unit: null,
            multiplier: null,
            value: value == 1,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('SPEED=')) {
        final value = _extractNumeric(line, 'SPEED=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'speed',
            rawKey: 'SPEED',
            category: 'vehicle',
            name: 'Velocidade',
            unit: 'km/h',
            multiplier: 1,
            value: value,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('LAT=') && line.contains('LON=')) {
        final lat = _extractNumeric(line, 'LAT=') ?? 0;
        final lon = _extractNumeric(line, 'LON=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'latitude',
            rawKey: 'LAT',
            category: 'position',
            name: 'Latitude',
            unit: 'deg',
            multiplier: 1,
            value: lat,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
        measurements.add(
          NormalizedMeasurement(
            key: 'longitude',
            rawKey: 'LON',
            category: 'position',
            name: 'Longitude',
            unit: 'deg',
            multiplier: 1,
            value: lon,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
      }

      if (line.contains('ALT=')) {
        final value = _extractNumeric(line, 'ALT=') ?? 0;
        measurements.add(
          NormalizedMeasurement(
            key: 'altitude',
            rawKey: 'ALT',
            category: 'position',
            name: 'Altitude',
            unit: 'm',
            multiplier: 1,
            value: value,
            timestamp: input.timestamp,
            metadata: {'raw': line},
          ),
        );
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
          transport: CommandTransport.tcpCodec12,
        );
      case 'teltonika.status':
        return EncodedCommand(
          commandId: commandId,
          encoded: 'STATUS',
          transport: CommandTransport.tcpCodec12,
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
          code: 'TLT-VEH-001',
          severity: DiagnosticSeverity.warning,
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

  num? _extractNumeric(String line, ...String patterns) {
    for (final pattern in patterns) {
      if (line.contains(pattern)) {
        final regex = RegExp(r'\d+(\.\d+)?');
        final match = regex.firstMatch(line);
        return match?.group(0)?.toNum();
      }
    }
    return null;
  }
}
