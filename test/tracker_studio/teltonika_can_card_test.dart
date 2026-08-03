import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/can_mapping/can_mapping_store.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_live_screen.dart';
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

  testWidgets('CAN card lists unknown IOs and persists a mapping',
      (tester) async {
    final controller = await createStudioTestController();
    await controller.testTransport.connect(
      const SerialConnectionRequest(commandPortPath: '/dev/tty.test'),
    );
    controller.startTeltonikaCapture();
    controller.testTransport.feedLines([
      '[READ] :cfg_connect',
      ..._record(index: 0, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
        'IO ID[ 283]: 10',
        'IO ID[ 3845]: 100',
      ]),
      ..._record(index: 1, ioLines: [
        'IO ID[ 3]: 1',
        'IO ID[ 66]: 12000',
        'IO ID[ 283]: 26',
        'IO ID[ 3845]: 150',
      ]),
    ]);
    await tester.pump();
    controller.stopTeltonikaCapture();
    expect(controller.state.logCapture.analysis, isNotNull);

    final tmpPath =
        '${Directory.systemTemp.path}/can_card_test_${DateTime.now().microsecondsSinceEpoch}';
    final store = CanMappingStore(pathResolver: () async => '$tmpPath/mapping.json');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeltonikaCanCard(session: controller.state, store: store),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.text('CAN / Sensores mapeados'), findsOneWidget);
    expect(find.text('Candidatos da última captura (2)'), findsOneWidget);
    expect(find.text('IO 283'), findsWidgets);
    expect(find.text('IO 3845'), findsWidgets);
    expect(find.text('10.0 → 26.0'), findsOneWidget);
    expect(find.text('100.0 → 150.0'), findsOneWidget);

    await tester.runAsync(() async {
      final nameField = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'IO 283');
      await tester.enterText(nameField, 'Engine RPM');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Mapear').first);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(store.byId(283)?.name, 'Engine RPM');
    expect(store.byId(283)?.unit, isNull);
    expect(find.text('Engine RPM'), findsWidgets);

    final reloaded = CanMappingStore(
      pathResolver: () async => '$tmpPath/mapping.json',
    );
    await tester.runAsync(() async {
      await reloaded.load();
      expect(reloaded.byId(283)?.name, 'Engine RPM');
      expect(reloaded.all.map((m) => m.avlId), [283]);
      if (await Directory(tmpPath).exists()) {
        await Directory(tmpPath).delete(recursive: true);
      }
    });
  });
}
