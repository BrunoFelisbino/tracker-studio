/// Utilitários para decodificar hexadecimal e timestamps do log Teltonika.
library;

class HexDecoder {
  const HexDecoder();

  /// Converte uma string hex (espaçada ou não) em bytes.
  List<int>? parseBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[\s:]+'), '');
    if (cleaned.isEmpty || cleaned.length.isOdd) return null;
    final bytes = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }

  /// Decodifica uma linha [READ_HEX] para texto ASCII quando o conteúdo
  /// for texto imprimível. Retorna null se não for texto decodificável.
  String? decodeAsciiIfText(String hex) {
    final bytes = parseBytes(hex);
    if (bytes == null || bytes.isEmpty) return null;
    if (!isPrintableAscii(bytes)) return null;
    return String.fromCharCodes(bytes);
  }

  bool isPrintableAscii(List<int> bytes) {
    if (bytes.isEmpty) return false;
    var printable = 0;
    for (final byte in bytes) {
      if (byte == 9 || byte == 10 || byte == 13) {
        printable++;
        continue;
      }
      if (byte >= 32 && byte <= 126) {
        printable++;
        continue;
      }
    }
    return printable * 10 >= bytes.length * 9;
  }

  String bytesToHex(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}

class TimestampParser {
  const TimestampParser();

  /// Timestamp da aplicação: 2026-07-31T22:00:09.431595
  DateTime? parseAppTimestamp(String text) {
    final match = RegExp(
      r'(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match == null) return null;
    final parts = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    ];
    final date = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    return date.toLocal();
  }

  /// Timestamp interno do equipamento: 2026.08.01 01:00:09
  DateTime? parseDeviceTimestamp(String text) {
    final match = RegExp(
      r'(\d{4})\.(\d{2})\.(\d{2})[ ](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
