import 'dart:typed_data';

import 'teltonika_usb_models.dart';

/// Result of decoding a Teltonika AVL binary frame.
///
/// Instead of returning an empty list for every failure mode, the decoder
/// returns a structured result so callers can distinguish between
/// "no frame found", "corrupt data", "unsupported codec", etc.
sealed class TeltonikaDecodeResult {
  const TeltonikaDecodeResult();
}

/// Successful decode: at least one valid AVL record was extracted.
class TeltonikaDecodeSuccess extends TeltonikaDecodeResult {
  final List<TeltonikaGeneratedAvlRecord> records;

  const TeltonikaDecodeSuccess(this.records);
}

/// Decode failed: the input did not contain a valid frame or was corrupt.
class TeltonikaDecodeFailure extends TeltonikaDecodeResult {
  final TeltonikaDecodeError error;

  /// Byte offset in the input where the failure was detected, or null when
  /// the failure applies to the entire input.
  final int? offset;

  const TeltonikaDecodeFailure(this.error, {this.offset});

  const TeltonikaDecodeFailure.invalidCodec({this.offset})
      : error = TeltonikaDecodeError.invalidCodecId;

  const TeltonikaDecodeFailure.recordCountMismatch({this.offset})
      : error = TeltonikaDecodeError.recordCountMismatch;

  const TeltonikaDecodeFailure.truncatedFrame({this.offset})
      : error = TeltonikaDecodeError.truncatedFrame;

  const TeltonikaDecodeFailure.trailingCodecMismatch({this.offset})
      : error = TeltonikaDecodeError.trailingCodecMismatch;

  const TeltonikaDecodeFailure.recordTooShort({this.offset})
      : error = TeltonikaDecodeError.recordTooShort;

  const TeltonikaDecodeFailure.ioGroupCorrupt({this.offset})
      : error = TeltonikaDecodeError.ioGroupCorrupt;

  const TeltonikaDecodeFailure.emptyInput()
      : error = TeltonikaDecodeError.emptyInput,
        offset = null;

  const TeltonikaDecodeFailure.invalidHex({this.offset})
      : error = TeltonikaDecodeError.invalidHex;
}

/// Categories of decode failures.
enum TeltonikaDecodeError {
  /// No data was provided.
  emptyInput,

  /// Leading codec ID is not one of the supported values (e.g. 0x08).
  invalidCodecId,

  /// Declared record count is implausible (>= 0x8000) or zero.
  recordCountMismatch,

  /// Not enough bytes to read a complete record.
  truncatedFrame,

  /// Trailing record count or codec ID does not match the header.
  trailingCodecMismatch,

  /// A single record was shorter than the minimum required byte length.
  recordTooShort,

  /// IO group count or elements could not be read within remaining bytes.
  ioGroupCorrupt,

  /// Input hex string was malformed (odd length, non-hex characters).
  invalidHex,
}

/// Teltonika AVL binary codec decoder (codec 0x08 family) for USB/serial dumps.
///
/// The FMB devices stream AVL records as a binary frame that — in the serial
/// debug log — surfaces as `[READ_HEX]` chunks. The frame layout is:
///
/// ```
/// CODEC_ID (1 byte)            // e.g. 0x08 for AVL, 0x03 for I/O
/// RECORDS_COUNT (uint32 BE)    // number of records
/// <record> ...                 // RECORDS_COUNT records
/// RECORDS_COUNT (uint32 BE)    // number of records again
/// CODEC_ID (1 byte)            // mirrors the leading codec id
/// ```
///
/// Each codec-0x08 record:
/// ```
/// timestamp   (uint64, millis)
/// priority    (uint8)
/// longitude   (int32)  / 1000000
/// latitude    (int32)  / 1000000
/// altitude    (int16)
/// angle       (uint16)
/// speed       (uint16)
/// gpsByte     (uint8)   // satellite count + flags on codec 0x08
/// io_count    (uint16)  // total IO elements
/// nb1 (uint8)  then [id1(1) value1(1)] * nb1
/// nb2 (uint8)  then [id2(2) value2(2)] * nb2
/// nb4 (uint8)  then [id2(2) value4(4)] * nb4
/// nb8 (uint8)  then [id2(2) value8(8)] * nb8
/// nb16(uint8) then [id2(2) value16(16)] * nb16
/// ```
///
/// See: Teltonika FMB XXX Protocol TCP Link (codec 0x08).
class TeltonikaAvlCodec {
  /// Supported codec IDs.
  static const supportedCodecs = <int>[0x08];

  /// Maximum record count we will attempt to decode before rejecting.
  static const maxRecords = 0x7FFF;

  /// Decodes all records from a raw binary blob.
  ///
  /// Returns a [TeltonikaDecodeSuccess] when at least one valid frame is
  /// found, or a [TeltonikaDecodeFailure] with a structured error and
  /// optional offset when the input is not a valid AVL frame.
  static TeltonikaDecodeResult decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const TeltonikaDecodeFailure.emptyInput();
    }
    if (bytes.length < 7) {
      return const TeltonikaDecodeFailure.truncatedFrame(offset: 0);
    }
    TeltonikaDecodeFailure? firstFailure;
    for (var i = 0; i + 6 < bytes.length; i++) {
      final codec = bytes[i];
      if (!supportedCodecs.contains(codec)) continue;
      final result = _tryDecode(bytes, i, codec);
      if (result is TeltonikaDecodeSuccess) return result;
      if (result is TeltonikaDecodeFailure && firstFailure == null) {
        firstFailure = result;
      }
    }
    return firstFailure ?? const TeltonikaDecodeFailure.invalidCodec(offset: 0);
  }

  static TeltonikaDecodeResult _tryDecode(
    Uint8List bytes,
    int start,
    int codec,
  ) {
    var offset = start + 1; // skip codec id
    final count = _readUint32(bytes, offset);
    if (count == null) {
      return const TeltonikaDecodeFailure.truncatedFrame();
    }
    if (count < 1 || count > maxRecords) {
      return TeltonikaDecodeFailure.recordCountMismatch(offset: start + 1);
    }
    offset += 4;

    final reader = _TeltonikaReader(bytes, offset);
    final records = <TeltonikaGeneratedAvlRecord>[];
    int ioTotal = 0;
    for (var i = 0; i < count; i++) {
      final record = _readRecord(reader, i, codec);
      if (record == null) {
        return TeltonikaDecodeFailure.recordTooShort(offset: reader.offset);
      }
      ioTotal += record.ioElements.length;
      records.add(record);
    }

    // Validate trailing count + codec id.
    final trailingCount = _readUint32(bytes, reader.offset);
    if (trailingCount == null) {
      return TeltonikaDecodeFailure.truncatedFrame(offset: reader.offset);
    }
    if (trailingCount != count) {
      return TeltonikaDecodeFailure.recordCountMismatch(offset: reader.offset);
    }
    final trailingCodec =
        reader.offset + 4 < bytes.length ? bytes[reader.offset + 4] : -1;
    if (trailingCodec != codec) {
      return TeltonikaDecodeFailure.trailingCodecMismatch(
          offset: reader.offset + 4);
    }

    // Build a synthetic single record aggregating IOs across the window, plus
    // keep the per-record list for diffing.
    final merged = <int, dynamic>{};
    final rawLines = <String>[];
    for (final rec in records) {
      for (final entry in rec.ioElements.entries) {
        merged[entry.key] = entry.value;
      }
      rawLines.addAll(rec.rawLines);
    }
    return TeltonikaDecodeSuccess([
      TeltonikaGeneratedAvlRecord(
        id: 'avl-bin-aggregate',
        generatedAt: records.first.generatedAt,
        deviceTimestamp: records.first.deviceTimestamp,
        priority: records.first.priority,
        latitude: records.first.latitude,
        longitude: records.first.longitude,
        altitude: records.first.altitude,
        angle: records.first.angle,
        speedKph: records.first.speedKph,
        hdop: records.first.hdop,
        satellites: records.first.satellites,
        gpsFix: records.first.gpsFix,
        eventAvlId: records.first.eventAvlId,
        ioElements: merged,
        recordSizeBytes: ioTotal,
        rawLines: rawLines,
        packetReferences: const [],
      ),
    ]);
  }

  static int? _readUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return null;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static TeltonikaGeneratedAvlRecord? _readRecord(
    _TeltonikaReader reader,
    int index,
    int codec,
  ) {
    final startOffset = reader.offset;
    final timestamp = reader.readUint64();
    if (timestamp == null) return null;
    final priority = reader.readUint8();
    final longitude = reader.readInt32();
    final latitude = reader.readInt32();
    final altitude = reader.readInt16();
    final angle = reader.readUint16();
    final speed = reader.readUint16();
    final gpsByte = reader.readUint8();
    final ioCount = reader.readUint16();
    if (ioCount == null) return null;

    final ioElements = <int, dynamic>{};
    void addIo(int id, dynamic value) {
      ioElements[id] = value;
    }

    int readGroup(int idBytes, int valueBytes) {
      final count = reader.readUint8();
      if (count == null) return 0;
      for (var i = 0; i < count; i++) {
        final id = reader.readUint(idBytes);
        final value = reader.readUint(valueBytes);
        if (id == null || value == null) return count;
        addIo(id, value);
      }
      return count;
    }

    readGroup(1, 1);
    readGroup(2, 2);
    readGroup(2, 4);
    readGroup(2, 8);
    readGroup(2, 16);

    return TeltonikaGeneratedAvlRecord(
      id: 'avl-bin-$index',
      generatedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      deviceTimestamp: timestamp,
      priority: priority,
      longitude: longitude == null ? null : longitude / 1000000.0,
      latitude: latitude == null ? null : latitude / 1000000.0,
      altitude: altitude?.toDouble(),
      angle: angle?.toDouble(),
      speedKph: speed?.toDouble(),
      hdop: gpsByte?.toDouble(),
      satellites: gpsByte,
      gpsFix: gpsByte != null && gpsByte > 0,
      eventAvlId: priority,
      ioElements: ioElements,
      recordSizeBytes: ioCount,
      memoryAddress: null,
      highPriorityAddress: null,
      rawLines: [
        '[AVL_BINÁRIO] codec=0x${codec.toRadixString(16)} offset=$startOffset'
      ],
      packetReferences: const [],
    );
  }

  /// Concatenates `[READ_HEX]` chunks and decodes any AVL frame in them.
  static TeltonikaDecodeResult decodeHexLines(Iterable<String> hexLines) {
    final hex = hexLines.join(' ');
    return decodeHex(hex);
  }

  /// Decodes a single space-separated hex string.
  static TeltonikaDecodeResult decodeHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.isEmpty) {
      return const TeltonikaDecodeFailure.emptyInput();
    }
    if (cleaned.length.isOdd) {
      return const TeltonikaDecodeFailure.invalidHex();
    }
    final buffer = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return decode(buffer);
  }
}

class _TeltonikaReader {
  _TeltonikaReader(this._bytes, [this._offset = 0]);

  final Uint8List _bytes;
  int _offset;

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;

  int? readUint8() {
    if (remaining < 1) return null;
    return _bytes[_offset++];
  }

  int? readUint16() {
    if (remaining < 2) return null;
    final value = (_bytes[_offset] << 8) | _bytes[_offset + 1];
    _offset += 2;
    return value;
  }

  int? readInt16() {
    final value = readUint16();
    if (value == null) return null;
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  int? readInt32() {
    if (remaining < 4) return null;
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value = (value << 8) | _bytes[_offset + i];
    }
    _offset += 4;
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }

  int? readUint64() {
    if (remaining < 8) return null;
    var value = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(_bytes[_offset + i]);
    }
    _offset += 8;
    return value.toUnsigned(64).toInt();
  }

  int? readUint(int byteCount) {
    if (remaining < byteCount) return null;
    var value = 0;
    for (var i = 0; i < byteCount; i++) {
      value = (value << 8) | _bytes[_offset + i];
    }
    _offset += byteCount;
    return value;
  }
}
