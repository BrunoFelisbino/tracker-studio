import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/diagnostics/core/diagnostic_types.dart';
import 'package:tracker_studio/features/diagnostics/protocols/teltonika/teltonika_event_classifier.dart';
import 'package:tracker_studio/features/diagnostics/protocols/teltonika/teltonika_line_normalizer.dart';

void main() {
  const normalizer = TeltonikaLineNormalizer();
  const classifier = TeltonikaEventClassifier();

  NormalizedDiagnosticEvent classify(String line) {
    final normalized = normalizer.normalize(line);
    return classifier.classify(
      normalized.first,
      0,
      manufacturer: SupportedManufacturer.teltonika,
    );
  }

  group('Teltonika FMB140 Field Session - Integration Tests', () {
    test('detects FMB140 model from HW ver', () {
      final line = '2026.08.01 02:01:05  [READ_ASCII] HW ver: FMB140';
      final normalized = normalizer.normalize(line);
      expect(normalized.first.content, contains('HW ver: FMB140'));
    });

    test('extracts IMEI from READ_ASCII', () {
      final line = '2026.08.01 02:01:06  [READ_ASCII] IMEI: 000000000000001';
      final event = classify(line);
      expect(event.details['imei'], '000000000000001');
    });

    test('parses firmware version', () {
      final line = '2026.08.01 02:01:07  [READ_ASCII] FW Ver: AXN_5.1.9';
      final event = classify(line);
      expect(event.details['firmware'], 'AXN_5.1.9');
    });

    test('parses bootloader version', () {
      final line = '2026.08.01 02:01:08  [READ_ASCII] BL ver: 1.10';
      final event = classify(line);
      expect(event.details['bootloader'], '1.10');
    });

    test('parses BLE availability', () {
      final line = '2026.08.01 02:01:09  [READ_ASCII] BLE: 1';
      final event = classify(line);
      expect(event.details['ble'], '1');
    });

    test('parses NAND info', () {
      final line = '2026.08.08 02:01:10  [READ_ASCII] NAND: 1';
      final event = classify(line);
      expect(event.details['nand'], '1');
    });

    test('parses accelerometer model', () {
      final line = '2026.08.01 02:01:11  [READ_ASCII] AXL: 2/LIS2DH';
      final event = classify(line);
      expect(event.details['accelerometer'], '2/LIS2DH');
    });

    test('extracts ICCID', () {
      final line = '2026.08.01 02:01:12  [READ_ASCII] ICCID: 8955000000000000000';
      final event = classify(line);
      expect(event.details['iccid'], '8955000000000000000');
    });

    test('extracts phone number', () {
      final line = '2026.08.01 02:01:13  [READ_ASCII] Phone: +5500000000000';
      final event = classify(line);
      expect(event.details['phone'], '+5500000000000');
    });

    test('parses SIM status', () {
      final line =
          '2026.08.01 02:01:14  [2026.08.01 02:01:15]-[MODEM.STATUS] SIM: detectado';
      final event = classify(line);
      expect(event.severity, DiagnosticSeverity.info);
    });

    test('parses PIN status', () {
      final line =
          '2026.08.01 02:01:15  [2026.08.01 02:01:16]-[MODEM.STATUS] PIN: status OK';
      final event = classify(line);
      expect(event.severity, DiagnosticSeverity.success);
    });

    test('parses SIM lock status', () {
      final line =
          '2026.08.01 02:01:16  [2026.08.01 02:01:17]-[MODEM.STATUS] SIM lock: OFF';
      final event = classify(line);
      expect(event.details['simLock'], 'OFF');
    });

    test('parses operator', () {
      final line =
          '2026.08.01 02:01:17  [2026.08.01 02:01:18]-[MODEM.STATUS] Operadora: TIM';
      final event = classify(line);
      expect(event.details['operator'], 'TIM');
    });

    test('parses MCC', () {
      final line =
          '2026.08.01 02:01:19  [2026.08.01 02:01:19]-[MODEM.STATUS] MCC: 724';
      final event = classify(line);
      expect(event.details['mcc'], '724');
    });

    test('parses MNC', () {
      final line =
          '2026.08.08 02:01:20  [2026.08.01 02:01:20]-[MODEM.STATUS] MNC: 02';
      final event = classify(line);
      expect(event.details['mnc'], '02');
    });

    test('parses roaming status', () {
      final line =
          '2026.08.01 02:01:21  [2026.08.01 02:01:21]-[MODEM.STATUS] Roaming: OFF';
      final event = classify(line);
      expect(event.details['roaming'], 'OFF');
    });

    test('parses network registration', () {
      final line =
          '2026.08.01 02:01:22  [2026.08.01 02:01:22]-[MODEM.STATUS] Registro de rede: 38497';
      final event = classify(line);
      expect(event.details['networkReg'], '38497');
    });

    test('detects internal modem commands (MODEM.ACTION)', () {
      final line1 =
          '2026.08.01 02:01:23  [2026.08.01 02:01:23]-[MODEM.ACTION] AT+ICCID';
      final event1 = classify(line1);
      expect(event1.source, 'MODEM.ACTION');
      expect(event1.details['command'], 'AT+ICCID');

      final line2 =
          '2026.08.01 02:01:24  [2026.08.01 02:01:24]-[MODEM.ACTION] AT+EPINC?';
      final event2 = classify(line2);
      expect(event2.source, 'MODEM.ACTION');
      expect(event2.details['command'], 'AT+EPINC?');
    });

    test('parses power state', () {
      final line =
          '2026.08.01 02:01:47  [2026.08.01 02:01:47]-[LiPo] ExtV: 12368mV';
      final event = classify(line);
      expect(event.value, closeTo(12.368, 0.001));
      expect(event.unit, 'V');
    });

    test('parses battery voltage', () {
      final line =
          '2026.08.01 02:01:48  [2026.08.01 02:01:48]-[LiPo] BatV: 3953mV';
      final event = classify(line);
      expect(event.value, closeTo(3.953, 0.001));
    });

    test('parses battery current', () {
      final line =
          '2026.08.01 02:01:49  [2026.08.01 02:01:49]-[LiPo] BatI: 93mA';
      final event = classify(line);
      expect(event.value, closeTo(0.093, 0.001));
      expect(event.unit, 'A');
    });

    test('parses GPS coordinates', () {
      final line =
          '2026.08.01 02:01:33  [2026.08.01 02:01:33]-[GPS.API] Lat: 0.0, Lon: 0.0, Alt: 851.5';
      final event = classify(line);
      expect(event.details['latitude'], closeTo(0.0, 0.0001));
      expect(event.details['longitude'], closeTo(0.0, 0.0001));
      expect(event.details['altitude'], closeTo(851.5, 0.001));
    });

    test('parses HDOP', () {
      final line1 =
          '2026.08.01 02:01:34  [2026.08.01 02:01:34]-[GPS.API] HDOP: 1.2';
      final event1 = classify(line1);
      expect(event1.details['hdop'], 1.2);

      final line2 =
          '2026.08.01 02:01:52  [2026.08.01 02:01:52]-[GPS.API] HDOP: 62.12';
      final event2 = classify(line2);
      expect(event2.details['hdop'], 62.12);
      expect(event2.severity, DiagnosticSeverity.critical);
    });

    test('parses satellites', () {
      final line =
          '2026.08.01 02:01:35  [2026.08.01 02:01:35]-[GPS.API] Sat: 12';
      final event = classify(line);
      expect(event.details['satellites'], 12);
    });

    test('parses speed', () {
      final line =
          '2026.08.01 02:01:36  [2026.08.01 02:01:36]-[GPS.API] Spd: 12.5';
      final event = classify(line);
      expect(event.details['speed'], 12.5);
    });

    test('parses fix status', () {
      final line =
          '2026.08.01 02:01:37  [2026.08.01 02:01:37]-[GPS.API] FixStatus: 1';
      final event = classify(line);
      expect(event.details['fixStatus'], 1);
    });

    test('detects ignition state changes', () {
      final line1 = '2026.08.01 02:02:39 02:02:39]-[ACC] Ign: ON';
      final event1 = classify(line1);
      expect(event1.source, 'ACC');

      final line2 = '2026.08.01 02:02:51 02:02:51]-[ACC] Ign: OFF';
      final event2 = classify(line2);
      expect(event2.source, 'ACC');
    });

    test('detects movement state changes', () {
      final line1 = '2026.08.01 02:02:40 02:02:40]-[ACC] Mov: YES';
      final event1 = classify(line1);
      expect(event1.source, 'ACC');

      final line2 = '2026.08.01 02:02:52 02:02:52]-[ACC] Mov: NO';
      final event2 = classify(line2);
      expect(event2.source, 'ACC');
    });

    test('detects CAN sleep mode', () {
      final line =
          '2026.08.01 02:02:23  [2026.08.01 02:02:23]-[LVCAN] CAN MODULE in sleep mode';
      final event = classify(line);
      expect(event.source, 'LVCAN');
      expect(event.severity, DiagnosticSeverity.info);
    });

    test('parses power unplug event', () {
      final line =
          '2026.08.01 02:01:50  [2026.08.01 02:01:50]-[UNPLUG] External power removed';
      final event = classify(line);
      expect(event.severity, DiagnosticSeverity.critical);
    });

    test('parses network socket opened', () {
      final line =
          '2026.08.01 02:01:30  [2026.08.01 02:01:30]-[NETWORK] Socket Opened';
      final event = classify(line);
      expect(event.severity, DiagnosticSeverity.success);
      expect(event.event, 'socket_opened');
    });

    test('parses network connection attempt', () {
      final line =
          '2026.08.01 02:01:31  [2026.08.01 02:01:31]-[NETWORK] Connecting to 192.0.2.10:5027@TCP';
      final event = classify(line);
      expect(event.severity, DiagnosticSeverity.info);
      expect(event.details['ip'], '192.0.2.10');
      expect(event.details['port'], 5027);
      expect(event.details['protocol'], 'TCP');
    });

    test('parses domain resolution', () {
      final line =
          '2026.08.01 02:01:32  [2026.08.01 02:01:32]-[NETWORK] Domain: device1.example.com, IP: 192.0.2.10';
      final event = classify(line);
      expect(event.details['domain'], 'device1.example.com');
    });
  });
}
