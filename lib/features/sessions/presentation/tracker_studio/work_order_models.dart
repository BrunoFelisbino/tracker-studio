import 'dart:convert';
import 'dart:math' as math;

enum ServiceScheduleKind { exactTime, morning, afternoon, fullDay }

class ServiceReminderRule {
  final String id;
  final String label;
  final Duration? before;
  final String? dayPeriod;

  const ServiceReminderRule({
    required this.id,
    required this.label,
    this.before,
    this.dayPeriod,
  });
}

class ServiceReminderOccurrence {
  final ServiceReminderRule rule;
  final DateTime scheduledAt;
  final String message;

  const ServiceReminderOccurrence({
    required this.rule,
    required this.scheduledAt,
    required this.message,
  });
}

enum WorkOrderStatus {
  scheduled,
  confirmed,
  attention,
  inProgress,
  pendingSync,
  completed,
  completedWithWarning,
  canceled,
}

enum WorkOrderPriority { normal, high, urgent }

enum ServiceType { installation, maintenance, removal, inspection, replacement }

enum VehicleType { car, motorcycle, truck, van, bus, machinery, other }

enum ServiceValidationStatus { pending, ok, warning }

enum WorkOrderPhotoType {
  vehiclePlate,
  deviceLabel,
  odometer,
  fixedLocation,
  wiringPower,
  ignitionConnection,
  blockingRelay,
  vehicleOverview,
}

class WorkOrderPhotoRequirement {
  final WorkOrderPhotoType type;
  final String label;
  final bool required;

  const WorkOrderPhotoRequirement(this.type, this.label, this.required);
}

List<WorkOrderPhotoRequirement> workOrderPhotoCatalog({
  required bool physicalIgnition,
  required bool blockingEnabled,
  bool vehicleOverviewRequired = false,
}) =>
    [
      const WorkOrderPhotoRequirement(
          WorkOrderPhotoType.vehiclePlate, 'Placa do veículo', true),
      const WorkOrderPhotoRequirement(WorkOrderPhotoType.deviceLabel,
          'Equipamento com código de barras/etiqueta', true),
      const WorkOrderPhotoRequirement(
          WorkOrderPhotoType.odometer, 'Odômetro/painel', true),
      const WorkOrderPhotoRequirement(WorkOrderPhotoType.fixedLocation,
          'Local onde o equipamento foi fixado', true),
      const WorkOrderPhotoRequirement(
          WorkOrderPhotoType.wiringPower, 'Ligações e alimentação', true),
      WorkOrderPhotoRequirement(WorkOrderPhotoType.ignitionConnection,
          'Ligação pós-chave/ignição', physicalIgnition),
      WorkOrderPhotoRequirement(
          WorkOrderPhotoType.blockingRelay, 'Bloqueio/relé', blockingEnabled),
      WorkOrderPhotoRequirement(WorkOrderPhotoType.vehicleOverview,
          'Visão geral do veículo', vehicleOverviewRequired),
    ];

class DeviceEvidence {
  final String? photoPath;
  final String? barcodeRaw;
  final String? labelSerial;
  final String? labelImei;
  final String? labelEsn;
  final DateTime? capturedAt;
  final String status;

  const DeviceEvidence({
    this.photoPath,
    this.barcodeRaw,
    this.labelSerial,
    this.labelImei,
    this.labelEsn,
    this.capturedAt,
    this.status = 'pending',
  });

  DeviceEvidence copyWith({
    String? photoPath,
    String? barcodeRaw,
    String? labelSerial,
    String? labelImei,
    String? labelEsn,
    DateTime? capturedAt,
    String? status,
  }) =>
      DeviceEvidence(
        photoPath: photoPath ?? this.photoPath,
        barcodeRaw: barcodeRaw ?? this.barcodeRaw,
        labelSerial: labelSerial ?? this.labelSerial,
        labelImei: labelImei ?? this.labelImei,
        labelEsn: labelEsn ?? this.labelEsn,
        capturedAt: capturedAt ?? this.capturedAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
        'photoPath': photoPath,
        'barcodeRaw': barcodeRaw,
        'labelSerial': labelSerial,
        'labelImei': labelImei,
        'labelEsn': labelEsn,
        'capturedAt': capturedAt?.toIso8601String(),
        'status': status,
      };
}

class WorkOrderPhoto {
  final String id;
  final WorkOrderPhotoType type;
  final String filePath;
  final String capturedAt;
  final bool required;

  const WorkOrderPhoto({
    required this.id,
    required this.type,
    required this.filePath,
    required this.capturedAt,
    required this.required,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'filePath': filePath,
        'capturedAt': capturedAt,
        'required': required,
      };
}

class WorkOrderCheck {
  final String id;
  final String label;
  final String status;
  final String notes;

  const WorkOrderCheck(
      {required this.id,
      required this.label,
      required this.status,
      this.notes = ''});

  Map<String, Object?> toJson() =>
      {'id': id, 'label': label, 'status': status, 'notes': notes};
}

class ServiceValidationItem {
  final String id;
  final String label;
  final ServiceValidationStatus status;
  final String detail;

  const ServiceValidationItem(
      {required this.id,
      required this.label,
      required this.status,
      required this.detail});

  Map<String, Object?> toJson() =>
      {'id': id, 'label': label, 'status': status.name, 'detail': detail};
}

class ServiceValidation {
  final List<ServiceValidationItem> items;
  final bool deviceLabelMatchesUsb;
  final String? deviceLabelWarning;

  const ServiceValidation({
    this.items = const [],
    this.deviceLabelMatchesUsb = false,
    this.deviceLabelWarning,
  });

  ServiceValidationStatus get result {
    if (items.any((item) => item.status == ServiceValidationStatus.warning)) {
      return ServiceValidationStatus.warning;
    }
    if (items.isEmpty ||
        items.any((item) => item.status == ServiceValidationStatus.pending)) {
      return ServiceValidationStatus.pending;
    }
    return ServiceValidationStatus.ok;
  }

  Map<String, Object?> toJson() => {
        'result': result.name,
        'items': items.map((item) => item.toJson()).toList(),
        'deviceLabelMatchesUsb': deviceLabelMatchesUsb,
        'deviceLabelWarning': deviceLabelWarning,
      };
}

class WorkOrder {
  final String id;
  final DateTime date;
  final String time;
  final ServiceScheduleKind scheduleKind;
  final String customerId;
  final String customerName;
  final String companyName;
  final ServiceType serviceType;
  final String serviceTitle;
  final String scheduledAddress;
  final double scheduledLatitude;
  final double scheduledLongitude;
  final String phone;
  final String phoneRaw;
  final WorkOrderPriority priority;
  final WorkOrderStatus status;
  final String vehicleId;
  final String plateExpected;
  final String plateRead;
  final String vehicleBrand;
  final String vehicleModel;
  final int? vehicleYear;
  final VehicleType vehicleType;
  final String expectedTrackerModel;
  final String expectedTrackerEsn;
  final String recommendedProfile;
  final String destinationServer;
  final String notes;
  final List<WorkOrderPhoto> photos;
  final List<WorkOrderCheck> checks;
  final DeviceEvidence? deviceEvidence;
  final String startedAt;
  final String finishedAt;

  const WorkOrder({
    required this.id,
    required this.date,
    required this.time,
    this.scheduleKind = ServiceScheduleKind.exactTime,
    required this.customerId,
    required this.customerName,
    required this.companyName,
    required this.serviceType,
    required this.serviceTitle,
    required this.scheduledAddress,
    required this.scheduledLatitude,
    required this.scheduledLongitude,
    required this.phone,
    required this.phoneRaw,
    required this.priority,
    required this.status,
    required this.vehicleId,
    required this.plateExpected,
    required this.plateRead,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleType,
    required this.expectedTrackerModel,
    required this.expectedTrackerEsn,
    required this.recommendedProfile,
    required this.destinationServer,
    required this.notes,
    required this.photos,
    required this.checks,
    required this.deviceEvidence,
    required this.startedAt,
    required this.finishedAt,
  });

  WorkOrder copyWith({
    DateTime? date,
    String? time,
    ServiceScheduleKind? scheduleKind,
    WorkOrderStatus? status,
    String? plateRead,
    List<WorkOrderPhoto>? photos,
    List<WorkOrderCheck>? checks,
    DeviceEvidence? deviceEvidence,
    String? startedAt,
    String? finishedAt,
  }) {
    return WorkOrder(
      id: id,
      date: date ?? this.date,
      time: time ?? this.time,
      scheduleKind: scheduleKind ?? this.scheduleKind,
      customerId: customerId,
      customerName: customerName,
      companyName: companyName,
      serviceType: serviceType,
      serviceTitle: serviceTitle,
      scheduledAddress: scheduledAddress,
      scheduledLatitude: scheduledLatitude,
      scheduledLongitude: scheduledLongitude,
      phone: phone,
      phoneRaw: phoneRaw,
      priority: priority,
      status: status ?? this.status,
      vehicleId: vehicleId,
      plateExpected: plateExpected,
      plateRead: plateRead ?? this.plateRead,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleType: vehicleType,
      expectedTrackerModel: expectedTrackerModel,
      expectedTrackerEsn: expectedTrackerEsn,
      recommendedProfile: recommendedProfile,
      destinationServer: destinationServer,
      notes: notes,
      photos: photos ?? this.photos,
      checks: checks ?? this.checks,
      deviceEvidence: deviceEvidence ?? this.deviceEvidence,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'time': time,
        'scheduleKind': scheduleKind.name,
        'customerId': customerId,
        'customerName': customerName,
        'companyName': companyName,
        'serviceType': serviceType.name,
        'serviceTitle': serviceTitle,
        'scheduledAddress': scheduledAddress,
        'scheduledLatitude': scheduledLatitude,
        'scheduledLongitude': scheduledLongitude,
        'phone': phone,
        'phoneRaw': phoneRaw,
        'priority': priority.name,
        'status': status.name,
        'vehicleId': vehicleId,
        'plateExpected': plateExpected,
        'plateRead': plateRead,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'vehicleType': vehicleType.name,
        'expectedTrackerModel': expectedTrackerModel,
        'expectedTrackerEsn': expectedTrackerEsn,
        'recommendedProfile': recommendedProfile,
        'destinationServer': destinationServer,
        'notes': notes,
        'photos': photos.map((photo) => photo.toJson()).toList(),
        'checks': checks.map((check) => check.toJson()).toList(),
        'deviceEvidence': deviceEvidence?.toJson(),
        'startedAt': startedAt,
        'finishedAt': finishedAt,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  DateTime get scheduledAt {
    final parts = time.split(':');
    final hour = parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

const exactTimeReminderRules = [
  ServiceReminderRule(
      id: 'exact-1h', label: '1h antes', before: Duration(hours: 1)),
  ServiceReminderRule(
      id: 'exact-30m', label: '30min antes', before: Duration(minutes: 30)),
  ServiceReminderRule(
      id: 'exact-now', label: 'No horário', before: Duration.zero),
];

const dayPeriodReminderRules = [
  ServiceReminderRule(
      id: 'period-previous-day',
      label: 'Dia anterior às 18:00',
      dayPeriod: 'previousDay'),
  ServiceReminderRule(
      id: 'period-service-day',
      label: 'No dia do serviço',
      dayPeriod: 'serviceDay'),
];

List<ServiceReminderOccurrence> serviceReminderOccurrences(WorkOrder order) {
  if (order.scheduleKind == ServiceScheduleKind.exactTime) {
    return [
      for (final rule in exactTimeReminderRules)
        ServiceReminderOccurrence(
          rule: rule,
          scheduledAt: order.scheduledAt.subtract(rule.before!),
          message: 'Você tem serviço hoje às ${order.time}',
        ),
    ];
  }
  final previousDay =
      DateTime(order.date.year, order.date.month, order.date.day - 1, 18);
  final (hour, minute, periodLabel) = switch (order.scheduleKind) {
    ServiceScheduleKind.morning => (7, 30, 'manhã'),
    ServiceScheduleKind.afternoon => (12, 30, 'tarde'),
    ServiceScheduleKind.fullDay => (8, 0, 'dia inteiro'),
    ServiceScheduleKind.exactTime => (0, 0, ''),
  };
  return [
    ServiceReminderOccurrence(
      rule: dayPeriodReminderRules[0],
      scheduledAt: previousDay,
      message: 'Serviço da $periodLabel amanhã: não esquecer',
    ),
    ServiceReminderOccurrence(
      rule: dayPeriodReminderRules[1],
      scheduledAt: DateTime(
          order.date.year, order.date.month, order.date.day, hour, minute),
      message: 'Você tem serviço no período da $periodLabel hoje',
    ),
  ];
}

List<ServiceReminderOccurrence> dueServiceReminders(
  Iterable<WorkOrder> workOrders,
  DateTime now, {
  Duration visibleFor = const Duration(minutes: 65),
}) {
  final reminders = [
    for (final order in workOrders)
      for (final reminder in serviceReminderOccurrences(order))
        if (!now.isBefore(reminder.scheduledAt) &&
            now.difference(reminder.scheduledAt) <= visibleFor)
          reminder,
  ];
  for (final order in workOrders) {
    if (!isOverdueWorkOrder(order, now) ||
        reminders.any((item) => item.message.contains(order.time))) {
      continue;
    }
    reminders.add(
      ServiceReminderOccurrence(
        rule:
            const ServiceReminderRule(id: 'overdue', label: 'Serviço atrasado'),
        scheduledAt: order.scheduledAt,
        message: 'Serviço atrasado: revisar agenda',
      ),
    );
  }
  return reminders;
}

bool isActionableWorkOrder(WorkOrder order) => !{
      WorkOrderStatus.pendingSync,
      WorkOrderStatus.completed,
      WorkOrderStatus.completedWithWarning,
      WorkOrderStatus.canceled,
    }.contains(order.status);

bool isOverdueWorkOrder(WorkOrder order, DateTime now) =>
    isActionableWorkOrder(order) &&
    order.scheduleKind == ServiceScheduleKind.exactTime &&
    now.isAfter(order.scheduledAt);

ServiceValidation validateWorkOrderService({
  required WorkOrder workOrder,
  required double technicianLatitude,
  required double technicianLongitude,
  required double trackerLatitude,
  required double trackerLongitude,
  required String trackerEsn,
  String trackerImei = '',
  bool physicalIgnition = false,
  bool blockingEnabled = false,
  double toleranceMeters = 150,
}) {
  final items = <ServiceValidationItem>[];
  final expectedPlate = _normalizePlate(workOrder.plateExpected);
  final readPlate = _normalizePlate(workOrder.plateRead);
  items.add(
    ServiceValidationItem(
      id: 'plate',
      label: 'Placa conferida',
      status: readPlate.isEmpty
          ? ServiceValidationStatus.pending
          : readPlate == expectedPlate
              ? ServiceValidationStatus.ok
              : ServiceValidationStatus.warning,
      detail: readPlate.isEmpty
          ? 'Placa ainda não informada'
          : '$readPlate / esperado $expectedPlate',
    ),
  );

  void addDistance(String id, String label, double latA, double lonA,
      double latB, double lonB) {
    if (!_validCoordinates(latA, lonA) || !_validCoordinates(latB, lonB)) {
      items.add(ServiceValidationItem(
          id: id,
          label: label,
          status: ServiceValidationStatus.pending,
          detail: 'Coordenadas ausentes'));
      return;
    }
    final distance = _distanceMeters(latA, lonA, latB, lonB);
    items.add(
      ServiceValidationItem(
        id: id,
        label: label,
        status: distance <= toleranceMeters
            ? ServiceValidationStatus.ok
            : ServiceValidationStatus.warning,
        detail:
            '${distance.toStringAsFixed(0)} m · tolerância ${toleranceMeters.toStringAsFixed(0)} m',
      ),
    );
  }

  addDistance(
    'scheduled_technician',
    'Endereço agendado x técnico',
    workOrder.scheduledLatitude,
    workOrder.scheduledLongitude,
    technicianLatitude,
    technicianLongitude,
  );
  addDistance(
    'scheduled_tracker',
    'Endereço agendado x rastreador',
    workOrder.scheduledLatitude,
    workOrder.scheduledLongitude,
    trackerLatitude,
    trackerLongitude,
  );
  addDistance(
    'technician_tracker',
    'Técnico x rastreador',
    technicianLatitude,
    technicianLongitude,
    trackerLatitude,
    trackerLongitude,
  );

  final expectedEsn = workOrder.expectedTrackerEsn.trim();
  items.add(
    ServiceValidationItem(
      id: 'esn',
      label: 'ESN esperado x lido',
      status: expectedEsn.isEmpty || trackerEsn.trim().isEmpty
          ? ServiceValidationStatus.pending
          : expectedEsn == trackerEsn.trim()
              ? ServiceValidationStatus.ok
              : ServiceValidationStatus.warning,
      detail: expectedEsn.isEmpty
          ? 'OS sem ESN esperado'
          : 'Lido: ${trackerEsn.isEmpty ? '-' : trackerEsn}',
    ),
  );
  final evidence = workOrder.deviceEvidence;
  final labelIdentity = evidence?.labelEsn?.trim().isNotEmpty == true
      ? evidence!.labelEsn!.trim()
      : evidence?.labelSerial?.trim() ?? '';
  final usbIdentity = trackerEsn.trim();
  final labelImei = evidence?.labelImei?.trim() ?? '';
  final usbImei = trackerImei.trim();
  final identityPending = (labelIdentity.isEmpty || usbIdentity.isEmpty) &&
      (labelImei.isEmpty || usbImei.isEmpty);
  final identityMatches = (labelIdentity.isNotEmpty &&
          usbIdentity.isNotEmpty &&
          labelIdentity == usbIdentity) ||
      (labelImei.isNotEmpty && usbImei.isNotEmpty && labelImei == usbImei);
  final identityWarning = !identityPending && !identityMatches
      ? 'Etiqueta diverge da identidade lida pela USB'
      : null;
  items.add(ServiceValidationItem(
    id: 'device_label_usb',
    label: 'Etiqueta x USB',
    status: identityPending
        ? ServiceValidationStatus.pending
        : identityMatches
            ? ServiceValidationStatus.ok
            : ServiceValidationStatus.warning,
    detail: identityPending
        ? 'Aguardando etiqueta e leitura USB comparáveis'
        : identityWarning ?? 'Identidade conferida',
  ));

  for (final requirement in workOrderPhotoCatalog(
    physicalIgnition: physicalIgnition,
    blockingEnabled: blockingEnabled,
  ).where((item) => item.required)) {
    final captured = workOrder.photos.any(
        (photo) => photo.type == requirement.type && photo.filePath.isNotEmpty);
    items.add(ServiceValidationItem(
      id: 'photo_${requirement.type.name}',
      label: requirement.label,
      status: captured
          ? ServiceValidationStatus.ok
          : ServiceValidationStatus.pending,
      detail: captured ? 'Evidência capturada' : 'Foto obrigatória pendente',
    ));
  }
  return ServiceValidation(
    items: items,
    deviceLabelMatchesUsb: identityMatches,
    deviceLabelWarning: identityWarning,
  );
}

bool hasMissingRequiredPhotos(
  WorkOrder workOrder, {
  bool physicalIgnition = false,
  bool blockingEnabled = false,
}) {
  final required = workOrderPhotoCatalog(
    physicalIgnition: physicalIgnition,
    blockingEnabled: blockingEnabled,
  ).where((item) => item.required);
  return required.any((requirement) => !workOrder.photos.any(
      (photo) => photo.type == requirement.type && photo.filePath.isNotEmpty));
}

String _normalizePlate(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
bool _validCoordinates(double latitude, double longitude) =>
    latitude != 0 && longitude != 0;

double _distanceMeters(double latA, double lonA, double latB, double lonB) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final deltaLat = radians(latB - latA);
  final deltaLon = radians(lonB - lonA);
  final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(radians(latA)) *
          math.cos(radians(latB)) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
