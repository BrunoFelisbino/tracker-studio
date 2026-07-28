import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tracker_studio/app/main_shell.dart';
import 'package:tracker_studio/core/widgets/tracker_bottom_navigation.dart';

void main() {
  group('Technical Workspace Navigation', () {
    testWidgets('Bottom navigation has 5 items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byType(TrackerBottomNavigation), findsOneWidget);
    });

    testWidgets('Bottom navigation does not show Agenda', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Agenda'), findsNothing);
    });

    testWidgets('Bottom navigation does not show Calendar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.calendar_month), findsNothing);
      expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    });

    testWidgets('Bottom navigation shows Teste Rápido', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Teste'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on_outlined), findsOneWidget);
    });

    testWidgets('Bottom navigation shows Comandos icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.code_outlined), findsOneWidget);
    });

    testWidgets('Bottom navigation shows Mapa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Mapa'), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('Bottom navigation shows Dispositivos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackerBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Dispositivos'), findsOneWidget);
      expect(find.byIcon(Icons.usb_outlined), findsOneWidget);
    });

    testWidgets('MainShell has 5 NavigationRail destinations', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/test',
            routes: [
              ShellRoute(
                builder: (_, __, child) => MainShell(child: child),
                routes: [
                  GoRoute(
                    path: '/test',
                    builder: (_, __) => const Scaffold(
                      body: Center(child: Text('child')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 5);
    });

    testWidgets('MainShell does not show Agenda in rail', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/test',
            routes: [
              ShellRoute(
                builder: (_, __, child) => MainShell(child: child),
                routes: [
                  GoRoute(
                    path: '/test',
                    builder: (_, __) => const Scaffold(
                      body: Center(child: Text('child')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Agenda'), findsNothing);
      expect(find.byIcon(Icons.calendar_month), findsNothing);
    });
  });
}
