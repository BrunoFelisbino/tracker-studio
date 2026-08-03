import 'equipment_lab_types.dart';

/// Interface que cada adaptador de fabricante implementa para o Laboratório
/// de Equipamentos.
///
/// Um adaptador por fabricante (SunTech, Teltonika, ...) implementa tudo;
/// não há condicionais `if manufacturer ==` espalhados pelo app.
abstract class EquipmentProtocolAdapter {
  Manufacturer get manufacturer;
  String get displayName;
  String get parserVersion;
  bool get supportsCommands;

  /// Detecção de fabricante/modelo a partir de evidências (confiança 0-100).
  ManufacturerDetectionResult detect(String text);

  /// Identidade completa do equipamento (IMEI/ESN/ICCID/model/firmware/...).
  EquipmentIdentity identify(String text);

  /// Parseia texto capturado -> campos + IOs + chunks.
  EquipmentParseResult parseLines(String text);

  /// Catálogos versionados.
  List<DeviceCommandDefinition> get commands;
  List<EquipmentFieldDefinition> get fieldDefinitions;
  List<IoDefinition> get ioDefinitions;
  List<EquipmentTestDefinition> get testDefinitions;
  List<DiagnosticFailureDefinition> get failureDefinitions;

  /// Probe seguro de uma porta (sem comandos destrutivos).
  Future<PortProbeResult> probePort(PortProbeInput input);

  /// Parseia a resposta a um comando.
  CommandTransaction parseResponse(
    CommandTransaction transaction,
    String commandId,
    List<String> lines,
  );

  /// Diagnóstico automático.
  List<DiagnosticFinding> diagnose(
    EquipmentParseResult parsed,
    List<CommandTransaction> transactions,
  );
}

/// Resultado de parse: identidade + campos + IOs + bruto.
class EquipmentParseResult {
  final EquipmentIdentity identity;
  final List<DetectedField> fields;
  final Map<int, dynamic> ioValues;
  final List<RawSerialChunk> rawChunks;

  const EquipmentParseResult({
    required this.identity,
    required this.fields,
    required this.ioValues,
    this.rawChunks = const [],
  });
}

/// Registro central de adaptadores.
class AdapterRegistry {
  final List<EquipmentProtocolAdapter> _adapters;

  AdapterRegistry(List<EquipmentProtocolAdapter> adapters)
      : _adapters = List.unmodifiable(adapters);

  List<EquipmentProtocolAdapter> get adapters => _adapters;

  EquipmentProtocolAdapter? byManufacturer(Manufacturer manufacturer) {
    for (final adapter in _adapters) {
      if (adapter.manufacturer == manufacturer) return adapter;
    }
    return null;
  }
}
