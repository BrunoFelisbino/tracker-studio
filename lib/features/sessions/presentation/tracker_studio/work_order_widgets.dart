import 'package:flutter/material.dart';

import 'completed_service_repository.dart';
import 'work_order_models.dart';

class WorkOrderAgendaSection extends StatelessWidget {
  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpen;
  final ValueChanged<WorkOrder> onStart;
  final ValueChanged<WorkOrder> onRoute;
  final ValueChanged<WorkOrder> onWhatsApp;

  const WorkOrderAgendaSection({
    super.key,
    required this.workOrders,
    required this.onOpen,
    required this.onStart,
    required this.onRoute,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Agenda de hoje',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 8),
            Chip(label: Text('${workOrders.length} serviços')),
          ],
        ),
        const SizedBox(height: 10),
        if (workOrders.isEmpty)
          const _EmptyPanel(label: 'Nenhuma OS local para hoje.')
        else
          ...workOrders.map(
            (workOrder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgendaCard(
                workOrder: workOrder,
                onOpen: () => onOpen(workOrder),
                onStart: () => onStart(workOrder),
                onRoute: () => onRoute(workOrder),
                onWhatsApp: () => onWhatsApp(workOrder),
              ),
            ),
          ),
      ],
    );
  }
}

class ActiveWorkOrderCard extends StatelessWidget {
  final WorkOrder workOrder;
  final ValueChanged<String> onPlateSubmitted;
  final VoidCallback onComplete;
  final String usbEsn;
  final String usbImei;
  final ServiceValidation validation;

  const ActiveWorkOrderCard({
    super.key,
    required this.workOrder,
    required this.onPlateSubmitted,
    required this.onComplete,
    required this.usbEsn,
    required this.usbImei,
    required this.validation,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Serviço ativo · ${workOrder.id}',
      icon: Icons.assignment_outlined,
      trailing: _StatusChip(status: workOrder.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workOrder.serviceTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Info(label: 'Cliente', value: workOrder.customerName),
              _Info(label: 'Empresa', value: workOrder.companyName),
              _Info(
                  label: 'Veículo',
                  value: '${workOrder.vehicleBrand} ${workOrder.vehicleModel}'),
              _Info(label: 'Placa esperada', value: workOrder.plateExpected),
              _Info(
                  label: 'Placa lida',
                  value:
                      workOrder.plateRead.isEmpty ? '-' : workOrder.plateRead),
              _Info(
                  label: 'Modelo esperado',
                  value: workOrder.expectedTrackerModel),
              _Info(
                  label: 'Perfil sugerido',
                  value: workOrder.recommendedProfile),
              _Info(
                  label: 'Servidor destino',
                  value: workOrder.destinationServer),
              _Info(
                  label: 'Endereço esperado',
                  value: workOrder.scheduledAddress),
              _Info(
                  label: 'ESN USB lido',
                  value: usbEsn.isEmpty || usbEsn == '-' ? '-' : usbEsn),
              _Info(
                  label: 'IMEI USB lido',
                  value: usbImei.isEmpty || usbImei == '-' ? '-' : usbImei),
              _Info(
                label: 'Etiqueta lida',
                value: workOrder.deviceEvidence?.labelEsn ??
                    workOrder.deviceEvidence?.labelSerial ??
                    workOrder.deviceEvidence?.labelImei ??
                    '-',
              ),
              _Info(
                  label: 'Conferência',
                  value: validation.result.name.toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${workOrder.id}-${workOrder.plateRead}'),
            initialValue: workOrder.plateRead,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Placa conferida no veículo',
              hintText: 'Informe após conferência visual',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            onFieldSubmitted: onPlateSubmitted,
          ),
          if (workOrder.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(workOrder.notes),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.task_alt),
              label: const Text('Concluir serviço'),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkOrderEvidenceCard extends StatelessWidget {
  final WorkOrder workOrder;
  final bool physicalIgnition;
  final bool blockingEnabled;
  final ValueChanged<WorkOrderPhotoType> onTakePhoto;
  final ValueChanged<WorkOrderPhotoType> onSelectPhoto;
  final ValueChanged<DeviceEvidence> onDeviceEvidenceChanged;

  const WorkOrderEvidenceCard({
    super.key,
    required this.workOrder,
    required this.physicalIgnition,
    required this.blockingEnabled,
    required this.onTakePhoto,
    required this.onSelectPhoto,
    required this.onDeviceEvidenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Evidências obrigatórias',
      icon: Icons.photo_camera_outlined,
      child: Column(
        children: [
          for (final requirement in workOrderPhotoCatalog(
            physicalIgnition: physicalIgnition,
            blockingEnabled: blockingEnabled,
          ))
            _EvidenceRow(
              requirement: requirement,
              captured: workOrder.photos.any((photo) =>
                  photo.type == requirement.type && photo.filePath.isNotEmpty),
              onTakePhoto: () => onTakePhoto(requirement.type),
              onSelectPhoto: () => onSelectPhoto(requirement.type),
            ),
          const Divider(height: 28),
          TextFormField(
            initialValue: workOrder.deviceEvidence?.barcodeRaw,
            decoration: const InputDecoration(
                labelText: 'Código de barras / código bruto'),
            onFieldSubmitted: (value) => onDeviceEvidenceChanged(
              (workOrder.deviceEvidence ?? const DeviceEvidence())
                  .copyWith(barcodeRaw: value),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: workOrder.deviceEvidence?.labelSerial,
            decoration:
                const InputDecoration(labelText: 'Serial lido da etiqueta'),
            onFieldSubmitted: (value) => onDeviceEvidenceChanged(
              (workOrder.deviceEvidence ?? const DeviceEvidence())
                  .copyWith(labelSerial: value),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: workOrder.deviceEvidence?.labelEsn,
            decoration:
                const InputDecoration(labelText: 'ESN lido da etiqueta'),
            onFieldSubmitted: (value) => onDeviceEvidenceChanged(
              (workOrder.deviceEvidence ?? const DeviceEvidence())
                  .copyWith(labelEsn: value),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: workOrder.deviceEvidence?.labelImei,
            decoration:
                const InputDecoration(labelText: 'IMEI lido da etiqueta'),
            onFieldSubmitted: (value) => onDeviceEvidenceChanged(
              (workOrder.deviceEvidence ?? const DeviceEvidence())
                  .copyWith(labelImei: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final WorkOrderPhotoRequirement requirement;
  final bool captured;
  final VoidCallback onTakePhoto;
  final VoidCallback onSelectPhoto;

  const _EvidenceRow({
    required this.requirement,
    required this.captured,
    required this.onTakePhoto,
    required this.onSelectPhoto,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(captured ? Icons.check_circle : Icons.schedule,
                color: captured ? Colors.green : Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requirement.label),
                  Text(
                    captured
                        ? 'Capturada'
                        : requirement.required
                            ? 'Pendente · obrigatória'
                            : 'Pendente · opcional',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 17),
              label: const Text('Tirar foto'),
            ),
            TextButton.icon(
              onPressed: onSelectPhoto,
              icon: const Icon(Icons.folder_open, size: 17),
              label: const Text('Selecionar foto'),
            ),
          ],
        ),
      );
}

class ServiceTripleCheckCard extends StatelessWidget {
  final ServiceValidation validation;
  final String localitelStatus;
  final VoidCallback onValidate;

  const ServiceTripleCheckCard({
    super.key,
    required this.validation,
    required this.localitelStatus,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Triple Check do Serviço',
      icon: Icons.fact_check_outlined,
      trailing: _ValidationBadge(status: validation.result),
      child: Column(
        children: [
          for (final item in validation.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_validationIcon(item.status),
                  color: _validationColor(item.status)),
              title: Text(item.label),
              subtitle: Text(item.detail),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sensors_outlined),
            title: const Text('LocaliTel'),
            subtitle:
                Text('$localitelStatus · validação opcional, não bloqueante'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onValidate,
              icon: const Icon(Icons.refresh),
              label: const Text('Validar novamente'),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkOrderPayloadCard extends StatelessWidget {
  final String payload;
  final VoidCallback onCopy;

  const WorkOrderPayloadCard(
      {super.key, required this.payload, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Payload da OS',
      icon: Icons.data_object,
      trailing: IconButton(
          onPressed: payload.isEmpty ? null : onCopy,
          icon: const Icon(Icons.copy),
          tooltip: 'Copiar JSON'),
      child: SelectableText(
        payload.isEmpty
            ? 'Abra uma OS no modo Operacional para inspecionar o payload.'
            : payload,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}

class CompletedServicesCard extends StatelessWidget {
  final List<CompletedServiceRecord> records;
  final int pendingCount;

  const CompletedServicesCard({
    super.key,
    required this.records,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Serviços feitos',
      icon: Icons.history,
      trailing: pendingCount == 0
          ? null
          : Chip(label: Text('$pendingCount pendentes de envio')),
      child: records.isEmpty
          ? const Text('Nenhum serviço finalizado neste dispositivo.')
          : ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver histórico'),
              subtitle: Text('${records.length} serviços recentes'),
              children: [
                for (final record in records)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      record.status == 'completedWithWarning'
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: record.status == 'completedWithWarning'
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: Text('${record.customerName} · ${record.plate}'),
                    subtitle: Text(
                      '${record.serviceType} · ${_dateTime(record.finishedAt)}',
                    ),
                    trailing: Chip(
                      label: Text(record.syncStatus == 'pending'
                          ? 'Pendente de sincronização'
                          : record.syncStatus == 'synced'
                              ? 'Sincronizado'
                              : record.syncStatus == 'failed'
                                  ? 'Erro no envio'
                                  : 'Salvo localmente'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final WorkOrder workOrder;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onRoute;
  final VoidCallback onWhatsApp;

  const _AgendaCard({
    required this.workOrder,
    required this.onOpen,
    required this.onStart,
    required this.onRoute,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final active = workOrder.status == WorkOrderStatus.inProgress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(workOrder.time,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(workOrder.serviceTitle,
                        style: Theme.of(context).textTheme.titleMedium)),
                _StatusChip(status: workOrder.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('${workOrder.customerName} · ${workOrder.companyName}'),
            const SizedBox(height: 4),
            Text(workOrder.scheduledAddress,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: active ? onOpen : onStart,
                  icon: Icon(active ? Icons.open_in_new : Icons.play_arrow),
                  label: Text(active ? 'Abrir' : 'Iniciar serviço'),
                ),
                OutlinedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.route),
                    label: const Text('Rota')),
                OutlinedButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp')),
                TextButton(onPressed: onOpen, child: const Text('Detalhes')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Panel(
      {required this.title,
      required this.icon,
      required this.child,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge)),
                if (trailing != null) trailing!,
              ],
            ),
            const Divider(height: 26),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final WorkOrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) => Chip(
      label: Text(_statusLabel(status)), visualDensity: VisualDensity.compact);
}

class _ValidationBadge extends StatelessWidget {
  final ServiceValidationStatus status;

  const _ValidationBadge({required this.status});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(_validationIcon(status),
            size: 16, color: _validationColor(status)),
        label: Text(status == ServiceValidationStatus.ok
            ? 'OK'
            : status == ServiceValidationStatus.warning
                ? 'Warning'
                : 'Pendente'),
      );
}

class _Info extends StatelessWidget {
  final String label;
  final String value;

  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value)
        ]),
      );
}

class _EmptyPanel extends StatelessWidget {
  final String label;

  const _EmptyPanel({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label),
      );
}

IconData _validationIcon(ServiceValidationStatus status) => switch (status) {
      ServiceValidationStatus.ok => Icons.check_circle,
      ServiceValidationStatus.warning => Icons.warning_amber_rounded,
      ServiceValidationStatus.pending => Icons.schedule,
    };

Color _validationColor(ServiceValidationStatus status) => switch (status) {
      ServiceValidationStatus.ok => Colors.green,
      ServiceValidationStatus.warning => Colors.orange,
      ServiceValidationStatus.pending => Colors.blueGrey,
    };

String _statusLabel(WorkOrderStatus status) => switch (status) {
      WorkOrderStatus.scheduled => 'Agendado',
      WorkOrderStatus.confirmed => 'Confirmado',
      WorkOrderStatus.attention => 'Atenção',
      WorkOrderStatus.inProgress => 'Em serviço',
      WorkOrderStatus.pendingSync => 'Pendente de sync',
      WorkOrderStatus.completed => 'Concluído',
      WorkOrderStatus.completedWithWarning => 'Concluído com warning',
      WorkOrderStatus.canceled => 'Cancelado',
    };

String _dateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}
