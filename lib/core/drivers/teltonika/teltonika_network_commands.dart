import 'teltonika_driver.dart';
import '../../uce/registry/uce_registry.dart';
import '../../uce/uce_interfaces.dart';

/// Sequence of USB Configurator commands that writes a Teltonika
/// network/server profile (APN, credentials, server, port, protocol).
class TeltonikaNetworkCommands {
  /// Commands to be sent in order over the serial transport.
  final List<String> commands;

  /// Parameter ids covered by the sequence (from the UCE catalog).
  final List<int> parameterIds;

  const TeltonikaNetworkCommands({
    required this.commands,
    required this.parameterIds,
  });

  /// Human-readable preview of the whole sequence.
  String get preview => commands.join('\n');
}

/// Parameter ids that make up the Teltonika network/server profile.
const teltonikaNetworkParameterIds = <int>[2001, 2002, 2003, 2004, 2005, 2006];

/// Builds a USB Configurator command sequence for any set of catalog
/// [parameters] (ordered `parameterId` -> raw value).
///
/// Every parameter is encoded through its registered [ParameterDefinition] so
/// the sequence stays in sync with the UCE catalog (documentation -> link).
TeltonikaNetworkCommands buildTeltonikaConfigSequence({
  required List<(int parameterId, String value)> parameters,
  bool connectFirst = true,
  bool saveLast = true,
  bool disconnectLast = true,
}) {
  String write(int parameterId, String value) {
    final definition = UceRegistry().parameters.getByParameterId(parameterId);
    if (definition == null ||
        definition.manufacturer != Manufacturer.teltonika) {
      throw StateError(
          'Parâmetro Teltonika $parameterId não registrado no catálogo UCE.');
    }
    final encoded = TeltonikaDriver.encodeParameterWrite(definition, value);
    if (encoded == null) {
      throw StateError('Falha ao codificar o parâmetro $parameterId.');
    }
    return encoded;
  }

  return TeltonikaNetworkCommands(
    commands: [
      if (connectFirst) TeltonikaDriver.encodeConnect(),
      for (final (parameterId, value) in parameters) write(parameterId, value),
      if (saveLast) TeltonikaDriver.encodeSaveConfiguration(),
      if (disconnectLast) TeltonikaDriver.encodeDisconnect(),
    ],
    parameterIds: [for (final parameter in parameters) parameter.$1],
  );
}

/// Builds the command sequence for the Teltonika network/server profile.
TeltonikaNetworkCommands buildTeltonikaNetworkCommands({
  required String apn,
  required String server,
  required int port,
  String username = '',
  String password = '',
  String protocol = '0',
}) {
  if (apn.trim().isEmpty || server.trim().isEmpty) {
    throw ArgumentError('APN e servidor são obrigatórios.');
  }
  if (port < 1 || port > 65535) {
    throw ArgumentError('Porta deve estar entre 1 e 65535.');
  }
  for (final value in [apn, server, username, password]) {
    if (RegExp(r'[;:#\r\n]').hasMatch(value)) {
      throw ArgumentError('Valor de rede contém caractere reservado.');
    }
  }
  if (protocol != '0' && protocol != '1') {
    throw ArgumentError('Protocolo deve ser 0 (TCP) ou 1 (UDP).');
  }

  return buildTeltonikaConfigSequence(
    parameters: [
      (2001, apn.trim()),
      if (username.trim().isNotEmpty) (2002, username.trim()),
      if (password.isNotEmpty) (2003, password),
      (2004, server.trim()),
      (2005, '$port'),
      (2006, protocol),
    ],
  );
}
