import 'package:flutter/animation.dart';

abstract final class TrackerMotion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 220);
  static const deliberate = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}
