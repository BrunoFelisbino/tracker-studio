import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';

void main() {
  test('probe', () {
    final parser = SuntechParser();
    for (final line in [
      'IMEI: 352093081540152',
      'FMB140 device connected',
      '[REC.GEN] Record Content:',
      'Priority: 1',
      'Lat: -23.550520',
      'Lon: -46.633309',
      'Record Size: 44',
    ]) {
      final snap = parser.parseLine(line);
      // ignore: avoid_print
      print('LINE: $line -> lat=${snap?.latitude} lon=${snap?.longitude} '
          'esn=${snap?.esn} model=${snap?.model} v=${snap?.mainVoltage} '
          'inside=${parser.isInsideTeltonikaRecord}');
    }
    final snap2 = parser.parseLine(
        '[2026.08.01 02:01:33]-[GPS.API] Lat: -23.550520, Lon: -46.633309, Alt: 851.5');
    // ignore: avoid_print
    print('STREAM lat=${snap2?.latitude} lon=${snap2?.longitude}');
  });
}
