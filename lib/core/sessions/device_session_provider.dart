import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../drivers/driver_contracts.dart';
import '../drivers/implementations.dart';
import 'device_session.dart';
import 'session_persistence.dart';

final deviceSessionProvider = StateNotifierProvider.family<
    DeviceSessionNotifier, AsyncValue<DeviceSession>, String>(
  (ref, deviceId) {
    final persistenceService = ref.watch(sessionPersistenceServiceProvider);
    return DeviceSessionNotifier(deviceId, persistenceService, ref);
  },
);

class DeviceSessionNotifier extends StateNotifier<AsyncValue<DeviceSession>> {
  final String _deviceId;
  final SessionPersistenceService _persistenceService;
  final Ref _ref;
  StreamSubscription? _transportSubscription;

  DeviceSessionNotifier(this._deviceId, this._persistenceService, this._ref)
      : super(const AsyncValue.loading()) {
    _loadOrCreateSession();
  }

  Future<void> _loadOrCreateSession() async {
    try {
      var session = await _persistenceService.loadSession(_deviceId);
      if (session == null) {
        final identity = DeviceIdentity(
          id: _deviceId,
          manufacturer: Manufacturer.unknown,
          confidence: 0,
        );
        const capabilities = DeviceCapabilities(
          can: false,
          ble: false,
          hasCan: false,
          obd2: false,
          cellular: false,
          gps: false,
        );
        final normalizedState = NormalizedDeviceState(
          lastUpdate: DateTime.now(),
          connectionStatus: 'connected',
          vehicle: const VehicleState(
              ignition: false, movement: false, speedKph: 0, odometerKm: 0),
          power: const PowerState(
              externalVoltage: 0,
              internalVoltage: 0,
              batteryPercent: 0,
              charging: false),
          network: const NetworkState(
              status: 'connected',
              operator: '',
              signalLevel: 0,
              technology: '',
              roaming: false),
          position: PositionState(
            latitude: 0,
            longitude: 0,
            altitude: 0,
            heading: 0,
            satellites: 0,
            hdop: 0,
            timestamp: DateTime.now(),
          ),
          measurements: const {},
        );
        session = DeviceSession(
          id: _deviceId,
          identity: identity,
          capabilities: capabilities,
          normalizedState: normalizedState,
          measurements: const [],
          rawData: const {},
          responses: const [],
          configurationSnapshots: const [],
          diagnostics: const [],
          createdAt: DateTime.now(),
          lastUpdate: DateTime.now(),
          isActive: true,
        );
        await _persistenceService.createSession(session);
      }
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSession(DeviceSession newSession) async {
    state = AsyncValue.data(newSession);
    await _persistenceService.updateSession(newSession);
  }

  Future<void> processRawInput(RawInput input) async {
    final current = state.value;
    if (current == null) return;

    // 1. Detect manufacturer & identity if unknown
    ManufacturerDriver driver = _ref.read(deviceDriverProvider(_deviceId));
    final detection = driver.detect(input);

    DeviceIdentity identity = current.identity;
    if (identity.manufacturer == Manufacturer.unknown &&
        detection.confidence > 50) {
      final identified = driver.identify(input);
      identity = DeviceIdentity(
        id: current.id,
        manufacturer: detection.manufacturer,
        model: identified.model,
        esn: identified.esn,
        imei: identified.imei,
        firmware: identified.firmware,
        protocol: identified.protocol,
        confidence: detection.confidence,
        firstSeenAt: current.identity.firstSeenAt ?? input.timestamp,
      );
    }
    if (identity.manufacturer == Manufacturer.suntech) {
      driver = SuntechDriver();
    } else if (identity.manufacturer == Manufacturer.teltonika) {
      driver = TeltonikaDriver();
    }

    final context = DeviceContext(
      deviceId: current.id,
      identity: identity,
      capabilities: driver.capabilities(DeviceContext(
          deviceId: current.id,
          identity: identity,
          capabilities: current.capabilities)),
    );

    // 2. Capabilities
    final capabilities = driver.capabilities(context);

    // 3. Normalize measurements
    final measurements = driver.normalize(input, context);

    // 4. Update normalized state fields
    bool ignition = current.normalizedState.vehicle.ignition;
    bool movement = current.normalizedState.vehicle.movement;
    int speedKph = current.normalizedState.vehicle.speedKph;
    int odometerKm = current.normalizedState.vehicle.odometerKm;
    double extVolt = current.normalizedState.power.externalVoltage;
    int battery = current.normalizedState.power.batteryPercent;
    double lat = current.normalizedState.position.latitude;
    double lon = current.normalizedState.position.longitude;

    for (final m in measurements) {
      if (m.key == 'ignition') ignition = m.value == true;
      if (m.key == 'speed') speedKph = (m.value as num?)?.toInt() ?? speedKph;
      if (m.key == 'odometer') {
        odometerKm = (m.value as num?)?.toInt() ?? odometerKm;
      }
      if (m.key == 'latitude') lat = (m.value as num?)?.toDouble() ?? lat;
      if (m.key == 'longitude') lon = (m.value as num?)?.toDouble() ?? lon;
      if (m.key == 'rpm') movement = true;
    }

    final newState = NormalizedDeviceState(
      lastUpdate: input.timestamp,
      connectionStatus: 'receiving',
      lastPacketAt: input.timestamp,
      vehicle: VehicleState(
        ignition: ignition,
        movement: movement || speedKph > 0,
        speedKph: speedKph,
        odometerKm: odometerKm,
      ),
      power: PowerState(
        externalVoltage: extVolt,
        internalVoltage: 12.0,
        batteryPercent: battery > 0 ? battery : 100,
        charging: extVolt > 13.0,
      ),
      network: current.normalizedState.network,
      position: PositionState(
        latitude: lat,
        longitude: lon,
        altitude: 0,
        heading: 0,
        satellites: 8,
        hdop: 0,
        timestamp: DateTime.now(),
      ),
      measurements: {
        for (final m in current.measurements) m.key: m.value,
        for (final m in measurements) m.key: m.value,
      },
    );

    // 5. Preserve raw data chunks (even unrecognized)
    final rawKey = 'chunk_${DateTime.now().millisecondsSinceEpoch}';
    final rawDataPayload = <String, dynamic>{
      rawKey: {
        'timestamp': input.timestamp.toIso8601String(),
        'ascii': input.asciiLine,
        'hex': input.hex,
        'portId': input.portId,
      }
    };

    final updatedSession = DeviceSession(
      id: current.id,
      identity: identity,
      capabilities: capabilities,
      normalizedState: newState,
      measurements: _mergeMeasurements(current.measurements, measurements),
      rawData: _mergeRawData(current.rawData, rawDataPayload),
      responses: current.responses,
      configurationSnapshots: current.configurationSnapshots,
      diagnostics: current.diagnostics,
      createdAt: current.createdAt,
      lastUpdate: input.timestamp,
      isActive: true,
    );

    await updateSession(updatedSession);
  }

  List<NormalizedMeasurement> _mergeMeasurements(
    List<NormalizedMeasurement> existing,
    List<NormalizedMeasurement> incoming,
  ) {
    final merged = List<NormalizedMeasurement>.from(existing);
    final incomingMap = {for (final m in incoming) m.key: m};
    for (final key in incomingMap.keys) {
      final inc = incomingMap[key]!;
      final index = merged.indexWhere((m) => m.key == key);
      if (index >= 0) {
        merged[index] = inc;
      } else {
        merged.add(inc);
      }
    }
    return merged;
  }

  Map<String, dynamic> _mergeRawData(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    merged.addAll(incoming);
    return merged;
  }
}
