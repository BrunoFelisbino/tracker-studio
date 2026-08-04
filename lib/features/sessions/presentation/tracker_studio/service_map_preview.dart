import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../map/data/erbs_repository.dart';

class ServiceMapPreview extends StatefulWidget {
  final double serviceLatitude;
  final double serviceLongitude;
  final double trackerLatitude;
  final double trackerLongitude;
  final int toleranceMeters;
  final bool compact;

  const ServiceMapPreview({
    super.key,
    required this.serviceLatitude,
    required this.serviceLongitude,
    required this.trackerLatitude,
    required this.trackerLongitude,
    this.toleranceMeters = 150,
    this.compact = false,
  });

  @override
  State<ServiceMapPreview> createState() => _ServiceMapPreviewState();
}

class _ServiceMapPreviewState extends State<ServiceMapPreview> {
  final ErbsRepository _erbsRepo = ErbsRepository();
  List<ErbStation> _erbs = [];
  bool _loadingErbs = false;

  @override
  void initState() {
    super.initState();
    _loadErbs();
  }

  @override
  void didUpdateWidget(ServiceMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceLatitude != widget.serviceLatitude ||
        oldWidget.serviceLongitude != widget.serviceLongitude ||
        oldWidget.trackerLatitude != widget.trackerLatitude ||
        oldWidget.trackerLongitude != widget.trackerLongitude) {
      _loadErbs();
    }
  }

  Future<void> _loadErbs() async {
    final service =
        _validPoint(widget.serviceLatitude, widget.serviceLongitude);
    final tracker =
        _validPoint(widget.trackerLatitude, widget.trackerLongitude);
    final points = [if (service != null) service, if (tracker != null) tracker];
    if (points.isEmpty) return;

    setState(() => _loadingErbs = true);

    final center = points.length == 1
        ? points.first
        : LatLng(
            (points[0].latitude + points[1].latitude) / 2,
            (points[0].longitude + points[1].longitude) / 2,
          );

    final allErbs = await _erbsRepo.getErbsNear(center, 15.0);

    final uniqueErbs = <String, ErbStation>{};
    for (final erb in allErbs) {
      final key =
          '${erb.position.latitude.toStringAsFixed(5)}_${erb.position.longitude.toStringAsFixed(5)}';
      uniqueErbs[key] = erb;
    }

    if (mounted) {
      setState(() {
        _erbs = uniqueErbs.values.toList();
        _loadingErbs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service =
        _validPoint(widget.serviceLatitude, widget.serviceLongitude);
    final tracker =
        _validPoint(widget.trackerLatitude, widget.trackerLongitude);
    final points = [if (service != null) service, if (tracker != null) tracker];
    if (points.isEmpty) {
      return const Center(child: Text('Aguardando coordenadas reais.'));
    }

    final center = points.length == 1
        ? points.first
        : LatLng(
            (points[0].latitude + points[1].latitude) / 2,
            (points[0].longitude + points[1].longitude) / 2,
          );
    final distance = service == null || tracker == null
        ? null
        : const Distance().as(LengthUnit.Meter, service, tracker);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (distance != null && !widget.compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Distância: ${distance.toStringAsFixed(0)} m · Tolerância: ${widget.toleranceMeters} m',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.length == 1 ? 16 : 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tracker.test.platform',
                ),
                if (service != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: service,
                        radius: widget.toleranceMeters.toDouble(),
                        useRadiusInMeter: true,
                        color: const Color(0x332563EB),
                        borderColor: const Color(0xFF2563EB),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (service != null && tracker != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                          points: [service, tracker],
                          color: const Color(0xFF64748B),
                          strokeWidth: 3),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final erb in _erbs)
                      Marker(
                        point: erb.position,
                        width: 40,
                        height: 40,
                        child: Tooltip(
                          message:
                              'ERB: ${erb.operadoras}\n${erb.tecnologias}\n${erb.endereco}',
                          child: const Icon(Icons.cell_tower_outlined,
                              color: Color(0xFF6B7280), size: 30),
                        ),
                      ),
                    if (service != null)
                      Marker(
                        point: service,
                        width: 46,
                        height: 46,
                        child: const Tooltip(
                          message: 'Localização do serviço',
                          child: Icon(Icons.person_pin_circle,
                              color: Color(0xFF2563EB), size: 40),
                        ),
                      ),
                    if (tracker != null)
                      Marker(
                        point: tracker,
                        width: 46,
                        height: 46,
                        child: const Tooltip(
                          message: 'Posição do rastreador',
                          child: Icon(Icons.location_on,
                              color: Color(0xFF16A34A), size: 40),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors')
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LatLng? _validPoint(double latitude, double longitude) {
    if (latitude == 0 || longitude == 0) return null;
    return LatLng(latitude, longitude);
  }
}

double? calculateServiceDistanceMeters({
  required double serviceLatitude,
  required double serviceLongitude,
  required double trackerLatitude,
  required double trackerLongitude,
}) {
  if (serviceLatitude == 0 ||
      serviceLongitude == 0 ||
      trackerLatitude == 0 ||
      trackerLongitude == 0) {
    return null;
  }
  return const Distance().as(
    LengthUnit.Meter,
    LatLng(serviceLatitude, serviceLongitude),
    LatLng(trackerLatitude, trackerLongitude),
  );
}
