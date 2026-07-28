enum TechnicalEvidenceStatus {
  unknown,
  pending,
  confirmed,
  failed,
  inconclusive,
}

enum TechnicalBinaryState { unknown, on, off }

class TechnicalEvidence<T> {
  final TechnicalEvidenceStatus status;
  final T? value;
  final String? rawValue;
  final TechnicalBinaryState binaryState;
  final String? detail;

  const TechnicalEvidence({
    required this.status,
    this.value,
    this.rawValue,
    this.binaryState = TechnicalBinaryState.unknown,
    this.detail,
  });

  const TechnicalEvidence.unknown({String? detail})
      : this(status: TechnicalEvidenceStatus.unknown, detail: detail);
}

class SuntechPresetSection {
  final String type;
  final int occurrence;
  final String raw;
  final Map<String, String> pairs;

  const SuntechPresetSection({
    required this.type,
    required this.occurrence,
    required this.raw,
    required this.pairs,
  });
}

List<SuntechPresetSection> splitSt8PresetSections(String response) {
  final normalized = response.replaceAll(RegExp(r'[\r\n]'), '').trim();
  final header = RegExp(r'^RES;[^;]+;03;05;(\d{2});').firstMatch(normalized);
  if (header == null) return const [];

  final sections = <SuntechPresetSection>[];
  final counts = <String, int>{};
  var type = header.group(1)!;
  var start = header.end;
  final markers = RegExp(r',(\d{2});').allMatches(normalized, start).toList();

  void addSection(int end) {
    final occurrence = (counts[type] ?? 0) + 1;
    counts[type] = occurrence;
    final raw = normalized.substring(start, end);
    sections.add(SuntechPresetSection(
      type: type,
      occurrence: occurrence,
      raw: raw,
      pairs: _parseSt8Pairs(raw),
    ));
  }

  for (final marker in markers) {
    addSection(marker.start);
    type = marker.group(1)!;
    start = marker.end;
  }
  addSection(normalized.length);
  return List.unmodifiable(sections);
}

Map<String, String> _parseSt8Pairs(String raw) {
  final pairs = <String, String>{};
  for (final token in raw.split(';')) {
    final separator = token.indexOf('#');
    if (separator < 0) continue;
    final code = token.substring(0, separator).trim();
    if (!RegExp(r'^\d{2}$').hasMatch(code)) continue;
    pairs[code] = token.substring(separator + 1).trim();
  }
  return Map.unmodifiable(pairs);
}

abstract class St8SectionParser {
  const St8SectionParser();

  String get sectionType;
  int get occurrence;

  SuntechPresetSection? extract(String response) {
    for (final section in splitSt8PresetSections(response)) {
      if (section.type == sectionType && section.occurrence == occurrence) {
        return section;
      }
    }
    return null;
  }
}

class NetworkSectionParser extends St8SectionParser {
  const NetworkSectionParser();
  @override
  String get sectionType => '10';
  @override
  int get occurrence => 1;
}

class IgnitionSectionParser extends St8SectionParser {
  const IgnitionSectionParser();
  @override
  String get sectionType => '17';
  @override
  int get occurrence => 1;
}

class InputSectionParser extends St8SectionParser {
  const InputSectionParser();
  @override
  String get sectionType => '17';
  @override
  int get occurrence => 2;
}

class OutputSectionParser extends St8SectionParser {
  const OutputSectionParser();
  @override
  String get sectionType => '17';
  @override
  int get occurrence => 3;
}

class SendingProfileSectionParser extends St8SectionParser {
  const SendingProfileSectionParser();
  @override
  String get sectionType => '16';
  @override
  int get occurrence => 1;
}

class OperationModeSectionParser extends St8SectionParser {
  const OperationModeSectionParser();
  @override
  String get sectionType => '16';
  @override
  int get occurrence => 2;
}

class SuntechParser {
  const SuntechParser();

  NormalizedTrackerSnapshot? parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;

    if (line.startsWith('RES;STT;')) return _parseSt8Status(line);
    if (line.startsWith('RES;') && line.contains(';03;05;')) {
      return _parseSt8Preset(line);
    }
    // Matches ST300STT, ST340STT, ST430STT, ST490STT, ST830STT, etc.
    if (RegExp(r'^ST\d{3,4}(U|UM|R)?STT;').hasMatch(line)) return _parseLegacyStatus(line);
    
    // Matches ST300NTW, ST430NTW, etc.
    if (RegExp(r'^ST\d{3,4}(U|UM|R)?NTW;').hasMatch(line)) return _parseLegacyPreset(line);

    if (line.contains('ST300') || line.contains('ST310')) {
      return NormalizedTrackerSnapshot(
        model: line.contains('ST310') ? 'ST310' : 'ST300 family',
        manufacturer: 'Suntech',
        rawLine: line,
        warnings: const [
          'Linha reconhecida como legado Suntech, mas ainda sem parser completo.',
        ],
      );
    }

    return NormalizedTrackerSnapshot(
      rawLine: line,
      warnings: const [
        'READ bruto recebido; parser ignorou por nao corresponder ao protocolo Suntech ASCII.',
      ],
    );
  }

  NormalizedTrackerSnapshot _parseSt8Status(String line) {
    final parts = line.split(';');
    final warnings = <String>[];
    String? at(int index) => index < parts.length ? parts[index] : null;
    double? doubleAt(int index) => double.tryParse(at(index) ?? '');
    int? intAt(int index) => int.tryParse(at(index) ?? '');

    final satellites = intAt(13);
    final fixCode = at(14);
    final gpsEvidence = _gpsEvidence(fixCode, satellites);
    final inputEvidence = _maskEvidence(at(15), 'entrada', minLength: 4, maxLength: 8);
    final outputEvidence = _maskEvidence(at(16), 'saida', minLength: 4, maxLength: 8);
    final rawIgnition = at(17);
    
    bool? ignitionOn;
    TechnicalEvidence<bool> ignitionEvidence;

    if (rawIgnition == '1' || rawIgnition == '0') {
      ignitionEvidence = _binaryEvidence(rawIgnition, 'ignicao');
      ignitionOn = ignitionEvidence.value;
    } else if (inputEvidence.value != null && inputEvidence.value!.isNotEmpty) {
      final isIgnitionOn = inputEvidence.value!.startsWith('1');
      ignitionOn = isIgnitionOn;
      ignitionEvidence = TechnicalEvidence<bool>(
        status: TechnicalEvidenceStatus.confirmed,
        value: isIgnitionOn,
        rawValue: inputEvidence.value,
        binaryState: isIgnitionOn ? TechnicalBinaryState.on : TechnicalBinaryState.off,
        detail: 'Ignição extraída da máscara de entradas ST8.',
      );
    } else {
      ignitionEvidence = _binaryEvidence(rawIgnition, 'ignicao');
      ignitionOn = ignitionEvidence.value;
    }

    final networkCode = at(25);
    final gprsEvidence = _gprsEvidence(at(26));

    if (networkCode == '255') {
      warnings.add(
        'Campo de rede 255 observado no STT; o estado GPRS depende de evidencia propria.',
      );
    }
    for (final evidence in [inputEvidence, outputEvidence, ignitionEvidence]) {
      if (evidence.status == TechnicalEvidenceStatus.inconclusive) {
        warnings.add(evidence.detail!);
      }
    }

    return NormalizedTrackerSnapshot(
      manufacturer: 'Suntech',
      model: 'ST8210/ST8310',
      esn: at(2),
      firmware: at(5),
      latitude: doubleAt(9),
      longitude: doubleAt(10),
      speed: doubleAt(11),
      direction: doubleAt(12),
      satellites: satellites,
      gpsFix: gpsEvidence.value,
      gpsEvidence: gpsEvidence,
      inputMask: inputEvidence.value,
      inputEvidence: inputEvidence,
      outputMask: outputEvidence.value,
      outputEvidence: outputEvidence,
      ignitionOn: ignitionEvidence.value,
      ignitionEvidence: ignitionEvidence,
      mainVoltage: doubleAt(22),
      backupVoltage: doubleAt(23),
      networkCode: networkCode,
      gprsOnline: gprsEvidence.value,
      gprsEvidence: gprsEvidence,
      rawLine: line,
      warnings: warnings,
    );
  }

  NormalizedTrackerSnapshot _parseSt8Preset(String line) {
    final sections = splitSt8PresetSections(line);
    final network = const NetworkSectionParser().extract(line);
    final config = network?.pairs ?? const <String, String>{};

    String protocolLabel(String? value) {
      if (value == '00') return 'TCP';
      if (value == '01') return 'UDP';
      return value ?? '';
    }

    final normalized = <String, String>{
      if ((config['01'] ?? '').isNotEmpty) 'APN': config['01']!,
      if ((config['02'] ?? '').isNotEmpty) 'Usuario': config['02']!,
      if ((config['03'] ?? '').isNotEmpty) 'Senha': config['03']!,
      if ((config['05'] ?? '').isNotEmpty) 'Servidor primario': config['05']!,
      if ((config['06'] ?? '').isNotEmpty) 'Porta primaria': config['06']!,
      if ((config['07'] ?? '').isNotEmpty)
        'Protocolo': protocolLabel(config['07']),
      if ((config['08'] ?? '').isNotEmpty) 'Servidor secundario': config['08']!,
      if ((config['09'] ?? '').isNotEmpty) 'Porta secundaria': config['09']!,
      if ((config['10'] ?? '').isNotEmpty)
        'Protocolo secundario': protocolLabel(config['10']),
      if ((config['15'] ?? '').isNotEmpty) 'AGPS': config['15']!,
    };

    return NormalizedTrackerSnapshot(
      manufacturer: 'Suntech',
      model: 'ST8210/ST8310',
      configuration: normalized,
      apn: config['01'],
      presetSections: sections,
      rawLine: line,
      warnings: sections.isEmpty
          ? const ['PRESET ST8 sem secoes reconhecidas.']
          : const [],
    );
  }

  NormalizedTrackerSnapshot _parseLegacyStatus(String payload) {
    // payload format: HDR;DEV_ID;MODEL;SW_VER;DATE;TIME;CELL;LAT;LON;SPD;CRS;SATS;FIX;DIST;PWR;VOLT;IO;...
    // Example ST310: ST300STT;200922881;01;055;20231019;145322;00115b;...
    // Example ST430: ST430STT;123456789;...
    final parts = payload.split(';');
    final warnings = <String>[];
    String? at(int index) => index < parts.length ? parts[index] : null;

    // Extract model from header (e.g. ST430STT -> ST430)
    final hdr = parts[0];
    final modelName = hdr.replaceAll('STT', '');
    
    final rawInputMaskIndex = parts.indexWhere(
      (value) => RegExp(r'^[01]{3,8}$').hasMatch(value),
    );
    final rawInputMask = rawInputMaskIndex >= 0 ? parts[rawInputMaskIndex] : null;

    int? latIndex;
    for (int i = 5; i < parts.length; i++) {
      final v1 = double.tryParse(parts[i]);
      final v2 = i + 1 < parts.length ? double.tryParse(parts[i + 1]) : null;
      if (v1 != null && v2 != null) {
        if (v1 >= -90 && v1 <= 90 && v2 >= -180 && v2 <= 180) {
          latIndex = i;
          break;
        }
      }
    }

    double? latitude;
    double? longitude;
    int? satellites;
    int? fixCode;
    bool? gpsFix;
    double? mainVoltage;

    if (latIndex != null) {
      latitude = double.tryParse(parts[latIndex]);
      longitude = double.tryParse(parts[latIndex + 1]);

      if (rawInputMaskIndex >= 0) {
        final courseIndex = latIndex + 3;
        final mainVoltIndex = rawInputMaskIndex - 1;
        
        if (mainVoltIndex > 0) {
           mainVoltage = double.tryParse(parts[mainVoltIndex]);
        }

        // Se houver 4 índices de diferença, temos Satélites, Fix e Odometer no meio.
        if (mainVoltIndex - courseIndex == 4) {
          satellites = int.tryParse(parts[courseIndex + 1]);
          fixCode = int.tryParse(parts[courseIndex + 2]);
          gpsFix = fixCode == 1; // 1 = GPS fix 2D/3D no ST310, 0 = no fix
        }
      }
    }

    // Se mainVoltage nao foi achado, usar a logica original de fallback
    mainVoltage ??= () {
      for (final value in parts) {
        final parsed = double.tryParse(value);
        if (parsed != null && parsed > 8 && parsed < 32) return parsed;
      }
      return null;
    }();

    String? ioInputMask;
    String? ioOutputMask;

    if (rawInputMask != null && rawInputMask.length >= 5) {
      // Formato ST310 comum (5 ou 6 caracteres): Ignição, In1, In2, Out1, Out2, [Out3]
      // Pegamos os primeiros 3 como entradas (o 1o é ignição)
      ioInputMask = rawInputMask.substring(0, 3);
      // Os proximos sao as saídas
      ioOutputMask = rawInputMask.substring(3, rawInputMask.length);
    } else {
      ioInputMask = rawInputMask;
    }

    final inputEvidence = _maskEvidence(
      ioInputMask,
      'entrada legacy',
      minLength: 3,
      maxLength: 8,
    );
    final ignitionEvidence = rawInputMask == null
        ? const TechnicalEvidence<bool>.unknown(
            detail: 'Mascara de entrada legacy nao encontrada.',
          )
        : TechnicalEvidence<bool>(
            status: TechnicalEvidenceStatus.confirmed,
            value: rawInputMask.startsWith('1'),
            rawValue: rawInputMask,
            binaryState: rawInputMask.startsWith('1')
                ? TechnicalBinaryState.on
                : TechnicalBinaryState.off,
          );
    if (rawInputMask == null) warnings.add(ignitionEvidence.detail!);

    final backupVoltage = parts
        .map(double.tryParse)
        .whereType<double>()
        .where((value) => value >= 3.0 && value <= 5.5)
        .lastOrNull;

    return NormalizedTrackerSnapshot(
      manufacturer: 'Suntech',
      model: modelName == 'ST300' ? 'ST300/ST310' : modelName,
      esn: parts[1],
      firmware: at(3),
      latitude: latitude,
      longitude: longitude,
      satellites: satellites,
      gpsFix: gpsFix,
      mainVoltage: mainVoltage,
      backupVoltage: backupVoltage,
      inputMask: inputEvidence.value,
      inputEvidence: inputEvidence,
      outputMask: ioOutputMask,
      ignitionOn: ignitionEvidence.value,
      ignitionEvidence: ignitionEvidence,
      rawLine: payload,
      warnings: warnings,
    );
  }

  NormalizedTrackerSnapshot _parseLegacyPreset(String line) {
    final parts = line.split(';');
    final ntwIndex = parts.indexOf('NTW');
    final config = <String, String>{};
    if (ntwIndex >= 0 && parts.length > ntwIndex + 7) {
      config['APN'] = parts[ntwIndex + 2];
      config['Servidor primario'] = parts[ntwIndex + 5];
      config['Porta primaria'] = parts[ntwIndex + 6];
      config['Servidor secundario'] = parts[ntwIndex + 7];
      if (parts.length > ntwIndex + 8) {
        config['Porta secundaria'] = parts[ntwIndex + 8];
      }
    }
    return NormalizedTrackerSnapshot(
      manufacturer: 'Suntech',
      model: 'ST300/ST310',
      configuration: config,
      apn: config['APN'],
      rawLine: line,
      warnings: config.isEmpty
          ? const ['PRESET legacy sem bloco NTW reconhecido.']
          : const [],
    );
  }
}

TechnicalEvidence<bool> _gpsEvidence(String? raw, int? satellites) {
  if (raw == '1' || (satellites != null && satellites >= 4)) {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: true,
      rawValue: raw,
      binaryState: TechnicalBinaryState.on,
    );
  }
  if (raw == '0' || satellites != null) {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: false,
      rawValue: raw,
      binaryState: TechnicalBinaryState.off,
    );
  }
  if (raw == null || raw.isEmpty) {
    return const TechnicalEvidence<bool>.unknown(
      detail: 'Estado GPS ausente no STT.',
    );
  }
  return TechnicalEvidence<bool>(
    status: TechnicalEvidenceStatus.inconclusive,
    rawValue: raw,
    detail: 'Estado GPS malformado no STT: $raw.',
  );
}

TechnicalEvidence<bool> _gprsEvidence(String? raw) {
  if (raw == '10') {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: true,
      rawValue: raw,
      binaryState: TechnicalBinaryState.on,
    );
  }
  if (raw == '0' || raw == '00') {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: false,
      rawValue: raw,
      binaryState: TechnicalBinaryState.off,
    );
  }
  if (raw == null || raw.isEmpty) {
    return const TechnicalEvidence<bool>.unknown(
      detail: 'Estado GPRS ausente no STT.',
    );
  }
  return TechnicalEvidence<bool>(
    status: TechnicalEvidenceStatus.inconclusive,
    rawValue: raw,
    detail: 'Estado GPRS nao reconhecido no STT: $raw.',
  );
}

TechnicalEvidence<bool> _binaryEvidence(String? raw, String label) {
  if (raw == '1') {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: true,
      rawValue: raw,
      binaryState: TechnicalBinaryState.on,
    );
  }
  if (raw == '0') {
    return TechnicalEvidence<bool>(
      status: TechnicalEvidenceStatus.confirmed,
      value: false,
      rawValue: raw,
      binaryState: TechnicalBinaryState.off,
    );
  }
  if (raw == null || raw.isEmpty) {
    return TechnicalEvidence<bool>.unknown(detail: '$label ausente no STT.');
  }
  return TechnicalEvidence<bool>(
    status: TechnicalEvidenceStatus.inconclusive,
    rawValue: raw,
    detail: '$label malformada no STT: $raw.',
  );
}

TechnicalEvidence<String> _maskEvidence(
  String? raw,
  String label, {
  required int minLength,
  int? maxLength,
}) {
  if (raw == null || raw.isEmpty) {
    return TechnicalEvidence<String>.unknown(
        detail: 'Mascara de $label ausente.');
  }
  final maximum = maxLength ?? minLength;
  final isBinary = RegExp(r'^[01]+$').hasMatch(raw);
  if (!isBinary || raw.length < minLength || raw.length > maximum) {
    return TechnicalEvidence<String>(
      status: TechnicalEvidenceStatus.inconclusive,
      rawValue: raw,
      detail: 'Mascara de $label malformada: $raw.',
    );
  }
  return TechnicalEvidence<String>(
    status: TechnicalEvidenceStatus.confirmed,
    value: raw,
    rawValue: raw,
  );
}

class NormalizedTrackerSnapshot {
  final String? manufacturer;
  final String? model;
  final String? esn;
  final String? firmware;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? direction;
  final int? satellites;
  final bool? gpsFix;
  final TechnicalEvidence<bool> gpsEvidence;
  final String? inputMask;
  final TechnicalEvidence<String> inputEvidence;
  final String? outputMask;
  final TechnicalEvidence<String> outputEvidence;
  final bool? ignitionOn;
  final TechnicalEvidence<bool> ignitionEvidence;
  final double? mainVoltage;
  final double? backupVoltage;
  final String? networkCode;
  final bool? gprsOnline;
  final TechnicalEvidence<bool> gprsEvidence;
  final String? apn;
  final String? rssi;
  final String? hdop;
  final Map<String, String> configuration;
  final List<SuntechPresetSection> presetSections;
  final String rawLine;
  final List<String> warnings;

  const NormalizedTrackerSnapshot({
    this.manufacturer,
    this.model,
    this.esn,
    this.firmware,
    this.latitude,
    this.longitude,
    this.speed,
    this.direction,
    this.satellites,
    this.gpsFix,
    this.gpsEvidence = const TechnicalEvidence<bool>.unknown(),
    this.inputMask,
    this.inputEvidence = const TechnicalEvidence<String>.unknown(),
    this.outputMask,
    this.outputEvidence = const TechnicalEvidence<String>.unknown(),
    this.ignitionOn,
    this.ignitionEvidence = const TechnicalEvidence<bool>.unknown(),
    this.mainVoltage,
    this.backupVoltage,
    this.networkCode,
    this.gprsOnline,
    this.gprsEvidence = const TechnicalEvidence<bool>.unknown(),
    this.apn,
    this.rssi,
    this.hdop,
    this.configuration = const {},
    this.presetSections = const [],
    required this.rawLine,
    this.warnings = const [],
  });

  bool get hasPosition =>
      latitude != null && longitude != null && latitude != 0 && longitude != 0;
  bool get backupPresent => backupVoltage != null && backupVoltage! > 0;
}
