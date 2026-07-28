import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/localitel_client.dart';

void main() {
  test('uses the configured integration and sends only tracker fields',
      () async {
    Map<String, dynamic>? sentPayload;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sentPayload = Map<String, dynamic>.from(options.data as Map);
          expect(options.path, '/');
          expect(options.method, 'POST');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'available',
                'riskLevel': 'low',
                'summary': 'Cobertura disponível.',
                'radiusMeters': 5000,
                'bestOperator': 'Claro',
                'bestTechnology': '4G',
                 'sources': ['example-provider'],
              },
            ),
          );
        },
      ),
    );

    final result = await LocalitelClient(dio: dio).analyze(
      latitude: -16.711915,
      longitude: -49.254693,
    );

    expect(sentPayload, {
      'addressLabel': 'Posição informada pelo rastreador',
      'latitude': -16.711915,
      'longitude': -49.254693,
      'radiusMeters': 5000,
    });
    expect(result.status, 'ok');
    expect(result.recommendedOperator, 'Claro');
    expect(result.recommendedTechnology, '4G');
  });
}
