import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/parsers/teltonika_usb/teltonika_capture_analysis.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';

List<String> _record({
  required int index,
  required List<String> ioLines,
}) {
  return [
    '[REC.GEN] Record Content:',
    'Priority: 1',
    'Lat: 0.0',
    'Lon: 0.0',
    'Alt: 780',
    'Angle: 45',
    'Speed: 0',
    'HDOP: 1.2',
    'SatInUse: 8',
    'GPS Fix: 1',
    'Event AVL ID: $index',
    ...ioLines,
    'Record Size: ${40 + ioLines.length}',
  ];
}

void main() {
  setUpAll(() {
    UceRegistry.initialize();
    TeltonikaDriver.registerAll();
  });

  group('TeltonikaCaptureAnalyzer.analyze', () {
    test('detects device, parses records, IOs and config commands', () {
      final lines = [
        'IMEI: 000000000000001',
        'FMB140 device connected',
        ..._record(index: 0, ioLines: [
          'IO ID[ 3]: 1',
          'IO ID[ 66]: 12000',
          'IO ID[ 89]: 55',
        ]),
        ':cfg_setparam:2005:5026',
        '<SETPARAM_RESULT>:1',
      ];

      final analysis = TeltonikaCaptureAnalyzer.analyze(lines);

      expect(analysis.device, isNotNull);
      expect(analysis.device!.model, 'FMB140');
      expect(analysis.device!.imei, '000000000000001');
      expect(analysis.avlRecords, hasLength(1));
      expect(analysis.observedIos, hasLength(3));
      expect(analysis.configCommands, hasLength(2));

      final externalVoltage =
          analysis.observedIos.where((io) => io.avlId == 66).first;
      expect(externalVoltage.normalizedKey, 'external_voltage');
      expect(externalVoltage.normalizedValue, 12.0);
    });

    test('reports warnings for empty captures', () {
      final analysis = TeltonikaCaptureAnalyzer.analyze(const []);
      expect(analysis.device, isNull);
      expect(analysis.avlRecords, isEmpty);
      expect(analysis.warnings, isNotEmpty);
    });

    test('warns when record content exists but no complete record parsed', () {
      final analysis = TeltonikaCaptureAnalyzer.analyze(const [
        '[REC.GEN] Record Content:',
        'Priority: 1',
      ]);
      expect(analysis.avlRecords, isEmpty);
      expect(
        analysis.warnings.any((warning) => warning.contains('registro')),
        isTrue,
      );
    });
  });

  group('TeltonikaCaptureAnalyzer.diff', () {
    test('identifies unknown changed IO as CAN sensor candidate', () {
      final lines = [
        ..._record(index: 0, ioLines: [
          'IO ID[ 3]: 1',
          'IO ID[ 283]: 10',
        ]),
        ..._record(index: 1, ioLines: [
          'IO ID[ 3]: 1',
          'IO ID[ 283]: 24',
        ]),
        ..._record(index: 2, ioLines: [
          'IO ID[ 3]: 1',
          'IO ID[ 283]: 24',
        ]),
      ];

      final analysis = TeltonikaCaptureAnalyzer.analyze(lines);
      final diff = TeltonikaCaptureAnalyzer.diff(analysis);

      expect(diff.totalRecords, 3);
      expect(diff.changedRecordCount, 1);
      expect(diff.changedPackets.single.recordIndex, 1);
      expect(diff.ioChanges, hasLength(1));

      final change = diff.ioChanges.single;
      expect(change.avlId, 283);
      expect(change.known, isFalse);
      expect(change.before, 10);
      expect(change.after, 24);
      expect(change.transitions, 1);
      expect(diff.unknownChangedIos, hasLength(1));
      expect(diff.knownChangedIos, isEmpty);
      expect(
        diff.summary.any((line) => line.contains('283')),
        isTrue,
      );
    });

    test('identifies known IO changes with unit conversion', () {
      final lines = [
        ..._record(index: 0, ioLines: [
          'IO ID[ 66]: 12000',
          'IO ID[ 89]: 55',
        ]),
        ..._record(index: 1, ioLines: [
          'IO ID[ 66]: 12000',
          'IO ID[ 89]: 45',
        ]),
      ];

      final analysis = TeltonikaCaptureAnalyzer.analyze(lines);
      final diff = TeltonikaCaptureAnalyzer.diff(analysis);

      expect(diff.ioChanges, hasLength(1));
      final change = diff.ioChanges.single;
      expect(change.avlId, 89);
      expect(change.known, isTrue);
      expect(change.normalizedKey, 'fuel_level');
      expect(change.before, 55);
      expect(change.after, 45);
      expect(diff.knownChangedIos, hasLength(1));
      expect(diff.unknownChangedIos, isEmpty);
    });

    test('no changes when all IOs stay constant', () {
      final lines = [
        ..._record(index: 0, ioLines: ['IO ID[ 3]: 1']),
        ..._record(index: 1, ioLines: ['IO ID[ 3]: 1']),
      ];

      final analysis = TeltonikaCaptureAnalyzer.analyze(lines);
      final diff = TeltonikaCaptureAnalyzer.diff(analysis);

      expect(diff.hasChanges, isFalse);
      expect(diff.changedRecordCount, 0);
      expect(diff.changedPackets, isEmpty);
    });

    test('empty analysis produces empty diff', () {
      final analysis = TeltonikaCaptureAnalyzer.analyze(const []);
      final diff = TeltonikaCaptureAnalyzer.diff(analysis);
      expect(diff.totalRecords, 0);
      expect(diff.hasChanges, isFalse);
      expect(diff.ioChanges, isEmpty);
      expect(diff.summary, isNotEmpty);
    });

    test('parses READ_ASCII-prefixed FMB140 log lines', () {
      final lines = [
        '[2026.08.03 15:16:01]-[REC.GEN]\tRecord Content:',
        '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[  9]: 1',
        '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[  6]: 1',
        '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[199]: 821',
        '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[ 16]: 1200',
        '[2026.08.03 15:16:01]-[READ_ASCII] \tIO ID[ 12]: 1918000',
        '[2026.08.03 15:16:01]-[READ_ASCII]  Record Size:\t142 Bytes',
      ];

      final analysis = TeltonikaCaptureAnalyzer.analyze(lines);

      expect(analysis.avlRecords, isNotEmpty);
      expect(analysis.observedIos, isNotEmpty);
      final ioIds = analysis.observedIos.map((io) => io.avlId).toSet();
      expect(ioIds, containsAllInOrder([9, 6, 199, 16, 12]));
    });
  });
}
