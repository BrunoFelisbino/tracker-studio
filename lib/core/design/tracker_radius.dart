import 'package:flutter/widgets.dart';

abstract final class TrackerRadius {
  static const small = BorderRadius.all(Radius.circular(6));
  static const medium = BorderRadius.all(Radius.circular(10));
  static const large = BorderRadius.all(Radius.circular(14));
  static const xlarge = BorderRadius.all(Radius.circular(20));
  static const pill = BorderRadius.all(Radius.circular(999));
}
