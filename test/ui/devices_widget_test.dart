import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/devices/presentation/screens/devices_screen.dart';

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

    expect(find.byTooltip('Atualizar portas'), findsOneWidget);
  });

  testWidgets('empty state shows USB connection guidance', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Conecte um adaptador USB serial'), findsOneWidget);
  });
}
