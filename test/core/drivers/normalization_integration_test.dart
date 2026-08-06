import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_studio/core/drivers/driver_contracts.dart';
import 'package:tracker_studio/core/drivers/implementations.dart';
import 'package:tracker_studio/core/sessions/device_session.dart';
import 'package:tracker_studio/core/sessions/device_session_provider.dart';
import 'package:tracker_studio/core/sessions/session_persistence.dart';

/// Memory-only persistence service for testing — no SQLite required.
class MemorySessionPersistenceService extends SessionPersistenceService {
  final Map<String, DeviceSession> store = {};

  MemorySessionPersistenceService() : super(_NoopRepository());

  @override
  Future<void> createSession(DeviceSession session) async {
    store[session.id] = session;
  }

  @override
  Future<DeviceSession?> loadSession(String sessionId) async =>
      store[sessionId];

  @override
  Future<void> updateSession(DeviceSession session) async {
    store[session.id] = session;
  }
}

class _NoopRepository implements SessionRepository {
  @override
  Future<void> saveSession(DeviceSession session) async {}

  @override
  Future<DeviceSession?> loadSession(String id) async => null;

  @override
  Future<List<DeviceSession>> listSessionsByDevice(String deviceId) async =>
      [];

  @override
  Future<List<DeviceSession>> listAllSessions() async => [];
}

/// Helper: creates a fresh DeviceSession with a Teltonika identity.
DeviceSession _teltonikaSession(String id) {
  final now = DateTime(2025, 1, 1, 10, 0, 0);
  return DeviceSession(
    id: id,
    identity: const DeviceIdentity(
      id: 'test-dev-1',
      manufacturer: Manufacturer.teltonika,
      model: 'FMB140',
      confidence: 90,
    ),
    capabilities: const DeviceCapabilities(
      can: true,
      ble: false,
      hasCan: true,
      obd2: true,
      cellular: true,
      gps: true,
      sensors: [],
      ioTypes: [],
    ),
    normalizedState: NormalizedDeviceState(
      lastUpdate: now,
      connectionStatus: 'connected',
      vehicle: const VehicleState(
        ignition: false,
        movement: false,
        speedKph: 0,
        odometerKm: 0,
      ),
      power: const PowerState(
        externalVoltage: 0,
        internalVoltage: 0,
        batteryPercent: 0,
        charging: false,
      ),
      network: const NetworkState(
        status: 'unknown',
        operator: '',
        signalLevel: 0,
        technology: '',
        roaming: false,
      ),
      position: PositionState(
        latitude: 0,
        longitude: 0,
        altitude: 0,
        heading: 0,
        satellites: 0,
        hdop: 0,
        timestamp: now,
      ),
      measurements: const {},
    ),
    measurements: const [],
    rawData: const {},
    responses: const [],
    configurationSnapshots: const [],
    diagnostics: const [],
    createdAt: now,
    lastUpdate: now,
    isActive: true,
  );
}

/// Helper: creates a fresh DeviceSession with a Suntech identity.
DeviceSession _suntechSession(String id) {
  final session = _teltonikaSession(id);
  return DeviceSession(
    id: session.id,
    identity: const DeviceIdentity(
      id: 'test-dev-1',
      manufacturer: Manufacturer.suntech,
      model: 'ST8210',
      confidence: 90,
    ),
    capabilities: const DeviceCapabilities(
      can: false,
      ble: false,
      hasCan: false,
      obd2: false,
      cellular: true,
      gps: true,
      sensors: [],
      ioTypes: [],
    ),
    normalizedState: session.normalizedState,
    measurements: const [],
    rawData: const {},
    responses: const [],
    configurationSnapshots: const [],
    diagnostics: const [],
    createdAt: session.createdAt,
    lastUpdate: session.lastUpdate,
    isActive: true,
  );
}

void main() {
  group('NormalizedMeasurement key contract — Teltonika driver', () {
    test('produces canonical keys from ASCII GPS + IO line', () {
      final driver = TeltonikaDriver();
      final input = RawInput(
        portId: 'COM1',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'AVL ID: 12345678 Lat: -23.550520 Lon: -46.633309 '
            'GPS Speed: 50 Sat: 10 HDOP: 1.5 Alt: 935 Heading: 27 '
            'IO ID[ 3]: 1 IO ID[ 66]: 13800 IO ID[ 67]: 55',
        lineTerminator: '\n',
        baudRate: 115200,
      );
      final metrics = driver.normalize(input, const DeviceContext(
        deviceId: '1',
        identity: DeviceIdentity(
            id: '1', manufacturer: Manufacturer.teltonika, confidence: 100),
        capabilities: DeviceCapabilities(
            can: true,
            ble: false,
            hasCan: true,
            obd2: true,
            cellular: true,
            gps: true,
            sensors: [],
            ioTypes: []),
      ));

      final keys = metrics.map((m) => m.key).toSet();
      expect(keys, contains('ignition'));
      expect(keys, contains('speedKph'));
      expect(keys, contains('latitude'));
      expect(keys, contains('longitude'));
      expect(keys, contains('satellites'));
      expect(keys, contains('altitude'));
      expect(keys, contains('heading'));
      expect(keys, contains('hdop'));
      expect(keys, contains('externalVoltage'));
      expect(keys, contains('internalVoltage'));

      // Verify actual values
      final ign = metrics.firstWhere((m) => m.key == 'ignition');
      expect(ign.value, isTrue);

      final speed = metrics.firstWhere((m) => m.key == 'speedKph');
      expect(speed.value, 50);

      final lat = metrics.firstWhere((m) => m.key == 'latitude');
      expect(lat.value, closeTo(-23.55, 0.01));

      final lon = metrics.firstWhere((m) => m.key == 'longitude');
      expect(lon.value, closeTo(-46.63, 0.01));

      final extV = metrics.firstWhere((m) => m.key == 'externalVoltage');
      expect(extV.value, closeTo(13.8, 0.01));

      final intV = metrics.firstWhere((m) => m.key == 'internalVoltage');
      expect(intV.value, closeTo(0.055, 0.001));
    });

    test('produces speedKph (not speed) for backward compatibility', () {
      final driver = TeltonikaDriver();
      final input = RawInput(
        portId: 'COM1',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'Speed=85',
        lineTerminator: '\n',
        baudRate: 115200,
      );
      final metrics = driver.normalize(input, const DeviceContext(
        deviceId: '1',
        identity: DeviceIdentity(
            id: '1', manufacturer: Manufacturer.teltonika, confidence: 100),
        capabilities: DeviceCapabilities(
            can: true,
            ble: false,
            hasCan: true,
            obd2: true,
            cellular: true,
            gps: true,
            sensors: [],
            ioTypes: []),
      ));

      final speedList = metrics.where((m) => m.key == 'speedKph').toList();
      expect(speedList, isNotEmpty,
          reason: 'speedKph canonical key must be produced');
      expect(speedList.first.value, 85);
    });
  });

  group('NormalizedMeasurement key contract — Suntech driver', () {
    test('produces canonical keys from STT structured response', () {
      final driver = SuntechDriver();
      // RES;STT;ESN;03;FW;DATE;TIME;CELL;LAT;LON;SPEED;COURSE;
      // SATS;FIX;IN_MASK;OUT_MASK;IGN;...;MAIN_VOLT;BACKUP_VOLT;...;NET_CODE;GPRS
      final input = RawInput(
        portId: 'COM2',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'RES;STT;12345678;03;055;20231019;145322;00115b;'
            '-23.550520;-46.633309;50;27;10;1;1100;0000;1;'
            '0;0;0;13.8;3.7;0;0;0;0;0;001;10;',
        lineTerminator: '\n',
        baudRate: 9600,
      );
      final metrics = driver.normalize(input, const DeviceContext(
        deviceId: '2',
        identity: DeviceIdentity(
            id: '2', manufacturer: Manufacturer.suntech, confidence: 100),
        capabilities: DeviceCapabilities(
            can: false,
            ble: false,
            hasCan: false,
            obd2: false,
            cellular: true,
            gps: true,
            sensors: [],
            ioTypes: []),
      ));

      final keys = metrics.map((m) => m.key).toSet();
      expect(keys, contains('ignition'));
      expect(keys, contains('speedKph'));
      expect(keys, contains('latitude'));
      expect(keys, contains('longitude'));
      expect(keys, contains('satellites'));
      expect(keys, contains('heading'));
      expect(keys, contains('externalVoltage'));
      expect(keys, contains('internalVoltage'));
      expect(keys, contains('networkStatus'));

      final ign = metrics.firstWhere((m) => m.key == 'ignition');
      expect(ign.value, isTrue);

      final speed = metrics.firstWhere((m) => m.key == 'speedKph');
      expect(speed.value, 50);

      final lat = metrics.firstWhere((m) => m.key == 'latitude');
      expect(lat.value, closeTo(-23.55, 0.01));

      final extV = metrics.firstWhere((m) => m.key == 'externalVoltage');
      expect(extV.value, closeTo(13.8, 0.01));
    });

    test('produces canonical keys from simple AT line', () {
      final driver = SuntechDriver();
      final input = RawInput(
        portId: 'COM2',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'IGNO=1 SPEED=60 NET=1 PWR=13.8 BATT=85 MOV=1',
        lineTerminator: '\r\n',
        baudRate: 9600,
      );
      final metrics = driver.normalize(input, const DeviceContext(
        deviceId: '2',
        identity: DeviceIdentity(
            id: '2', manufacturer: Manufacturer.suntech, confidence: 100),
        capabilities: DeviceCapabilities(
            can: false,
            ble: false,
            hasCan: false,
            obd2: false,
            cellular: true,
            gps: true,
            sensors: [],
            ioTypes: []),
      ));

      final keys = metrics.map((m) => m.key).toSet();
      expect(keys, contains('ignition'));
      expect(keys, contains('speedKph'));
      expect(keys, contains('networkStatus'));
      expect(keys, contains('externalVoltage'));
      expect(keys, contains('batteryPercent'));
      expect(keys, contains('movement'));
    });
  });

  group('End-to-end: processRawInput populates NormalizedDeviceState', () {
    test('Teltonika: connects and fills ignition, speed, position, network '
        'on all cards', () async {
      final persistence = MemorySessionPersistenceService();
      persistence.store['test-dev-1'] = _teltonikaSession('test-dev-1');

      final container = ProviderContainer(overrides: [
        sessionPersistenceServiceProvider.overrideWithValue(persistence),
      ]);

      final notifier = container.read(deviceSessionProvider('test-dev-1').notifier);

      // Wait for async load
      await Future.delayed(const Duration(milliseconds: 100));

      final raw = RawInput(
        portId: 'COM1',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'AVL ID: 12345678 Lat: -23.550520 Lon: -46.633309 '
            'GPS Speed: 50 Sat: 10 HDOP: 1.5 Alt: 935 Heading: 27 '
            'IO ID[ 3]: 1 IO ID[ 66]: 13800 IO ID[ 67]: 55',
        lineTerminator: '\n',
        baudRate: 115200,
      );

      await notifier.processRawInput(raw);

      final session = await persistence.loadSession('test-dev-1');
      final state = session!.normalizedState;

      expect(state.vehicle.ignition, isTrue);
      expect(state.vehicle.movement, isTrue);
      expect(state.vehicle.speedKph, 50);
      expect(state.position.latitude, closeTo(-23.55, 0.01));
      expect(state.position.longitude, closeTo(-46.63, 0.01));
      expect(state.position.altitude, 935);
      expect(state.position.satellites, 10);
      expect(state.position.hdop, closeTo(1.5, 0.01));
      expect(state.position.heading, 27);
      expect(state.power.externalVoltage, closeTo(13.8, 0.01));
      expect(state.power.internalVoltage, closeTo(0.055, 0.001));
      expect(state.power.charging, isTrue);

      container.dispose();
    });

    test('Suntech: STT response fills ignition, speed, position, network, '
        'power on all cards', () async {
      final persistence = MemorySessionPersistenceService();
      persistence.store['test-dev-2'] = _suntechSession('test-dev-2');

      final container = ProviderContainer(overrides: [
        sessionPersistenceServiceProvider.overrideWithValue(persistence),
      ]);

      final notifier = container.read(deviceSessionProvider('test-dev-2').notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      final raw = RawInput(
        portId: 'COM2',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'RES;STT;12345678;03;055;20231019;145322;00115b;'
            '-23.550520;-46.633309;50;27;10;1;1100;0000;1;'
            '0;0;0;13.8;3.7;0;0;0;0;0;001;10;',
        lineTerminator: '\r\n',
        baudRate: 9600,
      );

      await notifier.processRawInput(raw);

      final session = await persistence.loadSession('test-dev-2');
      final state = session!.normalizedState;

      expect(state.vehicle.ignition, isTrue);
      expect(state.vehicle.speedKph, 50);
      expect(state.position.latitude, closeTo(-23.55, 0.01));
      expect(state.position.longitude, closeTo(-46.63, 0.01));
      expect(state.position.satellites, 10);
      expect(state.position.heading, 27);
      expect(state.power.externalVoltage, closeTo(13.8, 0.01));
      expect(state.power.internalVoltage, closeTo(3.7, 0.01));
      expect(state.power.charging, isTrue);
      expect(state.network.status, 'offline');

      container.dispose();
    });

    test('Suntech: simple AT line fills ignition, speed, network, power',
        () async {
      final persistence = MemorySessionPersistenceService();
      persistence.store['test-dev-3'] = _suntechSession('test-dev-3');

      final container = ProviderContainer(overrides: [
        sessionPersistenceServiceProvider.overrideWithValue(persistence),
      ]);

      final notifier = container.read(deviceSessionProvider('test-dev-3').notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      final raw = RawInput(
        portId: 'COM2',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'IGNO=1 SPEED=60 MOV=1 NET=1 PWR=13.8 BATT=85',
        lineTerminator: '\r\n',
        baudRate: 9600,
      );

      await notifier.processRawInput(raw);

      final session = await persistence.loadSession('test-dev-3');
      final state = session!.normalizedState;

      expect(state.vehicle.ignition, isTrue);
      expect(state.vehicle.speedKph, 60);
      expect(state.vehicle.movement, isTrue);
      expect(state.power.externalVoltage, closeTo(13.8, 0.01));
      expect(state.power.batteryPercent, 85);
      expect(state.network.status, 'online');

      container.dispose();
    });
  });

  group('Shared normalized state — both manufacturers populate same fields', () {
    test('Teltonika and Suntech both populate vehicle.ignition, '
        'vehicle.speedKph, position.latitude/longitude, power.externalVoltage',
        () {
      // Teltonika
      final tDriver = TeltonikaDriver();
      final tInput = RawInput(
        portId: 'COM1',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'IGN=1 Speed=50 IO ID[ 66]: 12000',
        lineTerminator: '\n',
        baudRate: 115200,
      );
      final tMetrics = tDriver.normalize(tInput, const DeviceContext(
        deviceId: '1',
        identity: DeviceIdentity(
            id: '1', manufacturer: Manufacturer.teltonika, confidence: 100),
        capabilities: DeviceCapabilities(
            can: true, ble: false, hasCan: true, obd2: true,
            cellular: true, gps: true, sensors: [], ioTypes: []),
      ));

      // Suntech
      final sDriver = SuntechDriver();
      final sInput = RawInput(
        portId: 'COM2',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        asciiLine: 'IGNO=1 SPEED=50 PWR=12.0',
        lineTerminator: '\r\n',
        baudRate: 9600,
      );
      final sMetrics = sDriver.normalize(sInput, const DeviceContext(
        deviceId: '2',
        identity: DeviceIdentity(
            id: '2', manufacturer: Manufacturer.suntech, confidence: 100),
        capabilities: DeviceCapabilities(
            can: false, ble: false, hasCan: false, obd2: false,
            cellular: true, gps: true, sensors: [], ioTypes: []),
      ));

      final tKeys = tMetrics.map((m) => m.key).toSet();
      final sKeys = sMetrics.map((m) => m.key).toSet();

      // Both must produce these canonical keys
      for (final key in ['ignition', 'speedKph', 'externalVoltage']) {
        expect(tKeys, contains(key),
            reason: 'Teltonika must produce canonical key: $key');
        expect(sKeys, contains(key),
            reason: 'Suntech must produce canonical key: $key');
      }
    });
  });
}
