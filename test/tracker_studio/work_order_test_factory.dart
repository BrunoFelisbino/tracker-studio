import 'package:tracker_studio/features/sessions/presentation/tracker_studio/work_order_models.dart';

List<WorkOrder> fixtureWorkOrders({DateTime? date}) {
  final target = date ?? DateTime.now();
  const photoChecks = [
    WorkOrderCheck(
      id: 'photo_vehicle',
      label: 'Foto do veículo',
      status: 'pending',
    ),
    WorkOrderCheck(
      id: 'photo_plate',
      label: 'Foto da placa',
      status: 'pending',
    ),
    WorkOrderCheck(
      id: 'photo_tracker',
      label: 'Foto do rastreador instalado',
      status: 'pending',
    ),
    WorkOrderCheck(
      id: 'photo_wiring',
      label: 'Foto da ligação elétrica',
      status: 'pending',
    ),
  ];

  return [
    WorkOrder(
      id: 'TEST-OS-001',
      date: DateTime(target.year, target.month, target.day),
      time: '09:00',
      customerId: 'TEST-CUSTOMER',
      customerName: 'Cliente de teste',
      companyName: 'Empresa de teste',
      serviceType: ServiceType.installation,
      serviceTitle: 'Instalação de teste',
      scheduledAddress: 'Endereço de teste',
      scheduledLatitude: 0.0,
      scheduledLongitude: 0.0,
      phone: '',
      phoneRaw: '',
      priority: WorkOrderPriority.normal,
      status: WorkOrderStatus.scheduled,
      vehicleId: 'TEST-VEHICLE',
      plateExpected: 'ABC1D23',
      plateRead: '',
      vehicleBrand: 'Marca teste',
      vehicleModel: 'Modelo teste',
      vehicleYear: 2023,
      vehicleType: VehicleType.car,
      expectedTrackerModel: '',
      expectedTrackerEsn: '',
      recommendedProfile: '',
      destinationServer: '',
      notes: '',
      photos: const [],
      checks: photoChecks,
      deviceEvidence: const DeviceEvidence(),
      startedAt: '',
      finishedAt: '',
    ),
  ];
}
