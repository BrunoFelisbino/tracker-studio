import 'dart:typed_data';
import 'dart:convert';

import '../../../uce/uce_interfaces.dart';

/// Represents a single USB capture chunk with full traceability
class UsbCaptureChunk {
  final String id;
  final String fileId;
  final int packetNumber;
  final DateTime timestamp;

  final int interfaceId;
  final int busId;
  final int deviceAddress;
  final int endpoint;

  final String direction;
  final String transferType;

  final Uint8List rawBytes;
  final String hex;

  String? asciiCandidate;

  UsbCaptureChunk({
    required this.id,
    required this.fileId,
    required this.packetNumber,
    required this.timestamp,
    required this.interfaceId,
    required this.busId,
    required this.deviceAddress,
    required this.endpoint,
    required this.direction,
    required this.transferType,
    required this.rawBytes,
    required this.hex,
    this.asciiCandidate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileId': fileId,
    'packetNumber': packetNumber,
    'timestamp': timestamp.toIso8601String(),
    'interfaceId': interfaceId,
    'busId': busId,
    'deviceAddress': deviceAddress,
    'endpoint': '0x${endpoint.toRadixString(16).padLeft(2, '0')}',
    'direction': direction,
    'transferType': transferType,
    'byteLength': rawBytes.length,
    'hex': hex,
    'asciiCandidate': asciiCandidate,
  };
}

/// Key for grouping USB stream chunks
class UsbStreamKey {
  final int interfaceId;
  final int deviceAddress;
  final int endpoint;
  final String direction;

  const UsbStreamKey({
    required this.interfaceId,
    required this.deviceAddress,
    required this.endpoint,
    required this.direction,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbStreamKey &&
          runtimeType == other.runtimeType &&
          interfaceId == other.interfaceId &&
          deviceAddress == other.deviceAddress &&
          endpoint == other.endpoint &&
          direction == other.direction;

  @override
  int get hashCode =>
      interfaceId.hashCode ^
      deviceAddress.hashCode ^
      endpoint.hashCode ^
      direction.hashCode;

  String get keyString => '$interfaceId-$deviceAddress-${endpoint.toRadixString(16)}-$direction';
}

/// Reassembled USB stream from multiple chunks
class ReassembledUsbStream {
  final UsbStreamKey key;
  final List<UsbCaptureChunk> chunks;
  final Uint8List bytes;
  final String text;

  ReassembledUsbStream({
    required this.key,
    required this.chunks,
    required this.bytes,
    required this.text,
  });

  int get chunkCount => chunks.length;
  int get byteLength => bytes.length;

  Map<String, dynamic> toJson() => {
    'key': key.keyString,
    'chunkCount': chunkCount,
    'byteLength': byteLength,
    'textLength': text.length,
    'textPreview': text.length > 500 ? text.substring(0, 500) : text,
    'firstTimestamp': chunks.first.timestamp.toIso8601String(),
    'lastTimestamp': chunks.last.timestamp.toIso8601String(),
    'packetNumbers': chunks.map((c) => c.packetNumber).toList(),
  };
}

/// Extracted text fragment with metadata
class ExtractedTextFragment {
  final String id;
  final UsbStreamKey streamKey;
  final int packetStart;
  final int packetEnd;
  final DateTime timestampStart;
  final DateTime timestampEnd;
  final String text;
  final Uint8List rawBytes;
  final String encoding;
  final double confidence;

  ExtractedTextFragment({
    required this.id,
    required this.streamKey,
    required this.packetStart,
    required this.packetEnd,
    required this.timestampStart,
    required this.timestampEnd,
    required this.text,
    required this.rawBytes,
    required this.encoding,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'streamKey': streamKey.keyString,
    'packetStart': packetStart,
    'packetEnd': packetEnd,
    'timestampStart': timestampStart.toIso8601String(),
    'timestampEnd': timestampEnd.toIso8601String(),
    'text': text,
    'encoding': encoding,
    'confidence': confidence,
  };
}

/// Reconstructed log line from fragments
class ReconstructedLogLine {
  final String id;
  final DateTime? timestamp;
  final String? category;
  final String message;
  final bool complete;
  final double reconstructionConfidence;
  final List<int> packetReferences;
  final List<String> rawFragments;
  final List<Uint8List> rawBytes;

  ReconstructedLogLine({
    required this.id,
    this.timestamp,
    this.category,
    required this.message,
    required this.complete,
    required this.reconstructionConfidence,
    required this.packetReferences,
    required this.rawFragments,
    required this.rawBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp?.toIso8601String(),
    'category': category,
    'message': message,
    'complete': complete,
    'reconstructionConfidence': reconstructionConfidence,
    'packetReferences': packetReferences,
    'rawFragments': rawFragments,
    'rawBytesHex': rawBytes.map((b) => bytesToHex(b)).toList(),
  };
}

/// Teltonika device identity detected from USB capture
class DetectedTeltonikaDevice {
  final String manufacturer = 'teltonika';
  final String? model;
  final String? imei;
  final String? iccid;
  final String? firmware;
  final String? internalFirmware;
  final String? hardwareVersion;
  final String? bootloaderVersion;
  final String? modemVersion;
  final String? bluetoothMac;
  final String? accelerometerModel;
  final double confidence;
  final List<String> evidence;

  DetectedTeltonikaDevice({
    this.model,
    this.imei,
    this.iccid,
    this.firmware,
    this.internalFirmware,
    this.hardwareVersion,
    this.bootloaderVersion,
    this.modemVersion,
    this.bluetoothMac,
    this.accelerometerModel,
    required this.confidence,
    required this.evidence,
  });

  Map<String, dynamic> toJson() => {
    'manufacturer': manufacturer,
    'model': model,
    'imei': imei != null ? _maskImei(imei!) : null,
    'iccid': iccid != null ? _maskIccid(iccid!) : null,
    'firmware': firmware,
    'internalFirmware': internalFirmware,
    'hardwareVersion': hardwareVersion,
    'bootloaderVersion': bootloaderVersion,
    'modemVersion': modemVersion,
    'bluetoothMac': bluetoothMac,
    'accelerometerModel': accelerometerModel,
    'confidence': confidence,
    'evidence': evidence,
  };

  String _maskImei(String imei) {
    if (imei.length >= 15) {
      return '${imei.substring(0, 8)}*******';
    }
    return '***';
  }

  String _maskIccid(String iccid) {
    if (iccid.length >= 20) {
      return '${iccid.substring(0, 10)}**********';
    }
    return '***';
  }
}

/// Parsed AVL record from Record Content block
class TeltonikaGeneratedAvlRecord {
  final String id;
  final DateTime? generatedAt;
  final int? deviceTimestamp;
  final int? priority;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? angle;
  final double? speedKph;
  final double? hdop;
  final int? satellites;
  final bool? gpsFix;
  final double? gpsSpeed;
  final int? eventAvlId;
  final Map<int, dynamic> ioElements;
  final int? recordSizeBytes;
  final String? memoryAddress;
  final String? highPriorityAddress;
  final List<String> rawLines;
  final List<int> packetReferences;

  TeltonikaGeneratedAvlRecord({
    required this.id,
    this.generatedAt,
    this.deviceTimestamp,
    this.priority,
    this.latitude,
    this.longitude,
    this.altitude,
    this.angle,
    this.speedKph,
    this.hdop,
    this.satellites,
    this.gpsFix,
    this.gpsSpeed,
    this.eventAvlId,
    required this.ioElements,
    this.recordSizeBytes,
    this.memoryAddress,
    this.highPriorityAddress,
    required this.rawLines,
    required this.packetReferences,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'generatedAt': generatedAt?.toIso8601String(),
    'deviceTimestamp': deviceTimestamp,
    'priority': priority,
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'angle': angle,
    'speedKph': speedKph,
    'hdop': hdop,
    'satellites': satellites,
    'gpsFix': gpsFix,
    'gpsSpeed': gpsSpeed,
    'eventAvlId': eventAvlId,
    'ioElements': ioElements.map((k, v) => MapEntry(k.toString(), v)),
    'recordSizeBytes': recordSizeBytes,
    'memoryAddress': memoryAddress,
    'highPriorityAddress': highPriorityAddress,
    'rawLines': rawLines,
    'packetReferences': packetReferences,
  };
}

/// Observed IO ID with value
class TeltonikaObservedIo {
  final int avlId;
  final dynamic rawValue;
  final AvlDefinition? definition;
  final String? normalizedKey;
  final dynamic normalizedValue;
  final String? rawUnit;
  final String? displayUnit;
  final String definitionStatus;
  final String source;
  final List<int> packetReferences;
  final String rawLine;

  TeltonikaObservedIo({
    required this.avlId,
    required this.rawValue,
    this.definition,
    this.normalizedKey,
    this.normalizedValue,
    this.rawUnit,
    this.displayUnit,
    required this.definitionStatus,
    required this.source,
    required this.packetReferences,
    required this.rawLine,
  });

  Map<String, dynamic> toJson() => {
    'avlId': avlId,
    'rawValue': rawValue,
    'definition': definition?.toJson(),
    'normalizedKey': normalizedKey,
    'normalizedValue': normalizedValue,
    'rawUnit': rawUnit,
    'displayUnit': displayUnit,
    'definitionStatus': definitionStatus,
    'source': source,
    'packetReferences': packetReferences,
    'rawLine': rawLine,
  };
}

/// Use AvlDefinition from uce_interfaces.dart instead of duplicate TeltonikaAvlDefinition

/// USB Config command parsed
class TeltonikaUsbConfigCommand {
  final DateTime? timestamp;
  final String command;
  final int? parameterId;
  final String? rawValue;
  final dynamic parsedValue;
  final String direction;
  final List<int> packetReferences;
  final String rawText;

  TeltonikaUsbConfigCommand({
    this.timestamp,
    required this.command,
    this.parameterId,
    this.rawValue,
    this.parsedValue,
    required this.direction,
    required this.packetReferences,
    required this.rawText,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp?.toIso8601String(),
    'command': command,
    'parameterId': parameterId,
    'rawValue': rawValue,
    'parsedValue': parsedValue,
    'direction': direction,
    'packetReferences': packetReferences,
    'rawText': rawText,
  };
}

/// Configuration parameter definition
class TeltonikaConfigurationParameter {
  final int parameterId;
  final String name;
  final String? description;
  final String category;
  final String valueType;
  final Map<String, String>? enumValues;
  final List<String>? supportedModels;
  final String sourceStatus;

  const TeltonikaConfigurationParameter({
    required this.parameterId,
    required this.name,
    this.description,
    required this.category,
    required this.valueType,
    this.enumValues,
    this.supportedModels,
    required this.sourceStatus,
  });

  Map<String, dynamic> toJson() => {
    'parameterId': parameterId,
    'name': name,
    'description': description,
    'category': category,
    'valueType': valueType,
    'enumValues': enumValues,
    'supportedModels': supportedModels,
    'sourceStatus': sourceStatus,
  };
}

/// Complete parse result for USB Teltonika capture
class TeltonikaUsbParseResult {
  final String fileId;
  final String fileName;
  final DateTime parsedAt;
  final int totalPackets;
  final int totalBytes;
  final List<UsbCaptureChunk> chunks;
  final List<ReassembledUsbStream> streams;
  final List<ExtractedTextFragment> textFragments;
  final List<ReconstructedLogLine> logLines;
  final DetectedTeltonikaDevice? device;
  final List<TeltonikaGeneratedAvlRecord> avlRecords;
  final List<TeltonikaObservedIo> observedIos;
  final List<TeltonikaUsbConfigCommand> configCommands;
  final List<String> warnings;
  final List<String> errors;

  TeltonikaUsbParseResult({
    required this.fileId,
    required this.fileName,
    required this.parsedAt,
    required this.totalPackets,
    required this.totalBytes,
    required this.chunks,
    required this.streams,
    required this.textFragments,
    required this.logLines,
    this.device,
    required this.avlRecords,
    required this.observedIos,
    required this.configCommands,
    required this.warnings,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fileName': fileName,
    'parsedAt': parsedAt.toIso8601String(),
    'totalPackets': totalPackets,
    'totalBytes': totalBytes,
    'chunkCount': chunks.length,
    'streamCount': streams.length,
    'textFragmentCount': textFragments.length,
    'logLineCount': logLines.length,
    'device': device?.toJson(),
    'avlRecordCount': avlRecords.length,
    'observedIoCount': observedIos.length,
    'configCommandCount': configCommands.length,
    'warnings': warnings,
    'errors': errors,
    'streams': streams.map((s) => s.toJson()).toList(),
    'textFragments': textFragments.map((t) => t.toJson()).toList(),
    'logLines': logLines.map((l) => l.toJson()).toList(),
    'avlRecords': avlRecords.map((a) => a.toJson()).toList(),
    'observedIos': observedIos.map((i) => i.toJson()).toList(),
    'configCommands': configCommands.map((c) => c.toJson()).toList(),
  };
}

/// Utility functions
String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
}

String tryDecodeAscii(Uint8List bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return '';
  }
}

bool isPrintableAscii(Uint8List bytes) {
  for (final b in bytes) {
    if (b < 0x20 && b != 0x09 && b != 0x0A && b != 0x0D) return false;
    if (b > 0x7E) return false;
  }
  return true;
}