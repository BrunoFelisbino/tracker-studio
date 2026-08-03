import 'equipment_lab_types.dart';

/// Registro versionado de definições de testes automatizados.
class TestRegistry {
  TestRegistry({required this.version, required this.definitions});

  final String version;
  final List<EquipmentTestDefinition> definitions;

  List<EquipmentTestDefinition> forManufacturer(Manufacturer m) =>
      definitions.where((d) => d.manufacturer == m).toList();

  EquipmentTestDefinition? byId(String id) {
    final matches = definitions.where((d) => d.id == id);
    return matches.isEmpty ? null : matches.first;
  }
}
