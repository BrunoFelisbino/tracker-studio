import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Maximum number of user-defined CAN mappings retained on disk.
const kMaxCanMappings = 500;

/// A user-defined mapping for an observed AVL IO element (CAN sensor) that has
/// no catalog definition. Persisted so the mapping survives between sessions.
class CanSensorMapping {
  final int avlId;
  final String name;
  final String? unit;
  final String? note;

  const CanSensorMapping({
    required this.avlId,
    required this.name,
    this.unit,
    this.note,
  });

  CanSensorMapping copyWith({String? name, String? unit, String? note}) {
    return CanSensorMapping(
      avlId: avlId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'avlId': avlId,
        'name': name,
        'unit': unit,
        'note': note,
      };

  factory CanSensorMapping.fromJson(Map<String, dynamic> json) {
    return CanSensorMapping(
      avlId: json['avlId'] as int,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String?,
      note: json['note'] as String?,
    );
  }
}

/// Persists [CanSensorMapping] entries to a JSON file in the application
/// support directory (injectable for tests).
///
/// Retention: keeps at most [kMaxCanMappings] entries.
///
/// Persistence is atomic: data is written to a temporary file, flushed to
/// disk, then the original file is replaced to reduce corruption risk.
class CanMappingStore {
  final Future<String> Function() _pathResolver;
  final Map<int, CanSensorMapping> _mappings = {};
  bool _loaded = false;

  CanMappingStore({Future<String> Function()? pathResolver})
      : _pathResolver = pathResolver ?? _defaultPath;

  static Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    return path.join(directory.path, 'tracker_studio_can_mapping.json');
  }

  Future<File> _file() async => File(await _pathResolver());

  bool get isLoaded => _loaded;

  /// All mappings sorted by AVL ID.
  List<CanSensorMapping> get all {
    final list = _mappings.values.toList()
      ..sort((a, b) => a.avlId.compareTo(b.avlId));
    return list;
  }

  CanSensorMapping? byId(int avlId) => _mappings[avlId];

  Future<void> load() async {
    if (_loaded) return;
    final file = await _file();
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final entries = decoded['mappings'];
          if (entries is List) {
            for (final entry in entries) {
              if (entry is Map<String, dynamic>) {
                final mapping = CanSensorMapping.fromJson(entry);
                if (mapping.avlId > 0 && mapping.name.isNotEmpty) {
                  _mappings[mapping.avlId] = mapping;
                }
              }
            }
          }
        }
      } catch (e) {
        // Corrupt file: keep an empty mapping and let save overwrite it.
        debugPrint('CanMappingStore: failed to parse stored JSON: $e');
      }
    }
    _loaded = true;
  }

  Future<void> upsert(CanSensorMapping mapping) async {
    _mappings[mapping.avlId] = mapping;
    await save();
  }

  Future<void> remove(int avlId) async {
    _mappings.remove(avlId);
    await save();
  }

  Future<void> save() async {
    final file = await _file();
    await file.parent.create(recursive: true);

    // Apply retention limit.
    _pruneMappings();

    final encoded = jsonEncode({
      'version': 1,
      'mappings': _mappings.values.map((m) => m.toJson()).toList(),
    });

    // Atomic write: write to a temp file, sync, then replace.
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await tmpFile.copy(file.path);
    } else {
      await tmpFile.rename(file.path);
    }
    // Clean up temp file if it still exists (rename moves it).
    if (await tmpFile.exists()) {
      await tmpFile.delete(recursive: true);
    }
  }

  /// Removes oldest entries when the count exceeds the limit.
  void _pruneMappings() {
    if (_mappings.length <= kMaxCanMappings) return;
    final sorted = _mappings.values.toList()
      ..sort((a, b) => a.avlId.compareTo(b.avlId));
    final toRemove = sorted.sublist(0, sorted.length - kMaxCanMappings);
    for (final m in toRemove) {
      _mappings.remove(m.avlId);
    }
  }
}
