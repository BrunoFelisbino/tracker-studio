import 'diagnostic_types.dart';

class EventDeduplicator {
  final Map<String, _Group> _groups = {};

  /// Agrupa eventos por chave mantendo a primeira ocorrência como representante.
  /// Retorna eventos com `repeatCount` ajustado, ordenados pelo timestamp.
  List<NormalizedDiagnosticEvent> deduplicate(
    List<NormalizedDiagnosticEvent> events,
  ) {
    _groups.clear();
    for (final event in events) {
      final group = _groups.putIfAbsent(event.key, () => _Group(event));
      group.count += event.repeatCount;
      group.first ??= event;
      group.last = event;
    }
    final result = <NormalizedDiagnosticEvent>[];
    for (final group in _groups.values) {
      final representative = group.first!;
      result.add(NormalizedDiagnosticEvent(
        id: representative.id,
        timestamp: representative.timestamp,
        deviceTimestamp: representative.deviceTimestamp,
        severity: representative.severity,
        category: representative.category,
        source: representative.source,
        event: representative.event,
        title: representative.title,
        message: representative.message,
        value: representative.value,
        unit: representative.unit,
        details: representative.details,
        raw: representative.raw,
        repeatCount: group.count,
        manufacturer: representative.manufacturer,
        manufacturerSpecific: representative.manufacturerSpecific,
      ));
    }
    result.sort((a, b) {
      final ta = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return result;
  }
}

class _Group {
  final NormalizedDiagnosticEvent initial;
  NormalizedDiagnosticEvent? first;
  NormalizedDiagnosticEvent? last;
  int count;

  _Group(this.initial)
      : count = initial.repeatCount,
        first = initial;
}
