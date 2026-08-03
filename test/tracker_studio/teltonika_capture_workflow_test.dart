import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/capture_logs/capture_log_store.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

import '../test_helpers/studio_test_harness.dart';

List<String> _record({required int index, required List<String> ioLines}) => [
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

void main() {
  setUpAll(() {
    UceRegistry.initialize();
    TeltonikaDriver.registerAll();
  });

  test('capture workflow accumulates lines and computes diff on stop', () async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    expect(controller.state.logCapture.active, isTrue);

    controller.testTransport.feedLines([
      '[READ] :cfg_connect',
      ..._record(index: 0, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
        'IO ID[ 283]: 10',
      ]),
      '[READ] <CFG_CONNECT>',
      ..._record(index: 1, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
        'IO ID[ 283]: 26',
      ]),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.logCapture.capturedLines, isNotEmpty);
    expect(controller.state.logCapture.capturedLines, contains(':cfg_connect'));

    controller.stopTeltonikaCapture();

    final capture = controller.state.logCapture;
    expect(capture.active, isFalse);
    expect(capture.analysis, isNotNull);
    expect(capture.diff, isNotNull);
    expect(capture.analysis!.avlRecords, hasLength(2));
    expect(capture.diff!.totalRecords, 2);
    expect(capture.diff!.changedRecordCount, 1);
    expect(capture.diff!.unknownChangedIos, hasLength(1));
    expect(capture.diff!.unknownChangedIos.single.avlId, 283);
  });

  test('capture keeps the READ/SEND content but drops noisy prefixes',
      () async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    controller.testTransport.feedLines([
      '[READ] <SETPARAM_RESULT>:1',
      '[SEND] :cfg_setparam:2005:5026',
      '[READ_ASCII] <SETPARAM_RESULT>:1\\r\\n',
      '[READ_HEX] 3C 53 45 54',
      '[SERIAL] Buffer de entrada limpo',
    ]);
    await Future<void>.delayed(Duration.zero);
    controller.stopTeltonikaCapture();

    final lines = controller.state.logCapture.capturedLines;
    expect(lines, contains('<SETPARAM_RESULT>:1'));
    expect(lines, contains(':cfg_setparam:2005:5026'));
    expect(
      lines.any((line) => line.startsWith('[READ_ASCII]')),
      isFalse,
      reason: 'READ_ASCII raw chunks should not be captured as lines',
    );
    expect(
      lines.any((line) => line.startsWith('[READ_HEX]')),
      isFalse,
      reason: 'READ_HEX raw chunks should not be captured as lines',
    );
    expect(
      lines.any((line) => line.startsWith('[SERIAL')),
      isFalse,
      reason: 'SERIAL status lines should not be captured',
    );
  });

  test('capture requires a connected USB port', () async {
    final controller = await createStudioTestController();

    controller.startTeltonikaCapture();

    expect(controller.state.logCapture.active, isFalse);
    expect(
      controller.state.logs.any((log) =>
          log.source == 'Captura' && log.message.contains('Conecte a porta')),
      isTrue,
    );
  });

  test('clear resets capture state', () async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    controller.testTransport.feed('[READ] :cfg_connect');
    await Future<void>.delayed(Duration.zero);
    controller.stopTeltonikaCapture();

    expect(controller.state.logCapture.analysis, isNotNull);

    controller.clearTeltonikaCapture();

    final capture = controller.state.logCapture;
    expect(capture.active, isFalse);
    expect(capture.capturedLines, isEmpty);
    expect(capture.analysis, isNull);
    expect(capture.diff, isNull);
  });

  test('capture extracts parameter values and confirmed IDs', () async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    controller.testTransport.feedLines([
      '[READ] :cfg_connect',
      '[SEND] :cfg_setparam:2001:VIVO.COM.BR',
      '[READ] <SETPARAM_RESULT>:1',
      '[SEND] :cfg_setparam:2005:5026',
      '[READ] <SETPARAM_RESULT>:1',
      '[SEND] :cfg_setparam:2002:usuario',
      '[READ] <SETPARAM_RESULT>:1',
      '[SEND] :cfg_setparam:2003:senha123',
      '[READ] <SETPARAM_RESULT>:0',
      '[SEND] :cfg_setparam:2004:teltonika.latam.com',
    ]);
    await Future<void>.delayed(Duration.zero);
    controller.stopTeltonikaCapture();

    final analysis = controller.state.logCapture.analysis!;
    expect(analysis.parameterValues[2001], 'VIVO.COM.BR');
    expect(analysis.parameterValues[2005], '5026');
    expect(analysis.parameterValues[2002], 'usuario');
    expect(analysis.parameterValues[2003], 'senha123');
    expect(analysis.parameterValues[2004], 'teltonika.latam.com');
    expect(analysis.confirmedParameters,
        containsAll([2001, 2005, 2002]));
    expect(analysis.confirmedParameters, isNot(contains(2003)));
    expect(analysis.confirmedParameters, isNot(contains(2004)));
  });

  test('capture keeps the last value when a parameter is set twice', () async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    controller.testTransport.feedLines([
      '[SEND] :cfg_setparam:2005:5000',
      '[SEND] :cfg_setparam:2005:5026',
      '[SEND] :cfg_setparam:2001:internet',
      '[SEND] :cfg_setparam:2001:VIVO.COM.BR',
    ]);
    await Future<void>.delayed(Duration.zero);
    controller.stopTeltonikaCapture();

    final analysis = controller.state.logCapture.analysis!;
    expect(analysis.parameterValues[2005], '5026');
    expect(analysis.parameterValues[2001], 'VIVO.COM.BR');
  });

  test('save capture persists logs and analysis for the session', () async {
    final tmpPath =
        '${Directory.systemTemp.path}/capture_logs_${DateTime.now().microsecondsSinceEpoch}';
    final store = CaptureLogStore(
      pathResolver: () async => '$tmpPath/logs.json',
    );
    final controller =
        await createStudioTestController(captureLogs: store);
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );

    controller.startTeltonikaCapture();
    controller.testTransport.feedLines([
      '[READ] :cfg_connect',
      '[SEND] :cfg_setparam:2001:VIVO.COM.BR',
      '[READ] <SETPARAM_RESULT>:1',
      ..._record(index: 0, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
      ]),
    ]);
    await Future<void>.delayed(Duration.zero);
    controller.stopTeltonikaCapture();

    expect(controller.state.logCapture.analysis, isNotNull);
    await controller.saveTeltonikaCaptureForAnalysis();

    expect(store.all, hasLength(1));
    final record = store.all.single;
    expect(record.sessionCode, controller.state.sessionCode);
    expect(record.lines, contains(':cfg_setparam:2001:VIVO.COM.BR'));
    expect(record.analysis!['parameterValues'],
        containsPair('2001', 'VIVO.COM.BR'));

    final reloaded = CaptureLogStore(
      pathResolver: () async => '$tmpPath/logs.json',
    );
    await reloaded.load();
    expect(reloaded.all, hasLength(1));
    expect(
      reloaded.all.single.analysis!['parameterValues'],
      containsPair('2001', 'VIVO.COM.BR'),
    );

    await Directory(tmpPath).delete(recursive: true);
  });

  test('save without analysis only logs guidance and stores nothing',
      () async {
    final store = CaptureLogStore(
      pathResolver: () async =>
          '${Directory.systemTemp.path}/empty_${DateTime.now().microsecondsSinceEpoch}/logs.json',
    );
    final controller =
        await createStudioTestController(captureLogs: store);

    await controller.saveTeltonikaCaptureForAnalysis();

    expect(store.all, isEmpty);
    expect(
      controller.state.logs.any((log) =>
          log.source == 'Captura' && log.message.contains('Pare a análise')),
      isTrue,
    );
  });
}
