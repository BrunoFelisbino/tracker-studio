import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/diagnostics/core/diagnostic_types.dart';
import 'package:tracker_studio/features/diagnostics/protocols/teltonika/teltonika_event_classifier.dart';
import 'package:tracker_studio/features/diagnostics/protocols/teltonika/teltonika_line_normalizer.dart';

void main() {
  const normalizer = TeltonikaLineNormalizer();
  const classifier = TeltonikaEventClassifier();

  NormalizedDiagnosticEvent classify(String line) {
    final normalized = normalizer.normalize(line);
    return classifier.classify(
      normalized.first,
      0,
      manufacturer: SupportedManufacturer.teltonika,
    );
  }

  group('TeltonikaEventClassifier', () {
    test('HDOP alto vira severidade crítica', () {
      final event = classify('[GPS.API] HDOP: 62.12');
      expect(event.severity, DiagnosticSeverity.critical);
      expect(event.details['hdop'], closeTo(62.12, 0.01));
    });

    test('HDOP baixo é info', () {
      final event = classify('[GPS.API] HDOP: 1.2');
      expect(event.severity, DiagnosticSeverity.info);
    });

    test('socket aberto é sucesso', () {
      final event = classify('[NETWORK] Socket Opened');
      expect(event.severity, DiagnosticSeverity.success);
      expect(event.event, 'socket_opened');
    });

    test('falha de rede é erro', () {
      final event = classify('[NETWORK] connection failed');
      expect(event.severity, DiagnosticSeverity.error);
    });

    test('imei send OK é sucesso', () {
      final event = classify('[REC.SEND.1] imei send OK');
      expect(event.severity, DiagnosticSeverity.success);
    });

    test('unplug é crítico', () {
      final event = classify('[UNPLUG] External power removed');
      expect(event.severity, DiagnosticSeverity.critical);
    });

    test('extrai IP e porta de conexão', () {
      final event = classify('[NETWORK] Connecting to 192.0.2.10:5027@TCP');
      expect(event.details['ip'], '192.0.2.10');
      expect(event.details['port'], 5027);
      expect(event.details['protocol'], 'TCP');
    });

    test('extrai coordenadas', () {
      final event = classify(
        '[GPS.API] Lat: 0.0, Lon: 0.0, Alt: 851.5',
      );
      expect(event.details['latitude'], closeTo(0.0, 0.0001));
      expect(event.details['longitude'], closeTo(0.0, 0.0001));
      expect(event.details['altitude'], closeTo(851.5, 0.001));
    });

    test('extrai tensão em mV e converte para V', () {
      final event = classify('[LiPo] 12368mV');
      expect(event.value, closeTo(12.368, 0.001));
      expect(event.unit, 'V');
    });

    test('extrai IMEI do handshake', () {
      final event = classify('[REC.SEND.1] IMEI: 000000000000001');
      expect(event.details['imei'], '000000000000001');
    });
  });
}
