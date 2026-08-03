import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Maximum number of capture records retained on disk.
const kMaxCaptureRecords = 100;

/// Maximum total size of the capture logs file before oldest records are pruned.
const kMaxCaptureLogBytes = 50 * 1024 * 1024; // 50 MB

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
///
/// Retention: keeps at most [kMaxCaptureRecords] records and at most
/// [kMaxCaptureLogBytes] total file size. Older records are pruned first.
///
/// Persistence is atomic: data is written to a temporary file, flushed to
/// disk, then the original file is replaced to reduce corruption risk.
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
  List<CaptureLogRecord> get all => _records.reversed.toList(growable: false);

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
      } catch (e) {
        // Corrupt file: keep empty and let the next save overwrite it.
        debugPrint('CaptureLogStore: failed to parse stored JSON: $e');
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

    // Apply retention limits before writing.
    _pruneRecords();

    final encoded = jsonEncode({
      'version': 1,
      'records': _records.map((record) => record.toJson()).toList(),
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

  /// Removes oldest records when the count or total size exceeds limits.
  void _pruneRecords() {
    // Sort oldest-first so we drop from the front.
    _records.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    while (_records.length > kMaxCaptureRecords) {
      _records.removeAt(0);
    }

    var totalBytes = _records.fold<int>(
      0,
      (sum, r) =>
          sum +
          r.lines.join('\n').length +
          (r.analysis?.toString().length ?? 0),
    );
    while (_records.isNotEmpty && totalBytes > kMaxCaptureLogBytes) {
      final removed = _records.removeAt(0);
      totalBytes -= removed.lines.join('\n').length +
          (removed.analysis?.toString().length ?? 0);
    }
  }
}
