import 'package:geolocator/geolocator.dart';

class ServiceLocationProvider {
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<ServiceLocationResult> getCurrentPosition() async {
    try {
      final hasAccess = await requestPermission();
      if (!hasAccess) {
        return const ServiceLocationResult.permissionDenied();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return ServiceLocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: DateTime.now(),
      );
    } catch (e) {
      return ServiceLocationResult.failure('Erro ao capturar localização: $e');
    }
  }

  Future<ServiceLocationResult> requestServiceLocation() async {
    return getCurrentPosition();
  }
}

class ServiceLocationResult {
  final bool success;
  final bool permissionDenied;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? error;

  const ServiceLocationResult.success({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  })  : success = true,
        permissionDenied = false,
        error = null;

  const ServiceLocationResult.permissionDenied()
      : success = false,
        permissionDenied = true,
        latitude = null,
        longitude = null,
        accuracyMeters = null,
        capturedAt = null,
        error =
            'Permissão de localização negada. Habilite nas configurações do sistema.';

  const ServiceLocationResult.failure(this.error)
      : success = false,
        permissionDenied = false,
        latitude = null,
        longitude = null,
        accuracyMeters = null,
        capturedAt = null;
}
