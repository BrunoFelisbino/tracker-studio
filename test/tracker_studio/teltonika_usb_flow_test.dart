import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/completed_service_repository.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/local_service_database.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/service_location_provider.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

List<String> _record({required int index, required List<String> ioLines}) {
  return [
    '[REC.GEN] Record Content:',
    'Priority: 1',
    'Lat: -23.550520',
    'Lon: -46.633309',
    'Alt: 780',
    'Angle: 45',
    'Speed: 0',
    'HDOP: 1.2',
    'SatInUse: 8',
    'GPS Fix: 1',
    'Event AVL ID: $index',
    ...ioLines,
    'Record Size: ${40 + ioLines.length}',
  ];
}

void main() {
  setUpAll(() {
    UceRegistry.initialize();
    TeltonikaDriver.registerAll();
  });

  test(
      'gate aceita linha Teltonika na primeira conexao e popula identidade',
      () async {
    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    controller.ingestRawLine(
        'AVL ID: 352093081540152 Lat: -23.550520 Lon: -46.633309');

    expect(controller.state.device.manufacturer, 'Teltonika');
    expect(controller.state.device.esn, '352093081540152');
    expect(controller.state.device.model, '-');
  });

  test('linha IMEI popula esn Teltonika', () async {
    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    controller.ingestRawLine('IMEI: 352093081540152');
    controller.ingestRawLine('FMB140 device connected');

    expect(controller.state.device.manufacturer, 'Teltonika');
    expect(controller.state.device.esn, '352093081540152');
    expect(controller.state.device.model, 'FMB140');
  });

  test('registro Teltonika popula posicao, voltagens e ignicao', () async {
    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    for (final line in [
      'IMEI: 352093081540152',
      'FMB140 device connected',
      ..._record(index: 0, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
        'IO ID[ 67]: 4100',
      ]),
    ]) {
      controller.ingestRawLine(line);
    }

    expect(controller.state.device.manufacturer, 'Teltonika');
    expect(controller.state.device.model, 'FMB140');
    expect(controller.state.device.esn, '352093081540152',
        reason: 'IMEI deve ser usado como ESN');

    expect(controller.state.localitel.hasValidCoordinates, isTrue);
    expect(controller.state.localitel.latitude, closeTo(-23.550520, 0.0001));
    expect(controller.state.localitel.longitude, closeTo(-46.633309, 0.0001));

    expect(controller.state.voltageHistory, isNotEmpty);
    expect(controller.state.voltageHistory.last.value, closeTo(12.0, 0.001));
    expect(controller.state.backupVoltageHistory, isNotEmpty);
    expect(
        controller.state.backupVoltageHistory.last.value, closeTo(4.1, 0.001));

    final ignition = controller.state.tests
        .where((t) => t.id == 'ignition')
        .firstOrNull;
    expect(ignition, isNotNull);
    expect(ignition!.status, TestStatus.passed);

    final ioGroup = controller.state.diagnostics
        .where((d) => d.title == 'I/O')
        .firstOrNull;
    expect(ioGroup, isNotNull);
    expect(ioGroup!.values['Ignicao'], 'ON');

    final gpsGroup = controller.state.diagnostics
        .where((d) => d.title == 'GPS')
        .firstOrNull;
    expect(gpsGroup, isNotNull);
    expect(gpsGroup!.values['Satelites'], '8');
    expect(gpsGroup.values['Latitude'], isNot('-'));
  });

  test('stream real do FMB140 ([timestamp]-[SECTION]) popula telemetria',
      () async {
    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    for (final line in [
      '[2026.08.01 02:01:06]-[READ_ASCII] IMEI: 352093081540152',
      '[2026.08.01 02:01:05]-[READ_ASCII] HW ver: FMB140',
      '[2026.08.01 02:01:33]-[GPS.API] Lat: -23.550520, Lon: -46.633309, '
          'Alt: 851.5',
      '[2026.08.01 02:01:35]-[GPS.API] Sat: 12',
      '[2026.08.01 02:01:37]-[GPS.API] FixStatus: 1',
      '[2026.08.01 02:01:47]-[LiPo] ExtV: 12368mV',
      '[2026.08.01 02:01:48]-[LiPo] BatV: 3953mV',
      '[2026.08.01 02:02:39]-[ACC] Ign: ON',
      '[2026.08.01 02:01:30]-[NETWORK] Socket Opened',
    ]) {
      controller.ingestRawLine(line);
    }

    expect(controller.state.device.manufacturer, 'Teltonika');
    expect(controller.state.device.esn, '352093081540152');
    expect(controller.state.device.model, 'FMB140');

    expect(controller.state.localitel.hasValidCoordinates, isTrue);
    expect(controller.state.localitel.latitude, closeTo(-23.550520, 0.0001));
    expect(controller.state.localitel.longitude, closeTo(-46.633309, 0.0001));

    expect(controller.state.voltageHistory, isNotEmpty);
    expect(controller.state.voltageHistory.last.value, closeTo(12.368, 0.001));
    expect(controller.state.backupVoltageHistory, isNotEmpty);
    expect(controller.state.backupVoltageHistory.last.value,
        closeTo(3.953, 0.001));

    final mainPower =
        controller.state.tests.where((t) => t.id == 'main_power').firstOrNull;
    expect(mainPower, isNotNull);
    expect(mainPower!.status, TestStatus.passed);

    final gps = controller.state.tests.where((t) => t.id == 'gps').firstOrNull;
    expect(gps, isNotNull);
    expect(gps!.status, TestStatus.passed);

    final ignition = controller.state.tests
        .where((t) => t.id == 'ignition')
        .firstOrNull;
    expect(ignition, isNotNull);
    expect(ignition!.status, TestStatus.passed);

    final network =
        controller.state.tests.where((t) => t.id == 'network').firstOrNull;
    expect(network, isNotNull);
    expect(network!.status, TestStatus.passed);
  });

  test('registro REC.GEN com prefixo de timestamp do aparelho e parseado',
      () async {
    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    for (final line in [
      '[2026.08.01 02:01:06]-[READ_ASCII] IMEI: 352093081540152',
      '[2026.08.01 02:01:05]-[READ_ASCII] HW ver: FMB140',
      '[2026.08.03 15:16:01]-[REC.GEN]\tRecord Content:',
      '[2026.08.03 15:16:01]-[READ_ASCII] \tLat: -23.550520',
      '[2026.08.03 15:16:01]-[READ_ASCII] \tLon: -46.633309',
      '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[  3]: 1',
      '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[ 66]: 12000',
      '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[ 67]: 4100',
      '[2026.08.03 15:16:01]-[READ_ASCII]  Record Size:\t142 Bytes',
    ]) {
      controller.ingestRawLine(line);
    }

    expect(controller.state.device.manufacturer, 'Teltonika');
    expect(controller.state.device.model, 'FMB140');
    expect(controller.state.device.esn, '352093081540152');
    expect(controller.state.localitel.hasValidCoordinates, isTrue);
    expect(controller.state.localitel.latitude, closeTo(-23.550520, 0.0001));
    expect(controller.state.localitel.longitude, closeTo(-46.633309, 0.0001));
    expect(controller.state.voltageHistory.last.value, closeTo(12.0, 0.001));
    expect(controller.state.backupVoltageHistory.last.value,
        closeTo(4.1, 0.001));
  });

  test('linha fora do protocolo continua sendo descartada', () async {    final controller = await _controller(_RecordingTransport());
    addTearDown(controller.dispose);

    controller.ingestRawLine('GARBAGE-NOT-A-PROTOCOL-LINE');
    controller.ingestRawLine('hello world');

    expect(controller.state.device.manufacturer, '-');
    expect(controller.state.device.esn, '-');
    expect(controller.state.localitel.hasValidCoordinates, isFalse);
  });

  test('lock/unlock Teltonika dispara comando correto no UCE registry',
      () async {
    final transport = _RecordingTransport();
    final controller = await _controller(transport);
    addTearDown(controller.dispose);

    await transport.connect(const SerialConnectionRequest(
      commandPortPath: '/dev/ttyUSB0',
      baudRate: 115200,
      lineTerminator: '\r',
    ));

    await controller.teltonikaLock();
    expect(transport.written, contains(':cfg_setparam:1001:1'));

    transport.written.clear();
    await controller.teltonikaUnlock();
    expect(transport.written, contains(':cfg_setparam:1001:0'));
  });
}

Future<TrackerStudioController> _controller(
        _RecordingTransport transport) async {
  sqfliteFfiInit();
  final database = LocalServiceDatabase(
    factory: databaseFactoryFfi,
    pathResolver: () async => inMemoryDatabasePath,
  );
  final controller = TrackerStudioController(
    parser: SuntechParser(),
    transport: transport,
    localitel: LocalitelClient(),
    serviceLocation: ServiceLocationProvider(),
    completedServices: CompletedServiceRepository(database),
  );
  // O construtor dispara loadCompletedServices/loadTodayWorkOrders de forma
  // nao-aguardada; aguarda ambos concluirem para que nada complete apos o
  // dispose no tearDown.
  await controller.loadCompletedServices();
  await controller.loadTodayWorkOrders();
  await Future<void>.delayed(Duration.zero);
  return controller;
}

class _RecordingTransport implements UsbSerialTransport {
  final StreamController<String> _lines = StreamController<String>.broadcast();
  final List<String> written = [];
  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<List<SerialPortInfo>> listPorts() async => const [];

  @override
  Future<void> writeLine(String line) async {
    written.add(line);
  }
}
