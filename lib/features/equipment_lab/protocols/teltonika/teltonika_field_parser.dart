import '../../../diagnostics/protocols/teltonika/teltonika_line_normalizer.dart';
import '../../core/equipment_lab_types.dart';

/// Campos extraídos de logs normais do Teltonika para campos.
///
/// Mapeia eventos de categoria de logs normais para dados interpretáveis.
class TeltonikaFieldParser {
  /// Extrai valores de campos a partir de uma linha normalizada.
  static List<DetectedField> parse(
    NormalizedTeltonikaLine line,
    DateTime timestamp,
  ) {
    final out = <DetectedField>[];

    switch (line.category) {
      case 'GPS.API':
        _add(out, 'teltonika.gps.latitude', 'Latitude', 'gps',
            _parseDouble(_extractCoord(line.content, 'Lat:')), timestamp);
        _add(out, 'teltonika.gps.longitude', 'Longitude', 'gps',
            _parseDouble(_extractCoord(line.content, 'Lon:')), timestamp);
        _add(out, 'teltonika.gps.altitude', 'Altitude', 'gps',
            _parseDouble(_extractCoord(line.content, 'Alt:')), timestamp);
        _add(out, 'teltonika.gps.hdop', 'HDOP', 'gps',
            _parseDouble(_parseKey(line.content, 'HDOP:')), timestamp);
        _add(out, 'teltonika.gps.satellites', 'Satélites', 'gps',
            _parseInt(_parseKey(line.content, 'Sat:')), timestamp);
        _add(out, 'teltonika.gps.speed', 'Velocidade', 'gps',
            _parseDouble(_parseKey(line.content, 'Spd:')), timestamp);
        _add(out, 'teltonika.gps.fix', 'GPS Fix', 'gps',
            _parseInt(_parseKey(line.content, 'FixStatus:')), timestamp);
        break;
      case 'LiPo':
        final v = _parseDouble(_parseKey(line.content, 'Voltage:') ??
            _parseKey(line.content, 'Voltage'));
        if (v != null) {
          _add(out, 'teltonika.power.external', 'Tensão externa', 'power', v,
              timestamp);
        }
        break;
      case 'ACC':
        _add(out, 'teltonika.ignition', 'Ignição', 'vehicle',
            line.content.toLowerCase().contains('on') ? 1 : 0, timestamp);
        break;
      case 'NETWORK':
        if (line.content.contains('Socket Opened')) {
          _add(out, 'teltonika.network.socket_opened', 'Socket aberto',
              'network', 1, timestamp);
        }
        if (line.content.contains('Connecting')) {
          _add(out, 'teltonika.network.connecting', 'Conectando', 'network', 1,
              timestamp);
        }
        if (_parseKey(line.content, 'Domain:') != null) {
          _add(out, 'teltonika.network.domain', 'Domínio', 'network',
              _parseKey(line.content, 'Domain:'), timestamp);
        }
        if (_parseKey(line.content, 'IP:') != null) {
          _add(out, 'teltonika.network.ip', 'IP', 'network',
              _parseKey(line.content, 'IP:'), timestamp);
        }
        break;
      case 'REC.SEND.1':
      case 'REC.SEND.2':
        if (line.content.contains('imei send OK')) {
          _add(out, 'teltonika.avl.imei_sent', 'IMEI enviado', 'avl', 1,
              timestamp);
        }
        if (line.content.contains('answer')) {
          _add(out, 'teltonika.avl.server_answer', 'Resposta servidor', 'avl',
              line.content, timestamp);
        }
        break;
      case 'TRACK':
        _add(out, 'teltonika.movement.tracked', 'Rastreamento', 'movement', 1,
            timestamp);
        break;
      case 'UNPLUG':
        _add(out, 'teltonika.power.unplugged', 'Alimentação removida', 'power',
            1, timestamp);
        break;
    }

    return out;
  }

  static void _add(
    List<DetectedField> out,
    String id,
    String rawName,
    String category,
    dynamic value,
    DateTime timestamp,
  ) {
    if (value == null) return;
    out.add(DetectedField(
      id: id,
      key: id.split('.').last,
      rawName: rawName,
      category: category,
      values: [
        FieldSample(
            timestamp: timestamp, rawValue: value, normalizedValue: value)
      ],
      firstSeenAt: timestamp,
      lastSeenAt: timestamp,
    ));
  }

  static String? _extractCoord(String content, String prefix) {
    final r = RegExp(r'${prefix}\s*([\-\d]+\.\d+)');
    final m = r.firstMatch(content);
    return m?.group(1);
  }

  static String? _parseKey(String content, String key) {
    final r = RegExp(r'${key}\s*([\-\d]+(?:\.\d+)?)', caseSensitive: false);
    return r.firstMatch(content)?.group(1);
  }

  static double? _parseDouble(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s);
  }

  static int? _parseInt(String? s) {
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s);
  }
}
