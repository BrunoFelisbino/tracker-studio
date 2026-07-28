import 'dart:core';

/// Gera links seguros para abrir ou criar rota no Google Maps sem depender
/// de dados fictícios. A origem pode ser omitida para o Google Maps usar a
/// localização atual do técnico.
class WorkOrderRoute {
  final String destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? providedGoogleMapsUrl;

  const WorkOrderRoute({
    required this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.providedGoogleMapsUrl,
  });

  bool get hasDestination =>
      destinationAddress.trim().isNotEmpty ||
      (destinationLatitude != null && destinationLongitude != null);

  Uri? get directLink {
    final provided = providedGoogleMapsUrl?.trim();
    if (provided != null && provided.isNotEmpty) {
      final uri = Uri.tryParse(provided);
      if (uri != null && _isAllowedGoogleMapsHost(uri.host)) return uri;
    }

    if (!hasDestination) return null;
    final destination = destinationLatitude != null &&
            destinationLongitude != null
        ? '${destinationLatitude!},${destinationLongitude!}'
        : destinationAddress.trim();

    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': destination,
    });
  }

  Uri? routeLink({String? origin}) {
    if (!hasDestination) return null;
    final destination = destinationLatitude != null &&
            destinationLongitude != null
        ? '${destinationLatitude!},${destinationLongitude!}'
        : destinationAddress.trim();

    final query = <String, String>{
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    };
    final normalizedOrigin = origin?.trim();
    if (normalizedOrigin != null && normalizedOrigin.isNotEmpty) {
      query['origin'] = normalizedOrigin;
    }

    return Uri.https('www.google.com', '/maps/dir/', query);
  }
}

bool _isAllowedGoogleMapsHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'maps.google.com' ||
      normalized == 'www.google.com' ||
      normalized == 'google.com' ||
      normalized.endsWith('.google.com');
}
