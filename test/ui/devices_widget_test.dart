import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/devices/presentation/screens/devices_screen.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

import '../test_helpers/studio_test_harness.dart';

void main() {
  testWidgets('empty enumeration does not break and shows no fake ports',
      (tester) async {
    final controller = await createStudioTestController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma porta detectada'), findsWidgets);
    expect(find.textContaining('/dev/ttyUSB0'), findsNothing);
    expect(find.textContaining('/dev/ttyACM0'), findsNothing);
    expect(find.textContaining('COM3'), findsNothing);
  });

  testWidgets('refresh button calls adapter', (tester) async {
    final controller = await createStudioTestController();
    final transport = controller.testTransport;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final before = transport.listPortsCalls;
    await tester.tap(find.text('Atualizar portas'));
    await tester.pumpAndSettle();

    expect(transport.listPortsCalls, greaterThan(before));
  });

  testWidgets('connection only enables with selected real port', (tester) async {
    final controller = await createStudioTestController(
      ports: const [
        SerialPortInfo(
          path: '/dev/cu.usbserial-real',
          label: 'USB Serial Real',
        ),
      ],
    );
    final transport = controller.testTransport;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final connectButton = find.widgetWithText(ElevatedButton, 'Conectar');
    ElevatedButton button = tester.widget(connectButton);
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Serial Real').last);
    await tester.pumpAndSettle();

    button = tester.widget(connectButton);
    expect(button.onPressed, isNotNull);

    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(transport.connectCalls, 1);
    expect(transport.lastRequest?.commandPortPath, '/dev/cu.usbserial-real');
    await controller.disconnectUsb();
    await tester.pump(const Duration(seconds: 1));
  });
}
