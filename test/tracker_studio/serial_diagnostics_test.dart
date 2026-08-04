import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/serial_diagnostics.dart';

void main() {
  test('calculates printable ASCII percentage', () {
    expect(printableAsciiRatio(Uint8List.fromList('OK\r\n'.codeUnits)), 1);
    expect(printableAsciiRatio(Uint8List.fromList([0x01, 0xFF, 0x04, 0x41])),
        0.25);
  });

  test('recognizes expected ASCII responses', () {
    expect(isProbableAsciiResponse('OK'), isTrue);
    expect(isProbableAsciiResponse('RES;STT;123'), isTrue);
    expect(isProbableAsciiResponse('ACK;123'), isTrue);
    expect(isProbableAsciiResponse('ERR;01'), isTrue);
  });

  test('matrix creates all route baud ending and command combinations', () {
    final matrix = generateSerialDiagnosticMatrix([
      '/dev/cu.usbmodem11200',
      '/dev/cu.usbmodem11202',
    ]);

    expect(matrix, hasLength(4 * 5 * 3 * 2));
    expect(
        matrix.any((item) =>
            item.commandPortPath.endsWith('11200') &&
            item.readPortPath.endsWith('11202')),
        isTrue);
    expect(
        matrix.any((item) =>
            item.commandPortPath.endsWith('11202') &&
            item.readPortPath.endsWith('11200')),
        isTrue);
  });

  test('binary bytes are not recognized as probable ASCII', () {
    final bytes = Uint8List.fromList([0x01, 0x56, 0xA5, 0x00, 0xFF, 0x04]);
    expect(printableAsciiRatio(bytes), lessThanOrEqualTo(0.70));
    expect(isProbableAsciiResponse(String.fromCharCodes(bytes), bytes: bytes),
        isFalse);
  });
}
