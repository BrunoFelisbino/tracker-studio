class SuntechCommandDefinition {
  final String id;
  final String label;
  final String commandTemplate;
  final bool requiresEsn;
  final bool critical;
  final bool requiresBackup;
  final String notes;
  final String catalogIndex;
  final String parameterLength;
  final String mode;
  final String code;
  final String sourceProvenance;
  final String namespace;
  final List<String> supportedModels;
  final String firmwareMin;
  final String firmwareMax;
  final String riskClassification;
  final String responseParser;

  const SuntechCommandDefinition({
    required this.id,
    required this.label,
    required this.commandTemplate,
    required this.requiresEsn,
    required this.critical,
    required this.requiresBackup,
    required this.notes,
    this.catalogIndex = 'unknown',
    this.parameterLength = 'unknown',
    this.mode = 'unknown',
    this.code = 'unknown',
    this.sourceProvenance = 'unknown',
    this.namespace = 'unknown',
    this.supportedModels = const [],
    this.firmwareMin = 'unknown',
    this.firmwareMax = 'unknown',
    this.riskClassification = 'unverified',
    this.responseParser = 'unverified',
  });

  String command({String esn = ''}) => commandTemplate.replaceAll('<ESN>', esn);
}

class SuntechLegacyCommands {
  static const at = SuntechCommandDefinition(
    id: 'legacy_at',
    label: 'AT básico',
    commandTemplate: 'AT',
    requiresEsn: false,
    critical: false,
    requiresBackup: false,
    notes: 'Valida somente a porta serial.',
  );

  static const status = SuntechCommandDefinition(
    id: 'legacy_status',
    label: 'ST300CMD StatusReq',
    commandTemplate: 'AT^ST300CMD;;02;StatusReq',
    requiresEsn: false,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura de status Legacy.',
  );

  static const reqVer = SuntechCommandDefinition(
    id: 'legacy_reqver',
    label: 'ST300CMD ReqVer',
    commandTemplate: 'AT^ST300CMD;;02;ReqVer',
    requiresEsn: false,
    critical: false,
    requiresBackup: false,
    notes: 'Identificação Legacy.',
  );

  static const preset = SuntechCommandDefinition(
    id: 'legacy_preset',
    label: 'ST300CMD Preset',
    commandTemplate: 'AT^ST300CMD;;02;Preset',
    requiresEsn: false,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura de configuração Legacy.',
  );

  static const networkNtn = SuntechCommandDefinition(
    id: 'legacy_network_ntn',
    label: 'ST300NTN Rede',
    commandTemplate: 'AT^ST300NTN;;02;0;<APN>;<USER>;<PASS>;<HOST>;<PORTA>;;;;',
    requiresEsn: false,
    critical: true,
    requiresBackup: true,
    notes: 'Preview apenas. Exige revisão, backup e readback homologado.',
  );

  static const all = [at, status, reqVer, preset, networkNtn];
}
