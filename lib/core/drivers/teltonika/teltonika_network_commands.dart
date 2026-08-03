import 'teltonika_driver.dart';
import '../../uce/registry/uce_registry.dart';
import '../../uce/uce_interfaces.dart';

enum TeltonikaConfigurationStepType {
  activateUsb,
  writeParameter,
  saveConfiguration,
  disconnectUsb,
}

class TeltonikaConfigurationStep {
  final TeltonikaConfigurationStepType type;
  final String title;
  final String description;
  final String command;
  final int? parameterId;

  const TeltonikaConfigurationStep({
    required this.type,
    required this.title,
    required this.description,
    required this.command,
    this.parameterId,
  });
}

/// Sequence of USB Configurator commands that writes a Teltonika
/// network/server profile (APN, credentials, server, port, protocol).
///
/// The order is mandatory:
/// 1. activate the USB Configurator session;
/// 2. write one or more parameters;
/// 3. persist the configuration;
/// 4. disconnect the Configurator session.
class TeltonikaNetworkCommands {
  /// Commands to be sent in order over the serial transport.
  final List<String> commands;

  /// Structured steps shown to the technician before applying the change.
  final List<TeltonikaConfigurationStep> steps;

  /// Parameter ids covered by the sequence (from the UCE catalog).
  final List<int> parameterIds;

  const TeltonikaNetworkCommands({
    required this.commands,
    required this.steps,
    required this.parameterIds,
  });

  /// Human-readable preview of the complete persistence flow.
  String get preview {
    final buffer = StringBuffer('FLUXO OBRIGATÓRIO TELTONIKA\n');
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      buffer
        ..writeln('${index + 1}. ${step.title}')
        ..writeln('   ${step.description}')
        ..writeln('   ${step.command}');
      if (index < steps.length - 1) buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
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
  if (parameters.isEmpty) {
    throw ArgumentError('Informe pelo menos um parâmetro Teltonika para alterar.');
  }
  if (!connectFirst || !saveLast) {
    throw ArgumentError(
      'O fluxo Teltonika deve ativar o USB antes da alteração e salvar ao final.',
    );
  }

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

  final connectCommand = TeltonikaDriver.encodeConnect();
  final saveCommand = TeltonikaDriver.encodeSaveConfiguration();
  final disconnectCommand = TeltonikaDriver.encodeDisconnect();
  final parameterCommands = <(int parameterId, String command)>[
    for (final (parameterId, value) in parameters)
      (parameterId, write(parameterId, value)),
  ];

  final steps = <TeltonikaConfigurationStep>[
    TeltonikaConfigurationStep(
      type: TeltonikaConfigurationStepType.activateUsb,
      title: 'ATIVAR USB CONFIGURATOR',
      description:
          'Abre a sessão de configuração antes de qualquer alteração.',
      command: connectCommand,
    ),
    for (final item in parameterCommands)
      TeltonikaConfigurationStep(
        type: TeltonikaConfigurationStepType.writeParameter,
        title: 'ALTERAR PARÂMETRO ${item.$1}',
        description:
            'Envia o valor do parâmetro selecionado para a memória de trabalho.',
        command: item.$2,
        parameterId: item.$1,
      ),
    TeltonikaConfigurationStep(
      type: TeltonikaConfigurationStepType.saveConfiguration,
      title: 'SALVAR / PERSISTIR CONFIGURAÇÃO',
      description:
          'Grava definitivamente os parâmetros alterados no equipamento.',
      command: saveCommand,
    ),
    if (disconnectLast)
      TeltonikaConfigurationStep(
        type: TeltonikaConfigurationStepType.disconnectUsb,
        title: 'ENCERRAR USB CONFIGURATOR',
        description: 'Finaliza a sessão somente depois da persistência.',
        command: disconnectCommand,
      ),
  ];

  return TeltonikaNetworkCommands(
    commands: [for (final step in steps) step.command],
    steps: steps,
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
