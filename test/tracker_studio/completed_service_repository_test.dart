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
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/work_order_repository.dart';

import 'work_order_test_factory.dart';

void main() {
  late LocalServiceDatabase database;
  late CompletedServiceRepository repository;

  setUp(() {
    sqfliteFfiInit();
    database = LocalServiceDatabase(
      factory: databaseFactoryFfi,
      pathResolver: () async => inMemoryDatabasePath,
    );
    repository = CompletedServiceRepository(database);
  });

  tearDown(() => database.close());

  test('saves minimum completed service data without photo columns', () async {
    final record = _record(id: 'service-1', syncStatus: 'notRequired');

    await repository.saveCompletedService(record);
    final saved = (await repository.listRecentCompletedServices()).single;
    final columns = await (await database.database)
        .rawQuery('PRAGMA table_info(completed_services)');

    expect(saved.customerName, 'Cliente teste');
    expect(saved.plate, 'ABC1D23');
    expect(saved.serviceType, 'installation');
    expect(columns.map((row) => row['name']), isNot(contains('photos')));
    expect(columns.map((row) => row['name']), isNot(contains('photo_blob')));
  });

  test('pending list, recent history and sync transitions work offline',
      () async {
    await repository
        .saveCompletedService(_record(id: 'pending', syncStatus: 'pending'));
    await repository.saveCompletedService(_record(
      id: 'local',
      syncStatus: 'notRequired',
      finishedAt: DateTime.utc(2026, 7, 23),
    ));

    expect((await repository.listPendingSync()).map((item) => item.id),
        ['pending']);
    expect((await repository.listRecentCompletedServices()).first.id, 'local');

    await repository.markSyncFailed('pending', 'offline');
    expect((await repository.listPendingSync()).single.syncStatus, 'failed');
    await repository.markSynced('pending');
    expect(await repository.listPendingSync(), isEmpty);
  });

  test('finalizing OS saves locally as notRequired without configured server',
      () async {
    final controller = _controller(repository, serviceSyncConfigured: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final workOrder = fixtureWorkOrders().first;

    await controller.startWorkOrder(workOrder.id);
    await controller.completeWorkOrder();

    final saved = (await repository.listRecentCompletedServices()).single;
    expect(saved.customerName, workOrder.customerName);
    expect(saved.plate, workOrder.plateExpected);
    expect(saved.serviceType, workOrder.serviceType.name);
    expect(saved.syncStatus, 'notRequired');
    expect(saved.status, 'completedWithWarning');
    controller.dispose();
  });

  test('configured server marks finalized OS as pending sync', () async {
    final controller = _controller(repository, serviceSyncConfigured: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final workOrder = fixtureWorkOrders().first;

    await controller.startWorkOrder(workOrder.id);
    await controller.completeWorkOrder();

    expect((await repository.listPendingSync()).single.syncStatus, 'pending');
    controller.dispose();
  });
}

TrackerStudioController _controller(
  CompletedServiceRepository repository, {
  required bool serviceSyncConfigured,
}) {
  final workOrders = fixtureWorkOrders();
  return TrackerStudioController(
    parser: SuntechParser(),
    transport: _FakeTransport(),
    localitel: LocalitelClient(),
    serviceLocation: ServiceLocationProvider(),
    workOrders: MemoryWorkOrderRepository(seed: workOrders),
    completedServices: repository,
    serviceSyncConfigured: serviceSyncConfigured,
  );
}

CompletedServiceRecord _record({
  required String id,
  required String syncStatus,
  DateTime? finishedAt,
}) {
  final finished = finishedAt ?? DateTime.utc(2026, 7, 22, 10);
  return CompletedServiceRecord(
    id: id,
    workOrderId: 'OS-1',
    customerName: 'Cliente teste',
    plate: 'ABC1D23',
    serviceType: 'installation',
    vehicleBrand: 'Volkswagen',
    vehicleModel: 'Saveiro',
    startedAt: finished.subtract(const Duration(hours: 1)),
    finishedAt: finished,
    status: 'completed',
    resultSummary: 'OK',
    syncStatus: syncStatus,
    createdAt: finished,
    updatedAt: finished,
  );
}

class _FakeTransport implements UsbSerialTransport {
  final StreamController<String> _lines = StreamController<String>.broadcast();

  @override
  bool get connected => false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortInfo>> listPorts() async => const [];

  @override
  Future<void> writeLine(String line) async {}
}
