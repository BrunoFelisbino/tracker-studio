import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

abstract class UsbSerialTransport {
  Future<List<SerialPortInfo>> listPorts();
  Future<void> connect(SerialConnectionRequest request);
  Future<void> disconnect();
  Future<void> writeLine(String line);
  Stream<String> get lines;
  bool get connected;
}

abstract class SerialScanDiagnosticsProvider {
  SerialScanDiagnostics get lastScanDiagnostics;
}

abstract class SerialHandshakeTransportControl {
  SerialConnectionRequest? get currentRequest;
  Future<void> reconnectForHandshake(SerialConnectionRequest request);
  Future<void> clearInputBuffer();
}

class SerialScanDiagnostics {
  final int devicesScanned;
  final List<String> candidates;
  final List<String> ignoredDevices;

  const SerialScanDiagnostics({
    this.devicesScanned = 0,
    this.candidates = const [],
    this.ignoredDevices = const [],
  });
}

class SerialPortInfo {
  final String path;
  final String label;
  final String? manufacturer;
  final String? serialNumber;

  const SerialPortInfo({
    required this.path,
    required this.label,
    this.manufacturer,
    this.serialNumber,
  });
}

class SerialConnectionRequest {
  final String commandPortPath;
  final String? readPortPath;
  final int baudRate;
  final Duration readTimeout;
  final String lineTerminator;
  final bool dtrEnabled;
  final bool rtsEnabled;

  const SerialConnectionRequest({
    required this.commandPortPath,
    this.readPortPath,
    this.baudRate = 115200,
    this.readTimeout = const Duration(seconds: 2),
    this.lineTerminator = '\r',
    this.dtrEnabled = false,
    this.rtsEnabled = false,
  });

  SerialConnectionRequest copyWith({
    int? baudRate,
    String? lineTerminator,
    Duration? readTimeout,
  }) {
    return SerialConnectionRequest(
      commandPortPath: commandPortPath,
      readPortPath: readPortPath,
      baudRate: baudRate ?? this.baudRate,
      readTimeout: readTimeout ?? this.readTimeout,
      lineTerminator: lineTerminator ?? this.lineTerminator,
      dtrEnabled: dtrEnabled,
      rtsEnabled: rtsEnabled,
    );
  }
}

class SerialLineBuffer {
  final List<int> _pending = [];

  List<String> add(Uint8List chunk) {
    final lines = <String>[];
    for (final byte in chunk) {
      if (byte == 10 || byte == 13) {
        if (_pending.isNotEmpty) {
          final line = utf8.decode(_pending, allowMalformed: true).trim();
          _pending.clear();
          if (line.isNotEmpty) lines.add(line);
        }
        continue;
      }
      _pending.add(byte);
    }
    return lines;
  }

  void clear() => _pending.clear();
}

class LibSerialPortTransport
    implements
        UsbSerialTransport,
        SerialScanDiagnosticsProvider,
        SerialHandshakeTransportControl {
  final _linesController = StreamController<String>.broadcast();
  final _lineBuffer = SerialLineBuffer();
  SerialPort? _commandPort;
  SerialPort? _readPort;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;
  SerialScanDiagnostics _lastScanDiagnostics = const SerialScanDiagnostics();
  String _lineTerminator = '\r\n';
  SerialConnectionRequest? _currentRequest;
  bool _isDisconnecting = false;
  bool _acceptingData = false;

  @override
  bool get connected =>
      _commandPort?.isOpen == true && _readPort?.isOpen == true;

  @override
  Stream<String> get lines => _linesController.stream;

  @override
  SerialScanDiagnostics get lastScanDiagnostics => _lastScanDiagnostics;

  @override
  SerialConnectionRequest? get currentRequest => _currentRequest;

  @override
  Future<List<SerialPortInfo>> listPorts() async {
    List<String> available;
    try {
      available = SerialPort.availablePorts;
    } catch (_) {
      _lastScanDiagnostics = const SerialScanDiagnostics();
      return const [];
    }
    final ignored = <String>[];
    final ports = <SerialPortInfo>[];

    for (final address in available) {
      final port = SerialPort(address);
      try {
        final description =
            _firstNonEmpty([port.productName, port.description]);
        final metadata = [
          address,
          description,
          port.description,
          port.manufacturer,
          port.productName
        ];
        if (_shouldIgnore(metadata) || !_isRelevant(address)) {
          ignored.add(address);
          continue;
        }
        ports.add(
          SerialPortInfo(
            path: address,
            label: description == null
                ? _basename(address)
                : '$description · ${_basename(address)}',
            manufacturer: _firstNonEmpty([port.manufacturer, port.description]),
            serialNumber: port.serialNumber,
          ),
        );
      } finally {
        port.dispose();
      }
    }

    if (Platform.isMacOS &&
        ports.any((port) => port.path.toLowerCase().startsWith('/dev/cu.'))) {
      ports.removeWhere(
          (port) => port.path.toLowerCase().startsWith('/dev/tty.'));
    }
    ports.sort((left, right) {
      final priority =
          _portPriority(left.path).compareTo(_portPriority(right.path));
      return priority != 0 ? priority : left.path.compareTo(right.path);
    });

    _lastScanDiagnostics = SerialScanDiagnostics(
      devicesScanned: available.length,
      candidates: ports.map((port) => port.path).toList(),
      ignoredDevices: ignored,
    );
    return ports;
  }

  @override
  Future<void> connect(SerialConnectionRequest request) async {
    await _close(emitLog: false);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final readPath = request.readPortPath ?? request.commandPortPath;
    SerialPort? commandPort;
    SerialPort? readPort;
    try {
      final singlePort = readPath == request.commandPortPath;
      commandPort = await _openConfiguredPort(
        request.commandPortPath,
        singlePort ? SerialPortMode.readWrite : SerialPortMode.write,
        request,
      );
      readPort = singlePort
          ? commandPort
          : await _openConfiguredPort(
              readPath,
              SerialPortMode.read,
              request,
            );

      _commandPort = commandPort;
      _readPort = readPort;
      _currentRequest = request;
      _lineTerminator = request.lineTerminator;
      _lineBuffer.clear();
      _acceptingData = true;
      _reader = SerialPortReader(readPort,
          timeout: request.readTimeout.inMilliseconds);
      _readerSubscription = _reader!.stream.listen(
        (chunk) {
          if (!_acceptingData || !connected) return;
          final ascii = utf8
              .decode(chunk, allowMalformed: true)
              .replaceAll('\r', r'\r')
              .replaceAll('\n', r'\n');
          final hex = chunk
              .map((byte) =>
                  byte.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(' ');
          _addLine('[READ_ASCII] $ascii');
          _addLine('[READ_HEX] $hex');
          for (final line in _lineBuffer.add(chunk)) {
            _addLine('[READ] $line');
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_acceptingData && !_isDisconnecting) {
            _linesController.addError(error, stackTrace);
          }
        },
      );
      _addLine(
        'USB conectado. Comando: ${request.commandPortPath} · Retorno: $readPath',
      );
    } catch (error) {
      _acceptingData = false;
      if (readPort != null && !identical(readPort, commandPort)) {
        _disposePort(readPort);
      }
      if (commandPort != null) _disposePort(commandPort);
      _commandPort = null;
      _readPort = null;
      _currentRequest = null;
      rethrow;
    }
  }

  @override
  Future<void> writeLine(String line) async {
    final port = _commandPort;
    if (port == null || !port.isOpen) {
      throw StateError('USB serial não conectado.');
    }

    final payload = Uint8List.fromList(utf8.encode('$line$_lineTerminator'));
    final written = port.write(payload, timeout: 2000);
    if (written != payload.length) {
      throw StateError('Falha ao enviar o comando completo pela porta serial.');
    }
    _addLine('[SEND] $line');
    _addLine(
      '[SEND_HEX] ${payload.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
    );
  }

  @override
  Future<void> disconnect() => _close(emitLog: true);

  @override
  Future<void> reconnectForHandshake(SerialConnectionRequest request) =>
      connect(request);

  @override
  Future<void> clearInputBuffer() async {
    final port = _readPort;
    if (port != null && port.isOpen && !_isDisconnecting) {
      try {
        port.flush(SerialPortBuffer.input);
      } catch (_) {
        // A desconexão concorrente já invalida o conteúdo pendente.
      }
    }
    _lineBuffer.clear();
    _addLine('[SERIAL] Buffer de entrada limpo');
  }

  Future<void> _close({required bool emitLog}) async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    _acceptingData = false;
    final subscription = _readerSubscription;
    final reader = _reader;
    final commandPort = _commandPort;
    final readPort = _readPort;
    try {
      try {
        await subscription?.cancel();
      } catch (_) {}
      _readerSubscription = null;
      try {
        reader?.close();
      } catch (_) {}
      _reader = null;
      _lineBuffer.clear();
      if (readPort != null && !identical(readPort, commandPort)) {
        _disposePort(readPort);
      }
      if (commandPort != null) _disposePort(commandPort);
    } finally {
      _commandPort = null;
      _readPort = null;
      _currentRequest = null;
      _isDisconnecting = false;
      if (emitLog) _addLine('USB desconectado');
    }
  }

  Future<SerialPort> _openConfiguredPort(
    String path,
    int mode,
    SerialConnectionRequest request,
  ) async {
    final port = SerialPort(path);
    Object? failure;
    try {
      var opened = false;
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          opened = port.open(mode: mode);
          if (!opened) failure = SerialPort.lastError;
        } catch (error) {
          failure = error;
        }
        if (opened) break;
        if (attempt == 1) {
          _linesController.add(
            '[SERIAL RETRY] ${_failureDiagnostics(path, request, port, failure, mode)}',
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      if (!opened) {
        throw failure ?? StateError('Falha desconhecida ao abrir a porta.');
      }

      final config = SerialPortConfig();
      try {
        config
          ..baudRate = request.baudRate
          ..bits = 8
          ..stopBits = 1
          ..parity = SerialPortParity.none
          ..setFlowControl(SerialPortFlowControl.none)
          ..dtr = request.dtrEnabled ? SerialPortDtr.on : SerialPortDtr.off
          ..rts = request.rtsEnabled ? SerialPortRts.on : SerialPortRts.off;
        port.config = config;
      } finally {
        config.dispose();
      }
      return port;
    } catch (error) {
      final details = _failureDiagnostics(path, request, port, error, mode);
      _linesController.add('[SERIAL ERROR] $details');
      _disposePort(port);
      throw StateError(_failureMessage(path, error));
    }
  }

  void _disposePort(SerialPort port) {
    try {
      if (port.isOpen) port.close();
    } catch (_) {}
    try {
      port.dispose();
    } catch (_) {}
  }

  void _addLine(String line) {
    if (!_linesController.isClosed) _linesController.add(line);
  }

  bool _shouldIgnore(Iterable<String?> values) {
    const blocked = [
      'bluetooth',
      'edifier',
      'buds',
      'headset',
      'audio',
      'wireless',
      'debug',
      'console',
    ];
    final metadata = values.whereType<String>().join(' ').toLowerCase();
    return blocked.any(metadata.contains);
  }

  bool _isRelevant(String address) {
    final lower = address.toLowerCase();
    if (Platform.isWindows) {
      return RegExp(r'^com\d+$', caseSensitive: false).hasMatch(address);
    }
    if (Platform.isLinux) {
      return lower.contains('/dev/ttyusb') || lower.contains('/dev/ttyacm');
    }
    if (!Platform.isMacOS) return false;
    return lower.contains('/dev/cu.usbserial') ||
        lower.contains('/dev/tty.usbserial') ||
        lower.contains('/dev/cu.slab') ||
        lower.contains('/dev/tty.slab') ||
        lower.contains('/dev/cu.wchusbserial') ||
        lower.contains('/dev/tty.wchusbserial') ||
        lower.contains('/dev/cu.usbmodem') ||
        lower.contains('/dev/tty.usbmodem');
  }

  int _portPriority(String address) {
    final lower = address.toLowerCase();
    const preferred = [
      '/dev/cu.usbserial',
      '/dev/cu.slab',
      '/dev/cu.wchusbserial',
      '/dev/cu.usbmodem',
      '/dev/ttyusb',
      '/dev/ttyacm',
    ];
    for (var index = 0; index < preferred.length; index++) {
      if (lower.contains(preferred[index])) return index;
    }
    if (RegExp(r'^com\d+$', caseSensitive: false).hasMatch(address)) return 10;
    return 20;
  }

  String _basename(String address) => address.split('/').last;

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _failureDiagnostics(
    String path,
    SerialConnectionRequest request,
    SerialPort port,
    Object? error,
    int mode,
  ) {
    final serialError = error is SerialPortError ? error : SerialPort.lastError;
    return 'port=$path; '
        'lastError=${SerialPort.lastError}; '
        'message=${serialError?.message}; '
        'errorCode=${serialError?.errorCode}; '
        'isOpen=${port.isOpen}; '
        'mode=$mode; '
        'config=${request.baudRate},8N1,flow=none,DTR=${request.dtrEnabled},RTS=${request.rtsEnabled}';
  }

  String _failureMessage(String path, Object? error) {
    final serialError = error is SerialPortError ? error : SerialPort.lastError;
    final reason = serialError?.message.trim().isNotEmpty == true
        ? serialError!.message.trim()
        : error?.toString() ?? 'Erro desconhecido';
    final lower = reason.toLowerCase();
    if (lower.contains('permission denied') ||
        lower.contains('operation not permitted') ||
        lower.contains('not permitted') ||
        lower.contains('sandbox')) {
      return 'Acesso USB bloqueado pelo macOS. Rode o app em build debug sem sandbox ou ajuste os entitlements. '
          'Porta: $path. Erro: $reason';
    }
    if (lower.contains('resource busy') || lower.contains('device busy')) {
      return 'Falha ao abrir $path: $reason. Porta ocupada por outro app. '
          'Feche screen, Arduino IDE, monitor serial ou outro processo.';
    }
    return 'Falha ao abrir $path: $reason';
  }
}
