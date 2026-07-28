import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/tracker_colors.dart';
import '../core/widgets/tracker_bottom_navigation.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _paths = [
    '/dashboard',
    '/quick-test',
    '/commands',
    '/map',
    '/devices',
  ];

  int _index(String location) {
    if (location.startsWith('/quick-test')) return 1;
    if (location.startsWith('/commands')) return 2;
    if (location.startsWith('/map')) return 3;
    if (location.startsWith('/devices')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _index(GoRouterState.of(context).uri.toString());
    void navigate(int index) => context.go(_paths[index]);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            backgroundColor: TrackerColors.background,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selected,
                  onDestinationSelected: navigate,
                  extended: constraints.maxWidth >= 1180,
                  backgroundColor: TrackerColors.surface,
                  indicatorColor:
                      TrackerColors.communicationBlue.withValues(alpha: 0.12),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Início')),
                    NavigationRailDestination(
                        icon: Icon(Icons.flash_on_outlined),
                        selectedIcon: Icon(Icons.flash_on),
                        label: Text('Teste Rápido')),
                    NavigationRailDestination(
                        icon: Icon(Icons.code_outlined),
                        selectedIcon: Icon(Icons.code),
                        label: Text('Comandos')),
                    NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: Text('Mapa')),
                    NavigationRailDestination(
                        icon: Icon(Icons.usb_outlined),
                        selectedIcon: Icon(Icons.usb),
                        label: Text('Dispositivos')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: TrackerColors.background,
          body: child,
          bottomNavigationBar: TrackerBottomNavigation(
            selectedIndex: selected,
            onSelected: navigate,
          ),
        );
      },
    );
  }
}
