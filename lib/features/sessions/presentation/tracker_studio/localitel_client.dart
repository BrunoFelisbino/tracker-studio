import 'package:dio/dio.dart';

import '../../../../core/config/env.dart';

class LocalitelClient {
  late final Dio _dio;

  LocalitelClient({Dio? dio}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  bool get enabled => AppEnv.apiBaseUrl.isNotEmpty;

  Future<LocalitelCoverageResult> analyze({
    required double latitude,
    required double longitude,
    int radiusKm = 5,
    String? connectedOperator,
    String? connectedTechnology,
    String? deviceModel,
    double? serviceLatitude,
    double? serviceLongitude,
    int? serviceRadiusMeters,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/',
        data: {
          'addressLabel': 'Posição informada pelo rastreador',
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusKm * 1000,
        },
      );

      final raw = response.data ?? const <String, dynamic>{};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return LocalitelCoverageResult.fromBridgeJson(data,
          latitude: latitude, longitude: longitude, radiusKm: radiusKm);
    } on DioException catch (error) {
      return LocalitelCoverageResult.warning(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        message:
            'Integracao externa indisponivel: ${error.type.name}. O teste do rastreador continua valido.',
      );
    } catch (error) {
      return LocalitelCoverageResult.warning(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        message:
            'Falha na integracao externa. O teste do rastreador continua valido.',
      );
    }
  }
}

class LocalitelCoverageResult {
  final double latitude;
  final double longitude;
  final int radiusKm;
  final String status;
  final String address;
  final String summary;
  final String? connectedOperator;
  final String? connectedTechnology;
  final String? recommendedOperator;
  final String? recommendedTechnology;
  final int? erbCount;
  final double? serviceDistanceMeters;
  final int? serviceToleranceMeters;
  final bool? serviceWithinRadius;

  const LocalitelCoverageResult({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.status,
    required this.address,
    required this.summary,
    this.connectedOperator,
    this.connectedTechnology,
    this.recommendedOperator,
    this.recommendedTechnology,
    this.erbCount,
    this.serviceDistanceMeters,
    this.serviceToleranceMeters,
    this.serviceWithinRadius,
  });

  factory LocalitelCoverageResult.fromJson(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) {
    final serviceCheck = json['serviceCheck'] is Map<String, dynamic>
        ? json['serviceCheck'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return LocalitelCoverageResult(
      latitude: _asDouble(json['latitude']) ?? latitude,
      longitude: _asDouble(json['longitude']) ?? longitude,
      radiusKm: _asInt(json['radiusKm']) ?? radiusKm,
      status: 'ok',
      address:
          '${json['address'] ?? json['formattedAddress'] ?? 'Endereco nao informado'}',
      summary: '${json['summary'] ?? 'Resposta da integracao recebida.'}',
      connectedOperator: _asString(json['connectedOperator']),
      connectedTechnology: _asString(json['connectedTechnology']),
      recommendedOperator: _asString(json['recommendedOperator']),
      recommendedTechnology: _asString(json['recommendedTechnology']),
      erbCount: _asInt(json['erbCount']),
      serviceDistanceMeters: _asDouble(
          serviceCheck['distanceMeters'] ?? json['serviceDistanceMeters']),
      serviceToleranceMeters:
          _asInt(serviceCheck['radiusMeters'] ?? json['serviceRadiusMeters']),
      serviceWithinRadius:
          _asBool(serviceCheck['withinRadius'] ?? json['serviceWithinRadius']),
    );
  }

  factory LocalitelCoverageResult.fromBridgeJson(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) {
    final status = switch ('${json['status']}') {
      'available' || 'ok' => 'ok',
      'unavailable' || 'error' => 'warning',
      _ => 'disabled',
    };
    final radiusMeters = _asInt(json['radiusMeters']);
    final operator = _asString(json['bestOperator']);
    final technology = _asString(json['bestTechnology']);
    return LocalitelCoverageResult(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusMeters == null ? radiusKm : (radiusMeters / 1000).round(),
      status: status,
      address: status == 'ok'
          ? 'Resposta consultada pela integracao configurada'
          : 'Integracao indisponivel',
      summary: '${json['summary'] ?? 'Cobertura não informada.'}',
      recommendedOperator: operator,
      recommendedTechnology: technology,
    );
  }

  factory LocalitelCoverageResult.disabled({
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) {
    return LocalitelCoverageResult(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      status: 'disabled',
      address: 'Integracao nao ativada',
      summary:
          'Integracao opcional desativada. Configure uma API nas configuracoes.',
    );
  }

  factory LocalitelCoverageResult.warning({
    required double latitude,
    required double longitude,
    required int radiusKm,
    required String message,
  }) {
    return LocalitelCoverageResult(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      status: 'warning',
      address: 'Double-check pendente',
      summary: message,
    );
  }

  static String? _asString(Object? value) => value == null ? null : '$value';
  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if ('$value'.toLowerCase() == 'true') return true;
    if ('$value'.toLowerCase() == 'false') return false;
    return null;
  }
}
