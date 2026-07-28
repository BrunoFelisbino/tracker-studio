import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/app/router.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_controller.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_models.dart';

void main() {
  testWidgets('/settings and /reports routes work and invalid route uses internal error screen',
      (tester) async {
    final bootstrap = BootstrapController(
      checkSession: () async {},
      validateCatalog: () async {},
      validateProfiles: () async {},
      probeUsb: () async => SerialBootstrapStatus.disconnected,
    );
    await bootstrap.start();
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith((ref) => bootstrap),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsWidgets);

    container.read(routerProvider).go('/reports');
    await tester.pumpAndSettle();
    expect(find.text('Relatórios'), findsWidgets);

    container.read(routerProvider).go('/invalid-route');
    await tester.pumpAndSettle();
    expect(find.text('Rota indisponível'), findsOneWidget);
    expect(find.textContaining('/invalid-route'), findsWidgets);
    expect(find.text('Page Not Found'), findsNothing);
  });
}
