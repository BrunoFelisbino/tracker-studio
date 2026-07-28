import 'dart:async';
import 'dart:convert';

import 'suntech_command_family.dart';
import 'suntech_legacy_commands.dart';
import 'suntech_newgen_commands.dart';
import 'usb_serial_transport.dart';

class SuntechHandshakeProbe {
  final String command;
  final Duration wait;
  final Duration maxWait;
  final bool waitForEtx;
  final bool clearInput;

  const SuntechHandshakeProbe({
    required this.command,
    required this.wait,
    required this.maxWait,
    this.waitForEtx = false,
    this.clearInput = false,
  });
}

class SuntechHandshakeResult {
  final SuntechCommandFamily family;
  final String? model;
  final String? esn;
  final String? firmware;
  final String? imei;
  final int baudRate;
  final String? protocol;
  final String compatibility;
  final bool portOk;
  final Map<String, SuntechCommandDefinition> commandCatalog;
  final List<String> rawEvidence;
  final Map<String, HandshakeProbeStatus> probeStatuses;
  final String? error;
  final bool canceled;
  final String lastAction;

  const SuntechHandshakeResult({
    required this.family,
    required this.model,
    required this.esn,
    required this.firmware,
    required this.imei,
    required this.baudRate,
    required this.protocol,
    required this.compatibility,
    required this.portOk,
    required this.commandCatalog,
    required this.rawEvidence,
    this.probeStatuses = const {},
    this.error,
    this.canceled = false,
    this.lastAction = 'Auto identificação concluída sem crash',
  });

  bool get identified =>
      family != SuntechCommandFamily.unknown &&
      family != SuntechCommandFamily.manual;
}

enum HandshakeProbeStatus { ok, noResponse, echo, error, canceled }

String handshakeProbeStatusLabel(HandshakeProbeStatus? status) =>
    switch (status) {
      HandshakeProbeStatus.ok => 'OK',
      HandshakeProbeStatus.noResponse => 'sem resposta',
      HandshakeProbeStatus.echo => 'ECHO',
      HandshakeProbeStatus.error => 'erro',
      HandshakeProbeStatus.canceled => 'cancelado',
      null => 'pendente',
    };

class _ProbeResult {
  final String response;
  final HandshakeProbeStatus status;
  final String? error;

  const _ProbeResult(this.response, this.status, [this.error]);
}

enum NetworkWriteStatus { failed, awaitingReadback, verified }

class NetworkWriteResult {
  final NetworkWriteStatus status;
  final String part1Command;
  final String part2Command;
  final String part1Response;
  final String part2Response;
  final bool part1Confirmed;
  final bool part2Confirmed;
  final bool readbackConfirmed;
  final List<String> rawEvidence;

  const NetworkWriteResult({
    required this.status,
    required this.part1Command,
    required this.part2Command,
    required this.part1Response,
    required this.part2Response,
    required this.part1Confirmed,
    required this.part2Confirmed,
    required this.readbackConfirmed,
    required this.rawEvidence,
  });

  bool get applied =>
      status == NetworkWriteStatus.verified && readbackConfirmed;
}

class NewGenNetworkCommands {
  final String part1;
  final String part2;

  const NewGenNetworkCommands(this.part1, this.part2);
}

class SuntechHandshakeEngine {
  static const atProbe = SuntechHandshakeProbe(
    command: 'AT',
    wait: Duration(milliseconds: 120),
    maxWait: Duration(seconds: 2),
  );
  static const st8Probes = [
    SuntechHandshakeProbe(
      command: r'AT^$PSTRdy',
      wait: Duration(milliseconds: 120),
      maxWait: Duration(milliseconds: 1800),
    ),
    SuntechHandshakeProbe(
      command: r'AT^$PSTVer;1416',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(milliseconds: 5500),
    ),
    SuntechHandshakeProbe(
      command: r'AT^$PSTVer',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(seconds: 3),
    ),
    SuntechHandshakeProbe(
      command: r'AT^$PSTGetJson',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(seconds: 3),
    ),
  ];
  static const legacyProbes = [
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;ReqVer',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(seconds: 3),
    ),
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;StatusReq',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(seconds: 3),
    ),
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;Preset',
      wait: Duration(milliseconds: 200),
      maxWait: Duration(seconds: 3),
    ),
  ];
  static const fastSt8Probes = [
    SuntechHandshakeProbe(
      command: r'AT^$PSTRdy',
      wait: Duration(milliseconds: 120),
      maxWait: Duration(milliseconds: 1500),
    ),
    SuntechHandshakeProbe(
      command: r'AT^$PSTVer;1416',
      wait: Duration(milliseconds: 150),
      maxWait: Duration(seconds: 2),
    ),
    SuntechHandshakeProbe(
      command: r'AT^$PSTGetJson',
      wait: Duration(milliseconds: 150),
      maxWait: Duration(seconds: 2),
    ),
  ];
  static const fastLegacyProbes = [
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;ReqVer',
      wait: Duration(milliseconds: 150),
      maxWait: Duration(seconds: 2),
    ),
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;StatusReq',
      wait: Duration(milliseconds: 150),
      maxWait: Duration(seconds: 2),
    ),
    SuntechHandshakeProbe(
      command: 'AT^ST300CMD;;02;Preset',
      wait: Duration(milliseconds: 150),
      maxWait: Duration(seconds: 2),
    ),
  ];

  final double timeoutScale;
  UsbSerialTransport? _transport;
  SuntechHandshakeResult? _lastResult;
  bool _cancelled = false;

  SuntechHandshakeEngine({this.timeoutScale = 1});

  void cancel() => _cancelled = true;

  Future<SuntechHandshakeResult> runFastHandshake({
    required UsbSerialTransport transport,
    required int baudRate,
    void Function(SuntechHandshakeResult result)? onProgress,
  }) async {
    _cancelled = false;
    _transport = transport;
    final evidence = <String>[];
    final statuses = <String, HandshakeProbeStatus>{};
    final deadline = DateTime.now().add(_scaled(const Duration(seconds: 12)));
    var portOk = false;

    try {
      await _reconnect(transport, baudRate, lineTerminator: '\r');
      final at = await _runProbe(
        transport,
        atProbe,
        evidence: evidence,
        deadline: deadline,
      );
      statuses[atProbe.command] = at.status;
      portOk = _isAtOk(at.response);
      if (portOk) {
        onProgress?.call(
          _unknownResult(
            baudRate: baudRate,
            portOk: true,
            evidence: evidence,
            statuses: statuses,
            compatibility: 'Porta OK. Tentando identificar família.',
            lastAction: 'Porta validada; identificando família',
          ),
        );
      }

      final st8Responses = <String>[];
      for (final probe in fastSt8Probes) {
        if (_deadlineReached(deadline) || _shouldCancel(transport)) break;
        final probeResult = await _runProbe(
          transport,
          probe,
          evidence: evidence,
          deadline: deadline,
        );
        statuses[probe.command] = probeResult.status;
        st8Responses.add(probeResult.response);
      }
      final st8Combined = st8Responses.join('\n');
      if (detectNewGenModel(st8Combined) != null ||
          st8Combined.contains('TotalGrpNo')) {
        final result = await _loadJsonSchema(
          transport: transport,
          baudRate: baudRate,
          initialEvidence: evidence,
          initialResponses: st8Responses,
          portOk: portOk,
          statuses: statuses,
          deadline: deadline,
          requestJsonIfMissing: false,
        );
        _lastResult = result;
        return result;
      }
      if (_shouldCancel(transport)) {
        return _finishUnknown(
          rates: [baudRate],
          baudRate: baudRate,
          portOk: portOk,
          evidence: evidence,
          statuses: statuses,
          canceled: true,
        );
      }
      evidence.add('[HANDSHAKE] Sem resposta ST8, tentando Legacy');

      for (final probe in fastLegacyProbes) {
        if (_deadlineReached(deadline) || _shouldCancel(transport)) break;
        final probeResult = await _runProbe(
          transport,
          probe,
          evidence: evidence,
          deadline: deadline,
        );
        statuses[probe.command] = probeResult.status;
        final legacy = parseLegacyResponse(probeResult.response);
        if (legacy != null) {
          final result = SuntechHandshakeResult(
            family: SuntechCommandFamily.legacySt300St310,
            model: legacy.model,
            esn: legacy.esn,
            firmware: legacy.firmware,
            imei: null,
            baudRate: baudRate,
            protocol: 'Legacy AT^ST300',
            compatibility: 'ST300/ST310 Legacy identificado',
            portOk: portOk,
            commandCatalog: legacyCommandCatalog(),
            rawEvidence: List.unmodifiable(evidence),
            probeStatuses: Map.unmodifiable(statuses),
          );
          _lastResult = result;
          return result;
        }
      }
      evidence.add('[HANDSHAKE] Sem resposta Legacy');
      return _finishUnknown(
        rates: [baudRate],
        baudRate: baudRate,
        portOk: portOk,
        evidence: evidence,
        statuses: statuses,
      );
    } catch (error) {
      evidence.add('[HANDSHAKE ERROR] $error');
      return _finishUnknown(
        rates: [baudRate],
        baudRate: baudRate,
        portOk: portOk,
        evidence: evidence,
        statuses: statuses,
        error: _friendlyError(error),
      );
    }
  }

  Future<SuntechHandshakeResult> runFullHandshakeScan({
    required UsbSerialTransport transport,
    required List<int> baudRates,
    List<String> lineTerminators = const ['\r', '\r\n'],
  }) async {
    SuntechHandshakeResult? lastResult;
    for (final terminator in lineTerminators) {
      final result = await runHandshake(
        transport: transport,
        baudRates: baudRates,
        lineTerminator: terminator,
      );
      if (result.identified || result.canceled) return result;
      lastResult = result;
    }
    return lastResult ??
        _finishUnknown(
          rates: baudRates,
          baudRate: baudRates.isEmpty ? 115200 : baudRates.first,
          portOk: false,
          evidence: const [],
          statuses: const {},
        );
  }

  Future<SuntechHandshakeResult> runHandshake({
    required UsbSerialTransport transport,
    required List<int> baudRates,
    String lineTerminator = '\r',
  }) async {
    _cancelled = false;
    _transport = transport;
    final evidence = <String>[];
    final statuses = <String, HandshakeProbeStatus>{};
    var portOk = false;
    final rates = <int>[];
    for (final rate in baudRates) {
      if (!rates.contains(rate)) rates.add(rate);
    }

    try {
      for (final baudRate in rates) {
        if (_shouldCancel(transport)) {
          return _finishUnknown(
            rates: rates,
            baudRate: baudRate,
            portOk: portOk,
            evidence: evidence,
            statuses: statuses,
            canceled: true,
          );
        }
        try {
          await _reconnect(
            transport,
            baudRate,
            lineTerminator: lineTerminator,
          );
        } catch (error) {
          evidence.add('[HANDSHAKE ERROR] reconexão $baudRate: $error');
          if (_shouldCancel(transport)) {
            return _finishUnknown(
              rates: rates,
              baudRate: baudRate,
              portOk: portOk,
              evidence: evidence,
              statuses: statuses,
              canceled: true,
            );
          }
          continue;
        }
        final at = await _runProbe(transport, atProbe, evidence: evidence);
        statuses[atProbe.command] = at.status;
        portOk = portOk || _isAtOk(at.response);

        final st8Responses = <String>[];
        for (final probe in st8Probes) {
          if (_shouldCancel(transport)) break;
          final probeResult =
              await _runProbe(transport, probe, evidence: evidence);
          statuses[probe.command] = probeResult.status;
          st8Responses.add(probeResult.response);
          final combined = st8Responses.join('\n');
          if (detectNewGenModel(combined) != null ||
              probeResult.response.contains('TotalGrpNo')) {
            final result = await _loadJsonSchema(
              transport: transport,
              baudRate: baudRate,
              initialEvidence: evidence,
              initialResponses: st8Responses,
              portOk: portOk,
              statuses: statuses,
            );
            _lastResult = result;
            return result;
          }
        }
        if (_shouldCancel(transport)) {
          return _finishUnknown(
            rates: rates,
            baudRate: baudRate,
            portOk: portOk,
            evidence: evidence,
            statuses: statuses,
            canceled: true,
          );
        }
        evidence.add('[HANDSHAKE] Sem resposta ST8, tentando Legacy');

        for (final probe in legacyProbes) {
          if (_shouldCancel(transport)) break;
          final probeResult =
              await _runProbe(transport, probe, evidence: evidence);
          statuses[probe.command] = probeResult.status;
          final legacy = parseLegacyResponse(probeResult.response);
          if (legacy != null) {
            final result = SuntechHandshakeResult(
              family: SuntechCommandFamily.legacySt300St310,
              model: legacy.model,
              esn: legacy.esn,
              firmware: legacy.firmware,
              imei: null,
              baudRate: baudRate,
              protocol: 'Legacy AT^ST300',
              compatibility: 'ST300/ST310 Legacy identificado',
              portOk: portOk,
              commandCatalog: legacyCommandCatalog(),
              rawEvidence: List.unmodifiable(evidence),
              probeStatuses: Map.unmodifiable(statuses),
            );
            _lastResult = result;
            return result;
          }
        }
      }
    } catch (error, stackTrace) {
      evidence.add('[HANDSHAKE ERROR] $error');
      evidence.add('[HANDSHAKE STACK] $stackTrace');
      return _finishUnknown(
        rates: rates,
        baudRate: rates.isEmpty ? 115200 : rates.first,
        portOk: portOk,
        evidence: evidence,
        statuses: statuses,
        error: _friendlyError(error),
      );
    }

    return _finishUnknown(
      rates: rates,
      baudRate: rates.isEmpty ? 115200 : rates.first,
      portOk: portOk,
      evidence: evidence,
      statuses: statuses,
    );
  }

  SuntechHandshakeResult _finishUnknown({
    required List<int> rates,
    required int baudRate,
    required bool portOk,
    required List<String> evidence,
    required Map<String, HandshakeProbeStatus> statuses,
    String? error,
    bool canceled = false,
  }) {
    final result = SuntechHandshakeResult(
      family: SuntechCommandFamily.unknown,
      model: null,
      esn: null,
      firmware: null,
      imei: null,
      baudRate: baudRate,
      protocol: null,
      compatibility: portOk
          ? 'Porta OK, mas equipamento não identificado.'
          : 'Sem resposta Suntech reconhecida',
      portOk: portOk,
      commandCatalog: const {},
      rawEvidence: List.unmodifiable(evidence),
      probeStatuses: Map.unmodifiable(statuses),
      error: error,
      canceled: canceled,
      lastAction: canceled
          ? 'Auto identificação cancelada sem crash'
          : 'Auto identificação concluída sem crash',
    );
    _lastResult = result;
    return result;
  }

  Future<String> runProbe(
    UsbSerialTransport transport,
    SuntechHandshakeProbe probe, {
    List<String>? evidence,
  }) async {
    return (await _runProbe(transport, probe, evidence: evidence)).response;
  }

  Future<_ProbeResult> _runProbe(
    UsbSerialTransport transport,
    SuntechHandshakeProbe probe, {
    List<String>? evidence,
    DateTime? deadline,
  }) async {
    if (_shouldCancel(transport)) {
      evidence?.add('[HANDSHAKE CANCELED] ${probe.command}');
      return const _ProbeResult('', HandshakeProbeStatus.canceled);
    }
    final control = transport is SerialHandshakeTransportControl
        ? transport as SerialHandshakeTransportControl
        : null;
    if (probe.clearInput && control != null) {
      try {
        await control.clearInputBuffer();
      } catch (error) {
        evidence?.add('[HANDSHAKE ERROR] limpar buffer: $error');
      }
    }
    final responseChunks = <String>[];
    var receivedAt = DateTime.fromMillisecondsSinceEpoch(0);
    StreamSubscription<String>? subscription;
    Object? streamError;
    try {
      subscription = transport.lines.listen((event) {
        if (_cancelled || !transport.connected) return;
        evidence?.add(event);
        final chunk = _responseChunk(event);
        if (chunk == null || chunk.isEmpty) return;
        responseChunks.add(chunk);
        receivedAt = DateTime.now();
      }, onError: (Object error) {
        streamError = error;
        evidence?.add('[HANDSHAKE READ ERROR] $error');
      });
      evidence?.add('[HANDSHAKE SEND] ${probe.command}');
      if (_shouldCancel(transport)) {
        return const _ProbeResult('', HandshakeProbeStatus.canceled);
      }
      await transport.writeLine(probe.command);
      await _delayWithinDeadline(_scaled(probe.wait), deadline);
      final started = DateTime.now();
      while (DateTime.now().difference(started) < _scaled(probe.maxWait) &&
          !_deadlineReached(deadline)) {
        if (_shouldCancel(transport)) {
          return const _ProbeResult('', HandshakeProbeStatus.canceled);
        }
        final combined = responseChunks.join('');
        if (probe.waitForEtx && combined.contains(String.fromCharCode(3))) {
          break;
        }
        if (responseChunks.isNotEmpty &&
            DateTime.now().difference(receivedAt) >=
                _scaled(probe.waitForEtx
                    ? const Duration(milliseconds: 1200)
                    : const Duration(milliseconds: 350))) {
          break;
        }
        await _delayWithinDeadline(
          _scaled(const Duration(milliseconds: 30)),
          deadline,
        );
      }
    } catch (error) {
      if (_shouldCancel(transport) || _isClosedPortError(error)) {
        evidence?.add('[HANDSHAKE CANCELED] ${probe.command}: $error');
        return const _ProbeResult('', HandshakeProbeStatus.canceled);
      }
      evidence?.add('[HANDSHAKE ERROR] ${probe.command}: $error');
      return _ProbeResult(
          '', HandshakeProbeStatus.error, _friendlyError(error));
    } finally {
      try {
        await subscription?.cancel();
      } catch (error) {
        evidence?.add('[HANDSHAKE READ CLOSE] $error');
      }
    }
    final raw = responseChunks.join('');
    final response = _removeEcho(raw, probe.command);
    if (response.isNotEmpty) {
      return _ProbeResult(response, HandshakeProbeStatus.ok);
    }
    if (_containsEcho(raw, probe.command)) {
      evidence?.add('[HANDSHAKE ECHO] ${probe.command}');
      return const _ProbeResult('', HandshakeProbeStatus.echo);
    }
    if (streamError != null) {
      return _ProbeResult(
          '', HandshakeProbeStatus.error, _friendlyError(streamError!));
    }
    evidence?.add('[HANDSHAKE NO RESPONSE] ${probe.command}');
    return const _ProbeResult('', HandshakeProbeStatus.noResponse);
  }

  Future<SuntechHandshakeResult> _loadJsonSchema({
    required UsbSerialTransport transport,
    required int baudRate,
    required List<String> initialEvidence,
    required List<String> initialResponses,
    required bool portOk,
    required Map<String, HandshakeProbeStatus> statuses,
    DateTime? deadline,
    bool requestJsonIfMissing = true,
  }) async {
    var combined = initialResponses.join('\n');
    if (requestJsonIfMissing && !combined.contains('TotalGrpNo')) {
      final getJson = await _runProbe(
        transport,
        const SuntechHandshakeProbe(
          command: r'AT^$PSTGetJson',
          wait: Duration(milliseconds: 150),
          maxWait: Duration(seconds: 12),
          clearInput: true,
        ),
        evidence: initialEvidence,
        deadline: deadline,
      );
      statuses[r'AT^$PSTGetJson'] = getJson.status;
      combined += getJson.response;
    }
    final total = int.tryParse(
          RegExp(r'TotalGrpNo;(\d+)', caseSensitive: false)
                  .firstMatch(combined)
                  ?.group(1) ??
              '',
        ) ??
        0;
    initialEvidence.add('[JSON] TotalGrpNo=$total');
    final packets = <Map<String, dynamic>>[];
    var requestedPackets = 0;
    for (var number = 1; number <= total; number++) {
      if (_shouldCancel(transport) || _deadlineReached(deadline)) break;
      requestedPackets++;
      final packetResult = await _runProbe(
        transport,
        SuntechHandshakeProbe(
          command: r'AT^$ReqJsonPk;No;' '$number',
          wait: const Duration(milliseconds: 80),
          maxWait: const Duration(seconds: 15),
          waitForEtx: true,
          clearInput: true,
        ),
        evidence: initialEvidence,
        deadline: deadline,
      );
      final response = packetResult.response;
      final json = _extractJson(response);
      if (json != null) packets.add(json);
      combined += '\n$response';
    }

    initialEvidence.add('[JSON] Pacotes solicitados=$requestedPackets');
    initialEvidence.add('[JSON] Pacotes parseados=${packets.length}');
    final info = _findBestInfo(packets, combined);
    final esnCandidates = _extractEsnCandidates(combined);
    if (esnCandidates.length > 1) {
      initialEvidence.add(
        '[HANDSHAKE WARNING] múltiplos candidatos ESN: ${esnCandidates.join(', ')}',
      );
    }
    final esn = _extractEsnFromInfo(info) ??
        (esnCandidates.isEmpty ? null : esnCandidates.first);
    final detectedModel = _extractModelFromInfo(info, combined);
    final firmware = _extractFirmwareFromInfo(info, combined);
    final protocol = _extractProtocolFromInfo(info) ?? 'ST8 JSON';
    final imei = _firstInfoValue(info, const ['IMEI', 'imei']);
    initialEvidence.add(
      '[JSON] Info keys=${info == null ? 'nenhuma' : info.keys.join(',')}',
    );
    initialEvidence
        .add(esn == null ? '[JSON] ESN não localizado' : '[JSON] ESN=$esn');
    initialEvidence.add('[JSON] Model=${detectedModel ?? 'não localizado'}');
    final bundledCatalog = newGenCommandCatalogForModel(detectedModel);
    final schemaCatalog = <String, SuntechCommandDefinition>{};
    for (final packet in packets) {
      _collectCommands(
        packet,
        schemaCatalog,
        model: detectedModel,
        firmware: firmware,
      );
    }
    final catalog = <String, SuntechCommandDefinition>{
      ...?bundledCatalog,
    };
    if (bundledCatalog == null) {
      catalog.addAll(schemaCatalog);
    } else {
      initialEvidence.add(
        '[CATALOG] Perfil obrigatório carregado: ${catalog.length} comandos',
      );
      final unexpected =
          schemaCatalog.keys.toSet().difference(catalog.keys.toSet());
      if (unexpected.isNotEmpty) {
        initialEvidence.add(
          '[CATALOG WARNING] Comandos fora do perfil ignorados: '
          '${unexpected.toList()..sort()}',
        );
      }
    }
    return SuntechHandshakeResult(
      family: SuntechCommandFamily.newGenSt8210St8310,
      model: detectedModel,
      esn: esn,
      firmware: firmware,
      imei: imei,
      baudRate: baudRate,
      protocol: protocol,
      compatibility: esn == null
          ? 'ST8 identificado, mas ESN não extraído.'
          : packets.isEmpty && bundledCatalog == null
              ? 'ST8 identificado; schema JSON não carregado'
              : bundledCatalog != null
                  ? 'ST8 identificado; catálogo de perfil carregado'
                  : 'ST8 identificado; catálogo JSON carregado',
      portOk: portOk,
      commandCatalog: Map.unmodifiable(catalog),
      rawEvidence: List.unmodifiable(initialEvidence),
      probeStatuses: Map.unmodifiable(statuses),
    );
  }

  Future<NetworkWriteResult> writeNewGenNetwork({
    required String apn,
    required String server,
    required int port,
    String username = '',
    String password = '',
    String auth = '01',
    String serverType = '00',
    String backupServer = '0.0.0.0',
    int backupPort = 0,
    String backupType = '00',
    String agpsEnabled = '01',
    String agpsUrl = 'https://example.com/agps',
    String scanningBand = '03',
  }) async {
    final result = _lastResult;
    final transport = _transport;
    if (result == null ||
        result.family != SuntechCommandFamily.newGenSt8210St8310) {
      throw StateError('PRG bloqueado: equipamento New Gen não identificado.');
    }
    final esn = result.esn?.trim() ?? '';
    if (esn.isEmpty) throw StateError('PRG bloqueado: ESN não identificado.');
    if (transport == null || !transport.connected) {
      throw StateError('PRG bloqueado: USB não conectado.');
    }
    final commands = buildNewGenNetworkCommands(
      family: result.family,
      esn: esn,
      apn: apn,
      server: server,
      port: port,
      username: username,
      password: password,
      auth: auth,
      serverType: serverType,
      backupServer: backupServer,
      backupPort: backupPort,
      backupType: backupType,
      agpsEnabled: agpsEnabled,
      agpsUrl: agpsUrl,
      scanningBand: scanningBand,
    );
    final evidence = <String>[];
    final confirmation = 'RPR;$esn;OK;10';
    final response1 = await runProbe(
      transport,
      SuntechHandshakeProbe(
        command: commands.part1,
        wait: const Duration(milliseconds: 350),
        maxWait: const Duration(seconds: 8),
        clearInput: true,
      ),
      evidence: evidence,
    );
    final part1Confirmed = response1.contains(confirmation);
    if (!part1Confirmed) {
      return NetworkWriteResult(
        status: NetworkWriteStatus.failed,
        part1Command: commands.part1,
        part2Command: commands.part2,
        part1Response: response1,
        part2Response: '',
        part1Confirmed: false,
        part2Confirmed: false,
        readbackConfirmed: false,
        rawEvidence: evidence,
      );
    }
    final response2 = await runProbe(
      transport,
      SuntechHandshakeProbe(
        command: commands.part2,
        wait: const Duration(milliseconds: 350),
        maxWait: const Duration(seconds: 8),
        clearInput: true,
      ),
      evidence: evidence,
    );
    final part2Confirmed = response2.contains(confirmation);
    return NetworkWriteResult(
      status: part2Confirmed
          ? NetworkWriteStatus.awaitingReadback
          : NetworkWriteStatus.failed,
      part1Command: commands.part1,
      part2Command: commands.part2,
      part1Response: response1,
      part2Response: response2,
      part1Confirmed: true,
      part2Confirmed: part2Confirmed,
      readbackConfirmed: false,
      rawEvidence: evidence,
    );
  }

  Duration _scaled(Duration value) {
    final milliseconds = (value.inMilliseconds * timeoutScale).round();
    return Duration(milliseconds: milliseconds < 1 ? 1 : milliseconds);
  }

  Future<void> _reconnect(
    UsbSerialTransport transport,
    int baudRate, {
    String lineTerminator = '\r',
  }) async {
    if (_shouldCancel(transport)) return;
    if (transport is! SerialHandshakeTransportControl) return;
    final control = transport as SerialHandshakeTransportControl;
    final request = control.currentRequest;
    if (request == null) return;
    if (request.baudRate == baudRate &&
        request.lineTerminator == lineTerminator) {
      return;
    }
    await control.reconnectForHandshake(
      request.copyWith(baudRate: baudRate, lineTerminator: lineTerminator),
    );
    await Future<void>.delayed(_scaled(const Duration(milliseconds: 150)));
  }

  bool _shouldCancel(UsbSerialTransport transport) =>
      _cancelled || !transport.connected;

  bool _deadlineReached(DateTime? deadline) =>
      deadline != null && !DateTime.now().isBefore(deadline);

  Future<void> _delayWithinDeadline(
      Duration duration, DateTime? deadline) async {
    if (deadline == null) {
      await Future<void>.delayed(duration);
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) return;
    await Future<void>.delayed(duration < remaining ? duration : remaining);
  }

  SuntechHandshakeResult _unknownResult({
    required int baudRate,
    required bool portOk,
    required List<String> evidence,
    required Map<String, HandshakeProbeStatus> statuses,
    required String compatibility,
    required String lastAction,
  }) =>
      SuntechHandshakeResult(
        family: SuntechCommandFamily.unknown,
        model: null,
        esn: null,
        firmware: null,
        imei: null,
        baudRate: baudRate,
        protocol: null,
        compatibility: compatibility,
        portOk: portOk,
        commandCatalog: const {},
        rawEvidence: List.unmodifiable(evidence),
        probeStatuses: Map.unmodifiable(statuses),
        lastAction: lastAction,
      );

  bool _isClosedPortError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('already closed') ||
        message.contains('bad file descriptor') ||
        message.contains('port closed') ||
        message.contains('não conectado') ||
        message.contains('not connected');
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}

NewGenNetworkCommands buildNewGenNetworkCommands({
  required SuntechCommandFamily family,
  required String esn,
  required String apn,
  required String server,
  required int port,
  String username = '',
  String password = '',
  String auth = '01',
  String serverType = '00',
  String backupServer = '0.0.0.0',
  int backupPort = 0,
  String backupType = '00',
  String agpsEnabled = '01',
  String agpsUrl = 'https://example.com/agps',
  String scanningBand = '03',
}) {
  if (family != SuntechCommandFamily.newGenSt8210St8310) {
    throw StateError('PRG não é permitido para a família selecionada.');
  }
  if (esn.trim().isEmpty) throw StateError('ESN obrigatório para PRG New Gen.');
  for (final value in [apn, server, username, password, agpsUrl]) {
    if (RegExp(r'[;#\r\n]').hasMatch(value)) {
      throw ArgumentError('Valor de rede contém caractere reservado.');
    }
  }
  if (apn.trim().isEmpty || server.trim().isEmpty || port < 1 || port > 65535) {
    throw ArgumentError('APN, servidor e porta válida são obrigatórios.');
  }
  return NewGenNetworkCommands(
    'AT^PRG;$esn;10;00#$auth;01#$apn;02#$username;03#$password;04#;05#$server;06#$port;07#$serverType;08#$backupServer;09#$backupPort;10#$backupType;11#0;12#0;13#00;60#10;70#01;71#600;61#00;62#500;63#300',
    'AT^PRG;$esn;10;16#$scanningBand;52#00;53#60;14#$agpsEnabled;15#$agpsUrl',
  );
}

String? detectNewGenModel(String response) {
  final patterns = [
    RegExp(r'\$PST;Ver;([^;\r\n]+)', caseSensitive: false),
    RegExp(r'(?:MODEL|Model|model)[\s:=;]+(ST8[0-9A-Z_.-]+)',
        caseSensitive: false),
    RegExp(r'"S"\s*:\s*"(ST8[0-9A-Z_.-]+)"', caseSensitive: false),
    RegExp(r'\b(ST8(?:210|310|310U|310UM)[0-9A-Z_.-]*)\b',
        caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final captured = pattern.firstMatch(response)?.group(1)?.toUpperCase();
    final model = RegExp(r'ST8[0-9A-Z]+').firstMatch(captured ?? '')?.group(0);
    if (model != null) return model;
  }
  return null;
}

({String esn, String firmware, String model})? parseLegacyResponse(
    String response) {
  final match = RegExp(
    r'ST300CMD;Res;([^;]+);([^;]+);ReqVer;([^\r\n;]+)',
    caseSensitive: false,
  ).firstMatch(response);
  if (match == null) return null;
  final blob = match.group(3)!.toUpperCase();
  final model = RegExp(r'ST3[0-9A-Z]+').firstMatch(blob)?.group(0) ??
      blob.split('_').first;
  return (esn: match.group(1)!, firmware: match.group(2)!, model: model);
}

Map<String, SuntechCommandDefinition> legacyCommandCatalog() {
  const names = [
    'StatusReq',
    'Reset',
    'Preset',
    'PresetA',
    'Enable1',
    'Disable1',
    'ReqIMSI',
    'ReqICCID',
    'ReqVer',
    'Reboot',
    'ReqTest',
    'ReqBattLife',
    'ReqShortTest',
    'EraseAll',
    'InitDist',
    'SetOdometer',
    'InitMsgNo',
    'ReqOwnNo',
    'ReqGoogleMap',
    'ReqSMSNoOfPanic',
  ];
  return {
    for (final name in names)
      name: SuntechCommandDefinition(
        id: 'legacy_${name.toLowerCase()}',
        label: name,
        commandTemplate:
            'AT^ST300CMD;;02;${name == 'SetOdometer' ? 'InitDist' : name}',
        requiresEsn: false,
        critical: const {
          'Reset',
          'Reboot',
          'EraseAll',
          'InitDist',
          'SetOdometer',
          'InitMsgNo'
        }.contains(name),
        requiresBackup: const {
          'Reset',
          'EraseAll',
          'InitDist',
          'SetOdometer',
          'InitMsgNo'
        }.contains(name),
        notes: 'Catálogo Legacy permitido.',
      ),
  };
}

bool _isAtOk(String response) =>
    RegExp(r'(^|[\r\n])\s*OK\s*($|[\r\n])', caseSensitive: false)
        .hasMatch(response);

String? _responseChunk(String event) {
  if (event.startsWith('[READ_ASCII] ')) {
    return event.substring(13).replaceAll(r'\r', '\r').replaceAll(r'\n', '\n');
  }
  if (event.startsWith('[READ] ')) return null;
  if (event.startsWith('[') || event.startsWith('USB ')) return null;
  return event;
}

String _removeEcho(String response, String command) {
  final lines = response.split(RegExp(r'[\r\n]+'));
  return lines
      .where((line) => line.trim().isNotEmpty && line.trim() != command.trim())
      .join('\n');
}

bool _containsEcho(String response, String command) => response
    .split(RegExp(r'[\r\n]+'))
    .any((line) => line.trim() == command.trim());

Map<String, dynamic>? _extractJson(String response) {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = 0; index < response.length; index++) {
    final character = response[index];
    if (start < 0) {
      if (character != '{') continue;
      start = index;
      depth = 1;
      continue;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
      }
      continue;
    }
    if (character == '"') {
      inString = true;
    } else if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth != 0) continue;
      try {
        final decoded = jsonDecode(response.substring(start, index + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Continue with a later object if this framed block is malformed.
      }
      start = -1;
    }
  }
  return null;
}

Map<String, dynamic>? _findBestInfo(
  List<Map<String, dynamic>> packets,
  String combined,
) {
  Map<String, dynamic>? best;
  var bestScore = 0;

  void visit(Object? node) {
    if (node is List) {
      for (final item in node) {
        visit(item);
      }
      return;
    }
    if (node is! Map) return;
    final candidate = <String, dynamic>{
      for (final entry in node.entries) entry.key.toString(): entry.value,
    };
    var score = 0;
    if (_extractEsnFromInfo(candidate) != null) score += 100;
    if (_firstInfoValue(candidate,
            const ['S', 'MODEL', 'Model', 'model', 'Device', 'device']) !=
        null) {
      score += 20;
    }
    if (_firstInfoValue(candidate,
            const ['V', 'FW', 'Firmware', 'firmware', 'VER', 'version']) !=
        null) {
      score += 10;
    }
    if (_extractProtocolFromInfo(candidate) != null) score += 5;
    if (_firstInfoValue(candidate, const ['IMEI', 'imei']) != null) score += 3;
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
    for (final value in node.values) {
      visit(value);
    }
  }

  for (final packet in packets) {
    visit(packet);
  }
  if (best != null) return best;
  final candidates = _extractEsnCandidates(combined);
  return candidates.isEmpty ? null : {'ESN': candidates.first};
}

String? _extractEsnFromInfo(Map<String, dynamic>? info) => _firstInfoValue(
      info,
      const [
        'I',
        'ESN',
        'Esn',
        'esn',
        'SN',
        'Serial',
        'serial',
        'DeviceID',
        'deviceId'
      ],
      validator: (value) => RegExp(r'^\d{8,15}$').hasMatch(value),
    );

String? _extractModelFromInfo(Map<String, dynamic>? info, String combined) =>
    _firstInfoValue(
      info,
      const ['S', 'MODEL', 'Model', 'model', 'Device', 'device'],
    ) ??
    detectNewGenModel(combined);

String? _extractFirmwareFromInfo(Map<String, dynamic>? info, String combined) =>
    _firstInfoValue(
      info,
      const ['V', 'FW', 'Firmware', 'firmware', 'VER', 'version'],
    ) ??
    _extractFirmware(combined);

String? _extractProtocolFromInfo(Map<String, dynamic>? info) =>
    _firstInfoValue(info, const ['P', 'Protocol', 'protocol', 'PROTO']);

String? _firstInfoValue(
  Map<String, dynamic>? info,
  List<String> keys, {
  bool Function(String value)? validator,
}) {
  if (info == null) return null;
  for (final key in keys) {
    final value = _string(info[key]);
    if (value != null && (validator == null || validator(value))) return value;
  }
  return null;
}

List<String> _extractEsnCandidates(String combined) {
  final candidates = <String>{};
  final patterns = [
    RegExp(
      r'(?:ESN|SN|DeviceID|deviceId)\s*["\x27:=;,]+\s*["\x27]?([0-9]{8,15})',
      caseSensitive: false,
    ),
    RegExp(
      r'["\x27]I["\x27]\s*[:=;,]+\s*["\x27]?([0-9]{8,15})',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(combined)) {
      final value = match.group(1);
      if (value != null) candidates.add(value);
    }
  }
  return candidates.toList();
}

void _collectCommands(
  Object? node,
  Map<String, SuntechCommandDefinition> catalog, {
  required String? model,
  required String? firmware,
}) {
  if (node is List) {
    for (final item in node) {
      _collectCommands(item, catalog, model: model, firmware: firmware);
    }
    return;
  }
  if (node is! Map) return;
  final command = node['Command'];
  if (command is List) {
    for (final group in command.whereType<Map>()) {
      final list = group['list'];
      if (list is! List) continue;
      for (final item in list.whereType<Map>()) {
        for (final raw in item.values.whereType<String>()) {
          final parts = raw.split(';');
          if (parts.length < 5 || !RegExp(r'^\d{4}$').hasMatch(parts[4])) {
            continue;
          }
          final name = parts[1];
          final code = parts[4];
          catalog[name] = SuntechCommandDefinition(
            id: 'newgen_${name.toLowerCase()}',
            label: name,
            commandTemplate:
                'AT^CMD;<ESN>;${code.substring(0, 2)};${code.substring(2)}',
            requiresEsn: true,
            critical: _isCriticalCommandName(name),
            requiresBackup: false,
            notes: 'Carregado do JSON do equipamento.',
            catalogIndex: parts[0],
            parameterLength: parts[2],
            mode: parts[3],
            code: code,
            sourceProvenance: 'device-json',
            namespace: 'ST8',
            supportedModels: model == null ? const [] : [model],
            firmwareMin: firmware ?? 'unknown',
            firmwareMax: firmware ?? 'unknown',
            riskClassification: 'unverified',
            responseParser: 'unverified',
          );
        }
      }
    }
  }
  for (final value in node.values) {
    _collectCommands(value, catalog, model: model, firmware: firmware);
  }
}

bool _isCriticalCommandName(String name) {
  final normalized = name.toLowerCase();
  const criticalTerms = [
    'reset',
    'reboot',
    'erase',
    'delete',
    'initdist',
    'setodometer',
    'block',
    'disable',
    'factory',
  ];
  return criticalTerms.any(normalized.contains);
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _extractFirmware(String response) =>
    RegExp(r'\b\d+\.\d+(?:\.\d+)?(?:[-_.][0-9A-Z]+)?\b', caseSensitive: false)
        .firstMatch(response)
        ?.group(0);
