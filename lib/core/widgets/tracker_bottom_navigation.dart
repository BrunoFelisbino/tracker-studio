import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_radius.dart';
import '../design/tracker_shadows.dart';

class TrackerBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const TrackerBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Início'),
    (Icons.flash_on_outlined, Icons.flash_on, 'Teste'),
    (Icons.code_outlined, Icons.code, 'Comandos'),
    (Icons.map_outlined, Icons.map, 'Mapa'),
    (Icons.usb_outlined, Icons.usb, 'Dispositivos'),
  ];

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: TrackerColors.surface.withValues(alpha: 0.8),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: TrackerColors.line)),
                boxShadow: TrackerShadows.soft,
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final selected = selectedIndex == index;
                      final central = index == 2;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: item.$3,
                          child: InkWell(
                            onTap: () => onSelected(index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: central ? 44 : 34,
                                  height: central ? 44 : 32,
                                  decoration: BoxDecoration(
                                    color: central
                                        ? TrackerColors.communicationBlue
                                        : selected
                                            ? TrackerColors.surfaceMuted
                                            : Colors.transparent,
                                    borderRadius: central
                                        ? TrackerRadius.medium
                                        : TrackerRadius.pill,
                                    boxShadow:
                                        central ? TrackerShadows.soft : null,
                                  ),
                                  child: Icon(
                                    selected ? item.$2 : item.$1,
                                    color: central
                                        ? Colors.white
                                        : selected
                                            ? TrackerColors.communicationBlue
                                            : TrackerColors.textSecondary,
                                  ),
                                ),
                                if (!central) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.$3,
                                    style: TextStyle(
                                      color: selected
                                          ? TrackerColors.primaryDark
                                          : TrackerColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
