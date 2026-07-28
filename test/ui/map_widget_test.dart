import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/map/presentation/tracker_map_screen.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_studio_controller.dart';

import '../test_helpers/studio_test_harness.dart';

void main() {
  testWidgets('map does not show field concepts and shows empty state without positions',
      (tester) async {
    final controller = await createStudioTestController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: TrackerMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atendimento'), findsNothing);
    expect(find.text('Propostas'), findsNothing);
    expect(find.text('Próximo'), findsNothing);
    expect(find.text('Posição indisponível'), findsOneWidget);
  });

  testWidgets('map shows integration not configured when LocaliTel is disabled',
      (tester) async {
    final controller = await createStudioTestController();
    controller.replaceState(_withMapState(TrackerSessionState.empty(), disabledLocalitel: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackerSessionControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: TrackerMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Integração LocaliTel não configurada'), findsWidgets);
    expect(find.textContaining('Computador/técnico'), findsOneWidget);
  });
}

TrackerSessionState _withMapState(TrackerSessionState state,
    {required bool disabledLocalitel}) {
  return TrackerSessionState(
    sessionCode: state.sessionCode,
    profileName: state.profileName,
    device: state.device,
    connection: state.connection,
    configuration: state.configuration,
    localitel: LocalitelAnalysis(
      latitude: -16.6799,
      longitude: -49.255,
      address: disabledLocalitel
          ? 'Integração LocaliTel não configurada'
          : 'Cobertura consultada',
      radiusKm: 5,
      status: disabledLocalitel ? 'disabled' : 'ok',
      summary: disabledLocalitel ? 'Integração LocaliTel não configurada' : 'Cobertura recebida',
    ),
    serviceLocation: const ServiceLocation(
      latitude: -16.6801,
      longitude: -49.2548,
      accuracyMeters: 8,
      status: 'capturado',
      capturedAt: '2026-07-23 10:00:00',
    ),
    manualCommand: state.manualCommand,
    selectedProfile: state.selectedProfile,
    generatedCommandPlan: state.generatedCommandPlan,
    serialDiagnostic: state.serialDiagnostic,
    selectedSuntechFamily: state.selectedSuntechFamily,
    studioMode: state.studioMode,
    stages: state.stages,
    tests: state.tests,
    commands: state.commands,
    diagnostics: state.diagnostics,
    logs: state.logs,
    activeWorkOrder: state.activeWorkOrder,
    todayWorkOrders: state.todayWorkOrders,
    serviceValidation: state.serviceValidation,
    handshakeResult: state.handshakeResult,
    networkWriteResult: state.networkWriteResult,
    recentCompletedServices: state.recentCompletedServices,
    pendingSyncServices: state.pendingSyncServices,
  );
}
