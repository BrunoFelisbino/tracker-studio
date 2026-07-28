import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/completed_service_repository.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/local_service_database.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/service_location_provider.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

void main() {
  test('permission failure stores a macOS sandbox diagnostic', () async {
    sqfliteFfiInit();
    final database = LocalServiceDatabase(
      factory: databaseFactoryFfi,
      pathResolver: () async => inMemoryDatabasePath,
    );
    final controller = TrackerStudioController(
      parser: const SuntechParser(),
      transport: _DeniedTransport(),
      localitel: LocalitelClient(),
      serviceLocation: ServiceLocationProvider(),
      completedServices: CompletedServiceRepository(database),
    );

    await expectLater(
      controller.connectUsb('/dev/cu.usbmodem11200'),
      throwsStateError,
    );

    final failure = controller.state.serialDiagnostic.permissionFailure;
    expect(failure, isNotNull);
    expect(failure!.attemptedPort, '/dev/cu.usbmodem11200');
    expect(failure.rawError, contains('Operation not permitted'));
    expect(failure.sandboxLikely, isTrue);
    expect(failure.suggestion, contains('DebugProfile.entitlements'));

    controller.dispose();
    await database.close();
  });
}

class _DeniedTransport implements UsbSerialTransport {
  final StreamController<String> _lines = StreamController<String>.broadcast();

  @override
  bool get connected => false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {
    throw StateError('Operation not permitted');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortInfo>> listPorts() async => const [];

  @override
  Future<void> writeLine(String line) async {}
}
