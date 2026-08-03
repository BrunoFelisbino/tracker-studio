import '../uce_interfaces.dart';
import 'uce_registry.dart';

/// Maps a catalog [ParameterDefinition] to an editable form field.
///
/// Adding a new editable field to the front-end is just registering a
/// `ParameterDefinition` in the manufacturer catalog (documentation -> link):
/// label, type, defaults, enum options, units and validation are all derived
/// from the UCE metadata.
class ConfigFieldSpec {
  final ParameterDefinition definition;

  const ConfigFieldSpec(this.definition);

  int get parameterId => definition.parameterId;
  String get label => definition.name;
  String get description => definition.description;
  dynamic get defaultValue => definition.defaultValue;
  num? get minimum => definition.minimum;
  num? get maximum => definition.maximum;
  String? get unit => definition.unit;
  Map<String, String>? get enumValues => definition.enumValues;

  /// Whether the value should be masked while typing (e.g. APN password).
  bool get obscureText =>
      definition.valueType == ParameterValueType.string &&
      (definition.id.toLowerCase().contains('password') ||
          definition.name.toLowerCase().contains('password'));

  /// Whether the value is entered as a plain text field.
  bool get isText =>
      definition.valueType == ParameterValueType.string ||
      definition.valueType == ParameterValueType.apn ||
      definition.valueType == ParameterValueType.ipAddress ||
      definition.valueType == ParameterValueType.hex;

  /// Whether the value is a number (with optional min/max/unit).
  bool get isNumeric =>
      definition.valueType == ParameterValueType.number ||
      definition.valueType == ParameterValueType.port ||
      definition.valueType == ParameterValueType.byte;

  /// Whether the value is selected from a fixed list of options.
  bool get isEnum =>
      definition.valueType == ParameterValueType.enumValue &&
      definition.enumValues != null;

  /// Validates a user-typed [input] against the catalog metadata.
  String? validate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'Valor obrigatório para ${definition.name}.';
    if (RegExp(r'[;:#\r\n]').hasMatch(trimmed)) {
      return 'Valor contém caractere reservado (; : #).';
    }
    if (definition.valueType == ParameterValueType.port) {
      final port = int.tryParse(trimmed);
      if (port == null || port < 1 || port > 65535) {
        return 'Porta deve ser um inteiro entre 1 e 65535.';
      }
    }
    if (isNumeric) {
      final value = num.tryParse(trimmed);
      if (value == null) return 'Valor numérico inválido.';
      if (minimum != null && value < minimum!) {
        return 'Mínimo: $minimum${unit != null ? ' $unit' : ''}.';
      }
      if (maximum != null && value > maximum!) {
        return 'Máximo: $maximum${unit != null ? ' $unit' : ''}.';
      }
    }
    if (isEnum && !enumValues!.containsKey(trimmed)) {
      return 'Opções: ${enumValues!.values.join(', ')}.';
    }
    return null;
  }
}

/// Resolves the [ConfigFieldSpec] for a registered catalog [parameterId].
ConfigFieldSpec configFieldFor(int parameterId) {
  final definition = UceRegistry().parameters.getByParameterId(parameterId);
  if (definition == null) {
    throw StateError('Parâmetro $parameterId não registrado no catálogo UCE.');
  }
  return ConfigFieldSpec(definition);
}
