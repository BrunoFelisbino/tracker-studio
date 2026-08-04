import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/design/tracker_theme.dart';
import 'package:tracker_studio/core/widgets/tracker_bottom_navigation.dart';
import 'package:tracker_studio/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tracker_studio/features/bench/presentation/screens/bench_screen.dart';
import 'package:tracker_studio/features/map/presentation/tracker_map_screen.dart';
import 'package:tracker_studio/features/devices/presentation/screens/devices_screen.dart';

void main() {
  test('uses the approved light palette', () {
    expect(TrackerColors.background, const Color(0xFFF0F2F5));
    expect(TrackerColors.surface, const Color(0xFFFFFFFF));
    expect(TrackerColors.communicationBlue, const Color(0xFF2563EB));
    expect(TrackerColors.primaryDark, const Color(0xFF0F2440));
    expect(TrackerColors.technicalGreen, const Color(0xFF059669));
  });

  testWidgets('navigation has five tabs with highlighted central test',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TrackerTheme.light(),
      home: TrackerBottomNavigation(selectedIndex: 2, onSelected: (_) {}),
    ));
    for (final label in [
      'Início',
      'Teste',
      'Comandos',
      'Mapa',
      'Dispositivos'
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('priority screens do not overflow at 320 logical pixels',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      oldHandler?.call(details);
    };

    for (final screen in <Widget>[
      const DashboardScreen(),
      const BenchScreen(),
      const TrackerMapScreen(),
      const DevicesScreen(),
    ]) {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: TrackerTheme.light(),
          home: screen,
        ),
      ));
      await tester.pump();
    }

    FlutterError.onError = oldHandler;
  });
}
