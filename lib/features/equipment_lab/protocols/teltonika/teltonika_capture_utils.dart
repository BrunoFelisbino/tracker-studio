import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/uce/uce_interfaces.dart';

/// Utility functions for USB Teltonika capture processing.
class TeltonikaCaptureUtils {
  /// Converts a list of hex strings to a combined bytes buffer.
  static Uint8List hexStringsToBytes(List<String> hexLines) {
    final bytes = <int>[];
    for (final hex in hexLines) {
      bytes.addAll(_hexToBytes(hex));
    }
    return Uint8List.fromList(bytes);
  }

  /// Converts a hex string to bytes.
  static List<int> _hexToBytes(String hex) {
    try {
      return _parseHex(hex);
    } catch (e) {
      debugPrint('Failed to parse hex string "$hex": $e');
      return [];
    }
  }

  /// Parses a hex string into bytes.
  static List<int> _parseHex(String hex) {
    if (hex.isEmpty) return [];

    // Remove whitespace and convert to uppercase
    final normalized = hex.replaceAll(RegExp(r'\s'), '').toUpperCase();

    // Ensure even length
    final len =
        normalized.length % 2 == 0 ? normalized.length : normalized.length + 1;
    final padded = normalized.padRight(len, '0');

    final bytes = <int>[];
    for (var i = 0; i < padded.length; i += 2) {
      final chunk = padded.substring(i, i + 2);
      try {
        bytes.add(int.parse(chunk, radix: 16));
      } catch (e) {
        // Skip invalid chunks
        continue;
      }
    }

    return bytes;
  }

  /// Attempts to decode ASCII text from bytes.
  static String tryDecodeAscii(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('tryDecodeAscii: failed to decode bytes: $e');
      return '';
    }
  }

  /// Checks if bytes represent valid ASCII.
  static bool isPrintableAscii(Uint8List bytes) {
    for (final b in bytes) {
      if (b < 0x20 && b != 0x09 && b != 0x0A && b != 0x0D) return false;
      if (b > 0x7E) return false;
    }
    return true;
  }

  /// Strips common prefixes from Teltonika log lines.
  static String normalizeLogLine(String line) {
    var normalized = line;

    // Remove [READ_ASCII] prefix
    if (normalized.startsWith('[READ_ASCII] ')) {
      normalized = normalized.substring('[READ_ASCII] '.length);
    }

    // Remove [READ_HEX] prefix
    if (normalized.startsWith('[READ_HEX] ')) {
      normalized = normalized.substring('[READ_HEX] '.length);
    }

    // Remove [READ] prefix
    if (normalized.startsWith('[READ] ')) {
      normalized = normalized.substring('[READ] '.length);
    }

    // Remove [SEND] prefix
    if (normalized.startsWith('[SEND] ')) {
      normalized = normalized.substring('[SEND] '.length);
    }

    // Remove timestamp prefix: [2026.08.03 15:16:01]-
    normalized = normalized.replaceFirst(RegExp(r'^\[.*\]-'), '');

    return normalized.trim();
  }

  /// Extracts all IO IDs from a line of text.
  static List<int> extractIoIds(String line) {
    final ids = <int>[];
    final pattern = RegExp(r'IO\s+ID\[(\d+)\]', caseSensitive: false);

    for (final match in pattern.allMatches(line)) {
      final id = int.tryParse(match.group(1)!);
      if (id != null) {
        ids.add(id);
      }
    }

    return ids;
  }

  /// Extracts all IO values from a line of text.
  static Map<int, dynamic> extractIoValues(String line) {
    final values = <int, dynamic>{};
    final pattern =
        RegExp(r'IO\s+ID\[(\d+)\]\s*[:=]\s*([^\s,;]+)', caseSensitive: false);

    for (final match in pattern.allMatches(line)) {
      final id = int.tryParse(match.group(1)!);
      final valueStr = match.group(2)!.trim();

      if (id != null) {
        // Try to parse as number, otherwise keep as string
        final numValue = num.tryParse(valueStr);
        values[id] = numValue ?? valueStr;
      }
    }

    return values;
  }

  /// Normalizes Teltonika-specific log line categories.
  static String normalizeCategory(String raw) {
    final lower = raw.toLowerCase();

    if (lower.contains('gps') || lower.contains('gnss')) {
      return 'GPS.API';
    }

    if (lower.contains('lipo') || lower.contains('batt')) {
      return 'LiPo';
    }

    if (lower.contains('acc') || lower.contains('ign')) {
      return 'ACC';
    }

    if (lower.contains('network') ||
        lower.contains('gprs') ||
        lower.contains('socket') ||
        lower.contains('ip')) {
      return 'NETWORK';
    }

    if (lower.contains('rec.send') || lower.contains('imei send')) {
      return lower.contains('1') ? 'REC.SEND.1' : 'REC.SEND.2';
    }

    if (lower.contains('rec.gen') || lower.contains('record content')) {
      return 'REC.GEN';
    }

    if (lower.contains('lvcan') || lower.contains('can raw')) {
      return 'LVCAN';
    }

    if (lower.contains('axtl.clbr')) {
      return 'AXL.CLBR';
    }

    if (lower.contains('tsync')) {
      return lower.contains('switch') ? 'TSYNC.SWITCH' : 'TSYNC';
    }

    if (lower.contains('modem.status')) {
      return 'MODEM.STATUS';
    }

    if (lower.contains('modem.action')) {
      return 'MODEM.ACTION';
    }

    if (lower.contains('atcmd')) {
      return 'ATCMD';
    }

    if (lower.contains('gprs')) {
      return 'GPRS';
    }

    if (lower.contains('sleep')) {
      return 'SLEEP';
    }

    if (lower.contains('unplug')) {
      return 'UNPLUG';
    }

    if (lower.contains('overspd')) {
      return 'OVERSPD';
    }

    if (lower.contains('wd.func')) {
      return 'WD.FUNC';
    }

    if (lower.contains('mthl')) {
      return 'MTHL';
    }

    if (lower.contains('sch')) {
      return 'SCH';
    }

    if (lower.contains('fc.calc')) {
      return 'FC.CALC';
    }

    if (lower.contains('track')) {
      return 'TRACK';
    }

    if (lower.contains('io ')) {
      return 'IO';
    }

    // Default category for system logs
    return 'SYSTEM';
  }

  /// Categorizes a line as GPS-related.
  static bool isGpsLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('lat') &&
            (lower.contains('lon') || lower.contains('longitude')) ||
        lower.contains('gps') &&
            (lower.contains('fix') || lower.contains('sat'));
  }

  /// Categorizes a line as power-related.
  static bool isPowerLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('volt') ||
        lower.contains('batt') ||
        lower.contains('power');
  }

  /// Categorizes a line as ignition-related.
  static bool isIgnitionLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('ign') ||
        lower.contains('ignition') ||
        lower.contains('acc') ||
        lower.contains('digital input') ||
        (line.contains('1') && line.contains('digital')) ||
        (line.contains('0') && line.contains('digital'));
  }

  /// Categorizes a line as network-related.
  static bool isNetworkLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('gprs') ||
        lower.contains('apn') ||
        lower.contains('socket') ||
        lower.contains('ip') ||
        lower.contains('port') ||
        lower.contains('domain') ||
        lower.contains('protocol');
  }

  /// Categorizes a line as CAN-related.
  static bool isCanLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('can ') ||
        lower.contains('lvcan') ||
        lower.contains('can.') ||
        lower.contains('can-');
  }

  /// Formats a hex byte for display.
  static String formatHex(int byte) {
    return '0x${byte.toRadixString(16).padLeft(2, '0')}';
  }

  /// Gets a hex string representation of bytes.
  static String toHexString(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Parses a hex string with validation.
  static bool isValidHex(String hex) {
    if (hex.isEmpty) return true;

    final normalized = hex.replaceAll(RegExp(r'\s'), '');

    // Remove 0x prefix if present
    final clean =
        normalized.startsWith('0x') ? normalized.substring(2) : normalized;

    if (clean.isEmpty) return true;

    // Check if all characters are valid hex digits
    final hexRegex = RegExp(r'^[0-9A-Fa-f]+$');
    return hexRegex.hasMatch(clean);
  }

  /// Normalizes temperature values from Kelvin to Celsius.
  static double? normalizeTemperature(double? kelvin) {
    if (kelvin == null) return null;
    return kelvin - 273.15;
  }

  /// Normalizes pressure values from hPa to bar.
  static double? normalizePressure(double? hpa) {
    if (hpa == null) return null;
    return hpa / 100.0;
  }

  /// Normalizes flow values from L/min to m³/h.
  static double? normalizeFlow(double? lpm) {
    if (lpm == null) return null;
    return lpm * 0.06;
  }

  /// Determines if a value is within expected range for a parameter.
  static bool isWithinExpectedRange(
    dynamic value, {
    required num? minExpected,
    required num? maxExpected,
    required num? minCritical,
    required num? maxCritical,
  }) {
    if (value == null) return false;

    final numValue = value is num ? value : num.tryParse('$value');
    if (numValue == null) return false;

    if (minCritical != null && maxCritical != null) {
      return numValue >= minCritical && numValue <= maxCritical;
    }

    if (minExpected != null && maxExpected != null) {
      return numValue >= minExpected && numValue <= maxExpected;
    }

    return true;
  }

  /// Determines if a value is in critical range for a parameter.
  static bool isCriticalRange(
    dynamic value, {
    required num? minCritical,
    required num? maxCritical,
  }) {
    if (value == null || minCritical == null || maxCritical == null) {
      return false;
    }

    final numValue = value is num ? value : num.tryParse('$value');
    if (numValue == null) return false;

    return numValue < minCritical || numValue > maxCritical;
  }

  /// Gets a human-readable description for a parameter ID.
  static String getParameterDescription(int parameterId) {
    switch (parameterId) {
      case 2001:
        return 'Configuração de APN';
      case 2002:
        return 'Usuário de APN';
      case 2003:
        return 'Senha de APN';
      case 2004:
        return 'Servidor de destino';
      case 2005:
        return 'Porta de destino';
      case 2006:
        return 'Protocolo de transporte';
      case 2007:
        return 'Domínio do servidor backup';
      case 2008:
        return 'Porta do servidor backup';
      case 2009:
        return 'Protocolo do servidor backup';
      case 2010:
        return 'Modo do servidor backup';
      case 10050:
        return 'Período mínimo de aquisição em movimento';
      case 10051:
        return 'Distância mínima de aquisição em movimento';
      case 10052:
        return 'Ângulo mínimo para registrar em movimento';
      case 10053:
        return 'Delta de velocidade mínima para registrar em movimento';
      case 10054:
        return 'Mínimo de registros salvos antes de enviar';
      case 10055:
        return 'Período máximo de envio em movimento';
      case 104:
        return 'Tensão de ignição alta (mV)';
      case 105:
        return 'Tensão de ignição baixa (mV)';
      case 901:
        return 'Período de resync via NTP (horas)';
      case 902:
        return 'Servidor NTP primário';
      case 903:
        return 'Servidor NTP secundário';
      case 19500:
        return 'Modo de energia de baixo consumo';
      case 19501:
        return 'Período de wake-up no modo de baixo consumo';
      case 19502:
        return 'Período de busca GPS após wake-up';
      case 19504:
        return 'Quantidade de satélites GPS necessários';
      default:
        return 'Parâmetro $parameterId';
    }
  }

  /// Gets the category for a parameter ID.
  static ParameterCategory getParameterCategory(int parameterId) {
    if ([2001, 2002, 2003, 2007, 2008, 2009, 2010].contains(parameterId)) {
      return ParameterCategory.network;
    }

    if ([2004, 2005, 2006].contains(parameterId)) {
      return ParameterCategory.server;
    }

    if ([10050, 10051, 10052, 10053, 10054, 10055].contains(parameterId)) {
      return ParameterCategory.moving;
    }

    if ([104, 105].contains(parameterId)) {
      return ParameterCategory.power;
    }

    if ([901, 902, 903].contains(parameterId)) {
      return ParameterCategory.system;
    }

    if ([19500, 19501, 19502, 19504].contains(parameterId)) {
      return ParameterCategory.system;
    }

    return ParameterCategory.unknown;
  }

  /// Gets a human-readable description for an AVL ID.
  static String getAvlIdDescription(int avlId) {
    switch (avlId) {
      case 0:
        return 'DUTY';
      case 1:
        return 'Digital Input 1';
      case 2:
        return 'Digital Input 2';
      case 3:
        return 'Ignition';
      case 4:
        return 'Digital Output 1';
      case 5:
        return 'Digital Output 2';
      case 10:
        return 'Digital Output 1';
      case 11:
        return 'Digital Output 2';
      case 16:
        return 'Trip Odometer';
      case 66:
        return 'External Voltage';
      case 67:
        return 'Battery Voltage';
      case 69:
        return 'GNSS Status';
      case 80:
        return 'CAN Battery';
      case 81:
        return 'CAN Engine';
      case 82:
        return 'CAN Accelerometer';
      case 83:
        return 'CAN RPM';
      case 84:
        return 'CAN Speed';
      case 89:
        return 'Fuel Level (resistance)';
      case 113:
        return 'Fuel Level (CAN/LVCAN)';
      case 199:
        return 'Trip Odometer (m)';
      case 240:
        return 'Movement';
      case 241:
        return 'Trip';
      case 242:
        return 'Trip Average';
      case 243:
        return 'Trip Max';
      case 244:
        return 'Trip Distance';
      case 245:
        return 'Trip Duration';
      case 181:
        return 'PDOP';
      case 182:
        return 'HDOP';
      default:
        return 'IO $avlId';
    }
  }

  /// Gets the category for an AVL ID.
  static AvlCategory getAvlIdCategory(int avlId) {
    switch (avlId) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
        return AvlCategory.input;
      case 10:
      case 11:
        return AvlCategory.output;
      case 16:
      case 199:
      case 241:
      case 244:
      case 245:
        return AvlCategory.odometer;
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
      case 83:
      case 84:
      case 113:
      case 89:
        return AvlCategory.can;
      case 69:
      case 181:
      case 182:
        return AvlCategory.gps;
      case 240:
      case 242:
      case 243:
        return AvlCategory.movement;
      default:
        return AvlCategory.unknown;
    }
  }
}
