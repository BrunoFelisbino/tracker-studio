import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/diagnostics/protocols/teltonika/teltonika_line_normalizer.dart';

void main() {
  const normalizer = TeltonikaLineNormalizer();

  group('TeltonikaLineNormalizer', () {
    test('extrai categoria e conteúdo', () {
      final lines = normalizer.normalize(
        '[2026.08.01 01:00:09]-[NETWORK] Socket Opened',
      );
      expect(lines, hasLength(1));
      expect(lines.first.category, 'NETWORK');
      expect(lines.first.content, 'Socket Opened');
    });

    test('remove timestamp interno do device do conteúdo', () {
      final lines = normalizer.normalize(
        '[2026.08.01 01:00:09]-[GPS.API] HDOP: 62.12',
      );
      expect(lines.first.content, 'HDOP: 62.12');
      expect(lines.first.deviceTimestamp, '2026.08.01 01:00:09');
    });

    test('ignora linhas de envio do app', () {
      final lines = normalizer.normalize(
        '>> AT+CMGL=4\nSEND: xyz\n[2026.08.01 01:00:09]-[NETWORK] Socket Opened',
      );
      expect(lines, hasLength(1));
      expect(lines.first.category, 'NETWORK');
    });

    test('READ_HEX com texto ASCII é convertido', () {
      final lines = normalizer.normalize(
        '[READ_HEX] 48 65 6c 6c 6f',
      );
      expect(lines, hasLength(1));
      expect(lines.first.content, 'Hello');
    });

    test('READ_HEX binário é preservado como hex', () {
      final lines = normalizer.normalize(
        '[READ_HEX] 00 0F 03 1A FF',
      );
      expect(lines, hasLength(1));
      expect(lines.first.content, contains('00 0F 03 1A FF'));
    });

    test('linha vazia é descartada', () {
      final lines = normalizer.normalize('  \n\n[NETWORK] x\n');
      expect(lines, hasLength(1));
    });

    test('categoria desconhecida vira UNKNOWN sem perder conteúdo', () {
      final lines = normalizer.normalize(
        '[2026.08.01 01:00:09]-[FOOBAR] algo importante',
      );
      expect(lines, hasLength(1));
      expect(lines.first.category, 'UNKNOWN');
      expect(lines.first.content, contains('FOOBAR'));
    });
  });
}
