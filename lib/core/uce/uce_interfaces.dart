/// Universal Command Engine - public contracts.
///
/// The UCE keeps the logical model of a tracking device (parameters, AVL
/// telemetry IDs, commands and response patterns) independent from any
/// manufacturer. Each manufacturer registers its own catalog through
/// [UceRegistry] and the front-end renders the logical tree without knowing
/// which device it is talking to.
library;

/// Supported device manufacturers.
enum Manufacturer {
  unknown,
  suntech,
  teltonika,
  queclink,
  calamp,
  generic,
}

/// Logical category of a configuration parameter.
enum ParameterCategory {
  network,
  server,
  moving,
  gps,
  vehicle,
  engine,
  power,
  io,
  bluetooth,
  security,
  system,
  unknown,
}

/// Origin of an AVL IO element definition.
///
/// IOs inferred from field observations are NOT treated as official
/// catalog entries. Each definition must declare its provenance so
/// consumers can distinguish officially documented IDs from
/// community-contributed or user-mapped ones.
enum IoDefinitionSource {
  /// Published by the device manufacturer (manual, SDK, protocol doc).
  officialDocumentation,

  /// Observed on a real device during a technician session, then
  /// tentatively named by the community.
  deviceObservation,

  /// Contributed by the open-source community without formal verification.
  communityContribution,

  /// Created by a technician through the manual IO mapping UI.
  userMapping,

  /// Unknown / unverified origin.
  unknown,
}

/// Confidence level of an AVL IO element definition.
enum IoDefinitionConfidence {
  /// Confirmed by official documentation or repeated observations.
  confirmed,

  /// Likely correct based on observed behavior, but not formally documented.
  probable,

  /// Experimental mapping; needs further validation.
  experimental,

  /// Origin and correctness are unknown.
  unknown,
}

/// How a parameter value is entered/displayed.
enum ParameterValueType {
  string,
  number,
  boolean,
  ipAddress,
  port,
  apn,
  enumValue,
  hex,
  byte,
  list,
}

/// Risk of changing a parameter or executing a command.
enum RiskLevel { readOnly, safe, configuration, destructive }

/// Transport channels a command can travel through.
enum CommandTransport {
  usb,
  terminal,
  serial,
  sms,
  bluetooth,
  tcp,
  udp,
  codec12,
  serverCommand,
}

/// Logical group of an AVL telemetry element.
enum AvlCategory {
  input,
  output,
  ignition,
  power,
  battery,
  gps,
  fuel,
  movement,
  network,
  signal,
  emergency,
  odometer,
  driver,
  trip,
  can,
  accelerometer,
  system,
  unknown,
}

/// A single logical configuration parameter.
///
/// `parameterId` is the manufacturer-specific ID used by the command protocol
/// (e.g. Teltonika `:cfg_setparam:<parameterId>:<value>`), so the same logical
/// field renders in the front-end regardless of the device underneath.
class ParameterDefinition {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? supportedModels;
  final ParameterCategory category;
  final String group;
  final String name;
  final String description;

  /// Command identifier that writes this parameter (see [CommandDefinition.id]).
  final String command;
  final int parameterId;
  final ParameterValueType valueType;

  final dynamic defaultValue;
  final num? minimum;
  final num? maximum;
  final String? unit;
  final Map<String, String>? enumValues;

  final bool readable;
  final bool writable;
  final bool requiresSave;
  final bool requiresReboot;
  final RiskLevel risk;

  final String? documentationSource;
  final String? validationStatus;

  const ParameterDefinition({
    required this.id,
    required this.manufacturer,
    this.supportedModels,
    required this.category,
    this.group = '',
    required this.name,
    this.description = '',
    this.command = 'set_parameter',
    required this.parameterId,
    required this.valueType,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.unit,
    this.enumValues,
    this.readable = true,
    this.writable = true,
    this.requiresSave = true,
    this.requiresReboot = false,
    this.risk = RiskLevel.safe,
    this.documentationSource,
    this.validationStatus,
  });

  /// Renders the command payload for this parameter using [template].
  ///
  /// Supported placeholders: `{parameterId}`, `{value}`.
  String render(String template, dynamic value) => template
      .replaceAll('{parameterId}', '$parameterId')
      .replaceAll('{value}', '$value');

  Map<String, dynamic> toJson() => {
        'id': id,
        'manufacturer': manufacturer.name,
        'category': category.name,
        'group': group,
        'name': name,
        'command': command,
        'parameterId': parameterId,
        'valueType': valueType.name,
        'defaultValue': defaultValue,
        'minimum': minimum,
        'maximum': maximum,
        'unit': unit,
        'readable': readable,
        'writable': writable,
        'requiresSave': requiresSave,
        'requiresReboot': requiresReboot,
        'risk': risk.name,
        'enumValues': enumValues,
      };
}

/// Definition of an AVL telemetry element observed on the bus.
class AvlDefinition {
  final int avlId;
  final String name;
  final String normalizedKey;
  final AvlCategory category;
  final String? description;
  final String? rawUnit;
  final String? displayUnit;

  /// Converts a raw value into the display unit (e.g. mV -> V).
  final num? multiplier;

  /// Origin of this definition.
  final IoDefinitionSource source;

  /// Confidence level of this definition.
  final IoDefinitionConfidence confidence;

  /// Manufacturer-specific fields allowing the catalog to distinguish
  /// definitions across manufacturers, models, families and firmware.
  final Manufacturer manufacturer;
  final String? model;
  final String? family;
  final String? firmware;
  final int? codec;

  /// Free-form provenance string (e.g. "Teltonika FMB XXX Protocol, p. 42").
  final String? documentationSource;

  const AvlDefinition({
    required this.avlId,
    required this.name,
    required this.normalizedKey,
    required this.category,
    this.description,
    this.rawUnit,
    this.displayUnit,
    this.multiplier,
    this.source = IoDefinitionSource.officialDocumentation,
    this.confidence = IoDefinitionConfidence.confirmed,
    this.manufacturer = Manufacturer.unknown,
    this.model,
    this.family,
    this.firmware,
    this.codec,
    this.documentationSource,
  });

  /// Applies [multiplier] to raw numeric values.
  dynamic convertValue(dynamic raw) {
    if (multiplier == null) return raw;
    if (raw is num) return raw * multiplier!;
    if (raw is String) {
      final parsed = num.tryParse(raw);
      if (parsed != null) return parsed * multiplier!;
    }
    return raw;
  }

  /// Whether this definition originates from official manufacturer documentation.
  bool get isOfficiallyDocumented =>
      source == IoDefinitionSource.officialDocumentation &&
      confidence == IoDefinitionConfidence.confirmed;

  /// Convenience for IOs that are not in any catalog (IO 12, 16, 24, 199, etc.).
  /// These should appear as "not cataloged" / "CAN sensor candidate".
  bool get isUncataloged =>
      source == IoDefinitionSource.unknown &&
      confidence == IoDefinitionConfidence.unknown;

  Map<String, dynamic> toJson() => {
        'avlId': avlId,
        'name': name,
        'normalizedKey': normalizedKey,
        'category': category.name,
        'description': description,
        'rawUnit': rawUnit,
        'displayUnit': displayUnit,
        'multiplier': multiplier,
        'source': source.name,
        'confidence': confidence.name,
        'manufacturer': manufacturer.name,
        'model': model,
        'family': family,
        'firmware': firmware,
        'codec': codec,
        'documentationSource': documentationSource,
        'sourceStatus': source.name,
      };
}

/// A device command with its wire template.
class CommandDefinition {
  final String id;
  final Manufacturer manufacturer;
  final List<String>? supportedModels;
  final String name;
  final String description;
  final List<CommandTransport> transport;

  /// Wire template with placeholders (e.g. `:cfg_setparam:{parameterId}:{value}`).
  final String commandTemplate;
  final Duration timeout;
  final RiskLevel risk;
  final bool requiresConfirmation;

  CommandDefinition({
    required this.id,
    required this.manufacturer,
    this.supportedModels,
    required this.name,
    this.description = '',
    this.transport = const [CommandTransport.usb],
    required this.commandTemplate,
    this.timeout = const Duration(seconds: 3),
    this.risk = RiskLevel.readOnly,
    this.requiresConfirmation = false,
  });

  /// Replaces `{placeholder}` tokens with [args].
  String buildCommand(Map<String, dynamic> args) {
    var out = commandTemplate;
    args.forEach((k, v) {
      out = out.replaceAll('{$k}', '$v');
    });
    return out;
  }

  bool isCompatibleTransport(CommandTransport t) => transport.contains(t);

  Map<String, dynamic> toJson() => {
        'id': id,
        'manufacturer': manufacturer.name,
        'name': name,
        'transport': transport.map((t) => t.name).toList(),
        'commandTemplate': commandTemplate,
        'timeoutMs': timeout.inMilliseconds,
        'risk': risk.name,
        'requiresConfirmation': requiresConfirmation,
      };
}

/// Expected response pattern of a command.
class ResponseDefinition {
  final String id;
  final Manufacturer manufacturer;
  final String pattern;
  final String description;
  final String? parserFunction;

  const ResponseDefinition({
    required this.id,
    required this.manufacturer,
    required this.pattern,
    this.description = '',
    this.parserFunction,
  });

  bool matches(String text) => text.contains(pattern);

  Map<String, dynamic> toJson() => {
        'id': id,
        'manufacturer': manufacturer.name,
        'pattern': pattern,
        'parserFunction': parserFunction,
      };
}
