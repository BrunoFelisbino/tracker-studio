import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// One persisted capture window (logs + analysis) saved per session so the
/// technician can review or send it for analysis after closing the session.
class CaptureLogRecord {
  final String id;

  /// Session code the capture belongs to.
  final String sessionCode;
  final String startedAt;
  final String stoppedAt;

  /// Normalized captured lines (device responses + host commands).
  final List<String> lines;

  /// `TeltonikaCaptureAnalysis.toJson()` result (parameter values, device,
  /// record counts, warnings) or null when no analysis was produced.
  final Map<String, dynamic>? analysis;

  const CaptureLogRecord({
    required this.id,
    required this.sessionCode,
    required this.startedAt,
    required this.stoppedAt,
    required this.lines,
    this.analysis,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionCode': sessionCode,
        'startedAt': startedAt,
        'stoppedAt': stoppedAt,
        'lineCount': lines.length,
        'lines': lines,
        'analysis': analysis,
      };

  factory CaptureLogRecord.fromJson(Map<String, dynamic> json) {
    return CaptureLogRecord(
      id: json['id'] as String? ?? '',
      sessionCode: json['sessionCode'] as String? ?? '',
      startedAt: json['startedAt'] as String? ?? '',
      stoppedAt: json['stoppedAt'] as String? ?? '',
      lines: (json['lines'] as List? ?? [])
          .whereType<String>()
          .toList(growable: false),
      analysis: json['analysis'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['analysis'] as Map)
          : null,
    );
  }
}

/// Persists [CaptureLogRecord] entries to a JSON file in the application
/// support directory (injectable for tests), one record per saved capture.
class CaptureLogStore {
  final Future<String> Function() _pathResolver;
  final List<CaptureLogRecord> _records = [];

  CaptureLogStore({Future<String> Function()? pathResolver})
      : _pathResolver = pathResolver ?? _defaultPath;

  static Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    return path.join(directory.path, 'tracker_studio_capture_logs.json');
  }

  Future<File> _file() async => File(await _pathResolver());

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Saved records, most recent first.
  List<CaptureLogRecord> get all =>
      _records.reversed.toList(growable: false);

  Future<void> load() async {
    if (_loaded) return;
    final file = await _file();
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final entries = decoded['records'];
          if (entries is List) {
            for (final entry in entries) {
              if (entry is Map<String, dynamic>) {
                _records.add(CaptureLogRecord.fromJson(entry));
              }
            }
          }
        }
      } catch (_) {
        // Corrupt file: keep empty and let the next save overwrite it.
      }
    }
    _loaded = true;
  }

  Future<void> append(CaptureLogRecord record) async {
    await load();
    _records.add(record);
    await save();
  }

  Future<void> save() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'version': 1,
      'records': _records.map((record) => record.toJson()).toList(),
    }));
  }
}
