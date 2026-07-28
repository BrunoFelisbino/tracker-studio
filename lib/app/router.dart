import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/bootstrap/bootstrap_controller.dart';
import '../core/bootstrap/bootstrap_diagnostics_screen.dart';
import '../core/widgets/internal_route_error_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/bench/presentation/screens/bench_screen.dart';
import '../features/commands/presentation/screens/commands_screen.dart';
import '../features/devices/presentation/screens/devices_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/map/presentation/tracker_map_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/sms/presentation/screens/sms_screen.dart';
import '../features/sessions/presentation/tracker_studio/tracker_studio_live_screen.dart';
import '../features/sessions/presentation/tracker_studio/tracker_session_state.dart';
import '../features/validations/presentation/screens/validations_screen.dart';
import 'main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final bootstrapNotifier = ref.watch(bootstrapProvider.notifier);

  return GoRouter(
    refreshListenable: bootstrapNotifier,
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/bootstrap-diagnostics',
        builder: (_, __) => const BootstrapDiagnosticsScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            redirect: (_, __) => '/dashboard',
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/quick-test',
            builder: (_, __) =>
                const TrackerStudioLiveScreen(initialMode: StudioMode.quickTest),
          ),
          GoRoute(
            path: '/bench',
            builder: (_, __) => const BenchScreen(),
          ),
          GoRoute(
            path: '/lab',
            builder: (_, __) =>
                const TrackerStudioLiveScreen(initialMode: StudioMode.lab),
          ),
          GoRoute(
            path: '/devices',
            builder: (_, __) => const DevicesScreen(),
          ),
          GoRoute(
            path: '/commands',
            builder: (_, __) => const CommandsScreen(),
          ),
          GoRoute(
            path: '/sms',
            builder: (_, __) => const SmsScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (_, __) =>
                const TrackerStudioLiveScreen(initialMode: StudioMode.lab),
          ),
          GoRoute(
            path: '/validations',
            builder: (_, __) => const ValidationsScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => const TrackerMapScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => InternalRouteErrorScreen(
      requestedRoute: state.uri.toString(),
      error: state.error,
    ),
    redirect: (context, state) {
      final bootstrap = bootstrapNotifier.state;
      final location = state.matchedLocation;
      final isDiagnostics = location == '/bootstrap-diagnostics';

      if (isDiagnostics && kDebugMode) return null;

      if (!bootstrap.canEnterApp) {
        return location == '/splash' ? null : '/splash';
      }

      return null;
    },
  );
});
