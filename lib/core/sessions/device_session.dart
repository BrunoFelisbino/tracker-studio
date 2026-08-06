import 'package:equatable/equatable.dart';
import '../drivers/driver_contracts.dart';

/// Representa uma sessão ativa de um dispositivo com todos os seus dados normalizados.
class DeviceSession extends Equatable {
  final String id;
  final DeviceIdentity identity;
  final DeviceCapabilities capabilities;
  final NormalizedDeviceState normalizedState;
  final List<NormalizedMeasurement> measurements;
  final Map<String, dynamic> rawData;
  final List<CommandTransaction> responses;
  final List<ConfigurationSnapshot> configurationSnapshots;
  final List<DiagnosticFinding> diagnostics;
  final DateTime createdAt;
  final DateTime lastUpdate;
  final bool isActive;

  const DeviceSession({
    required this.id,
    required this.identity,
    required this.capabilities,
    required this.normalizedState,
    required this.measurements,
    required this.rawData,
    required this.responses,
    required this.configurationSnapshots,
    required this.diagnostics,
    required this.createdAt,
    required this.lastUpdate,
    required this.isActive,
  });

  /// Atualiza a sessão com novos dados normalizados.
  DeviceSession updateState({
    required NormalizedDeviceState newState,
    required List<NormalizedMeasurement> newMeasurements,
    required Map<String, dynamic> newRawData,
    required DateTime timestamp,
  }) {
    return DeviceSession(
      id: id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: newState,
      measurements: _mergeMeasurements(measurements, newMeasurements),
      rawData: _mergeRawData(rawData, newRawData),
      responses: responses,
      configurationSnapshots: configurationSnapshots,
      diagnostics: diagnostics,
      createdAt: createdAt,
      lastUpdate: timestamp,
      isActive: isActive,
    );
  }

  /// Adiciona uma nova resposta de comando à sessão.
  DeviceSession addResponse(CommandTransaction response) {
    final updatedResponses = List<CommandTransaction>.from(responses)
      ..add(response);
    return DeviceSession(
      id: id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: normalizedState,
      measurements: measurements,
      rawData: rawData,
      responses: updatedResponses,
      configurationSnapshots: configurationSnapshots,
      diagnostics: diagnostics,
      createdAt: createdAt,
      lastUpdate: DateTime.now(),
      isActive: isActive,
    );
  }

  /// Atualiza as configurações na sessão.
  DeviceSession updateConfiguration(ConfigurationSnapshot snapshot) {
    final updatedSnapshots =
        List<ConfigurationSnapshot>.from(configurationSnapshots)..add(snapshot);
    return DeviceSession(
      id: id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: normalizedState,
      measurements: measurements,
      rawData: rawData,
      responses: responses,
      configurationSnapshots: updatedSnapshots,
      diagnostics: diagnostics,
      createdAt: createdAt,
      lastUpdate: DateTime.now(),
      isActive: isActive,
    );
  }

  /// Define o estado ativo da sessão.
  DeviceSession setActive(bool active) {
    return DeviceSession(
      id: id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: normalizedState,
      measurements: measurements,
      rawData: rawData,
      responses: responses,
      configurationSnapshots: configurationSnapshots,
      diagnostics: diagnostics,
      createdAt: createdAt,
      lastUpdate: DateTime.now(),
      isActive: active,
    );
  }

  /// Atualiza o estado de diagnóstico.
  DeviceSession updateDiagnostics(List<DiagnosticFinding> newFindings) {
    final updatedDiagnostics = List<DiagnosticFinding>.from(diagnostics)
      ..addAll(newFindings);
    return DeviceSession(
      id: id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: normalizedState,
      measurements: measurements,
      rawData: rawData,
      responses: responses,
      configurationSnapshots: configurationSnapshots,
      diagnostics: updatedDiagnostics,
      createdAt: createdAt,
      lastUpdate: DateTime.now(),
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        identity,
        capabilities,
        normalizedState,
        measurements,
        rawData,
        responses,
        configurationSnapshots,
        diagnostics,
        createdAt,
        lastUpdate,
        isActive,
      ];

  /// Mescla medições novas em medições existentes.
  List<NormalizedMeasurement> _mergeMeasurements(
    List<NormalizedMeasurement> existing,
    List<NormalizedMeasurement> incoming,
  ) {
    final merged = List<NormalizedMeasurement>.from(existing);
    final incomingMap = {for (final m in incoming) m.key: m};
    for (final key in incomingMap.keys) {
      final incoming = incomingMap[key]!;
      final index = existing.indexWhere((m) => m.key == key);
      if (index >= 0) {
        merged[index] = incoming;
      } else {
        merged.add(incoming);
      }
    }
    return merged;
  }

  /// Mescla dados brutos.
  Map<String, dynamic> _mergeRawData(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    merged.addAll(incoming);
    return merged;
  }
}

/// Snapshot de um estado de configuração.
class ConfigurationSnapshot extends Equatable {
  final DateTime timestamp;
  final Map<String, dynamic> values;

  const ConfigurationSnapshot({
    required this.timestamp,
    required this.values,
  });

  @override
  List<Object?> get props => [timestamp, values];
}
