import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

void main() {
  test('emits a line terminated by CRLF', () {
    final buffer = SerialLineBuffer();

    expect(buffer.add(Uint8List.fromList(utf8.encode('RES;STT;123\r\n'))),
        ['RES;STT;123']);
  });

  test('accumulates a line split across chunks', () {
    final buffer = SerialLineBuffer();

    expect(buffer.add(Uint8List.fromList(utf8.encode('RES;ST'))), isEmpty);
    expect(buffer.add(Uint8List.fromList(utf8.encode('T;123\r\n'))),
        ['RES;STT;123']);
  });

  test('emits multiple non-empty lines from one chunk', () {
    final buffer = SerialLineBuffer();

    expect(
      buffer.add(Uint8List.fromList(utf8.encode('FIRST\r\nSECOND\nTHIRD\r'))),
      ['FIRST', 'SECOND', 'THIRD'],
    );
  });
}
