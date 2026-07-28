import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_studio/core/design/tracker_theme.dart';
import 'package:tracker_studio/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tracker_studio/core/widgets/tracker_module_tile.dart';

void main() {
  testWidgets('home opens without login and shows technical modules only',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.text('Tracker Studio'), findsWidgets);
    expect(find.text('Matriz de Diagnóstico de Campo'), findsOneWidget);
    expect(find.text('COMANDOS RÁPIDOS'), findsOneWidget);
    expect(find.text('FERRAMENTAS'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);

    expect(find.text('Agenda'), findsNothing);
    expect(find.text('Calendário'), findsNothing);
    expect(find.text('Propostas'), findsNothing);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('home navigation tools can trigger routes', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/commands', builder: (_, __) => const Scaffold(body: Text('commands-route'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: TrackerTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    final catalogFinder = find.text('Catálogo');
    await tester.ensureVisible(catalogFinder);
    await tester.tap(catalogFinder);
    await tester.pumpAndSettle();

    expect(find.text('commands-route'), findsOneWidget);
  });
}
