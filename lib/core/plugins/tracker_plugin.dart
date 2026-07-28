/// Public extension contract for Tracker Studio equipment and project plugins.
///
/// The core application must depend only on these contracts. Manufacturer-
/// specific parsing, commands, manuals and diagnostics belong in plugins.
abstract interface class TrackerStudioPlugin {
  PluginManifest get manifest;

  /// Returns true when this plugin can handle the supplied device identity.
  bool supports(DeviceIdentity device);

  /// Creates an isolated runtime session for the selected device.
  Future<TrackerPluginSession> openSession(DeviceConnection connection);
}

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.vendor,
    required this.version,
    required this.apiVersion,
    this.description = '',
    this.capabilities = const <PluginCapability>{},
  });

  final String id;
  final String name;
  final String vendor;
  final String version;
  final String apiVersion;
  final String description;
  final Set<PluginCapability> capabilities;
}

enum PluginCapability {
  serial,
  bluetooth,
  tcp,
  udp,
  sms,
  commandCatalog,
  diagnostics,
  firmwareInfo,
  iccidRead,
  installationWorkflow,
  reportExtension,
}

class DeviceIdentity {
  const DeviceIdentity({
    this.manufacturer,
    this.model,
    this.protocol,
    this.serialNumber,
    this.metadata = const <String, Object?>{},
  });

  final String? manufacturer;
  final String? model;
  final String? protocol;
  final String? serialNumber;
  final Map<String, Object?> metadata;
}

class DeviceConnection {
  const DeviceConnection({
    required this.transport,
    this.endpoint,
    this.settings = const <String, Object?>{},
  });

  final String transport;
  final String? endpoint;
  final Map<String, Object?> settings;
}

abstract interface class TrackerPluginSession {
  Stream<PluginEvent> get events;

  Future<PluginResult> execute(PluginCommand command);

  Future<void> close();
}

class PluginCommand {
  const PluginCommand({
    required this.id,
    this.arguments = const <String, Object?>{},
  });

  final String id;
  final Map<String, Object?> arguments;
}

class PluginResult {
  const PluginResult({
    required this.success,
    this.message,
    this.data = const <String, Object?>{},
  });

  final bool success;
  final String? message;
  final Map<String, Object?> data;
}

class PluginEvent {
  const PluginEvent({
    required this.type,
    required this.timestamp,
    this.data = const <String, Object?>{},
  });

  final String type;
  final DateTime timestamp;
  final Map<String, Object?> data;
}
