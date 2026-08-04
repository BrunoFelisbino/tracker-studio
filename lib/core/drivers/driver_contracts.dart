import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

/// Interface contrat para o driver de fabricante.
///
/// Implementação por fabricante (Teltonika, Suntech, etc.) gerencia todos os detalhes
/// específicos da fabricante. O front usa somente este contrato.
abstract class ManufacturerDriver {
  /// Identidade do fabricante.
  Manufacturer get manufacturer;

  /// Detecta fabricante/modelo a partir de dados brutos (confiança 0-100).
  DetectionResult detect(RawInput input);

  /// Identifica equipamento completo a partir de dados brutos.
  DeviceIdentity identify(RawInput input);

  /// Retorna capacidades do dispositivo.
  DeviceCapabilities capabilities(DeviceContext context);

  /// Normaliza dados brutos para modelo de estado.
  ///
  /// Cada entrada pode gerar múltiplos campos normalizados.
  List<NormalizedMeasurement> normalize(
    RawInput input,
    DeviceContext context,
  );

  /// Retorna catálogo de comandos disponíveis para este dispositivo.
  List<CommandDefinition> commands(DeviceContext context);

  /// Retorna lista de seções de configuração.
  List<ConfigurationSection> configuration(DeviceContext context);

  /// Codifica uma solicitação de comando para transporte.
  EncodedCommand encodeCommand(
    CommandRequest request,
    DeviceContext context,
  );

  /// Decodifica resposta bruta em objeto estruturado.
  ParsedResponse parseResponse(
    RawResponse response,
    DeviceContext context,
  );

  /// Executa diagnóstico e retorna resultados.
  DiagnosticResult diagnose(
    DeviceSession session,
  );
}

/// Resposta de detecção.
class DetectionResult extends Equatable {
  final Manufacturer manufacturer;
  final String? protocol;
  final String? model;
  final int confidence;
  final List<DetectionEvidence> evidence;

  const DetectionResult({
    required this.manufacturer,
    this.protocol,
    this.model,
    required this.confidence,
    this.evidence = const [],
  });

  @override
  List<Object?> get props =>
      [manufacturer, protocol, model, confidence, evidence];
}

/// Evidência de uma detecção (regra, peso, valor correspondido).
class DetectionEvidence extends Equatable {
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

  @override
  List<Object?> get props => [rule, description, weight, matchedValue];
}

/// Identidade normalizada de um dispositivo.
class DeviceIdentity extends Equatable {
  final String id;
  final Manufacturer manufacturer;
  final String? model;
  final String? esn;
  final String? imei;
  final String? firmware;
  final String? hardwareVersion;
  final String? protocol;
  final String? codec;
  final DateTime? firstSeenAt;
  final int confidence;

  const DeviceIdentity({
    required this.id,
    required this.manufacturer,
    this.model,
    this.esn,
    this.imei,
    this.firmware,
    this.hardwareVersion,
    this.protocol,
    this.codec,
    this.firstSeenAt,
    required this.confidence,
  });

  @override
  List<Object?> get props => [
        id,
        manufacturer,
        model,
        esn,
        imei,
        firmware,
        hardwareVersion,
        protocol,
        codec,
        firstSeenAt,
        confidence,
      ];
}

/// Contexto de um dispositivo (sessão).
class DeviceContext extends Equatable {
  final String deviceId;
  final DeviceIdentity identity;
  final DeviceCapabilities capabilities;

  const DeviceContext({
    required this.deviceId,
    required this.identity,
    required this.capabilities,
  });

  @override
  List<Object?> get props => [deviceId, identity, capabilities];
}

/// Capacidades declaradas pelo driver.
class DeviceCapabilities extends Equatable {
  final bool can; // CAN/LVCAN
  final bool ble; // Bluetooth Low Energy
  final bool hasCan; // Detecção CAN por IOs
  final bool obd2; // OBD-II
  final bool cellular; // GPRS/Cellular
  final bool gps; // GPS
  final List<String> sensors; // Lista de sensores suportados
  final List<String> ioTypes; // Tipos de IO suportados

  const DeviceCapabilities({
    required this.can,
    required this.ble,
    required this.hasCan,
    required this.obd2,
    required this.cellular,
    required this.gps,
    this.sensors = const [],
    this.ioTypes = const [],
  });

  @override
  List<Object?> get props => [
        can,
        ble,
        hasCan,
        obd2,
        cellular,
        gps,
        sensors,
        ioTypes,
      ];
}

/// Dados brutos recebidos do serial/transport.
class RawInput extends Equatable {
  final String portId;
  final DateTime timestamp;
  final String? asciiLine;
  final List<int>? bytes;
  final String? hex;
  final String lineTerminator;
  final int baudRate;

  const RawInput({
    required this.portId,
    required this.timestamp,
    this.asciiLine,
    this.bytes,
    this.hex,
    required this.lineTerminator,
    required this.baudRate,
  });

  @override
  List<Object?> get props => [
        portId,
        timestamp,
        asciiLine,
        bytes,
        hex,
        lineTerminator,
        baudRate,
      ];
}

/// Comando normalizado para transporte.
class EncodedCommand extends Equatable {
  final String commandId;
  final String encoded;
  final CommandTransport transport;

  const EncodedCommand({
    required this.commandId,
    required this.encoded,
    required this.transport,
  });

  @override
  List<Object?> get props => [commandId, encoded, transport];
}

/// Resposta bruta decodificada.
class ParsedResponse extends Equatable {
  final String responseId;
  final DateTime timestamp;
  final Map<String, dynamic> fields;

  const ParsedResponse({
    required this.responseId,
    required this.timestamp,
    required this.fields,
  });

  @override
  List<Object?> get props => [responseId, timestamp, fields];
}

/// Medição normalizada para o front.
class NormalizedMeasurement extends Equatable {
  final String key;
  final String rawKey;
  final String category;
  final String name;
  final String? unit;
  final num? multiplier;
  final dynamic value;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const NormalizedMeasurement({
    required this.key,
    required this.rawKey,
    required this.category,
    required this.name,
    this.unit,
    this.multiplier,
    this.value,
    required this.timestamp,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        key,
        rawKey,
        category,
        name,
        unit,
        multiplier,
        value,
        timestamp,
        metadata,
      ];
}

/// Definição de comando para o catálogo.
class CommandDefinition extends Equatable {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? models;
  final String title;
  final String description;
  final String category;
  final RiskLevel risk;
  final List<CommandArgument> arguments;

  const CommandDefinition({
    required this.id,
    required this.manufacturer,
    this.models,
    required this.title,
    required this.description,
    required this.category,
    required this.risk,
    this.arguments = const [],
  });

  @override
  List<Object?> get props =>
      [id, manufacturer, models, title, description, category, risk, arguments];
}

/// Argumento para um comando.
class CommandArgument extends Equatable {
  final String name;
  final String type;

  const CommandArgument({
    required this.name,
    required this.type,
  });

  @override
  List<Object?> get props => [name, type];
}

/// Seção de configuração.
class ConfigurationSection extends Equatable {
  final String id;
  final String title;
  final String? description;
  final List<ConfigurationField> fields;

  const ConfigurationSection({
    required this.id,
    required this.title,
    this.description,
    required this.fields,
  });

  @override
  List<Object?> get props => [id, title, description, fields];
}

/// Campo individual de configuração.
class ConfigurationField extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? currentValue;
  final String? pendingValue;
  final FieldValueType valueType;
  final Map<String, String>? enumValues;
  final bool requiresSave;

  const ConfigurationField({
    required this.id,
    required this.name,
    this.description,
    this.currentValue,
    this.pendingValue,
    required this.valueType,
    this.enumValues,
    required this.requiresSave,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        currentValue,
        pendingValue,
        valueType,
        enumValues,
        requiresSave,
      ];
}

/// Resultado de diagnóstico.
class DiagnosticResult extends Equatable {
  final List<DiagnosticFinding> findings;
  final List<DiagnosticFinding> warnings;
  final List<DiagnosticFinding> errors;

  const DiagnosticResult({
    this.findings = const [],
    this.warnings = const [],
    this.errors = const [],
  });

  @override
  List<Object?> get props => [findings, warnings, errors];
}

/// Estado completo normalizado do dispositivo.
class NormalizedDeviceState extends Equatable {
  final DateTime lastUpdate;
  final String connectionStatus;
  final DateTime? lastPacketAt;
  final String? networkInfo;

  final VehicleState vehicle;
  final PowerState power;
  final NetworkState network;
  final PositionState position;
  final Map<String, dynamic> measurements;

  const NormalizedDeviceState({
    required this.lastUpdate,
    required this.connectionStatus,
    this.lastPacketAt,
    this.networkInfo,
    required this.vehicle,
    required this.power,
    required this.network,
    required this.position,
    required this.measurements,
  });

  @override
  List<Object?> get props => [
        lastUpdate,
        connectionStatus,
        lastPacketAt,
        networkInfo,
        vehicle,
        power,
        network,
        position,
        measurements,
      ];
}

/// Estado do veículo.
class VehicleState extends Equatable {
  final bool ignition;
  final bool movement;
  final int speedKph;
  final int odometerKm;
  final DateTime? ignitionOnAt;
  final DateTime? ignitionOffAt;

  const VehicleState({
    required this.ignition,
    required this.movement,
    required this.speedKph,
    required this.odometerKm,
    this.ignitionOnAt,
    this.ignitionOffAt,
  });

  @override
  List<Object?> get props => [
        ignition,
        movement,
        speedKph,
        odometerKm,
        ignitionOnAt,
        ignitionOffAt,
      ];
}

/// Estado de energia.
class PowerState extends Equatable {
  final double externalVoltage;
  final double internalVoltage;
  final int batteryPercent;
  final bool charging;

  const PowerState({
    required this.externalVoltage,
    required this.internalVoltage,
    required this.batteryPercent,
    required this.charging,
  });

  @override
  List<Object?> get props => [
        externalVoltage,
        internalVoltage,
        batteryPercent,
        charging,
      ];
}

/// Estado de rede.
class NetworkState extends Equatable {
  final String status;
  final String operator;
  final int signalLevel;
  final String technology;
  final bool roaming;

  const NetworkState({
    required this.status,
    required this.operator,
    required this.signalLevel,
    required this.technology,
    required this.roaming,
  });

  @override
  List<Object?> get props => [
        status,
        operator,
        signalLevel,
        technology,
        roaming,
      ];
}

/// Estado de posição.
class PositionState extends Equatable {
  final double latitude;
  final double longitude;
  final double altitude;
  final double heading;
  final int satellites;
  final double hdop;
  final DateTime timestamp;

  const PositionState({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.heading,
    required this.satellites,
    required this.hdop,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        altitude,
        heading,
        satellites,
        hdop,
        timestamp,
      ];
}
