import 'protocol_adapter.dart';
import 'diagnostic_types.dart';

class ParserRegistry {
  final List<DiagnosticProtocolAdapter> _adapters;

  ParserRegistry(List<DiagnosticProtocolAdapter> adapters)
      : _adapters = List.unmodifiable(adapters);

  List<DiagnosticProtocolAdapter> get adapters => _adapters;

  DiagnosticProtocolAdapter resolve(ProtocolDetectionResult detection) {
    for (final adapter in _adapters) {
      if (adapter.manufacturer == detection.manufacturer) {
        return adapter;
      }
    }
    return _adapters.last;
  }

  DiagnosticProtocolAdapter? byManufacturer(
      SupportedManufacturer manufacturer) {
    for (final adapter in _adapters) {
      if (adapter.manufacturer == manufacturer) return adapter;
    }
    return null;
  }
}
