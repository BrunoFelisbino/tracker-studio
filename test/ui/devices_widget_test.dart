import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/devices/presentation/screens/devices_screen.dart';

import '../test_helpers/studio_test_harness.dart';

void main() {
  testWidgets('empty enumeration does not break and shows no fake ports',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma porta detectada'), findsOneWidget);
    expect(find.textContaining('/dev/ttyUSB0'), findsNothing);
    expect(find.textContaining('/dev/ttyACM0'), findsNothing);
    expect(find.textContaining('COM3'), findsNothing);
  });

  testWidgets('refresh button is present', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atualizar portas'), findsOneWidget);
  });

  testWidgets('connection button is present', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectar'), findsOneWidget);
  });
}