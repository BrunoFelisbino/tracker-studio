import '../uce_interfaces.dart';

/// Registry of logical configuration parameters, per manufacturer.
class ParameterRegistry {
  final Map<String, ParameterDefinition> _byId = {};
  final Map<int, ParameterDefinition> _byParameterId = {};

  void register(ParameterDefinition definition) {
    _byId[definition.id] = definition;
    _byParameterId[definition.parameterId] = definition;
  }

  void registerAll(Iterable<ParameterDefinition> definitions) {
    for (final d in definitions) {
      register(d);
    }
  }

  ParameterDefinition? getById(String id) => _byId[id];

  ParameterDefinition? getByParameterId(int parameterId) =>
      _byParameterId[parameterId];

  List<ParameterDefinition> get all => _byId.values.toList();

  List<ParameterDefinition> byManufacturer(Manufacturer manufacturer) =>
      _byId.values
          .where((d) => d.manufacturer == manufacturer)
          .toList(growable: false);

  List<String> get groups {
    final seen = <String>{};
    for (final d in _byId.values) {
      if (d.group.isNotEmpty) seen.add(d.group);
    }
    return seen.toList()..sort();
  }

  List<ParameterDefinition> byGroup(String group) =>
      _byId.values.where((d) => d.group == group).toList(growable: false);

  List<ParameterDefinition> search(String query) {
    final q = query.toLowerCase();
    return _byId.values
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q) ||
            d.description.toLowerCase().contains(q))
        .toList();
  }

  void clear() {
    _byId.clear();
    _byParameterId.clear();
  }
}

/// Registry of AVL telemetry element definitions.
class AvlRegistry {
  final Map<int, AvlDefinition> _byAvlId = {};
  final Map<String, AvlDefinition> _byNormalizedKey = {};

  void register(AvlDefinition definition) {
    _byAvlId[definition.avlId] = definition;
    _byNormalizedKey[definition.normalizedKey] = definition;
  }

  void registerAll(Iterable<AvlDefinition> definitions) {
    for (final d in definitions) {
      register(d);
    }
  }

  AvlDefinition? getByAvlId(int avlId) => _byAvlId[avlId];

  AvlDefinition? getByNormalizedKey(String key) => _byNormalizedKey[key];

  List<AvlDefinition> get all => _byAvlId.values.toList();

  void clear() {
    _byAvlId.clear();
    _byNormalizedKey.clear();
  }
}

/// Registry of device commands.
class CommandRegistry {
  final Map<String, CommandDefinition> _byId = {};

  void register(CommandDefinition command) {
    _byId[command.id] = command;
  }

  void registerAll(Iterable<CommandDefinition> commands) {
    for (final c in commands) {
      register(c);
    }
  }

  CommandDefinition? getById(String id) => _byId[id];

  List<CommandDefinition> get all => _byId.values.toList();

  List<CommandDefinition> byManufacturer(Manufacturer manufacturer) =>
      _byId.values
          .where((c) => c.manufacturer == manufacturer)
          .toList(growable: false);

  void clear() {
    _byId.clear();
  }
}

/// Registry of expected response patterns.
class ResponseRegistry {
  final Map<String, ResponseDefinition> _byId = {};

  void register(ResponseDefinition response) {
    _byId[response.id] = response;
  }

  void registerAll(Iterable<ResponseDefinition> responses) {
    for (final r in responses) {
      register(r);
    }
  }

  ResponseDefinition? getById(String id) => _byId[id];

  List<ResponseDefinition> get all => _byId.values.toList();

  List<ResponseDefinition> byManufacturer(Manufacturer manufacturer) =>
      _byId.values
          .where((r) => r.manufacturer == manufacturer)
          .toList(growable: false);

  /// Returns the first response definition whose pattern appears in [text].
  ResponseDefinition? matching(String text) {
    for (final r in _byId.values) {
      if (r.matches(text)) return r;
    }
    return null;
  }

  void clear() {
    _byId.clear();
  }
}

/// Central Universal Command Engine registry.
///
/// All sub-registries are shared across instances so that a manufacturer
/// driver can register its catalog once (`TeltonikaDriver.registerAll()`) and
/// any code can read it through a plain `UceRegistry()`.
class UceRegistry {
  UceRegistry();

  static final ParameterRegistry _parameters = ParameterRegistry();
  static final AvlRegistry _avl = AvlRegistry();
  static final CommandRegistry _commands = CommandRegistry();
  static final ResponseRegistry _responses = ResponseRegistry();

  ParameterRegistry get parameters => _parameters;
  AvlRegistry get avl => _avl;
  CommandRegistry get commands => _commands;
  ResponseRegistry get responses => _responses;

  /// Clears every catalog before registering a new set of definitions.
  static void initialize() {
    _parameters.clear();
    _avl.clear();
    _commands.clear();
    _responses.clear();
  }

  static void reset() => initialize();

  /// Convenience: registers a single parameter.
  void registerParameter(ParameterDefinition definition) =>
      _parameters.register(definition);

  /// Convenience: registers a single AVL definition.
  void registerAvl(AvlDefinition definition) => _avl.register(definition);

  /// Convenience: registers a single command.
  void registerCommand(CommandDefinition command) =>
      _commands.register(command);

  /// Convenience: registers a single response pattern.
  void registerResponse(ResponseDefinition response) =>
      _responses.register(response);
}
