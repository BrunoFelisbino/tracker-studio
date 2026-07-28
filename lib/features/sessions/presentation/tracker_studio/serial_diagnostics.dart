import 'dart:typed_data';

enum SerialLineEnding { cr, crlf, lf, none }

extension SerialLineEndingValue on SerialLineEnding {
  String get value => switch (this) {
        SerialLineEnding.cr => '\r',
        SerialLineEnding.crlf => '\r\n',
        SerialLineEnding.lf => '\n',
        SerialLineEnding.none => '',
      };

  String get label => switch (this) {
        SerialLineEnding.cr => 'CR',
        SerialLineEnding.crlf => 'CRLF',
        SerialLineEnding.lf => 'LF',
        SerialLineEnding.none => 'NONE',
      };
}

class SerialMatrixAttempt {
  final String commandPortPath;
  final String readPortPath;
  final int baudRate;
  final SerialLineEnding ending;
  final String command;

  const SerialMatrixAttempt({
    required this.commandPortPath,
    required this.readPortPath,
    required this.baudRate,
    required this.ending,
    required this.command,
  });
}

class SerialDiagnosticResult {
  final String commandPortPath;
  final String readPortPath;
  final int baudRate;
  final SerialLineEnding ending;
  final String command;
  final String response;

  const SerialDiagnosticResult({
    required this.commandPortPath,
    required this.readPortPath,
    required this.baudRate,
    required this.ending,
    required this.command,
    required this.response,
  });
}

class UsbPermissionDiagnostic {
  final String attemptedPort;
  final String rawError;
  final bool sandboxLikely;
  final String suggestion;

  const UsbPermissionDiagnostic({
    required this.attemptedPort,
    required this.rawError,
    required this.sandboxLikely,
    this.suggestion =
        'Verifique DebugProfile.entitlements e rode flutter clean.',
  });
}

class SerialDiagnosticState {
  final bool running;
  final int completedAttempts;
  final int totalAttempts;
  final bool rawBinaryReceived;
  final SerialLineEnding selectedEnding;
  final bool dtrEnabled;
  final bool rtsEnabled;
  final SerialDiagnosticResult? probableChannel;
  final UsbPermissionDiagnostic? permissionFailure;

  const SerialDiagnosticState({
    this.running = false,
    this.completedAttempts = 0,
    this.totalAttempts = 0,
    this.rawBinaryReceived = false,
    this.selectedEnding = SerialLineEnding.cr,
    this.dtrEnabled = false,
    this.rtsEnabled = false,
    this.probableChannel,
    this.permissionFailure,
  });

  SerialDiagnosticState copyWith({
    bool? running,
    int? completedAttempts,
    int? totalAttempts,
    bool? rawBinaryReceived,
    SerialLineEnding? selectedEnding,
    bool? dtrEnabled,
    bool? rtsEnabled,
    SerialDiagnosticResult? probableChannel,
    bool clearProbableChannel = false,
    UsbPermissionDiagnostic? permissionFailure,
    bool clearPermissionFailure = false,
  }) {
    return SerialDiagnosticState(
      running: running ?? this.running,
      completedAttempts: completedAttempts ?? this.completedAttempts,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      rawBinaryReceived: rawBinaryReceived ?? this.rawBinaryReceived,
      selectedEnding: selectedEnding ?? this.selectedEnding,
      dtrEnabled: dtrEnabled ?? this.dtrEnabled,
      rtsEnabled: rtsEnabled ?? this.rtsEnabled,
      probableChannel:
          clearProbableChannel ? null : probableChannel ?? this.probableChannel,
      permissionFailure: clearPermissionFailure
          ? null
          : permissionFailure ?? this.permissionFailure,
    );
  }
}

List<SerialMatrixAttempt> generateSerialDiagnosticMatrix(
    List<String> usbModemPorts) {
  if (usbModemPorts.isEmpty) return const [];
  final ports = usbModemPorts.take(2).toList();
  final routes = <(String, String)>[(ports[0], ports[0])];
  if (ports.length > 1) {
    routes.addAll([
      (ports[1], ports[1]),
      (ports[0], ports[1]),
      (ports[1], ports[0]),
    ]);
  }
  const baudRates = [9600, 19200, 38400, 57600, 115200];
  const endings = [
    SerialLineEnding.cr,
    SerialLineEnding.crlf,
    SerialLineEnding.lf
  ];
  const commands = ['AT', 'AT^CMD;;03;01'];
  return [
    for (final route in routes)
      for (final baudRate in baudRates)
        for (final ending in endings)
          for (final command in commands)
            SerialMatrixAttempt(
              commandPortPath: route.$1,
              readPortPath: route.$2,
              baudRate: baudRate,
              ending: ending,
              command: command,
            ),
  ];
}

double printableAsciiRatio(Uint8List bytes) {
  if (bytes.isEmpty) return 0;
  final printable = bytes
      .where((byte) =>
          byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte <= 126))
      .length;
  return printable / bytes.length;
}

bool isProbableAsciiResponse(String response, {Uint8List? bytes}) {
  final normalized = response.trim().toUpperCase();
  const prefixes = ['OK', 'RES;', 'ACK', 'ERR', 'AT'];
  if (prefixes.any(normalized.startsWith)) return true;
  final rawBytes = bytes ?? Uint8List.fromList(response.codeUnits);
  return rawBytes.length >= 2 && printableAsciiRatio(rawBytes) > 0.70;
}

Uint8List bytesFromHex(String value) {
  final values = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part, radix: 16))
      .whereType<int>()
      .toList();
  return Uint8List.fromList(values);
}
