import 'dart:convert';
import 'dart:io';

class ParameterType {
  static const digital = 'digital';
  static const analog = 'analog';
  static const network = 'network';
  static const selection = 'selection';
  static const text = 'text';
  static const boolean = 'boolean';
  static const list = 'list';
}

class RiskLevel {
  static const low = 'LOW';
  static const medium = 'MEDIUM';
  static const high = 'HIGH';
  static const critical = 'CRITICAL';
}

class CommandExecutionResult {
  final bool success;
  final String? response;
  final String? error;
  final int? executionTimeMs;
  final Map<String, dynamic>? parsedResponse;

  CommandExecutionResult({
    required this.success,
    this.response,
    this.error,
    this.executionTimeMs,
    this.parsedResponse,
  });

  factory CommandExecutionResult.success(String response, {int? executionTime}) {
    return CommandExecutionResult(
      success: true,
      response: response,
      executionTimeMs: executionTime,
    );
  }

  factory CommandExecutionResult.error(String error) {
    return CommandExecutionResult(
      success: false,
      error: error,
    );
  }
}

class DeviceManualParameter {
  final String field;
  final String type;
  final List<String> states;
  final String description;
  final List<CommandTemplate> commands;
  final String currentState;
  final Map<String, dynamic>? metadata;

  DeviceManualParameter({
    required this.field,
    required this.type,
    required this.states,
    required this.description,
    required this.commands,
    required this.currentState,
    this.metadata,
  });

  factory DeviceManualParameter.fromJson(Map<String, dynamic> json) {
    return DeviceManualParameter(
      field: json['field'],
      type: json['type'],
      states: List<String>.from(json['states']),
      description: json['description'],
      commands: [],
      currentState: json['current_state'] ?? json['default_state'] ?? 'OFF',
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'type': type,
      'states': states,
      'description': description,
      'current_state': currentState,
      'metadata': metadata,
    };
  }
}

class CommandTemplate {
  final String commandTemplate;
  final String expectedResponse;
  final String riskLevel;
  final bool requiresEsn;
  final bool destructive;
  final bool requiresBackup;
  final String? notes;
  final Map<String, dynamic>? mappings;

  CommandTemplate({
    required this.commandTemplate,
    required this.expectedResponse,
    required this.riskLevel,
    required this.requiresEsn,
    required this.destructive,
    this.requiresBackup = false,
    this.notes,
    this.mappings,
  });

  CommandTemplate.fromJson(Map<String, dynamic> json)
      : commandTemplate = json['command_template'] ?? '',
        expectedResponse = json['expected_response'] ?? '',
        riskLevel = json['risk_level'] ?? 'LOW',
        requiresEsn = json['requires_esn'] ?? false,
        destructive = json['destructive'] ?? false,
        requiresBackup = json['requires_backup'] ?? false,
        notes = json['notes'],
        mappings = json['mappings'];

  Map<String, dynamic> toJson() {
    return {
      'command_template': commandTemplate,
      'expected_response': expectedResponse,
      'risk_level': riskLevel,
      'requires_esn': requiresEsn,
      'destructive': destructive,
      'requires_backup': requiresBackup,
      'notes': notes,
      'mappings': mappings,
    };
  }

  String buildCommand({
    required String esn,
    required String targetState,
    Map<String, String> customMappings = const {},
  }) {
    var command = commandTemplate;

    command = command.replaceAll('<ESN>', esn);
    command = command.replaceAll('<TARGET_STATE>', targetState);

    mappings?.forEach((key, value) {
      command = command.replaceAll('<$key>', value as String);
    });

    customMappings.forEach((key, value) {
      command = command.replaceAll('<$key>', value);
    });

    return command;
  }

  bool isSafeToExecute(bool hasEsn, {bool confirmed = false}) {
    if (destructive && !confirmed) {
      return false;
    }

    if (requiresEsn && !hasEsn) {
      return false;
    }

    return true;
  }
}

class DeviceManualConfig {
  final String model;
  final String manufacturer;
  final String firmwareVersion;
  final String generationDate;
  final Map<String, DeviceManualParameter> parameters;
  final Map<String, CommandTemplate> commandCatalog;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> security;
  final Map<String, dynamic> ui;

  DeviceManualConfig({
    required this.model,
    required this.manufacturer,
    required this.firmwareVersion,
    required this.generationDate,
    required this.parameters,
    required this.commandCatalog,
    required this.deviceInfo,
    required this.security,
    required this.ui,
  });

  factory DeviceManualConfig.fromJson(Map<String, dynamic> json) {
    final parameters = <String, DeviceManualParameter>{};

    if (json['parameters'] != null) {
      json['parameters'].forEach((key, value) {
        parameters[key] = DeviceManualParameter.fromJson(value);
      });
    }

    final commandCatalog = <String, CommandTemplate>{};

    if (json['commands'] != null) {
      json['commands'].forEach((key, value) {
        commandCatalog[key] = CommandTemplate.fromJson(value);
      });
    }

    return DeviceManualConfig(
      model: json['model'],
      manufacturer: json['manufacturer'],
      firmwareVersion: json['firmware_version'],
      generationDate: json['generation_date'],
      parameters: parameters,
      commandCatalog: commandCatalog,
      deviceInfo: json['device_info'] ?? {},
      security: json['security'] ?? {},
      ui: json['ui'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'manufacturer': manufacturer,
      'firmware_version': firmwareVersion,
      'generation_date': generationDate,
      'parameters': parameters.map((key, value) => MapEntry(key, value.toJson())),
      'commands': commandCatalog.map((key, value) => MapEntry(key, value.toJson())),
      'device_info': deviceInfo,
      'security': security,
      'ui': ui,
    };
  }
}

class ManualCommandResult {
  final String? response;
  final String? error;
  final int? executionTimeMs;
  final Map<String, dynamic>? parsedData;
  final bool isSuccess;

  ManualCommandResult({
    this.response,
    this.error,
    this.executionTimeMs,
    this.parsedData,
    this.isSuccess = false,
  });

  factory ManualCommandResult.success(String response, {int? executionTime}) {
    return ManualCommandResult(
      response: response,
      executionTimeMs: executionTime,
      isSuccess: true,
    );
  }

  factory ManualCommandResult.error(String error) {
    return ManualCommandResult(
      error: error,
      isSuccess: false,
    );
  }
}

class ManualCommandFlowService {
  static final Map<String, DeviceManualConfig> _deviceManuals = {};

  static Future<void> initialize() async {
    await _loadAllManuals();
  }

  static Future<void> _loadAllManuals() async {
    try {
      _loadBuiltInManuals();
    } catch (_) {
      // Silently ignore manual loading errors during initialization
    }
  }

  static void _loadBuiltInManuals() {
    _deviceManuals['ST310ULC'] = _getST310ULCManual();
    _deviceManuals['ST4215U'] = _getST4215UManual();
    _deviceManuals['ST310U'] = _getST310UManual();
    _deviceManuals['ST4945'] = _getST4945Manual();
    _deviceManuals['ST6560'] = _getST6560Manual();
    _deviceManuals['ST8310U'] = _getST8310UManual();
    _deviceManuals['ST4305'] = _getST4305Manual();
    _deviceManuals['ST8300UM'] = _getST8300UMManual();
    _deviceManuals['ST8395'] = _getST8395Manual();
  }

  static Future<DeviceManualConfig?> getManualConfig(String model) async {
    model = model.toUpperCase();
    
    if (_deviceManuals.containsKey(model)) {
      return _deviceManuals[model];
    }

    // Try to load from assets
    if (model.startsWith('ST')) {
      try {
        return await _loadManualFromAssets(model);
      } catch (_) {
        return _getGenericManualConfig();
      }
    }

    return null;
  }

  static Future<DeviceManualConfig?> _loadManualFromAssets(String model) async {
    final directory = Directory('assets/manuals');
    
    if (!await directory.exists()) {
      return null;
    }

    final filename = '${model}_manual_mapping.json';
    final file = File('${directory.path}/$filename');
    
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    final jsonData = jsonDecode(content);
    
    return DeviceManualConfig.fromJson(Map<String, dynamic>.from(jsonData));
  }

  static DeviceManualConfig _getGenericManualConfig() {
    return DeviceManualConfig(
      model: 'ST_GENERIC',
      manufacturer: 'Suntech',
      firmwareVersion: 'unknown',
      generationDate: DateTime.now().toIso8601String(),
      parameters: {},
      commandCatalog: {},
      deviceInfo: {},
      security: {},
      ui: {},
    );
  }

  static Future<ManualCommandResult> sendCommand(
    String model,
    String parameterId,
    String targetState,
    String deviceId,
    String esn, {
    Map<String, String> customMappings = const {},
  }) async {
    final startTime = DateTime.now();
    
    try {
      final manualConfig = await getManualConfig(model);
      if (manualConfig == null) {
        return ManualCommandResult.error('Manual não encontrado para modelo: $model');
      }

      final parameter = manualConfig.parameters[parameterId];
      if (parameter == null) {
        return ManualCommandResult.error('Parâmetro não encontrado: $parameterId');
      }

      final commandTemplate = parameter.commands
          .where((cmd) => cmd.mappings?.entries.any((entry) => 
              entry.value == targetState) ?? false)
          .firstOrNull;

      if (commandTemplate == null) {
        return ManualCommandResult.error('Nenhum comando encontrado para estado: $targetState');
      }

      final command = commandTemplate.buildCommand(
        esn: esn,
        targetState: targetState,
        customMappings: customMappings,
      );

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      return ManualCommandResult.success(command, executionTime: executionTime);

    } catch (e) {
      return ManualCommandResult.error('Falha ao construir comando: $e');
    }
  }

  // Session management moved to ManualCommandFlowProvider

  static List<String> getSupportedModels() {
    return _deviceManuals.keys.toList();
  }

  static DeviceManualParameter? getParameter(String model, String parameterId) {
    final manualConfig = _deviceManuals[model];
    return manualConfig?.parameters[parameterId];
  }

  static Map<String, CommandTemplate> getCommandCatalog(String model) {
    final manualConfig = _deviceManuals[model];
    return manualConfig?.commandCatalog ?? {};
  }

  static List<String> getParameterIds(String model) {
    final manualConfig = _deviceManuals[model];
    return manualConfig?.parameters.keys.toList() ?? [];
  }

  static List<String> getCommandIds(String model) {
    final manualConfig = _deviceManuals[model];
    return manualConfig?.commandCatalog.keys.toList() ?? [];
  }

  static Map<String, dynamic> analyzeDeviceModel(String model, String esn, String firmware) {
    final manualConfig = _deviceManuals[model];
    if (manualConfig == null) return {};

    final analysis = <String, dynamic>{};

    analysis['model'] = model;
    analysis['esn'] = esn;
    analysis['firmware'] = firmware;
    analysis['parameters'] = manualConfig.parameters.map((key, param) => 
        MapEntry(key, {
          'type': param.type,
          'defaultState': param.currentState,
          'states': param.states,
        })
    );

    analysis['commands'] = manualConfig.commandCatalog.map((key, cmd) => 
        MapEntry(key, {
          'template': cmd.commandTemplate,
          'risk': cmd.riskLevel,
          'destructive': cmd.destructive,
          'requiresEsn': cmd.requiresEsn,
        })
    );

    return analysis;
  }

  static DeviceManualConfig _getST310ULCManual() {
    return DeviceManualConfig(
      model: 'ST310ULC',
      manufacturer: 'Suntech',
      firmwareVersion: 'v1.11',
      generationDate: '2023-10-24',
      parameters: _getST310ULCParameters(),
      commandCatalog: _getST310ULCCommands(),
      deviceInfo: _getST310ULCDeviceInfo(),
      security: _getST310ULCSecurity(),
      ui: _getST310ULCUI(),
    );
  }

  static DeviceManualConfig _getST4215UManual() {
    return DeviceManualConfig(
      model: 'ST4215U',
      manufacturer: 'Suntech',
      firmwareVersion: 'v2.1',
      generationDate: '2024-01-09',
      parameters: _getST4215UParameters(),
      commandCatalog: _getST4215UCommands(),
      deviceInfo: _getST4215UDeviceInfo(),
      security: _getST4215USecurity(),
      ui: _getST4215UUI(),
    );
  }

  static DeviceManualConfig _getST310UManual() {
    return DeviceManualConfig(
      model: 'ST310U',
      manufacturer: 'Suntech',
      firmwareVersion: 'v2.0',
      generationDate: '2023-11-15',
      parameters: _getST310UParameters(),
      commandCatalog: _getST310UCommands(),
      deviceInfo: _getST310UDeviceInfo(),
      security: _getST310USecurity(),
      ui: _getST310UUI(),
    );
  }

  static DeviceManualConfig _getST4945Manual() {
    return DeviceManualConfig(
      model: 'ST4945',
      manufacturer: 'Suntech',
      firmwareVersion: 'v1.5',
      generationDate: '2023-09-20',
      parameters: _getST4945Parameters(),
      commandCatalog: _getST4945Commands(),
      deviceInfo: _getST4945DeviceInfo(),
      security: _getST4945Security(),
      ui: _getST4945UI(),
    );
  }

  static DeviceManualConfig _getST6560Manual() {
    return DeviceManualConfig(
      model: 'ST6560',
      manufacturer: 'Suntech',
      firmwareVersion: 'v1.8',
      generationDate: '2023-12-10',
      parameters: _getST6560Parameters(),
      commandCatalog: _getST6560Commands(),
      deviceInfo: _getST6560DeviceInfo(),
      security: _getST6560Security(),
      ui: _getST6560UI(),
    );
  }

  static DeviceManualConfig _getST8310UManual() {
    return DeviceManualConfig(
      model: 'ST8310U',
      manufacturer: 'Suntech',
      firmwareVersion: 'v2.2',
      generationDate: '2024-02-05',
      parameters: _getST8310UParameters(),
      commandCatalog: _getST8310UCommands(),
      deviceInfo: _getST8310UDeviceInfo(),
      security: _getST8310USecurity(),
      ui: _getST8310UUI(),
    );
  }

  static DeviceManualConfig _getST4305Manual() {
    return DeviceManualConfig(
      model: 'ST4305',
      manufacturer: 'Suntech',
      firmwareVersion: 'v3.0',
      generationDate: '2024-03-15',
      parameters: _getST4305Parameters(),
      commandCatalog: _getST4305Commands(),
      deviceInfo: _getST4305DeviceInfo(),
      security: _getST4305Security(),
      ui: _getST4305UI(),
    );
  }

  static DeviceManualConfig _getST8300UMManual() {
    return DeviceManualConfig(
      model: 'ST8300UM',
      manufacturer: 'Suntech',
      firmwareVersion: 'v1.9',
      generationDate: '2023-08-08',
      parameters: _getST8300UMParameters(),
      commandCatalog: _getST8300UMCommands(),
      deviceInfo: _getST8300UMDeviceInfo(),
      security: _getST8300UMSecurity(),
      ui: _getST8300UMUI(),
    );
  }

  static DeviceManualConfig _getST8395Manual() {
    return DeviceManualConfig(
      model: 'ST8395',
      manufacturer: 'Suntech',
      firmwareVersion: 'v2.5',
      generationDate: '2024-04-20',
      parameters: _getST8395Parameters(),
      commandCatalog: _getST8395Commands(),
      deviceInfo: _getST8395DeviceInfo(),
      security: _getST8395Security(),
      ui: _getST8395UI(),
    );
  }

  static Map<String, DeviceManualParameter> _getST310ULCParameters() {
    return {
      'ignition': DeviceManualParameter(
        field: 'Pino 1',
        type: ParameterType.digital,
        states: ['OFF', 'ON'],
        description: 'Controle da ignição do veículo',
        commands: [
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;03;00',
            expectedResponse: 'RES;ESN;03;00',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Desativa ignição',
            mappings: {'STATE': 'OFF'},
          ),
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;03;01',
            expectedResponse: 'RES;ESN;03;01',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Ativa ignição',
            mappings: {'STATE': 'ON'},
          ),
        ],
        currentState: 'OFF',
      ),
      'output_relay_2': DeviceManualParameter(
        field: 'Pino 2 (Relé)',
        type: ParameterType.digital,
        states: ['OFF', 'ON'],
        description: 'Relé de controle de saída',
        commands: [
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;04;00',
            expectedResponse: 'RES;ESN;04;00',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Desativa saída do relé',
            mappings: {'STATE': 'OFF'},
          ),
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;04;01',
            expectedResponse: 'RES;ESN;04;01',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Ativa saída do relé',
            mappings: {'STATE': 'ON'},
          ),
        ],
        currentState: 'OFF',
      ),
      'gps': DeviceManualParameter(
        field: 'GPS e rede',
        type: ParameterType.network,
        states: ['DESABILITADO', 'HABILITADO'],
        description: 'Status do GPS e rede de localização',
        commands: [
          CommandTemplate(
            commandTemplate: 'AT^CMD;ESN;10;02',
            expectedResponse: 'GPS:DESABILITADO',
            riskLevel: RiskLevel.medium,
            requiresEsn: true,
            destructive: false,
            notes: 'Desabilita GPS',
            mappings: {'STATE': 'DESABILITADO'},
          ),
          CommandTemplate(
            commandTemplate: 'AT^CMD;ESN;10;01',
            expectedResponse: 'LAT;LON;VELOCIDADE;HEADING',
            riskLevel: RiskLevel.medium,
            requiresEsn: true,
            destructive: false,
            notes: 'Habilita GPS',
            mappings: {'STATE': 'HABILITADO'},
          ),
        ],
        currentState: 'DESABILITADO',
      ),
    };
  }

  static Map<String, DeviceManualParameter> _getST4215UParameters() {
    return {
      'ignition': DeviceManualParameter(
        field: 'Pino 1',
        type: ParameterType.digital,
        states: ['OFF', 'ON'],
        description: 'Controle da ignição do veículo',
        commands: [
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;03;00',
            expectedResponse: 'RES;ESN;03;00',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Desativa ignição',
            mappings: {'STATE': 'OFF'},
          ),
          CommandTemplate(
            commandTemplate: 'AT^ST300CMD;;02;03;01',
            expectedResponse: 'RES;ESN;03;01',
            riskLevel: RiskLevel.low,
            requiresEsn: false,
            destructive: false,
            notes: 'Ativa ignição',
            mappings: {'STATE': 'ON'},
          ),
        ],
        currentState: 'OFF',
      ),
      'gps': DeviceManualParameter(
        field: 'GPS+GLONASS',
        type: ParameterType.network,
        states: ['DESABILITADO', 'HABILITADO'],
        description: 'Status do GPS e rede de localização',
        commands: [
          CommandTemplate(
            commandTemplate: 'AT^CMD;ESN;10;02',
            expectedResponse: 'GPS:DESABILITADO',
            riskLevel: RiskLevel.medium,
            requiresEsn: true,
            destructive: false,
            notes: 'Desabilita GPS',
            mappings: {'STATE': 'DESABILITADO'},
          ),
          CommandTemplate(
            commandTemplate: 'AT^CMD;ESN;10;01',
            expectedResponse: 'LAT;LON;LAT;LON;VELOCIDADE;HEADING;HDOP;SNR',
            riskLevel: RiskLevel.medium,
            requiresEsn: true,
            destructive: false,
            notes: 'Habilita GPS com GLONASS',
            mappings: {'STATE': 'HABILITADO'},
          ),
        ],
        currentState: 'HABILITADO',
      ),
    };
  }

  static Map<String, CommandTemplate> _getST310ULCCommands() {
    return {
      'status_req': CommandTemplate(
        commandTemplate: 'AT^ST300CMD;;02;StatusReq',
        expectedResponse: 'RES;ESN;03;01;04;0x;10;...',
        riskLevel: RiskLevel.low,
        requiresEsn: false,
        destructive: false,
        notes: 'Status completo do dispositivo',
      ),
      'preset_read': CommandTemplate(
        commandTemplate: 'AT^ST300CMD;;02;Preset',
        expectedResponse: 'RES;ESN;03;05;...',
        riskLevel: RiskLevel.low,
        requiresEsn: false,
        destructive: false,
        notes: 'Leitura de configurações atuais',
      ),
      'network_setup': CommandTemplate(
        commandTemplate: 'AT^ST300NTN;;02;0;<APN>;<USER>;<PASS>;<HOST>;<PORT>;;;;',
        expectedResponse: 'OK',
        riskLevel: RiskLevel.high,
        requiresEsn: false,
        destructive: false,
        requiresBackup: true,
        notes: 'Configuração de rede APN, requer backup',
      ),
    };
  }

  static Map<String, CommandTemplate> _getST4215UCommands() {
    return {
      'status_req': CommandTemplate(
        commandTemplate: 'AT^CMD;ESN;01;01',
        expectedResponse: 'STATUS:ESN;IGN;GPS;REDE;APN',
        riskLevel: RiskLevel.low,
        requiresEsn: true,
        destructive: false,
        notes: 'Status completo do dispositivo',
      ),
      'preset_read': CommandTemplate(
        commandTemplate: 'AT^CMD;ESN;03;05',
        expectedResponse: 'CONFIG;IGN;GPS;REDE;APN;...',
        riskLevel: RiskLevel.low,
        requiresEsn: true,
        destructive: false,
        notes: 'Leitura completa das configurações atuais',
      ),
    };
  }

  static Map<String, dynamic> _getST310ULCDeviceInfo() {
    return {
      'baud_rates': [9600, 19200, 38400, 115200],
      'connection_type': 'USB/Serial',
      'esn_required': false,
      'firmware_detection': true,
      'model_pattern': 'ST310U|ST310ULC',
    };
  }

  static Map<String, dynamic> _getST310ULCSecurity() {
    return {
      'destructive_commands': ['network_setup'],
      'requires_backup_before': ['network_setup'],
      'require_confirmation': true,
      'log_all_commands': true,
      'audit_trail': true,
    };
  }

  static Map<String, dynamic> _getST310ULCUI() {
    return {
      'panel_layout': 'grid',
      'parameter_cards': true,
      'quick_actions': ['ignition', 'gps'],
      'evidence_collection': true,
      'auto_save_interval': 30,
      'language': 'pt-br',
    };
  }

  static Map<String, dynamic> _getST4215UDeviceInfo() {
    return {
      'baud_rates': [9600, 19200, 38400, 115200],
      'connection_type': 'USB/Serial',
      'esn_required': true,
      'firmware_detection': true,
      'model_pattern': 'ST4215U',
    };
  }

  static Map<String, dynamic> _getST4215USecurity() {
    return {
      'destructive_commands': ['network_setup', 'ignconfig_write'],
      'requires_backup_before': ['network_setup'],
      'require_confirmation': true,
      'log_all_commands': true,
      'audit_trail': true,
    };
  }

  static Map<String, dynamic> _getST4215UUI() {
    return {
      'panel_layout': 'grid',
      'parameter_cards': true,
      'quick_actions': ['ignition', 'gps'],
      'evidence_collection': true,
      'auto_save_interval': 30,
      'language': 'pt-br',
      'advanced_features': true,
    };
  }

  static Map<String, DeviceManualParameter> _getST310UParameters() {
    return _getST310ULCParameters();
  }

  static Map<String, CommandTemplate> _getST310UCommands() {
    return _getST310ULCCommands();
  }

  static Map<String, dynamic> _getST310UDeviceInfo() {
    return _getST310ULCDeviceInfo();
  }

  static Map<String, dynamic> _getST310USecurity() {
    return _getST310ULCSecurity();
  }

  static Map<String, dynamic> _getST310UUI() {
    return _getST310ULCUI();
  }

  static Map<String, DeviceManualParameter> _getST4945Parameters() {
    return _getST310ULCParameters();
  }

  static Map<String, CommandTemplate> _getST4945Commands() {
    return _getST310ULCCommands();
  }

  static Map<String, dynamic> _getST4945DeviceInfo() {
    return _getST310ULCDeviceInfo();
  }

  static Map<String, dynamic> _getST4945Security() {
    return _getST310ULCSecurity();
  }

  static Map<String, dynamic> _getST4945UI() {
    return _getST310ULCUI();
  }

  static Map<String, DeviceManualParameter> _getST6560Parameters() {
    return _getST4215UParameters();
  }

  static Map<String, CommandTemplate> _getST6560Commands() {
    return _getST4215UCommands();
  }

  static Map<String, dynamic> _getST6560DeviceInfo() {
    return _getST4215UDeviceInfo();
  }

  static Map<String, dynamic> _getST6560Security() {
    return _getST4215USecurity();
  }

  static Map<String, dynamic> _getST6560UI() {
    return _getST4215UUI();
  }

  static Map<String, DeviceManualParameter> _getST8310UParameters() {
    return _getST4215UParameters();
  }

  static Map<String, CommandTemplate> _getST8310UCommands() {
    return _getST4215UCommands();
  }

  static Map<String, dynamic> _getST8310UDeviceInfo() {
    return _getST4215UDeviceInfo();
  }

  static Map<String, dynamic> _getST8310USecurity() {
    return _getST4215USecurity();
  }

  static Map<String, dynamic> _getST8310UUI() {
    return _getST4215UUI();
  }

  static Map<String, DeviceManualParameter> _getST4305Parameters() {
    return _getST4215UParameters();
  }

  static Map<String, CommandTemplate> _getST4305Commands() {
    return _getST4215UCommands();
  }

  static Map<String, dynamic> _getST4305DeviceInfo() {
    return _getST4215UDeviceInfo();
  }

  static Map<String, dynamic> _getST4305Security() {
    return _getST4215USecurity();
  }

  static Map<String, dynamic> _getST4305UI() {
    return _getST4215UUI();
  }

  static Map<String, DeviceManualParameter> _getST8300UMParameters() {
    return _getST4215UParameters();
  }

  static Map<String, CommandTemplate> _getST8300UMCommands() {
    return _getST4215UCommands();
  }

  static Map<String, dynamic> _getST8300UMDeviceInfo() {
    return _getST4215UDeviceInfo();
  }

  static Map<String, dynamic> _getST8300UMSecurity() {
    return _getST4215USecurity();
  }

  static Map<String, dynamic> _getST8300UMUI() {
    return _getST4215UUI();
  }

  static Map<String, DeviceManualParameter> _getST8395Parameters() {
    return _getST4215UParameters();
  }

  static Map<String, CommandTemplate> _getST8395Commands() {
    return _getST4215UCommands();
  }

  static Map<String, dynamic> _getST8395DeviceInfo() {
    return _getST4215UDeviceInfo();
  }

  static Map<String, dynamic> _getST8395Security() {
    return _getST4215USecurity();
  }

  static Map<String, dynamic> _getST8395UI() {
    return _getST4215UUI();
  }
}
