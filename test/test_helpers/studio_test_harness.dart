import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker_studio/core/data/capture_logs/capture_log_store.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/completed_service_repository.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/local_service_database.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/service_location_provider.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

Future<MutableTrackerStudioController> createStudioTestController({
  List<SerialPortInfo> ports = const [],
  LocalitelClient? localitel,
  CaptureLogStore? captureLogs,
}) async {
  return MutableTrackerStudioController(
    parser: const SuntechParser(),
    transport: CountingTransport(ports: ports),
    localitel: localitel ?? LocalitelClient(),
    serviceLocation: ServiceLocationProvider(),
    completedServices: _MemoryCompletedServiceRepository(),
    captureLogs: captureLogs,
  );
}

class MutableTrackerStudioController extends TrackerStudioController {
  final CountingTransport testTransport;

  MutableTrackerStudioController({
    required super.parser,
    required CountingTransport transport,
    required super.localitel,
    required super.serviceLocation,
    required super.completedServices,
    super.captureLogs,
  })  : testTransport = transport,
        super(transport: transport);

  void replaceState(TrackerSessionState next) {
    state = next;
  }
}

class CountingTransport implements UsbSerialTransport {
  CountingTransport({this.ports = const []});

  final List<SerialPortInfo> ports;
  final StreamController<String> _lines = StreamController<String>.broadcast();
  int listPortsCalls = 0;
  int connectCalls = 0;
  SerialConnectionRequest? lastRequest;
  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {
    connectCalls += 1;
    lastRequest = request;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<List<SerialPortInfo>> listPorts() async {
    listPortsCalls += 1;
    return ports;
  }

  @override
  Future<void> writeLine(String line) async {}

  void feed(String line) {
    _lines.add(line);
  }

  void feedLines(Iterable<String> lines) {
    for (final line in lines) {
      _lines.add(line);
    }
  }
}

class DisabledLocalitelClient extends LocalitelClient {
  @override
  bool get enabled => false;
}

class _MemoryCompletedServiceRepository extends CompletedServiceRepository {
  _MemoryCompletedServiceRepository()
      : super(
          LocalServiceDatabase(
            factory: databaseFactoryFfi,
            pathResolver: () async => inMemoryDatabasePath,
          ),
        );

  final List<CompletedServiceRecord> _records = [];

  @override
  Future<List<CompletedServiceRecord>> listPendingSync() async =>
      _records.where((record) => record.syncStatus == 'pending').toList();

  @override
  Future<List<CompletedServiceRecord>> listRecentCompletedServices(
          {int limit = 50}) async =>
      _records.take(limit).toList();

  @override
  Future<void> saveCompletedService(CompletedServiceRecord record) async {
    _records.removeWhere((item) => item.id == record.id);
    _records.add(record);
  }
}
