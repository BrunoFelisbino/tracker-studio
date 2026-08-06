import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker_studio/core/design/tracker_theme.dart';
import 'package:tracker_studio/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/completed_service_repository.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/local_service_database.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/service_location_provider.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_parser.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/usb_serial_transport.dart';

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
    expect(find.text('MAPA'), findsOneWidget);

    expect(find.text('Agenda'), findsNothing);
    expect(find.text('Calendário'), findsNothing);
    expect(find.text('Propostas'), findsNothing);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('home shows Suntech quick commands by default', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.text('Ativar Saída 1'), findsOneWidget);
    expect(find.text('Desativar Saída 1'), findsOneWidget);
    expect(find.text('Ler Status'), findsOneWidget);
    expect(find.text('Ler Preset'), findsOneWidget);
    expect(find.text('Travar (Teltonika)'), findsNothing);
    expect(find.text('Destravar (Teltonika)'), findsNothing);
  });

  testWidgets('home shows Teltonika quick commands when Teltonika detected',
      (tester) async {
    final controller = await _makeController();
    controller.ingestRawLine(
        'AVL ID: 352093081540152 Lat: -23.550520 Lon: -46.633309');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Travar (Teltonika)'), findsOneWidget);
    expect(find.text('Destravar (Teltonika)'), findsOneWidget);
    expect(find.text('Ativar Saída 1'), findsNothing);
    expect(find.text('Desativar Saída 1'), findsNothing);
  });

  testWidgets('home navigation to map triggers route', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
            path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/map',
            builder: (_, __) => const Scaffold(body: Text('map-route'))),
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

    final iconFinder = find.byIcon(Icons.open_in_full).first;
    await tester.ensureVisible(iconFinder);
    await tester.tap(iconFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('map-route'), findsOneWidget);
  });
}

Future<TrackerStudioController> _makeController() async {
  sqfliteFfiInit();
  final database = LocalServiceDatabase(
    factory: databaseFactoryFfi,
    pathResolver: () async => inMemoryDatabasePath,
  );
  return TrackerStudioController(
    parser: SuntechParser(),
    transport: _FakeTransport(),
    localitel: LocalitelClient(),
    serviceLocation: ServiceLocationProvider(),
    completedServices: CompletedServiceRepository(database),
  );
}

class _FakeTransport implements UsbSerialTransport {
  final StreamController<String> _lines = StreamController<String>.broadcast();

  @override
  bool get connected => false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> connect(SerialConnectionRequest request) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortInfo>> listPorts() async => const [];

  @override
  Future<void> writeLine(String line) async {}
}
