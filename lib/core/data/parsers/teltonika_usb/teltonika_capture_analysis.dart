import '../../../drivers/teltonika/teltonika_driver.dart';
import '../../../uce/registry/uce_registry.dart';
import '../../../uce/uce_interfaces.dart';
import 'teltonika_usb_models.dart';

/// One observed value of an IO element inside a captured AVL record.
class TeltonikaIoReading {
  final int avlId;
  final dynamic rawValue;
  final dynamic normalizedValue;
  final int recordIndex;

  const TeltonikaIoReading({
    required this.avlId,
    required this.rawValue,
    required this.normalizedValue,
    required this.recordIndex,
  });
}

/// A value change observed for one IO element across the captured window.
class TeltonikaIoChange {
  final int avlId;

  /// AVL catalog definition, or null when the ID is unknown to the catalog.
  final AvlDefinition? definition;
  final String? normalizedKey;

  /// Display name (catalog name or a fallback like `IO 283`).
  final String name;
  final dynamic before;
  final dynamic after;
  final dynamic beforeNormalized;
  final dynamic afterNormalized;
  final String? unit;
  final int firstRecordIndex;
  final int lastRecordIndex;

  /// Number of times the value changed between consecutive records.
  final int transitions;
  final bool known;

  const TeltonikaIoChange({
    required this.avlId,
    required this.definition,
    required this.normalizedKey,
    required this.name,
    required this.before,
    required this.after,
    required this.beforeNormalized,
    required this.afterNormalized,
    required this.unit,
    required this.firstRecordIndex,
    required this.lastRecordIndex,
    required this.transitions,
    required this.known,
  });

  String get displayLabel => known ? name : 'IO $avlId (sem catálogo)';

  Map<String, dynamic> toJson() => {
        'avlId': avlId,
        'normalizedKey': normalizedKey,
        'name': name,
        'before': before,
        'after': after,
        'beforeNormalized': beforeNormalized,
        'afterNormalized': afterNormalized,
        'unit': unit,
        'firstRecordIndex': firstRecordIndex,
        'lastRecordIndex': lastRecordIndex,
        'transitions': transitions,
        'known': known,
      };
}

/// A parsed AVL record that differs from the previous record in the capture.
class TeltonikaChangedPacket {
  final int recordIndex;

  /// IO IDs that changed when compared with the previous record.
  final List<int> changedIoIds;

  /// IO IDs that changed but have no catalog definition (sensor candidates).
  final List<int> unknownChangedIoIds;

  const TeltonikaChangedPacket({
    required this.recordIndex,
    required this.changedIoIds,
    required this.unknownChangedIoIds,
  });

  bool get hasChanges => changedIoIds.isNotEmpty;
}

/// Complete analysis of a captured Teltonika log window.
class TeltonikaCaptureAnalysis {
  final List<String> rawLines;
  final DetectedTeltonikaDevice? device;
  final List<TeltonikaGeneratedAvlRecord> avlRecords;
  final List<TeltonikaObservedIo> observedIos;
  final List<TeltonikaUsbConfigCommand> configCommands;

  /// Last value seen per configuration parameter ID (from `:cfg_setparam`
  /// lines captured in the log), keyed by Teltonika parameter number.
  final Map<int, String> parameterValues;

  /// Parameter IDs whose `:cfg_setparam` was followed by `<SETPARAM_RESULT>:1`.
  final Set<int> confirmedParameters;

  final List<String> warnings;
  final List<String> errors;
  final DateTime analyzedAt;

  TeltonikaCaptureAnalysis({
    required this.rawLines,
    required this.device,
    required this.avlRecords,
    required this.observedIos,
    required this.configCommands,
    this.parameterValues = const {},
    this.confirmedParameters = const {},
    required this.warnings,
    required this.errors,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'rawLineCount': rawLines.length,
        'device': device?.toJson(),
        'avlRecordCount': avlRecords.length,
        'observedIoCount': observedIos.length,
        'configCommandCount': configCommands.length,
        'parameterValues':
            parameterValues.map((k, v) => MapEntry('$k', v)),
        'confirmedParameters':
            confirmedParameters.map((id) => id.toString()).toList(),
        'warnings': warnings,
        'errors': errors,
      };
}

/// Result of comparing IO/packet evolution inside a captured window.
class TeltonikaCaptureDiff {
  final int totalRecords;
  final int changedRecordCount;
  final List<TeltonikaChangedPacket> changedPackets;
  final List<TeltonikaIoChange> ioChanges;
  final List<TeltonikaIoChange> knownChangedIos;
  final List<TeltonikaIoChange> unknownChangedIos;
  final List<String> summary;

  const TeltonikaCaptureDiff({
    required this.totalRecords,
    required this.changedRecordCount,
    required this.changedPackets,
    required this.ioChanges,
    required this.knownChangedIos,
    required this.unknownChangedIos,
    required this.summary,
  });

  bool get hasChanges => ioChanges.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'totalRecords': totalRecords,
        'changedRecordCount': changedRecordCount,
        'changedPacketIndexes': changedPackets.map((p) => p.recordIndex).toList(),
        'ioChanges': ioChanges.map((c) => c.toJson()).toList(),
        'summary': summary,
      };
}

/// Analyzes captured Teltonika log lines and diffs the observed IO/packet
/// evolution. This is the core of the log capture/diff workflow used to map
/// device data (sensors, CAN, configuration) from reconstructed log lines.
class TeltonikaCaptureAnalyzer {
  /// Builds the analysis of a captured window.
  ///
  /// [hexChunks] are the raw `[READ_HEX]` payloads collected alongside
  /// [rawLines]. They're needed to decode the binary AVL codec the FMB devices
  /// stream over USB serial, which carries the real IO values during an event.
  static TeltonikaCaptureAnalysis analyze(
    List<String> rawLines, [
    List<String> hexChunks = const [],
  ]) {
    final warnings = <String>[];
    final errors = <String>[];

    if (rawLines.isEmpty) {
      warnings.add('Nenhuma linha capturada durante a análise.');
    }

    DetectedTeltonikaDevice? device;
    try {
      device = TeltonikaDriver.discoverDevice(rawLines);
    } catch (error) {
      errors.add('Falha ao detectar o dispositivo: $error');
    }

    var avlRecords = <TeltonikaGeneratedAvlRecord>[];
    try {
      avlRecords = TeltonikaDriver.parseAvlRecords(rawLines);
    } catch (error) {
      errors.add('Falha ao parsear registros AVL: $error');
    }

    // The FMB140 can stream real AVL records as a binary codec frame inside the
    // `[READ_HEX]` chunks of the serial log. Decode them so the IOs that move
    // during an event (ignition, door, brake, ...) become observed.
    if (hexChunks.isNotEmpty) {
      try {
        final binaryRecords =
            TeltonikaDriver.decodeBinaryFromHexLines(hexChunks);
        if (binaryRecords.isNotEmpty) {
          avlRecords = [...avlRecords, ...binaryRecords];
        }
      } catch (error) {
        errors.add('Falha ao decodificar AVL binário: $error');
      }
    }

    if (avlRecords.isEmpty && rawLines.any(_looksLikeRecordContent)) {
      warnings.add(
          'Conteúdo de registro encontrado, mas nenhum registro AVL completo foi parseado.');
    }

    List<TeltonikaObservedIo> observedIos = [];
    try {
      observedIos = TeltonikaDriver.collectObservedIos(avlRecords);
    } catch (error) {
      errors.add('Falha ao coletar IOs observados: $error');
    }

    final configCommands = <TeltonikaUsbConfigCommand>[];
    for (var index = 0; index < rawLines.length; index++) {
      final text = rawLines[index].trim();
      if (text.isEmpty) continue;
      final command = TeltonikaDriver.parseConfigCommand(
        text,
        packetNumber: index + 1,
        direction: text.startsWith('<') ? 'device-to-host' : 'host-to-device',
      );
      if (command != null) configCommands.add(command);
    }

    if (configCommands.isEmpty &&
        rawLines.any((line) => line.contains(':cfg_') || line.contains('<CFG_'))) {
      warnings.add(
          'Comandos de configuração vistos na captura, mas nenhum foi reconhecido.');
    }

    final parameterValues = _extractParameterValues(configCommands);
    final confirmedParameters =
        _extractConfirmedParameters(configCommands, parameterValues);

    return TeltonikaCaptureAnalysis(
      rawLines: List.unmodifiable(rawLines),
      device: device,
      avlRecords: List.unmodifiable(avlRecords),
      observedIos: List.unmodifiable(observedIos),
      configCommands: List.unmodifiable(configCommands),
      parameterValues: parameterValues,
      confirmedParameters: confirmedParameters,
      warnings: List.unmodifiable(warnings),
      errors: List.unmodifiable(errors),
    );
  }

  /// Maps each captured `:cfg_setparam:<id>:<value>` to its last value.
  static Map<int, String> _extractParameterValues(
      List<TeltonikaUsbConfigCommand> commands) {
    final values = <int, String>{};
    for (final command in commands) {
      if (command.command == 'set-parameter' &&
          command.parameterId != null &&
          command.rawValue != null) {
        values[command.parameterId!] = command.rawValue!;
      }
    }
    return values;
  }

  /// Tracks which parameter IDs were accepted (`<SETPARAM_RESULT>:1`) after a
  /// `:cfg_setparam` in the same window.
  static Set<int> _extractConfirmedParameters(
    List<TeltonikaUsbConfigCommand> commands,
    Map<int, String> parameterValues,
  ) {
    final confirmed = <int>{};
    int? pending;
    for (final command in commands) {
      if (command.command == 'set-parameter' && command.parameterId != null) {
        pending = command.parameterId;
      } else if (command.command == 'set-parameter-result') {
        if (command.parsedValue == 'accepted' && pending != null) {
          confirmed.add(pending);
        }
        pending = null;
      }
    }
    return confirmed;
  }

  /// Diffs the IO/packet evolution inside one captured window.
  static TeltonikaCaptureDiff diff(TeltonikaCaptureAnalysis analysis) {
    final records = analysis.avlRecords;

    final history = <int, List<TeltonikaIoReading>>{};
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      for (final entry in record.ioElements.entries) {
        final definition = UceRegistry().avl.getByAvlId(entry.key);
        history
            .putIfAbsent(entry.key, () => [])
            .add(TeltonikaIoReading(
              avlId: entry.key,
              rawValue: entry.value,
              normalizedValue: definition?.convertValue(entry.value),
              recordIndex: index,
            ));
      }
    }

    final ioChanges = <TeltonikaIoChange>[];
    history.forEach((avlId, readings) {
      final first = readings.first;
      final last = readings.last;
      var transitions = 0;
      for (var i = 1; i < readings.length; i++) {
        if (_valuesDiffer(
          readings[i - 1].normalizedValue ?? readings[i - 1].rawValue,
          readings[i].normalizedValue ?? readings[i].rawValue,
        )) {
          transitions += 1;
        }
      }
      if (transitions == 0) return;

      final definition = UceRegistry().avl.getByAvlId(avlId);
      ioChanges.add(TeltonikaIoChange(
        avlId: avlId,
        definition: definition,
        normalizedKey: definition?.normalizedKey,
        name: definition?.name ?? 'IO $avlId',
        before: first.rawValue,
        after: last.rawValue,
        beforeNormalized: first.normalizedValue,
        afterNormalized: last.normalizedValue,
        unit: definition?.displayUnit,
        firstRecordIndex: first.recordIndex,
        lastRecordIndex: last.recordIndex,
        transitions: transitions,
        known: definition != null,
      ));
    });
    ioChanges.sort((a, b) => a.avlId.compareTo(b.avlId));

    final changedPackets = <TeltonikaChangedPacket>[];
    for (var index = 1; index < records.length; index++) {
      final previous = records[index - 1];
      final current = records[index];
      final changedIoIds = _diffIoMaps(previous.ioElements, current.ioElements);
      if (changedIoIds.isEmpty) continue;
      changedPackets.add(TeltonikaChangedPacket(
        recordIndex: index,
        changedIoIds: changedIoIds,
        unknownChangedIoIds: changedIoIds
            .where((id) => UceRegistry().avl.getByAvlId(id) == null)
            .toList(),
      ));
    }

    final knownChangedIos =
        ioChanges.where((change) => change.known).toList(growable: false);
    final unknownChangedIos =
        ioChanges.where((change) => !change.known).toList(growable: false);

    final summary = _buildSummary(
      analysis: analysis,
      changedRecordCount: changedPackets.length,
      knownChangedIos: knownChangedIos,
      unknownChangedIos: unknownChangedIos,
    );

    return TeltonikaCaptureDiff(
      totalRecords: records.length,
      changedRecordCount: changedPackets.length,
      changedPackets: List.unmodifiable(changedPackets),
      ioChanges: List.unmodifiable(ioChanges),
      knownChangedIos: List.unmodifiable(knownChangedIos),
      unknownChangedIos: List.unmodifiable(unknownChangedIos),
      summary: List.unmodifiable(summary),
    );
  }

  static List<String> _buildSummary({
    required TeltonikaCaptureAnalysis analysis,
    required int changedRecordCount,
    required List<TeltonikaIoChange> knownChangedIos,
    required List<TeltonikaIoChange> unknownChangedIos,
  }) {
    final lines = <String>[
      if (analysis.device != null)
        'Dispositivo identificado: ${analysis.device!.model ?? 'Teltonika'} '
            '(confiança ${analysis.device!.confidence.toStringAsFixed(0)}%)'
      else
        'Nenhum dispositivo Teltonika identificado nas linhas capturadas.',
      '${analysis.avlRecords.length} registro(s) AVL em ${analysis.rawLines.length} '
          'linha(s) capturada(s).',
      if (analysis.configCommands.isNotEmpty)
        '${analysis.configCommands.length} comando(s) de configuração detectados.',
      if (analysis.parameterValues.isNotEmpty)
        '${analysis.parameterValues.length} parâmetro(s) de configuração vistos na captura.',
    ];

    if (analysis.avlRecords.isNotEmpty) {
      if (changedRecordCount == 0) {
        lines.add('Nenhuma alteração de IO entre os registros capturados.');
      } else {
        lines.add('$changedRecordCount pacote(s) com alteração de IO.');
        if (unknownChangedIos.isNotEmpty) {
          lines.add(
            '${unknownChangedIos.length} IO(s) alterado(s) sem definição no catálogo '
            '— candidatos a sensor CAN: '
            '${unknownChangedIos.map((c) => c.avlId).join(', ')}.',
          );
        }
        if (knownChangedIos.isNotEmpty) {
          lines.add(
            '${knownChangedIos.length} IO(s) alterado(s) conhecido(s): '
            '${knownChangedIos.map((c) => c.normalizedKey ?? c.avlId).join(', ')}.',
          );
        }
      }
    }

    for (final warning in analysis.warnings) {
      lines.add('Aviso: $warning');
    }
    return lines;
  }

  static List<int> _diffIoMaps(
      Map<int, dynamic> previous, Map<int, dynamic> current) {
    final changed = <int>[];
    final allIds = <int>{...previous.keys, ...current.keys};
    for (final id in allIds) {
      if (_valuesDiffer(previous[id], current[id])) {
        changed.add(id);
      }
    }
    changed.sort();
    return changed;
  }

  static bool _valuesDiffer(dynamic left, dynamic right) {
    if (left == right) return false;
    if (left == null || right == null) return true;
    final leftNum = left is num ? left : num.tryParse('$left');
    final rightNum = right is num ? right : num.tryParse('$right');
    if (leftNum != null && rightNum != null) {
      return leftNum != rightNum;
    }
    return '$left' != '$right';
  }

  static bool _looksLikeRecordContent(String line) {
    return line.contains('[REC.GEN]') ||
        line.contains('Record Content:') ||
        line.contains('IO ID[') ||
        line.contains('Record Size:');
  }
}
