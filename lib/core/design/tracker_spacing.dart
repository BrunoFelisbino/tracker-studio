import 'package:flutter/widgets.dart';

abstract final class TrackerSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;

  static const EdgeInsets pagePadding = EdgeInsets.all(xl);
  static const EdgeInsets sectionPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets tight = EdgeInsets.all(sm);
  static const EdgeInsets comfortable = EdgeInsets.all(xl);
}
