import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../sessions/presentation/tracker_studio/service_map_preview.dart';

/// Compact map widget for the Tools area.
///
/// Shows a real-time snapshot of all known positions — service location,
/// tracker current position and the Localitel tolerance circle — without
/// consuming excessive vertical space. Designed to be responsive: on desktop
/// it floats inside a card header, on mobile it expands minimally.
class MiniMapWidget extends StatelessWidget {
  final double serviceLatitude;
  final double serviceLongitude;
  final double trackerLatitude;
  final double trackerLongitude;
  final int toleranceMeters;
  final double height;
  final bool showLabels;

  const MiniMapWidget({
    super.key,
    required this.serviceLatitude,
    required this.serviceLongitude,
    required this.trackerLatitude,
    required this.trackerLongitude,
    this.toleranceMeters = 150,
    this.height = 180,
    this.showLabels = true,
  });

  bool get _hasService => serviceLatitude != 0 && serviceLongitude != 0;
  bool get _hasTracker => trackerLatitude != 0 && trackerLongitude != 0;

  LatLng? get _servicePoint =>
      _hasService ? LatLng(serviceLatitude, serviceLongitude) : null;

  LatLng? get _trackerPoint =>
      _hasTracker ? LatLng(trackerLatitude, trackerLongitude) : null;

  LatLng _center() {
    final s = _servicePoint;
    final t = _trackerPoint;
    if (s != null && t != null) {
      return LatLng(
        (s.latitude + t.latitude) / 2,
        (s.longitude + t.longitude) / 2,
      );
    }
    return s ?? t ?? const LatLng(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _hasService || _hasTracker;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: TrackerRadius.medium,
        border: Border.all(color: TrackerColors.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: TrackerRadius.medium,
        child: Stack(
          children: [
            if (!hasAny)
              const Center(
                child: Text(
                  'Aguardando coordenadas...',
                  style: TextStyle(
                    color: TrackerColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              FlutterMap(
                options: MapOptions(
                  initialCenter: _center(),
                  initialZoom: _hasService && _hasTracker ? 14 : 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tracker.test.platform',
                  ),
                  if (_hasTracker && _hasService)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_servicePoint!, _trackerPoint!],
                          color: const Color(0xFF94A3B8),
                          strokeWidth: 2,
                        ),
                      ],
                    ),
                  if (_hasService && _servicePoint != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _servicePoint!,
                          radius: toleranceMeters.toDouble(),
                          useRadiusInMeter: true,
                          color: const Color(0x332563EB),
                          borderColor: const Color(0xFF2563EB),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_hasService && _servicePoint != null)
                        Marker(
                          point: _servicePoint!,
                          width: 36,
                          height: 36,
                          child: const Tooltip(
                            message: 'Localização do serviço',
                            child: Icon(
                              Icons.person_pin_circle,
                              color: Color(0xFF2563EB),
                              size: 32,
                            ),
                          ),
                        ),
                      if (_hasTracker && _trackerPoint != null)
                        Marker(
                          point: _trackerPoint!,
                          width: 36,
                          height: 36,
                          child: const Tooltip(
                            message: 'Posição do rastreador',
                            child: Icon(
                              Icons.location_on,
                              color: Color(0xFF16A34A),
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_hasService || _hasTracker)
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors')
                      ],
                    ),
                ],
              ),
            if (showLabels && hasAny)
              Positioned(
                top: 6,
                right: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_hasService)
                      _MiniLabel(
                        color: const Color(0xFF2563EB),
                        text: 'Serviço',
                        distance: _hasTracker
                            ? '${calculateServiceDistanceMeters(
                                  serviceLatitude: serviceLatitude,
                                  serviceLongitude: serviceLongitude,
                                  trackerLatitude: trackerLatitude,
                                  trackerLongitude: trackerLongitude,
                                )?.toStringAsFixed(0) ?? '?'} m'
                            : null,
                      ),
                    if (_hasTracker)
                      const _MiniLabel(
                        color: Color(0xFF16A34A),
                        text: 'Rastreador',
                        distance: null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final Color color;
  final String text;
  final String? distance;

  const _MiniLabel({
    required this.color,
    required this.text,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (distance != null) ...[
            const SizedBox(width: 4),
            Text(
              distance!,
              style: const TextStyle(
                  fontSize: 10, color: TrackerColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
