import 'dart:convert';

enum ConfigurationValueStatus {
  unchanged,
  changed,
  pendingReadback,
  confirmed,
  failed,
  notSupported,
}

enum DeviceCommandChannel { usb, sms, gprs }

enum DeviceCommandExecutionStatus {
  queued,
  sent,
  accepted,
  confirmed,
  failed,
  canceled,
}

typedef CommandExecutionClock = DateTime Function();

class CommandExecutionRecord {
  final DeviceCommandChannel channel;
  final String model;
  final String firmware;
  final String esn;
  final Map<String, Object?> commandMetadata;
  final String maskedRawCommand;
  final String rawResponse;
  final DateTime sentAt;
  final DateTime? responseAt;
  final Duration? duration;
  final String transport;
  final Object? parsedResult;
  final bool confirmation;
  final String error;
  final String correlationId;

  CommandExecutionRecord._({
    required this.channel,
    required this.model,
    required this.firmware,
    required this.esn,
    required this.commandMetadata,
    required this.maskedRawCommand,
    required this.rawResponse,
    required this.sentAt,
    required this.responseAt,
    required this.duration,
    required this.transport,
    required this.parsedResult,
    required this.confirmation,
    required this.error,
    required this.correlationId,
  });

  factory CommandExecutionRecord.sent({
    required DeviceCommandChannel channel,
    required String rawCommand,
    required String transport,
    required String correlationId,
    String model = '',
    String firmware = '',
    String esn = '',
    Map<String, Object?> commandMetadata = const {},
    CommandExecutionClock? clock,
  }) {
    return CommandExecutionRecord._(
      channel: channel,
      model: model,
      firmware: firmware,
      esn: esn,
      commandMetadata: _maskSensitiveMap(commandMetadata),
      maskedRawCommand: maskSensitiveCommand(rawCommand),
      rawResponse: '',
      sentAt: (clock ?? DateTime.now)(),
      responseAt: null,
      duration: null,
      transport: transport,
      parsedResult: null,
      confirmation: false,
      error: '',
      correlationId: correlationId,
    );
  }

  CommandExecutionRecord recordResponse({
    required String rawResponse,
    Object? parsedResult,
    bool confirmation = false,
    String error = '',
    CommandExecutionClock? clock,
  }) {
    final receivedAt = (clock ?? DateTime.now)();
    if (receivedAt.isBefore(sentAt)) {
      throw ArgumentError.value(
        receivedAt,
        'clock',
        'Response time cannot precede the sent time.',
      );
    }
    return CommandExecutionRecord._(
      channel: channel,
      model: model,
      firmware: firmware,
      esn: esn,
      commandMetadata: commandMetadata,
      maskedRawCommand: maskedRawCommand,
      rawResponse: maskSensitiveCommand(rawResponse),
      sentAt: sentAt,
      responseAt: receivedAt,
      duration: receivedAt.difference(sentAt),
      transport: transport,
      parsedResult: _maskSensitiveValue(parsedResult),
      confirmation: confirmation,
      error: maskSensitiveCommand(error),
      correlationId: correlationId,
    );
  }

  Map<String, Object?> toJson() => {
        'channel': channel.name,
        'model': model,
        'firmware': firmware,
        'esn': esn,
        'commandMetadata': commandMetadata,
        'maskedRawCommand': maskedRawCommand,
        'rawResponse': rawResponse,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'responseAt': responseAt?.toUtc().toIso8601String(),
        'durationMs': duration?.inMilliseconds,
        'transport': transport,
        'parsedResult': parsedResult,
        'confirmation': confirmation,
        'error': error,
        'correlationId': correlationId,
      };
}

enum TechnicalTestStatus {
  notStarted,
  running,
  passed,
  warning,
  failed,
  notApplicable,
  pending,
}

class DeviceConfigurationSnapshot {
  final String id;
  final String sessionId;
  final String source;
  final DateTime capturedAt;
  final String manufacturer;
  final String family;
  final String model;
  final String firmware;
  final String esn;
  final String apn;
  final String apnUsername;
  final String apnPasswordMasked;
  final String primaryServer;
  final int? primaryPort;
  final String secondaryServer;
  final int? secondaryPort;
  final String vehicleProfile;
  final bool? sleepEnabled;
  final String ignitionMode;
  final bool? blockingEnabled;
  final Map<String, Object?> transmissionSettings;
  final Map<String, Object?> rawValues;

  const DeviceConfigurationSnapshot({
    required this.id,
    required this.sessionId,
    required this.source,
    required this.capturedAt,
    this.manufacturer = '',
    this.family = '',
    this.model = '',
    this.firmware = '',
    this.esn = '',
    this.apn = '',
    this.apnUsername = '',
    this.apnPasswordMasked = '',
    this.primaryServer = '',
    this.primaryPort,
    this.secondaryServer = '',
    this.secondaryPort,
    this.vehicleProfile = '',
    this.sleepEnabled,
    this.ignitionMode = '',
    this.blockingEnabled,
    this.transmissionSettings = const {},
    this.rawValues = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'source': source,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'manufacturer': manufacturer,
        'family': family,
        'model': model,
        'firmware': firmware,
        'esn': esn,
        'apn': apn,
        'apnUsername': apnUsername,
        'apnPasswordMasked': apnPasswordMasked,
        'primaryServer': primaryServer,
        'primaryPort': primaryPort,
        'secondaryServer': secondaryServer,
        'secondaryPort': secondaryPort,
        'vehicleProfile': vehicleProfile,
        'sleepEnabled': sleepEnabled,
        'ignitionMode': ignitionMode,
        'blockingEnabled': blockingEnabled,
        'transmissionSettings': transmissionSettings,
        'rawValues': rawValues,
      };

  String toJsonString() => jsonEncode(toJson());
}

class ConfigurationChangeItem {
  final String key;
  final String label;
  final Object? previousValue;
  final Object? requestedValue;
  final Object? confirmedValue;
  final ConfigurationValueStatus status;
  final String commandId;
  final String notes;

  const ConfigurationChangeItem({
    required this.key,
    required this.label,
    required this.previousValue,
    required this.requestedValue,
    this.confirmedValue,
    required this.status,
    this.commandId = '',
    this.notes = '',
  });

  bool get changed => previousValue != requestedValue;
  bool get readbackMatches => confirmedValue == requestedValue;

  Map<String, Object?> toJson() => {
        'key': key,
        'label': label,
        'previousValue': previousValue,
        'requestedValue': requestedValue,
        'confirmedValue': confirmedValue,
        'status': status.name,
        'commandId': commandId,
        'notes': notes,
      };
}

class DeviceCommandAuditEntry {
  final String id;
  final String sessionId;
  final DateTime createdAt;
  final DeviceCommandChannel channel;
  final String purpose;
  final String commandId;
  final String commandMasked;
  final String responseMasked;
  final DeviceCommandExecutionStatus status;
  final bool readbackRequired;
  final bool readbackConfirmed;
  final String errorMessage;
  final Map<String, Object?> metadata;

  const DeviceCommandAuditEntry({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.channel,
    required this.purpose,
    required this.commandId,
    required this.commandMasked,
    this.responseMasked = '',
    required this.status,
    this.readbackRequired = false,
    this.readbackConfirmed = false,
    this.errorMessage = '',
    this.metadata = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'channel': channel.name,
        'purpose': purpose,
        'commandId': commandId,
        'commandMasked': commandMasked,
        'responseMasked': responseMasked,
        'status': status.name,
        'readbackRequired': readbackRequired,
        'readbackConfirmed': readbackConfirmed,
        'errorMessage': errorMessage,
        'metadata': metadata,
      };
}

class TechnicalTestRecord {
  final String id;
  final String label;
  final TechnicalTestStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String expected;
  final String measured;
  final String evidence;
  final String pendingReason;

  const TechnicalTestRecord({
    required this.id,
    required this.label,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.expected = '',
    this.measured = '',
    this.evidence = '',
    this.pendingReason = '',
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'status': status.name,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'expected': expected,
        'measured': measured,
        'evidence': evidence,
        'pendingReason': pendingReason,
      };
}

class TechnicalSessionReportData {
  final String version;
  final String sessionId;
  final String workOrderId;
  final String technicianId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DeviceConfigurationSnapshot? before;
  final DeviceConfigurationSnapshot? after;
  final List<ConfigurationChangeItem> changes;
  final List<DeviceCommandAuditEntry> commands;
  final List<TechnicalTestRecord> tests;
  final List<String> pendingItems;
  final String finalStatus;

  const TechnicalSessionReportData({
    this.version = '1.0',
    required this.sessionId,
    this.workOrderId = '',
    this.technicianId = '',
    required this.startedAt,
    this.finishedAt,
    this.before,
    this.after,
    this.changes = const [],
    this.commands = const [],
    this.tests = const [],
    this.pendingItems = const [],
    this.finalStatus = 'pending',
  });

  bool get hasUnconfirmedChanges => changes.any(
        (item) =>
            item.changed && item.status != ConfigurationValueStatus.confirmed,
      );

  bool get hasFailedTests =>
      tests.any((item) => item.status == TechnicalTestStatus.failed);

  bool get hasPendingTests => tests.any(
        (item) =>
            item.status == TechnicalTestStatus.pending ||
            item.status == TechnicalTestStatus.notStarted,
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'sessionId': sessionId,
        'workOrderId': workOrderId,
        'technicianId': technicianId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'before': before?.toJson(),
        'after': after?.toJson(),
        'changes': changes.map((item) => item.toJson()).toList(),
        'commands': commands.map((item) => item.toJson()).toList(),
        'tests': tests.map((item) => item.toJson()).toList(),
        'pendingItems': pendingItems,
        'finalStatus': finalStatus,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

String maskSensitiveCommand(String command) {
  var masked = command;
  final patterns = <RegExp>[
    RegExp(
      r'(;\s*03\s*)(#\s*)([^;\r\n]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'(password|passwd|pwd)(\s*[:=;]\s*)([^;,\s]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'(token|secret|authorization)(\s*[:=;]\s*)([^;,\s]+)',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    masked = masked.replaceAllMapped(
      pattern,
      (match) => '${match.group(1)}${match.group(2)}***',
    );
  }
  return masked;
}

Map<String, Object?> _maskSensitiveMap(Map<String, Object?> values) =>
    Map.unmodifiable({
      for (final entry in values.entries)
        entry.key: _isSensitiveKey(entry.key)
            ? '***'
            : _maskSensitiveValue(entry.value),
    });

Object? _maskSensitiveValue(Object? value) {
  if (value is String) return maskSensitiveCommand(value);
  if (value is Map<String, Object?>) return _maskSensitiveMap(value);
  if (value is List<Object?>) {
    return List.unmodifiable(value.map(_maskSensitiveValue));
  }
  return value;
}

bool _isSensitiveKey(String key) => RegExp(
      r'password|passwd|pwd|token|secret|authorization',
      caseSensitive: false,
    ).hasMatch(key);
