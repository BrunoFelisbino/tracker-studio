import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'driver_contracts.dart';
import '../sessions/device_session.dart';
import '../sessions/device_session_provider.dart';
import '../data/parsers/teltonika_usb/teltonika_avl_binary_codec.dart';
import '../data/parsers/teltonika_usb/teltonika_usb_models.dart';

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
    try {
      final session = _ref.read(deviceSessionProvider(_deviceId)).valueOrNull;
      if (session != null &&
          session.identity.manufacturer != Manufacturer.unknown) {
        return _resolveDriver(session.identity.manufacturer);
      }
    } catch (e) {
      // Se a sessão ainda não foi carregada, retorna o default
    }
    // Default para novos dispositivos
    return DefaultDriver();
  }

  ManufacturerDriver _resolveDriver(Manufacturer manufacturer) {
    switch (manufacturer) {
      case Manufacturer.teltonika:
        return TeltonikaDriver();
      case Manufacturer.suntech:
        return SuntechDriver();
      default:
        return DefaultDriver();
    }
  }
}

/// Driver padrão para fabricantes desconhecidos/desenvolvimento.
class DefaultDriver implements ManufacturerDriver {
  @override
  Manufacturer get manufacturer => Manufacturer.unknown;

  @override
  DetectionResult detect(RawInput input) {
    return const DetectionResult(
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
      if (text.contains('at^') ||
          text.contains('^st8') ||
          text.contains('esn')) {
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
    return const DetectionResult(
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

      void add(
          String key, String rawKey, String name, String? unit, dynamic val,
          [String cat = 'vehicle']) {
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

      // Structured ST8210/ST8310 status response: RES;STT;...
      final sttMatch = RegExp(r'^RES;STT;').firstMatch(line);
      if (sttMatch != null) {
        _parseSt8StatusLine(line, add);
      } else if (RegExp(r'^ST\d{3,4}(U|UM|R)?STT;').hasMatch(line)) {
        _parseLegacyStatusLine(line, add);
      } else {
        _parseSimpleSuntechLine(line, add);
      }
    }

    return measurements;
  }

  void _parseSimpleSuntechLine(
    String line,
    void Function(String, String, String, String?, dynamic, [String]) add,
  ) {
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
      add('gpsFix', 'GPS', 'Fix GPS', null, val == 1, 'position');
    }
    if (line.contains('NET=')) {
      final val = _extractNumeric(line, 'NET=') ?? 0;
      add('networkStatus', 'NET', 'Status da Rede', null,
          val == 1 ? 'online' : 'offline', 'network');
    }
    if (line.contains('PWR=')) {
      final val = _extractNumeric(line, 'PWR=') ?? 0;
      add('externalVoltage', 'PWR', 'Alimentação', 'V', val.toDouble(),
          'power');
    }
    if (line.contains('BATT=')) {
      final val = _extractNumeric(line, 'BATT=') ?? 0;
      add('batteryPercent', 'BATT', 'Bateria', '%', val.toInt());
    }
    if (line.contains('Sat=')) {
      final val = _extractNumeric(line, 'Sat=') ?? 0;
      add('satellites', 'Sat', 'Satélites', null, val.toInt(), 'position');
    }
    if (line.contains('Lat=') || line.contains('Latitude=')) {
      final val = _extractNumeric(line, 'Lat=', 'Latitude:') ?? 0;
      add('latitude', 'Lat', 'Latitude', 'º', val.toDouble(), 'position');
    }
    if (line.contains('Lon=') || line.contains('Longitude=')) {
      final val = _extractNumeric(line, 'Lon=', 'Longitude:') ?? 0;
      add('longitude', 'Lon', 'Longitude', 'º', val.toDouble(), 'position');
    }
  }

  // Formato: RES;STT;<esn>;03;<sw>,<lat>,<lon>,<speed>,<course>,<sats>,
  //          <fix>,<in_mask>,<out_mask>,<ignition>,<io>,...,<main_v>,<batt_v>,
  //          ...,<net_code>,<gprs>,<rssi>,<mcc>,<mnc>,<lac>,<cell_id>,...
  void _parseSt8StatusLine(
    String line,
    void Function(String, String, String, String?, dynamic, [String]) add,
  ) {
    final parts = line.split(';');
    String? at(int index) => index < parts.length ? parts[index] : null;
    double? dblAt(int index) => double.tryParse(at(index) ?? '');
    int? intAt(int index) => int.tryParse(at(index) ?? '');

    final lat = dblAt(8);
    if (lat != null && lat != 0) {
      add('latitude', 'STT.LAT', 'Latitude', 'º', lat, 'position');
    }
    final lon = dblAt(9);
    if (lon != null && lon != 0) {
      add('longitude', 'STT.LON', 'Longitude', 'º', lon, 'position');
    }
    final speed = dblAt(10);
    if (speed != null && speed >= 0) {
      add('speedKph', 'STT.SPEED', 'Velocidade', 'km/h', speed.toInt());
    }
    final course = dblAt(11);
    if (course != null && course >= 0) {
      add('heading', 'STT.COURSE', 'Direção', 'º', course, 'position');
    }
    final sats = intAt(12);
    if (sats != null && sats >= 0) {
      add('satellites', 'STT.SATS', 'Satélites', null, sats, 'position');
    }
    final fix = at(13);
    final gpsFix = fix == '1' || (sats != null && sats >= 4);
    add('gpsFix', 'STT.FIX', 'Fix GPS', null, gpsFix, 'position');

    final inputMask = at(14);
    if (inputMask != null && inputMask.isNotEmpty) {
      add('inputMask', 'STT.INPUT', 'Entradas', null, inputMask, 'io');
      final ignitionOn = inputMask.startsWith('1');
      add('ignition', 'STT.IGN', 'Ignição', null, ignitionOn);
      add('movement', 'STT.MOV', 'Movimento', null, inputMask.length > 1 && inputMask[1] == '1');
    }

    final outputMask = at(15);
    if (outputMask != null && outputMask.isNotEmpty) {
      add('outputMask', 'STT.OUTPUT', 'Saídas', null, outputMask, 'io');
    }

    final mainVolt = dblAt(20);
    if (mainVolt != null && mainVolt > 0) {
      add('externalVoltage', 'STT.MAIN_V', 'Alimentação', 'V', mainVolt,
          'power');
    }
    final backupVolt = dblAt(21);
    if (backupVolt != null && backupVolt > 0) {
      add('internalVoltage', 'STT.BACKUP_V', 'Bateria Interna', 'V',
          backupVolt, 'power');
    }

    final gprs = at(parts.length - 2);
    if (gprs != null) {
      final gprsValue = int.tryParse(gprs) ?? 0;
      add('networkStatus', 'STT.GPRS', 'Status da Rede', null,
          gprsValue == 1 ? 'online' : 'offline', 'network');
    }
    final netCode = at(parts.length - 3);
    if (netCode != null && netCode.isNotEmpty && netCode != '255') {
      add('operatorName', 'STT.NETWORK', 'Operadora', null, netCode,
          'network');
    }
  }

  void _parseLegacyStatusLine(
    String line,
    void Function(String, String, String, String?, dynamic, [String]) add,
  ) {
    final parts = line.split(';');
    String? at(int index) => index < parts.length ? parts[index] : null;
    double? dblAt(int index) => double.tryParse(at(index) ?? '');
    int? intAt(int index) => int.tryParse(at(index) ?? '');

    final lat = dblAt(8);
    if (lat != null && lat != 0) {
      add('latitude', 'STT.LAT', 'Latitude', 'º', lat, 'position');
    }
    final lon = dblAt(9);
    if (lon != null && lon != 0) {
      add('longitude', 'STT.LON', 'Longitude', 'º', lon, 'position');
    }
    final speed = dblAt(10);
    if (speed != null && speed >= 0) {
      add('speedKph', 'STT.SPEED', 'Velocidade', 'km/h', speed.toInt());
    }
    final course = dblAt(12);
    if (course != null && course >= 0) {
      add('heading', 'STT.COURSE', 'Direção', 'º', course, 'position');
    }
    final sats = intAt(13);
    if (sats != null && sats >= 0) {
      add('satellites', 'STT.SATS', 'Satélites', null, sats, 'position');
    }

    final inputMask = at(15);
    if (inputMask != null && inputMask.isNotEmpty) {
      final ignitionOn = inputMask.startsWith('1');
      add('ignition', 'STT.IGN', 'Ignição', null, ignitionOn);
    }

    final mainVolt = dblAt(16);
    if (mainVolt != null && mainVolt > 0) {
      add('externalVoltage', 'STT.MAIN_V', 'Alimentação', 'V', mainVolt,
          'power');
    }
  }

  @override
  List<CommandDefinition> commands(DeviceContext context) {
    return [
      const CommandDefinition(
        id: 'suntech.identity',
        manufacturer: Manufacturer.suntech,
        title: 'Identificação',
        description: 'Lê identidade via comando AT.',
        category: 'identification',
        risk: RiskLevel.readOnly,
      ),
      const CommandDefinition(
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
      const ConfigurationSection(
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
        const DiagnosticFinding(
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
      final match = RegExp(r'ESN[=:]?\s*([0-9A-Fa-f]{8,16})')
          .firstMatch(input.asciiLine!);
      return match?.group(1);
    }
    return null;
  }

  num? _extractNumeric(String line,
      [String? p1, String? p2, String? p3, String? p4]) {
    final patterns = [p1, p2, p3, p4].whereType<String>();
    for (final pattern in patterns) {
      final clean = pattern.replaceAll(RegExp(r'[=:]'), '');
      final regex =
          RegExp(RegExp.escape(clean) + r'[=:]\s*(-?\d+(?:\.\d+)?)');
      final match = regex.firstMatch(line);
      if (match != null) {
        return num.tryParse(match.group(1)!);
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
      if (text.contains('teltonika') ||
          text.contains('fmb140') ||
          text.contains('fmb150')) {
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
    return const DetectionResult(
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

    // ── Binary AVL records (hex input from serial log dumps) ─────────────
    if (input.hex != null) {
      final decoded =
          TeltonikaAvlCodec.decodeHexLines([input.hex!]);
      if (decoded is TeltonikaDecodeSuccess) {
        for (final record in decoded.records) {
          _extractAvlRecord(record, measurements, input);
        }
        if (measurements.isNotEmpty) return measurements;
      }
    }

    if (input.bytes != null && input.bytes!.isNotEmpty) {
      final decoded = TeltonikaAvlCodec.decode(Uint8List.fromList(input.bytes!));
      if (decoded is TeltonikaDecodeSuccess) {
        for (final record in decoded.records) {
          _extractAvlRecord(record, measurements, input);
        }
        if (measurements.isNotEmpty) return measurements;
      }
    }

    // ── ASCII text lines ──────────────────────────────────────────────────
    if (input.asciiLine != null) {
      final line = input.asciiLine!;

      void add(
          String key, String rawKey, String name, String? unit, dynamic val,
          [String cat = 'vehicle']) {
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

      // AVL IO elements embedded in text logs: IO ID[66]: 12000
      for (final ioMatch
          in RegExp(r'IO\s+ID\[\s*(\d+)\s*\]\s*:\s*(-?\d+(?:\.\d+)?)')
              .allMatches(line)) {
        final ioId = int.parse(ioMatch.group(1)!);
        final ioVal = num.tryParse(ioMatch.group(2)!);
        if (ioVal == null) continue;

        switch (ioId) {
          case 3:
            add('ignition', 'IO3', 'Ignição', null, ioVal == 1, 'vehicle');
          case 66:
            add('externalVoltage', 'IO66', 'Alimentação', 'V',
                ioVal.toDouble() / 1000, 'power');
          case 67:
            add('internalVoltage', 'IO67', 'Bateria Interna', 'V',
                ioVal.toDouble() / 1000, 'power');
          case 240:
            add('movement', 'IO240', 'Movimento', null, ioVal == 1);
          case 89:
            add('fuelLevelPercentage', 'IO89', 'Nível de combustível', '%',
                ioVal, 'vehicle');
          case 105:
            add('io105', 'IO105', 'IO 105', null, ioVal, 'io');
          case 107:
            add('io107', 'IO 107', 'IO 107', null, ioVal, 'io');
          default:
            add('io_$ioId', 'IO$ioId', 'IO $ioId', null, ioVal, 'io');
        }
      }

      // CAN / OBD data
      if (line.contains('RPM=') || line.contains('rpm')) {
        final val = _extractNumeric(line, 'RPM=', 'rpm') ?? 0;
        add('rpm', 'RPM', 'RPM', 'rpm', val);
      }
      if (line.contains('OBD_SPEED=')) {
        final val = _extractNumeric(line, 'OBD_SPEED=') ?? 0;
        add('speedKph', 'OBD_SPEED', 'Velocidade CAN', 'km/h', val);
      }
      if (line.contains('OBD_ODOMETER=')) {
        final val = _extractNumeric(line, 'OBD_ODOMETER=') ?? 0;
        add('odometerKm', 'OBD_ODOMETER', 'Odômetro CAN', 'km', val);
      }
      if (line.contains('FUEL_LEVEL=')) {
        final val = _extractNumeric(line, 'FUEL_LEVEL=') ?? 0;
        add('fuelLevelPercentage', 'FUEL_LEVEL', 'Nível de combustível', '%',
            val);
      }
      if (line.contains('THROTTLE=')) {
        final val = _extractNumeric(line, 'THROTTLE=') ?? 0;
        add('throttle', 'THROTTLE', 'Acelerador', '%', val);
      }
      if (line.contains('FUEL_USED=')) {
        final val = _extractNumeric(line, 'FUEL_USED=') ?? 0;
        add('fuelUsed', 'FUEL_USED', 'Combustível Usado', 'L', val);
      }

      // Ignition from simple flag
      if (line.contains('IGN=')) {
        final value = _extractNumeric(line, 'IGN=') ?? 0;
        add('ignition', 'IGN', 'Ignição', null, value == 1);
      }

      // GPS / Position data
      final lat = _extractNumeric(line, 'Lat', 'Latitude');
      if (lat != null) {
        add('latitude', 'Lat', 'Latitude', 'º', lat.toDouble(), 'position');
      }
      final lon = _extractNumeric(line, 'Lon', 'Longitude');
      if (lon != null) {
        add('longitude', 'Lon', 'Longitude', 'º', lon.toDouble(), 'position');
      }
      final speed = _extractNumeric(line, 'GPS Speed', 'Speed');
      if (speed != null && !line.contains('OBD_SPEED')) {
        add('speedKph', 'Speed', 'Velocidade', 'km/h', speed);
      }
      final sats = _extractNumeric(line, 'Satellites Used', 'Sat');
      if (sats != null) {
        add('satellites', 'Sat', 'Satélites', null, sats.toInt(), 'position');
      }
      final alt = _extractNumeric(line, 'Alt', 'Altitude');
      if (alt != null) {
        add('altitude', 'Alt', 'Altitude', 'm', alt, 'position');
      }
      final heading = _extractNumeric(line, 'Angle', 'Heading');
      if (heading != null) {
        add('heading', 'Angle', 'Direção', 'º', heading, 'position');
      }
      final hdop = _extractNumeric(line, 'HDOP');
      if (hdop != null) {
        add('hdop', 'HDOP', 'HDOP', null, hdop, 'position');
      }

      // Network / GPRS
      if (line.contains('GSM Network Type:') ||
          line.contains('GSM Network Type=')) {
        final val = _extractStringAfter(line, 'GSM Network Type');
        if (val != null && val.isNotEmpty) {
          add('technology', 'GSM_NET_TYPE', 'Tecnologia', null, val,
              'network');
        }
      }
      if (line.contains('Operator:') || line.contains('Operator=')) {
        final val = _extractStringAfter(line, 'Operator');
        if (val != null && val.isNotEmpty) {
          add('operatorName', 'OPERATOR', 'Operadora', null, val, 'network');
        }
      }
      if (line.contains('RSSI:')) {
        final val = _extractNumeric(line, 'RSSI:') ?? 0;
        add('signalLevel', 'RSSI', 'Nível de Sinal', 'dBm', val.toInt(),
            'network');
      }
      if (line.contains('Roaming:')) {
        final val = _extractStringAfter(line, 'Roaming')
            ?.toLowerCase()
            .contains('on');
        add('roaming', 'ROAMING', 'Roaming', null, val ?? false, 'network');
      }
      if (line.contains('GPRS') || line.contains('gprs')) {
        final online = line.toLowerCase().contains('gprs') &&
            (line.toLowerCase().contains('online') ||
             line.toLowerCase().contains('ok'));
        add('networkStatus', 'GPRS', 'Status da Rede', null,
            online ? 'online' : 'offline', 'network');
      }

      // Power / Battery from text lines
      if (line.contains('Main Voltage:') ||
          line.contains('Main Volts:') ||
          line.contains('MainPower:')) {
        final val = _extractNumeric(line, 'Main Voltage:', 'Main Volts:',
                'MainPower:') ??
            0;
        add('externalVoltage', 'MAIN_VOLTAGE', 'Alimentação', 'V',
            val.toDouble(), 'power');
      }
      if (line.contains('Backup Voltage:') ||
          line.contains('Backup Volts:') ||
          line.contains('BackupBattery:')) {
        final val = _extractNumeric(
                line, 'Backup Voltage:', 'Backup Volts:', 'BackupBattery:') ??
            0;
        add('internalVoltage', 'BACKUP_VOLTAGE', 'Bateria Interna', 'V',
            val.toDouble(), 'power');
      }
      if (line.contains('Battery:') || line.contains('BatteryLevel:')) {
        final val =
            _extractNumeric(line, 'Battery:', 'BatteryLevel:') ?? 0;
        add('batteryPercent', 'BATT_LEVEL', 'Bateria', '%', val.toInt(),
            'power');
        add('charging', 'BATT_CHARGE', 'Carregando', null, val > 0, 'power');
      }
    }

    return measurements;
  }

  @override
  List<CommandDefinition> commands(DeviceContext context) {
    return [
      const CommandDefinition(
        id: 'teltonika.identity',
        manufacturer: Manufacturer.teltonika,
        title: 'Identificação',
        description: 'Lê identidade via comando.',
        category: 'identification',
        risk: RiskLevel.readOnly,
      ),
      const CommandDefinition(
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
      const ConfigurationSection(
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
        const DiagnosticFinding(
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

  static List<int> bytesFromHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length % 2 != 0) return [];
    return List<int>.generate(
      cleaned.length ~/ 2,
      (i) => int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16),
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
    if (input.hex != null) {
      final hex = input.hex!;
      final bytes = bytesFromHex(hex);
      if (bytes.isNotEmpty) {
        if (bytes[0] == 0x00 && bytes.length >= 9) {
          final id = bytes.sublist(5, 9);
          return id
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join('')
              .toUpperCase();
        }
      }
    }
    return null;
  }

  num? _extractNumeric(String line,
      [String? p1, String? p2, String? p3, String? p4]) {
    final patterns = [p1, p2, p3, p4].whereType<String>();
    for (final pattern in patterns) {
      final clean = pattern.replaceAll(RegExp(r'[=:]'), '');
      final regex =
          RegExp(RegExp.escape(clean) + r'[=:]\s*(-?\d+(?:\.\d+)?)');
      final match = regex.firstMatch(line);
      if (match != null) {
        return num.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  void _extractAvlRecord(
    TeltonikaGeneratedAvlRecord record,
    List<NormalizedMeasurement> measurements,
    RawInput input,
  ) {
    void add(String key, String rawKey, String name, String? unit,
        dynamic val, [String cat = 'vehicle']) {
      measurements.add(NormalizedMeasurement(
        key: key,
        rawKey: rawKey,
        category: cat,
        name: name,
        unit: unit,
        multiplier: 1,
        value: val,
        timestamp: input.timestamp,
        metadata: {'recordId': record.id, 'raw': record.rawLines.join('\n')},
      ));
    }

    if (record.latitude != null && record.latitude != 0) {
      add('latitude', 'AVL.LAT', 'Latitude', 'º', record.latitude, 'position');
    }
    if (record.longitude != null && record.longitude != 0) {
      add('longitude', 'AVL.LON', 'Longitude', 'º', record.longitude,
          'position');
    }
    if (record.altitude != null) {
      add('altitude', 'AVL.ALT', 'Altitude', 'm', record.altitude, 'position');
    }
    if (record.angle != null) {
      add('heading', 'AVL.ANGLE', 'Direção', 'º', record.angle, 'position');
    }
    if (record.speedKph != null && record.speedKph != 0) {
      add('speedKph', 'AVL.SPEED', 'Velocidade', 'km/h', record.speedKph);
    }
    if (record.hdop != null) {
      add('hdop', 'AVL.HDOP', 'HDOP', null, record.hdop, 'position');
    }
    if (record.satellites != null && record.satellites! > 0) {
      add('satellites', 'AVL.SATS', 'Satélites', null, record.satellites,
          'position');
    }

    // IO elements: map AVL IDs to canonical measurement keys using the
    // AVL catalog definition when available, otherwise fall back to raw key.
    for (final entry in record.ioElements.entries) {
      final avlId = entry.key;
      final val = entry.value;

      switch (avlId) {
        case 3:
          add('ignition', 'AVL.IO3', 'Ignição', null, val == 1);
        case 66:
          final v = (val as num?)?.toDouble() ?? 0;
          add('externalVoltage', 'AVL.IO66', 'Alimentação', 'V',
              v / 1000, 'power');
        case 67:
          final v = (val as num?)?.toDouble() ?? 0;
          add('internalVoltage', 'AVL.IO67', 'Bateria Interna', 'V',
              v / 1000, 'power');
        case 240:
          add('movement', 'AVL.IO240', 'Movimento', null, val == 1);
        case 89:
          add('fuelLevelPercentage', 'AVL.IO89', 'Nível de combustível', '%',
              val, 'vehicle');
        case 113:
          add('fuelLevelPercentage', 'AVL.IO113', 'Nível de combustível (CAN)',
              '%', val, 'vehicle');
        default:
          add('io_$avlId', 'AVL.IO$avlId', 'IO $avlId', null, val, 'io');
      }
    }
  }

  String? _extractStringAfter(String line, String prefix) {
    final regex = RegExp(
        RegExp.escape(prefix) + r'\s*[=:]\s*([^\r\n;]+?)(?:\s*;|$)');
    final match = regex.firstMatch(line);
    return match?.group(1)?.trim();
  }
}
