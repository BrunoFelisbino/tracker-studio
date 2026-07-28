import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/bench/presentation/screens/bench_screen.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';

import '../test_helpers/studio_test_harness.dart';

void main() {
  testWidgets('bench uses real empty state without fixed identity',
      (tester) async {
    final controller = await createStudioTestController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: BenchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desconectado'), findsWidgets);
    expect(find.text('/dev/ttyUSB0'), findsNothing);
    expect(find.text('ST8210'), findsNothing);
  });

  testWidgets('bench reflects controller state and execution stages',
      (tester) async {
    final controller = await createStudioTestController();
    controller.replaceState(TrackerSessionState.empty());

    await controller.connectUsb('/dev/cu.usbserial-real');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: BenchScreen()),
      ),
    );
    expect(find.text('/dev/cu.usbserial-real'), findsOneWidget);
    expect(find.text('Conectado'), findsOneWidget);
    await controller.disconnectUsb();
    await tester.pump(const Duration(seconds: 1));
  });
}
