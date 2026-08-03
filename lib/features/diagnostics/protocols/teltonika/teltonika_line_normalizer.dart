import 'teltonika_hex_timestamp.dart';

/// Linha já normalizada do log Teltonika.
class NormalizedTeltonikaLine {
  final String category;
  final String content;
  final String? deviceTimestamp;
  final String? appTimestamp;
  final String? rawHex;
  final String original;
  final int line;

  const NormalizedTeltonikaLine({
    required this.category,
    required this.content,
    this.deviceTimestamp,
    this.appTimestamp,
    this.rawHex,
    required this.original,
    required this.line,
  });

  /// Chave para agrupamento de repetições.
  String get groupKey => '$category|$content';

  bool get isEmpty => content.trim().isEmpty;
}

class TeltonikaLineNormalizer {
  const TeltonikaLineNormalizer();

  static const _timestampParser = TimestampParser();
  static const _hexDecoder = HexDecoder();

  /// Recebe o texto bruto e devolve linhas normalizadas, descartando ruído
  /// (READ_ASCII duplicado, READ_HEX que só repete o texto, etc).
  List<NormalizedTeltonikaLine> normalize(String rawText) {
    final rawLines = rawText.split('\n');
    final result = <NormalizedTeltonikaLine>[];

    for (var i = 0; i < rawLines.length; i++) {
      final lineIndex = i + 1;
      var raw = rawLines[i];
      if (raw.trim().isEmpty) continue;

      final appTimestamp = _timestampParser.parseAppTimestamp(raw);
      var stripped = _stripAppPrefix(raw);
      stripped = _stripSerialPrefix(stripped);
      stripped = stripped.trim();

      // Linhas de envio do próprio app — não são eventos do dispositivo.
      if (stripped.startsWith('>> ') ||
          stripped.startsWith('SEND: ') ||
          stripped.startsWith('CMD [') ||
          stripped.startsWith('USB ') ||
          stripped.startsWith('HEX: ')) {
        continue;
      }

      // [READ_HEX] pode conter texto ASCII duplicado da linha [READ].
      if (stripped.startsWith('[READ_HEX] ')) {
        final hex = stripped.substring('[READ_HEX] '.length).trim();
        final decoded = _hexDecoder.decodeAsciiIfText(hex);
        if (decoded != null) {
          result.add(_buildLine(
            decoded,
            lineIndex,
            appTimestamp: appTimestamp,
            rawHex: hex,
            original: raw,
          ));
        } else {
          result.add(_buildLine(
            hex,
            lineIndex,
            appTimestamp: appTimestamp,
            rawHex: hex,
            original: raw,
          ));
        }
        continue;
      }

      // [READ_ASCII] é redundante com [READ]; usamos apenas como fallback.
      if (stripped.startsWith('[READ_ASCII] ')) {
        final ascii = stripped
            .substring('[READ_ASCII] '.length)
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\n', '\n');
        final lines = ascii.split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          result.add(_buildLine(
            line,
            lineIndex,
            appTimestamp: appTimestamp,
            original: raw,
          ));
        }
        continue;
      }

      if (stripped.startsWith('[READ] ')) {
        stripped = stripped.substring('[READ] '.length).trim();
      }

      // Linha com timestamp interno [2026.08.01 01:00:09]-[CATEGORIA]...
      result.add(_buildLine(
        stripped,
        lineIndex,
        appTimestamp: appTimestamp,
        original: raw,
      ));
    }

    return result.where((line) => !line.isEmpty).toList();
  }

  NormalizedTeltonikaLine _buildLine(
    String text,
    int line, {
    DateTime? appTimestamp,
    String? rawHex,
    required String original,
  }) {
    final clean = text
        .replaceAll('\t', ' ')
        .replaceAll(r'\r', ' ')
        .replaceAll(r'\n', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    final category = _extractCategory(clean);
    var content = clean;
    if (category != null) {
      final regex = RegExp(r'\[[A-Za-z0-9._]+\][\s\-:]*');
      content = clean.replaceFirst(regex, '').trim();
    }
    // Remove o timestamp interno do equipamento que precede a categoria.
    content = content.replaceFirst(
      RegExp(r'^\[\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}\]\s*-?\s*'),
      '',
    );
    return NormalizedTeltonikaLine(
      category: category ?? 'UNKNOWN',
      content: content,
      deviceTimestamp: _extractDeviceTimestamp(clean),
      appTimestamp: appTimestamp?.toIso8601String(),
      rawHex: rawHex,
      original: original,
      line: line,
    );
  }

  String? _extractCategory(String text) {
    final match = RegExp(r'\[([A-Za-z0-9._]+)\]').firstMatch(text);
    if (match == null) return null;
    final candidate = match.group(1)!;
    const known = {
      'network': 'NETWORK',
      'rec.send.1': 'REC.SEND.1',
      'rec.send.2': 'REC.SEND.2',
      'rec.gen': 'REC.GEN',
      'track': 'TRACK',
      'gps.api': 'GPS.API',
      'tsync': 'TSYNC',
      'tsync.switch': 'TSYNC.SWITCH',
      'lipo': 'LiPo',
      'lvcan': 'LVCAN',
      'axl.clbr': 'AXL.CLBR',
      'modem.action': 'MODEM.ACTION',
      'atcmd': 'ATCMD',
      'unplug': 'UNPLUG',
      'sleep': 'SLEEP',
      'overspd': 'OVERSPD',
      'wd.func': 'WD.FUNC',
      'mthl': 'MTHL',
      'sch': 'SCH',
      'fc.calc': 'FC.CALC',
      'modem.status': 'MODEM.STATUS',
      'rec.blk': 'REC.BLK',
      'rec.new': 'REC.NEW',
      'gprs': 'GPRS',
      'acc': 'ACC',
      'io': 'IO',
    };
    final canonical = known[candidate.toLowerCase()];
    if (canonical != null) return canonical;
    return null;
  }

  String? _extractDeviceTimestamp(String text) {
    final match = RegExp(
      r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})',
    ).firstMatch(text);
    return match?.group(1);
  }

  String _stripAppPrefix(String raw) {
    final match = RegExp(
      r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?\s+)',
    ).firstMatch(raw);
    if (match == null) return raw;
    return raw.substring(match.end);
  }

  String _stripSerialPrefix(String raw) {
    final match = RegExp(r'^SERIAL:\s*').firstMatch(raw);
    if (match == null) return raw;
    return raw.substring(match.end);
  }
}
