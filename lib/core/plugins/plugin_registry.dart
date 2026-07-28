import 'tracker_plugin.dart';

/// In-memory registry used by the application core to discover plugins.
///
/// Registration is explicit so plugins cannot silently override one another.
class PluginRegistry {
  final Map<String, TrackerStudioPlugin> _plugins =
      <String, TrackerStudioPlugin>{};

  Iterable<TrackerStudioPlugin> get plugins => _plugins.values;

  void register(TrackerStudioPlugin plugin) {
    final id = plugin.manifest.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'plugin.manifest.id', 'must not be empty');
    }
    if (_plugins.containsKey(id)) {
      throw StateError('Plugin already registered: $id');
    }
    _plugins[id] = plugin;
  }

  TrackerStudioPlugin? byId(String id) => _plugins[id];

  TrackerStudioPlugin? resolve(DeviceIdentity device) {
    for (final plugin in _plugins.values) {
      if (plugin.supports(device)) return plugin;
    }
    return null;
  }

  bool unregister(String id) => _plugins.remove(id) != null;
}
