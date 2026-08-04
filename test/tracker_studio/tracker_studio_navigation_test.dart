import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/config/env.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_live_screen.dart';

void main() {
  setUp(() {
    UceRegistry.initialize();
    TeltonikaDriver.registerAll();
  });
  Future<void> pumpStudio(
    WidgetTester tester, {
    Size size = const Size(1440, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authEnabledProvider.overrideWithValue(false)],
        child: const MaterialApp(home: TrackerStudioLiveScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('local mode badge fits the compact Studio header',
      (tester) async {
    await pumpStudio(tester, size: const Size(390, 844));

    expect(find.text('MODO LOCAL'), findsOneWidget);
  });

  testWidgets('Teste Rápido Vapt-Vupt is active by default', (tester) async {
    await pumpStudio(tester);

    expect(find.text('Teste Rápido'), findsOneWidget);
    expect(find.text('Check-in Automático Vapt-Vupt'), findsOneWidget);
  });

  testWidgets('Teste Rápido hides debug commands and Laboratory shows them',
      (tester) async {
    await pumpStudio(tester, size: const Size(800, 600));

    await tester.tap(find.text('Teste Rápido'));
    await tester.pumpAndSettle();
    expect(find.text('TESTE RÁPIDO VAPT-VUPT'), findsOneWidget);
    expect(find.text('Comando manual'), findsNothing);
    expect(find.text('Serial RAW'), findsNothing);

    await tester.tap(find.text('Laboratório'));
    await tester.pumpAndSettle();
    expect(find.text('Comando manual'), findsOneWidget);
    expect(find.text('Serial RAW'), findsOneWidget);
    expect(find.text('Varredura completa'), findsOneWidget);
    expect(find.text('Catálogo do equipamento'), findsOneWidget);
    expect(find.text('Catálogo ainda não carregado.'), findsOneWidget);
  });
}
