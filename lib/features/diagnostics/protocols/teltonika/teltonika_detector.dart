import '../../core/diagnostic_types.dart';

class TeltonikaDetector {
  const TeltonikaDetector();

  static const _categories = [
    'NETWORK',
    'REC.SEND.1',
    'REC.GEN',
    'TRACK',
    'GPS.API',
    'TSYNC',
    'TSYNC.SWITCH',
    'LiPo',
    'LVCAN',
    'AXL.CLBR',
    'MODEM.ACTION',
    'ATCMD',
    'UNPLUG',
    'SLEEP',
    'OVERSPD',
    'WD.FUNC',
    'MTHL',
    'SCH',
    'FC.CALC',
    'MODEM.STATUS',
    'REC.BLK',
    'REC.NEW',
    'GPRS',
  ];

  ProtocolDetectionResult detect(RawDiagnosticInput input) {
    final text = input.text;
    final evidence = <DetectionEvidence>[];
    var score = 0;

    void add(String rule, String description, int weight, [String? value]) {
      evidence.add(DetectionEvidence(
        rule: rule,
        description: description,
        weight: weight,
        matchedValue: value,
      ));
      score += weight;
    }

    final lines = text.split('\n');

    // Estrutura interna de log: [timestamp]-[CATEGORIA] ou [CATEGORIA].
    var internalLogLines = 0;
    var categoryHits = 0;
    final seenCategories = <String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      final bracketMatch = RegExp(r'\[([A-Za-z0-9._]+)\]').allMatches(trimmed);
      for (final match in bracketMatch) {
        final token = match.group(1)!;
        if (_categories.contains(token.toUpperCase()) ||
            _categories.contains(token)) {
          categoryHits++;
          seenCategories.add(token);
        }
      }
      if (RegExp(r'^\[?\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}\]?-\[')
              .hasMatch(trimmed) ||
          RegExp(r'^\[\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}\]-\[')
              .hasMatch(trimmed)) {
        internalLogLines++;
      }
      if (RegExp(
              r'^\[(?:NETWORK|REC\.SEND\.\d|REC\.GEN|GPS\.API|LiPo|LVCAN|ATCMD|TRACK)\]')
          .hasMatch(trimmed)) {
        internalLogLines++;
      }
    }

    if (internalLogLines >= 2) {
      add('INTERNAL_LOG', 'Estrutura interna de log Teltonika', 30,
          '$internalLogLines linhas');
    }

    if (seenCategories.contains('NETWORK')) {
      add('CAT_NETWORK', 'Categoria NETWORK encontrada', 15);
    }
    if (seenCategories.contains('REC.SEND.1') ||
        seenCategories.contains('REC.GEN')) {
      add('CAT_REC', 'Categorias de registro AVL (REC.SEND/REC.GEN)', 25,
          'REC.SEND/REC.GEN');
    }
    if (seenCategories.contains('GPS.API')) {
      add('CAT_GPS_API', 'Categoria GPS.API encontrada', 15);
    }
    if (seenCategories.contains('LVCAN')) {
      add('CAT_LVCAN', 'Categoria LVCAN encontrada', 8);
    }
    if (seenCategories.contains('LiPo')) {
      add('CAT_LIPO', 'Categoria LiPo encontrada', 8);
    }
    if (seenCategories.contains('TSYNC.SWITCH') ||
        seenCategories.contains('TSYNC')) {
      add('CAT_TSYNC', 'Categoria TSYNC encontrada', 6);
    }
    if (seenCategories.contains('AXL.CLBR')) {
      add('CAT_AXL', 'Categoria AXL.CLBR encontrada', 5);
    }

    if (text.contains('imei send OK')) {
      add('IMEI_SENT', 'Padrão "imei send OK" encontrado', 25);
    }
    if (text.contains('Record Content') ||
        text.contains('Event AVL ID') ||
        text.contains('IO ID[') ||
        text.contains('Codec 8') ||
        text.contains('Codec 8E') ||
        text.contains('Codec 12')) {
      add('AVL_ELEMENTS', 'Elementos AVL/Codec Teltonika encontrados', 20,
          'Codec 8/8E/12');
    }

    final fmbMatch = RegExp(r'\bFMB\d{3}\b').firstMatch(text);
    if (fmbMatch != null) {
      add('MODEL', 'Modelo ${fmbMatch.group(0)} identificado', 25,
          fmbMatch.group(0));
    }

    // Handshake Teltonika: <IMEI de 15 dígitos>\0.
    if (RegExp(r'\b\d{15}\x00').hasMatch(text) ||
        RegExp(r'\b\d{15}\\0').hasMatch(text)) {
      add('IMEI_HANDSHAKE', 'Handshake com tamanho de IMEI Teltonika', 20);
    }

    if (text.contains('SN mode:') ||
        text.contains('gps state:') ||
        text.contains('fw version:') && text.contains('MT')) {
      add('FW_BANNER', 'Banner de firmware Teltonika', 10);
    }

    if (text.contains('Socket Opened')) {
      add('SOCKET', 'Evento de socket TCP (Socket Opened)', 10);
    }

    if (score >= 40 &&
        internalLogLines == 0 &&
        categoryHits == 0 &&
        !text.contains('imei send OK') &&
        !text.contains('Socket Opened')) {
      score = score.clamp(0, 39);
    }

    return ProtocolDetectionResult(
      manufacturer: SupportedManufacturer.teltonika,
      protocol: 'Log interno Teltonika / AVL',
      model: fmbMatch?.group(0),
      confidence: score.clamp(0, 100),
      evidence: evidence,
    );
  }
}
