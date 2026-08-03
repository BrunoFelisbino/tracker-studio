import 'equipment_lab_types.dart';

/// Registro versionado de mapeamentos de IO IDs.
class IoRegistry {
  IoRegistry({required this.version, required this.definitions});

  final String version;
  final List<IoDefinition> definitions;

  List<IoDefinition> forManufacturer(Manufacturer m) =>
      definitions.where((d) => d.manufacturer == m).toList();

  IoDefinition? byId(int id, Manufacturer m) {
    final matches = definitions.where((d) => d.id == id && d.manufacturer == m);
    return matches.isEmpty ? null : matches.first;
  }
}
