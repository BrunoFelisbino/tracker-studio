import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/completed_service_repository.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/local_service_database.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/service_location_provider.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

void main() {
  group('runtime real state', () {
    test('empty session does not invent device, port or position', () {
      final state = TrackerSessionState.empty();

      expect(state.connection.commandPortName, '-');
      expect(state.connection.readPortName, '-');
      expect(state.device.model, '-');
      expect(state.device.esn, '-');
      expect(state.serviceLocation.isValid, isFalse);
      expect(state.localitel.hasValidCoordinates, isFalse);
    });

    test('empty port scan does not fabricate ttyUSB, ttyACM or COM ports',
        () async {
      final controller = await _controller(const []);
      final ports = await controller.scanPorts();

      expect(ports, isEmpty);
      expect(
        controller.state.logs.any((log) =>
            log.message.contains('/dev/ttyUSB0') ||
            log.message.contains('/dev/ttyACM0') ||
            log.message.contains('COM3')),
        isFalse,
      );

      controller.dispose();
    });

    test('scan returns only adapter-provided ports', () async {
      final controller = await _controller(const [
        SerialPortInfo(
          path: '/dev/cu.usbserial-test',
          label: 'USB Serial Test',
        ),
      ]);
      final ports = await controller.scanPorts();

      expect(ports.map((port) => port.path), ['/dev/cu.usbserial-test']);

      controller.dispose();
    });
  });
}

Future<TrackerStudioController> _controller(List<SerialPortInfo> ports) async {
  sqfliteFfiInit();
  final database = LocalServiceDatabase(
    factory: databaseFactoryFfi,
    pathResolver: () async => inMemoryDatabasePath,
  );
  return TrackerStudioController(
    parser: SuntechParser(),
    transport: _FakeTransport(ports),
    localitel: LocalitelClient(),
    serviceLocation: ServiceLocationProvider(),
    completedServices: CompletedServiceRepository(database),
  );
}

class _FakeTransport implements UsbSerialTransport {
  final List<SerialPortInfo> ports;
  final StreamController<String> _lines = StreamController<String>.broadcast();

  _FakeTransport(this.ports);

  @override
  bool get connected => false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortInfo>> listPorts() async => ports;

  @override
  Future<void> writeLine(String line) async {}
}
