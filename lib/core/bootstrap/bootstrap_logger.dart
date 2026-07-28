import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bootstrap_models.dart';

abstract final class BootstrapLogger {
  static void log(
    String event, {
    BootstrapStep? step,
    DateTime? timestamp,
    Duration? duration,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final payload = <String, Object?>{
      'event': event,
      'step': step?.name ?? 'bootstrap',
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      'durationMs': duration?.inMilliseconds ?? 0,
      'error': error == null ? null : _safeError(error),
      if (kDebugMode && stackTrace != null) 'stackTrace': '$stackTrace',
    };
    debugPrint(jsonEncode(payload));
  }

  static String _safeError(Object error) {
    if (error is BootstrapStepException) return error.safeMessage;
    return 'Falha de inicializacao (${error.runtimeType}).';
  }
}
