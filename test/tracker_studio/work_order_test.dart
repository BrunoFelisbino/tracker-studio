import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/work_order_models.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/work_order_repository.dart';

import 'work_order_test_factory.dart';

void main() {
  test('runtime repository starts empty without fake work orders', () async {
    final repository = MemoryWorkOrderRepository();

    final items = await repository.listByDate(DateTime.now());

    expect(items, isEmpty);
  });

  test('test fixtures do not invent tracker identity or telemetry', () {
    final workOrders = fixtureWorkOrders(date: DateTime(2026, 7, 22));

    expect(workOrders, isNotEmpty);
    expect(workOrders.every((item) => item.expectedTrackerEsn.isEmpty), isTrue);
    expect(workOrders.every((item) => item.plateRead.isEmpty), isTrue);
  });

  test('exact time service creates 1h, 30min and on-time reminders', () {
    final order = fixtureWorkOrders(date: DateTime(2026, 7, 22))
        .first
        .copyWith(time: '09:00');

    final reminders = serviceReminderOccurrences(order);

    expect(reminders.map((item) => item.scheduledAt), [
      DateTime(2026, 7, 22, 8),
      DateTime(2026, 7, 22, 8, 30),
      DateTime(2026, 7, 22, 9),
    ]);
  });

  test('morning service alerts previous day and service morning', () {
    final order = fixtureWorkOrders(date: DateTime(2026, 7, 22))
        .first
        .copyWith(scheduleKind: ServiceScheduleKind.morning);

    final reminders = serviceReminderOccurrences(order);

    expect(reminders[0].scheduledAt, DateTime(2026, 7, 21, 18));
    expect(reminders[1].scheduledAt, DateTime(2026, 7, 22, 7, 30));
    expect(reminders[0].message, contains('manhã amanhã'));
  });

  test('triple check remains pending without real coordinates and ESN', () {
    final workOrder = fixtureWorkOrders().first;

    final validation = validateWorkOrderService(
      workOrder: workOrder,
      technicianLatitude: 0,
      technicianLongitude: 0,
      trackerLatitude: 0,
      trackerLongitude: 0,
      trackerEsn: '',
    );

    expect(validation.result, ServiceValidationStatus.pending);
  });

  test('plate mismatch produces warning without rejecting tracker state', () {
    final workOrder = fixtureWorkOrders().first.copyWith(plateRead: 'ZZZ9Z99');

    final validation = validateWorkOrderService(
      workOrder: workOrder,
      technicianLatitude: workOrder.scheduledLatitude,
      technicianLongitude: workOrder.scheduledLongitude,
      trackerLatitude: workOrder.scheduledLatitude,
      trackerLongitude: workOrder.scheduledLongitude,
      trackerEsn: '',
    );

    expect(validation.result, ServiceValidationStatus.warning);
  });

  test('repository records warning when required evidence is missing',
      () async {
    final workOrder = fixtureWorkOrders().first;
    final repository = MemoryWorkOrderRepository(seed: [workOrder]);

    final started = await repository.start(workOrder.id);
    final completed = await repository.complete(workOrder.id);

    expect(started.status, WorkOrderStatus.inProgress);
    expect(started.startedAt, isNotEmpty);
    expect(completed.status, WorkOrderStatus.completedWithWarning);
    expect(completed.finishedAt, isNotEmpty);
  });

  test('repository marks complete evidence as pending sync', () async {
    final workOrder = fixtureWorkOrders().first;
    final photos = [
      for (final requirement in workOrderPhotoCatalog(
        physicalIgnition: false,
        blockingEnabled: false,
      ).where((item) => item.required))
        WorkOrderPhoto(
          id: 'file-${requirement.type.name}',
          type: requirement.type,
          filePath: '/local/${requirement.type.name}.jpg',
          capturedAt: '2026-07-22T10:00:00Z',
          required: true,
        ),
    ];
    final repository =
        MemoryWorkOrderRepository(seed: [workOrder.copyWith(photos: photos)]);

    final completed = await repository.complete(workOrder.id);

    expect(completed.status, WorkOrderStatus.pendingSync);
  });

  test('matching plate and label ESN produce OK checks', () {
    final base = fixtureWorkOrders().first;
    final workOrder = base.copyWith(
      plateRead: base.plateExpected,
      deviceEvidence: const DeviceEvidence(labelEsn: 'USB123', status: 'read'),
    );

    final validation = validateWorkOrderService(
      workOrder: workOrder,
      technicianLatitude: workOrder.scheduledLatitude,
      technicianLongitude: workOrder.scheduledLongitude,
      trackerLatitude: workOrder.scheduledLatitude,
      trackerLongitude: workOrder.scheduledLongitude,
      trackerEsn: 'USB123',
    );

    expect(validation.items.firstWhere((item) => item.id == 'plate').status,
        ServiceValidationStatus.ok);
    expect(validation.deviceLabelMatchesUsb, isTrue);
  });

  test('physical ignition and blocking require their specific photos', () {
    final requirements = workOrderPhotoCatalog(
      physicalIgnition: true,
      blockingEnabled: true,
    );

    expect(
      requirements
          .firstWhere(
              (item) => item.type == WorkOrderPhotoType.ignitionConnection)
          .required,
      isTrue,
    );
    expect(
      requirements
          .firstWhere((item) => item.type == WorkOrderPhotoType.blockingRelay)
          .required,
      isTrue,
    );
  });
}
