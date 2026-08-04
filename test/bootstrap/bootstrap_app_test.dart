import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_controller.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_models.dart';
import 'package:tracker_studio/features/auth/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('failed bootstrap displays error without infinite spinner',
      (tester) async {
    final bootstrap = _controller(
      catalog: () async => throw const BootstrapStepException(
        'Arquivo de catalogo nao encontrado.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWith((ref) => bootstrap),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text('Atenção necessária'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Modo limitado'), findsOneWidget);
  });
}

BootstrapController _controller({
  BootstrapTask? session,
  BootstrapTask? catalog,
}) {
  return BootstrapController(
    checkSession: session ?? () async {},
    validateCatalog: catalog ?? () async {},
    validateProfiles: () async {},
    probeUsb: () async => SerialBootstrapStatus.disconnected,
  );
}
