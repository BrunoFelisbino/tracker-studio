import 'package:flutter/material.dart';

abstract final class TrackerShadows {
  static const none = <BoxShadow>[];

  static const soft = [
    BoxShadow(
      color: Color(0x0A0F1A2E),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const medium = [
    BoxShadow(
      color: Color(0x0F0F1A2E),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x050F1A2E),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  static const raised = [
    BoxShadow(
      color: Color(0x140F1A2E),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x080F1A2E),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const dramatic = [
    BoxShadow(
      color: Color(0x1A0F1A2E),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x0A0F1A2E),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
