import 'work_order_models.dart';

abstract class WorkOrderRepository {
  Future<List<WorkOrder>> listByDate(DateTime date);
  Future<WorkOrder?> getById(String id);
  Future<WorkOrder> upsert(WorkOrder workOrder);
  Future<WorkOrder> start(String id);
  Future<WorkOrder> complete(String id);
}

/// Repositório transitório para desenvolvimento da interface e testes.
///
/// Ele inicia vazio por padrão. Nenhuma OS fictícia é criada em runtime.
/// Dados só entram por `seed` explícito em testes ou por `upsert` realizado
/// por uma fonte real/manual.
class MemoryWorkOrderRepository implements WorkOrderRepository {
  final Map<String, WorkOrder> _items;

  MemoryWorkOrderRepository({List<WorkOrder> seed = const []})
      : _items = {for (final workOrder in seed) workOrder.id: workOrder};

  @override
  Future<List<WorkOrder>> listByDate(DateTime date) async {
    final items = _items.values
        .where((workOrder) => _sameDay(workOrder.date, date))
        .toList();
    items.sort((a, b) => a.time.compareTo(b.time));
    return List.unmodifiable(items);
  }

  @override
  Future<WorkOrder?> getById(String id) async => _items[id];

  @override
  Future<WorkOrder> upsert(WorkOrder workOrder) async {
    _items[workOrder.id] = workOrder;
    return workOrder;
  }

  @override
  Future<WorkOrder> start(String id) async {
    final workOrder = _require(id);
    final started = workOrder.copyWith(
      status: WorkOrderStatus.inProgress,
      startedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _items[id] = started;
    return started;
  }

  @override
  Future<WorkOrder> complete(String id) async {
    final workOrder = _require(id);
    final completed = workOrder.copyWith(
      status: hasMissingRequiredPhotos(workOrder)
          ? WorkOrderStatus.completedWithWarning
          : WorkOrderStatus.pendingSync,
      finishedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _items[id] = completed;
    return completed;
  }

  WorkOrder _require(String id) {
    final workOrder = _items[id];
    if (workOrder == null) throw StateError('OS $id não encontrada');
    return workOrder;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
