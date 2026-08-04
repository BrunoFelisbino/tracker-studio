// utils/antenna_distribution.dart
// Helper to generate circular antenna positions around a centre point.
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Generates [count] points uniformly distributed around a circle centered at [center].
/// The radius is expressed in kilometres. The points are returned as a list of [LatLng].
List<LatLng> generateCircularPositions({
  required LatLng center,
  required double radiusKm,
  required int count,
}) {
  final rand = math.Random();
  final points = <LatLng>[];
  for (var i = 0; i < count; i++) {
    // Angle uniformly around the circle with a small jitter to avoid perfect overlap.
    final angle = (2 * math.pi * i / count) + (rand.nextDouble() - 0.5) * 0.2;
    // Random radius between 0.5 and 1.0 of the max radius to keep points inside the area.
    final r = radiusKm * (0.5 + rand.nextDouble() * 0.5);
    // Convert polar to latitude/longitude offsets.
    final deltaLat =
        (r * math.cos(angle)) / 111.0; // approx degrees per km latitude
    final deltaLon = (r * math.sin(angle)) /
        (111.0 * math.cos(center.latitude * math.pi / 180));
    points.add(LatLng(center.latitude + deltaLat, center.longitude + deltaLon));
  }
  return points;
}
