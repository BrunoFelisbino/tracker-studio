import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/parsers/teltonika_usb/teltonika_avl_binary_codec.dart';

List<int> _u32be(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _u64be(int value) {
  final r = <int>[];
  for (var s = 56; s >= 0; s -= 8) {
    r.add((value >> s) & 0xFF);
  }
  return r;
}

/// Builds a single codec-0x08 record containing 3 IOs:
/// - 3 = ignition (1-byte group) value 1
/// - 66 = external voltage (2-byte group) value 12000
/// - 283 = unknown (4-byte group) value 26
List<int> _cleanRecord() {
  return [
    ..._u64be(0x18C2D7B9E00), // timestamp (8 bytes)
    0x01, // priority
    0x00, 0x00, 0x00, 0x00, // longitude int32
    0x00, 0x00, 0x00, 0x00, // latitude int32
    0x00, 0x64, // altitude int16 = 100
    0x00, 0x2C, // angle uint16 = 44
    0x00, 0x1E, // speed uint16 = 30
    0x08, // gps byte: 8 satellites
    0x00, 0x03, // total IO count = 3
    // 1-byte IO group
    0x01, // nb1 = 1
    0x03, 0x01, // id=3, value=1 (ignition)
    // 2-byte IO group
    0x01, // nb2 = 1
    0x00, 0x42, 0x2E, 0xE0, // id=66, value=12000
    // 4-byte IO group
    0x01, // nb4 = 1
    0x01, 0x1B, // id=283 (0x011B)
    0x00, 0x00, 0x00, 0x1A, // value=26
    // 8-byte IO group (empty)
    0x00,
    // 16-byte IO group (empty)
    0x00,
  ];
}

Uint8List _buildFrame(List<int> recordBytes, {int codec = 0x08}) {
  final bytes = <int>[
    codec,
    ..._u32be(1), // record count = 1
    ...recordBytes,
    ..._u32be(1), // trailing count = 1
    codec,
  ];
  return Uint8List.fromList(bytes);
}

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

void main() {
  test('codec decodes a hand-built frame with ignition/voltage/IO283', () {
    final frame = _buildFrame(_cleanRecord());
    final result = TeltonikaAvlCodec.decodeHex(_toHex(frame));
    expect(result, isA<TeltonikaDecodeSuccess>(),
        reason: 'binary AVL frame should decode');
    final records = (result as TeltonikaDecodeSuccess).records;
    expect(records, isNotEmpty, reason: 'at least one record');
    final io = records.single.ioElements;
    expect(io[3], 1, reason: 'ignition');
    expect(io[66], 12000, reason: 'external voltage');
    expect(io[283], 26, reason: 'unknown IO 283');
  });

  test('codec returns failure when no frame is present', () {
    final result = TeltonikaAvlCodec.decodeHex('5B 30 30 30 GARBAGE');
    expect(result, isA<TeltonikaDecodeFailure>());
    final failure = result as TeltonikaDecodeFailure;
    expect(failure.error, isNotNull);
  });

  test('codec returns failure for empty input', () {
    final result = TeltonikaAvlCodec.decodeHex('');
    expect(result, isA<TeltonikaDecodeFailure>());
    final failure = result as TeltonikaDecodeFailure;
    expect(failure.error, TeltonikaDecodeError.emptyInput);
  });

  test('codec detects trailing codec mismatch', () {
    final frame = _buildFrame(_cleanRecord(), codec: 0x08);
    final corrupted = Uint8List.fromList([
      ...frame.sublist(0, frame.length - 1),
      0x09, // wrong trailing codec
    ]);
    final result = TeltonikaAvlCodec.decode(corrupted);
    expect(result, isA<TeltonikaDecodeFailure>());
    final failure = result as TeltonikaDecodeFailure;
    expect(failure.error, TeltonikaDecodeError.trailingCodecMismatch);
  });

  test('codec detects record count mismatch', () {
    final frame = _buildFrame(_cleanRecord());
    final corrupted = Uint8List.fromList([
      frame[0],
      ..._u32be(5), // claims 5 records but only has 1
      ...frame.sublist(5, frame.length - 9),
      ..._u32be(5), // trailing count also wrong
      frame[frame.length - 1],
    ]);
    final result = TeltonikaAvlCodec.decode(corrupted);
    expect(result, isA<TeltonikaDecodeFailure>());
    final failure = result as TeltonikaDecodeFailure;
    expect(failure.error, TeltonikaDecodeError.recordTooShort);
  });
}
