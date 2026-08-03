import 'equipment_lab_types.dart';

/// Registro versionado de definições de campos.
class FieldRegistry {
  FieldRegistry({required this.version, required this.definitions});

  final String version;
  final List<EquipmentFieldDefinition> definitions;

  List<EquipmentFieldDefinition> forManufacturer(Manufacturer m) =>
      definitions.where((d) => d.manufacturer == m).toList();

  EquipmentFieldDefinition? byId(String id) {
    final matches = definitions.where((d) => d.id == id);
    return matches.isEmpty ? null : matches.first;
  }
}
