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

    // 4. Update normalized state fields from canonical measurement keys.
    //    Drivers produce NormalizedMeasurement with canonical keys; this
    //    mapper translates them into the structured NormalizedDeviceState
    //    sub-objects so the front-end cards are populated regardless of
    //    which manufacturer was detected.
    bool ignition = current.normalizedState.vehicle.ignition;
    bool movement = current.normalizedState.vehicle.movement;
    int speedKph = current.normalizedState.vehicle.speedKph;
    int odometerKm = current.normalizedState.vehicle.odometerKm;
    double extVolt = current.normalizedState.power.externalVoltage;
    double intVolt = current.normalizedState.power.internalVoltage;
    int battery = current.normalizedState.power.batteryPercent;
    bool charging = current.normalizedState.power.charging;
    double lat = current.normalizedState.position.latitude;
    double lon = current.normalizedState.position.longitude;
    double altitude = current.normalizedState.position.altitude;
    double heading = current.normalizedState.position.heading;
    int satellites = current.normalizedState.position.satellites;
    double hdop = current.normalizedState.position.hdop;
    String networkStatus = current.normalizedState.network.status;
    String operatorName = current.normalizedState.network.operator;
    int signalLevel = current.normalizedState.network.signalLevel;
    String technology = current.normalizedState.network.technology;
    bool roaming = current.normalizedState.network.roaming;

    for (final m in measurements) {
      switch (m.key) {
        case 'ignition':
          ignition = m.value == true;
        case 'movement':
          movement = m.value == true;
        case 'speedKph':
          speedKph = (m.value as num?)?.toInt() ?? speedKph;
        case 'speed':
          speedKph = (m.value as num?)?.toInt() ?? speedKph;
        case 'odometerKm':
          odometerKm = (m.value as num?)?.toInt() ?? odometerKm;
        case 'odometer':
          odometerKm = (m.value as num?)?.toInt() ?? odometerKm;
        case 'latitude':
          lat = (m.value as num?)?.toDouble() ?? lat;
        case 'longitude':
          lon = (m.value as num?)?.toDouble() ?? lon;
        case 'altitude':
          altitude = (m.value as num?)?.toDouble() ?? altitude;
        case 'heading':
          heading = (m.value as num?)?.toDouble() ?? heading;
        case 'satellites':
          satellites = (m.value as num?)?.toInt() ?? satellites;
        case 'sats':
          satellites = (m.value as num?)?.toInt() ?? satellites;
        case 'hdop':
          hdop = (m.value as num?)?.toDouble() ?? hdop;
        case 'externalVoltage':
          extVolt = (m.value as num?)?.toDouble() ?? extVolt;
        case 'power':
          extVolt = (m.value as num?)?.toDouble() ?? extVolt;
        case 'internalVoltage':
          intVolt = (m.value as num?)?.toDouble() ?? intVolt;
        case 'batteryPercent':
          final pct = (m.value as num?)?.toInt();
          if (pct != null && pct >= 0) battery = pct;
        case 'battery':
          final pct = (m.value as num?)?.toInt();
          if (pct != null && pct >= 0) battery = pct;
        case 'charging':
          charging = m.value == true;
        case 'networkStatus':
          networkStatus = m.value?.toString() ?? networkStatus;
        case 'network':
          networkStatus = m.value?.toString() ?? networkStatus;
        case 'operatorName':
          operatorName = m.value?.toString() ?? operatorName;
        case 'signalLevel':
          signalLevel = (m.value as num?)?.toInt() ?? signalLevel;
        case 'technology':
          technology = m.value?.toString() ?? technology;
        case 'roaming':
          roaming = m.value == true;
        case 'rpm':
          movement = true;
      }
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
        internalVoltage: intVolt,
        batteryPercent: battery > 0 ? battery : 100,
        charging: charging || extVolt > 13.0,
      ),
      network: NetworkState(
        status: networkStatus,
        operator: operatorName,
        signalLevel: signalLevel,
        technology: technology,
        roaming: roaming,
      ),
      position: PositionState(
        latitude: lat,
        longitude: lon,
        altitude: altitude,
        heading: heading,
        satellites: satellites,
        hdop: hdop,
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
