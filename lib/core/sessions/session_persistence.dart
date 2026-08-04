import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../drivers/driver_contracts.dart';
import 'device_session.dart';
import '../../data/database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SessionRepository(db);
});

final sessionPersistenceServiceProvider = Provider<SessionPersistenceService>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return SessionPersistenceService(repo);
});

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  Future<void> saveSession(DeviceSession session) async {
    final companion = DeviceSessionsTableCompanion(
      id: Value(session.id),
      manufacturer: Value(session.identity.manufacturer.name),
      identityJson: Value(jsonEncode(_serializeIdentity(session.identity))),
      capabilitiesJson: Value(jsonEncode(_serializeCapabilities(session.capabilities))),
      normalizedStateJson: Value(jsonEncode(_serializeNormalizedState(session.normalizedState))),
      measurementsJson: Value(jsonEncode(session.measurements.map(_serializeMeasurement).toList())),
      rawDataJson: Value(jsonEncode(session.rawData)),
      responsesJson: Value(jsonEncode(session.responses.map(_serializeResponse).toList())),
      configurationSnapshotsJson: Value(jsonEncode(session.configurationSnapshots.map(_serializeConfigSnapshot).toList())),
      diagnosticsJson: Value(jsonEncode(session.diagnostics.map(_serializeDiagnostic).toList())),
      createdAt: Value(session.createdAt),
      lastUpdate: Value(session.lastUpdate),
      isActive: Value(session.isActive),
    );

    await _db.into(_db.deviceSessionsTable).insertOnConflictUpdate(companion);
  }

  Future<DeviceSession?> loadSession(String id) async {
    final query = _db.select(_db.deviceSessionsTable)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _rowToSession(row);
  }

  Future<List<DeviceSession>> listSessionsByDevice(String deviceId) async {
    final query = _db.select(_db.deviceSessionsTable)
      ..where((t) => t.id.equals(deviceId) | t.identityJson.like('%$deviceId%'));
    final rows = await query.get();
    return rows.map(_rowToSession).toList();
  }

  Future<List<DeviceSession>> listAllSessions() async {
    final rows = await _db.select(_db.deviceSessionsTable).get();
    return rows.map(_rowToSession).toList();
  }

  DeviceSession _rowToSession(DeviceSessionsTableData row) {
    final identityMap = jsonDecode(row.identityJson) as Map<String, dynamic>;
    final capabilitiesMap = jsonDecode(row.capabilitiesJson) as Map<String, dynamic>;
    final stateMap = jsonDecode(row.normalizedStateJson) as Map<String, dynamic>;
    final measurementsList = jsonDecode(row.measurementsJson) as List<dynamic>;
    final rawDataMap = jsonDecode(row.rawDataJson) as Map<String, dynamic>;
    final responsesList = jsonDecode(row.responsesJson) as List<dynamic>;
    final configList = jsonDecode(row.configurationSnapshotsJson) as List<dynamic>;
    final diagnosticsList = jsonDecode(row.diagnosticsJson) as List<dynamic>;

    return DeviceSession(
      id: row.id,
      identity: _deserializeIdentity(identityMap),
      capabilities: _deserializeCapabilities(capabilitiesMap),
      normalizedState: _deserializeNormalizedState(stateMap),
      measurements: measurementsList.map((m) => _deserializeMeasurement(m as Map<String, dynamic>)).toList(),
      rawData: rawDataMap,
      responses: responsesList.map((r) => _deserializeResponse(r as Map<String, dynamic>)).toList(),
      configurationSnapshots: configList.map((c) => _deserializeConfigSnapshot(c as Map<String, dynamic>)).toList(),
      diagnostics: diagnosticsList.map((d) => _deserializeDiagnostic(d as Map<String, dynamic>)).toList(),
      createdAt: row.createdAt,
      lastUpdate: row.lastUpdate,
      isActive: row.isActive,
    );
  }

  Map<String, dynamic> _serializeIdentity(DeviceIdentity id) => {
        'id': id.id,
        'manufacturer': id.manufacturer.name,
        'model': id.model,
        'esn': id.esn,
        'imei': id.imei,
        'firmware': id.firmware,
        'hardwareVersion': id.hardwareVersion,
        'protocol': id.protocol,
        'codec': id.codec,
        'firstSeenAt': id.firstSeenAt?.toIso8601String(),
        'confidence': id.confidence,
      };

  DeviceIdentity _deserializeIdentity(Map<String, dynamic> map) => DeviceIdentity(
        id: map['id'] ?? '',
        manufacturer: Manufacturer.values.firstWhere(
          (m) => m.name == map['manufacturer'],
          orElse: () => Manufacturer.unknown,
        ),
        model: map['model'],
        esn: map['esn'],
        imei: map['imei'],
        firmware: map['firmware'],
        hardwareVersion: map['hardwareVersion'],
        protocol: map['protocol'],
        codec: map['codec'],
        firstSeenAt: map['firstSeenAt'] != null ? DateTime.parse(map['firstSeenAt']) : null,
        confidence: map['confidence'] ?? 0,
      );

  Map<String, dynamic> _serializeCapabilities(DeviceCapabilities cap) => {
        'can': cap.can,
        'ble': cap.ble,
        'hasCan': cap.hasCan,
        'obd2': cap.obd2,
        'cellular': cap.cellular,
        'gps': cap.gps,
        'sensors': cap.sensors,
        'ioTypes': cap.ioTypes,
      };

  DeviceCapabilities _deserializeCapabilities(Map<String, dynamic> map) => DeviceCapabilities(
        can: map['can'] ?? false,
        ble: map['ble'] ?? false,
        hasCan: map['hasCan'] ?? false,
        obd2: map['obd2'] ?? false,
        cellular: map['cellular'] ?? false,
        gps: map['gps'] ?? false,
        sensors: List<String>.from(map['sensors'] ?? []),
        ioTypes: List<String>.from(map['ioTypes'] ?? []),
      );

  Map<String, dynamic> _serializeNormalizedState(NormalizedDeviceState state) => {
        'lastUpdate': state.lastUpdate.toIso8601String(),
        'connectionStatus': state.connectionStatus,
        'lastPacketAt': state.lastPacketAt?.toIso8601String(),
        'networkInfo': state.networkInfo,
        'vehicle': {
          'ignition': state.vehicle.ignition,
          'movement': state.vehicle.movement,
          'speedKph': state.vehicle.speedKph,
          'odometerKm': state.vehicle.odometerKm,
          'ignitionOnAt': state.vehicle.ignitionOnAt?.toIso8601String(),
          'ignitionOffAt': state.vehicle.ignitionOffAt?.toIso8601String(),
        },
        'power': {
          'externalVoltage': state.power.externalVoltage,
          'internalVoltage': state.power.internalVoltage,
          'batteryPercent': state.power.batteryPercent,
          'charging': state.power.charging,
        },
        'network': {
          'status': state.network.status,
          'operator': state.network.operator,
          'signalLevel': state.network.signalLevel,
          'technology': state.network.technology,
          'roaming': state.network.roaming,
        },
        'position': {
          'latitude': state.position.latitude,
          'longitude': state.position.longitude,
          'altitude': state.position.altitude,
          'satellites': state.position.satellites,
          'heading': state.position.heading,
          'hdop': state.position.hdop,
        },
        'measurements': state.measurements,
      };

  NormalizedDeviceState _deserializeNormalizedState(Map<String, dynamic> map) {
    final v = map['vehicle'] ?? {};
    final p = map['power'] ?? {};
    final n = map['network'] ?? {};
    final pos = map['position'] ?? {};
    return NormalizedDeviceState(
      lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : DateTime.now(),
      connectionStatus: map['connectionStatus'] ?? 'disconnected',
      lastPacketAt: map['lastPacketAt'] != null ? DateTime.parse(map['lastPacketAt']) : null,
      networkInfo: map['networkInfo'],
      vehicle: VehicleState(
        ignition: v['ignition'] ?? false,
        movement: v['movement'] ?? false,
        speedKph: v['speedKph'] ?? 0,
        odometerKm: v['odometerKm'] ?? 0,
        ignitionOnAt: v['ignitionOnAt'] != null ? DateTime.parse(v['ignitionOnAt']) : null,
        ignitionOffAt: v['ignitionOffAt'] != null ? DateTime.parse(v['ignitionOffAt']) : null,
      ),
      power: PowerState(
        externalVoltage: (p['externalVoltage'] as num?)?.toDouble() ?? 0.0,
        internalVoltage: (p['internalVoltage'] as num?)?.toDouble() ?? 0.0,
        batteryPercent: p['batteryPercent'] ?? 0,
        charging: p['charging'] ?? false,
      ),
      network: NetworkState(
        status: n['status'] ?? 'unknown',
        operator: n['operator'] ?? 'unknown',
        signalLevel: n['signalLevel'] ?? 0,
        technology: n['technology'] ?? 'unknown',
        roaming: n['roaming'] ?? false,
      ),
      position: PositionState(
        latitude: (pos['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (pos['longitude'] as num?)?.toDouble() ?? 0.0,
        altitude: (pos['altitude'] as num?)?.toDouble() ?? 0.0,
        satellites: pos['satellites'] ?? 0,
        heading: (pos['heading'] as num?)?.toDouble() ?? 0.0,
        hdop: (pos['hdop'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      ),
      measurements: Map<String, dynamic>.from(map['measurements'] ?? {}),
    );
  }

  Map<String, dynamic> _serializeMeasurement(NormalizedMeasurement m) => {
        'key': m.key,
        'rawKey': m.rawKey,
        'category': m.category,
        'name': m.name,
        'unit': m.unit,
        'multiplier': m.multiplier,
        'value': m.value,
        'timestamp': m.timestamp.toIso8601String(),
        'metadata': m.metadata,
      };

  NormalizedMeasurement _deserializeMeasurement(Map<String, dynamic> map) => NormalizedMeasurement(
        key: map['key'] ?? '',
        rawKey: map['rawKey'] ?? '',
        category: map['category'] ?? '',
        name: map['name'] ?? '',
        unit: map['unit'],
        multiplier: map['multiplier'],
        value: map['value'],
        timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
        metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      );

  Map<String, dynamic> _serializeResponse(CommandTransaction r) => {
        'id': r.id,
        'command': r.command,
        'requestSentAt': r.requestSentAt.toIso8601String(),
        'responseReceivedAt': r.responseReceivedAt?.toIso8601String(),
        'responseRaw': r.responseRaw,
        'success': r.success,
      };

  CommandTransaction _deserializeResponse(Map<String, dynamic> map) => CommandTransaction(
        id: map['id'] ?? '',
        command: map['command'] ?? '',
        requestSentAt: map['requestSentAt'] != null ? DateTime.parse(map['requestSentAt']) : DateTime.now(),
        responseReceivedAt: map['responseReceivedAt'] != null ? DateTime.parse(map['responseReceivedAt']) : null,
        responseRaw: map['responseRaw'],
        success: map['success'] ?? false,
        portId: map['portId'] ?? '',
        request: map['request'] ?? '',
        responseLines: List<String>.from(map['responseLines'] ?? []),
        parsedResponse: map['parsedResponse'] != null ? Map<String, dynamic>.from(map['parsedResponse']) : null,
        error: map['error'],
        transport: CommandTransport.values.firstWhere(
          (t) => t.name == map['transport'],
          orElse: () => CommandTransport.usb,
        ),
      );

  Map<String, dynamic> _serializeConfigSnapshot(ConfigurationSnapshot c) => {
        'timestamp': c.timestamp.toIso8601String(),
        'values': c.values,
      };

  ConfigurationSnapshot _deserializeConfigSnapshot(Map<String, dynamic> map) => ConfigurationSnapshot(
        timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
        values: Map<String, dynamic>.from(map['values'] ?? {}),
      );

  Map<String, dynamic> _serializeDiagnostic(DiagnosticFinding d) => {
        'id': d.id,
        'code': d.code,
        'severity': d.severity.name,
        'title': d.title,
        'message': d.message,
      };

  DiagnosticFinding _deserializeDiagnostic(Map<String, dynamic> map) => DiagnosticFinding(
        id: map['id'] ?? '',
        code: map['code'] ?? '',
        severity: RiskLevel.values.firstWhere(
          (s) => s.name == map['severity'],
          orElse: () => RiskLevel.readOnly,
        ),
        title: map['title'] ?? '',
        message: map['message'] ?? '',
      );
}

class SessionPersistenceService {
  final SessionRepository _repository;

  SessionPersistenceService(this._repository);

  Future<void> createSession(DeviceSession session) async {
    await _repository.saveSession(session);
  }

  Future<void> updateSession(DeviceSession session) async {
    await _repository.saveSession(session);
  }

  Future<void> appendRawData(String sessionId, String key, dynamic value) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) return;
    final updatedRaw = Map<String, dynamic>.from(session.rawData)..[key] = value;
    final updated = DeviceSession(
      id: session.id,
      identity: session.identity,
      capabilities: session.capabilities,
      normalizedState: session.normalizedState,
      measurements: session.measurements,
      rawData: updatedRaw,
      responses: session.responses,
      configurationSnapshots: session.configurationSnapshots,
      diagnostics: session.diagnostics,
      createdAt: session.createdAt,
      lastUpdate: DateTime.now(),
      isActive: session.isActive,
    );
    await _repository.saveSession(updated);
  }

  Future<void> appendMeasurement(String sessionId, NormalizedMeasurement measurement) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) return;
    final updatedMeasurements = List<NormalizedMeasurement>.from(session.measurements);
    final index = updatedMeasurements.indexWhere((m) => m.key == measurement.key);
    if (index >= 0) {
      updatedMeasurements[index] = measurement;
    } else {
      updatedMeasurements.add(measurement);
    }
    final updated = session.updateState(
      newState: session.normalizedState,
      newMeasurements: updatedMeasurements,
      newRawData: session.rawData,
      timestamp: DateTime.now(),
    );
    await _repository.saveSession(updated);
  }

  Future<void> appendResponse(String sessionId, CommandTransaction response) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) return;
    final updated = session.addResponse(response);
    await _repository.saveSession(updated);
  }

  Future<void> saveConfigurationSnapshot(String sessionId, ConfigurationSnapshot snapshot) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) return;
    final updated = session.updateConfiguration(snapshot);
    await _repository.saveSession(updated);
  }

  Future<void> finishSession(String sessionId) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) return;
    final updated = session.setActive(false);
    await _repository.saveSession(updated);
  }

  Future<DeviceSession?> loadSession(String sessionId) async {
    return await _repository.loadSession(sessionId);
  }

  Future<List<DeviceSession>> listSessionsByDevice(String deviceId) async {
    return await _repository.listSessionsByDevice(deviceId);
  }

  Future<DeviceSession> reprocessSession(String sessionId) async {
    final session = await _repository.loadSession(sessionId);
    if (session == null) throw StateError('Sessão não encontrada para reprocessamento: $sessionId');
    // Reprocessar normalizações baseadas em rawData
    await _repository.saveSession(session);
    return session;
  }
}
