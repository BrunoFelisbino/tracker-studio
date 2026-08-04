// Catalogo de mapeamentos oficiais de parâmetros para Teltonika FMB-series.
// Este catálogo é extraído dos manuais oficiais e usado para mapear parâmetros
// dos dispositivos Teltonika para o fluxo de trabalho do Laboratório de Equipamentos.
//
// Copyright (c) 2026 Bruno Felisbino - LocaliTel
// Licença: Apache 2.0

import '../../uce/uce_interfaces.dart';

class TeltonikaParameterCatalog {
  /// Retorna o catálogo completo de definições de parâmetros para Teltonika.
  static List<TeltonikaParameterMapping> get all => [
        // --- Parâmetros de rede ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 2001,
          category: ParameterCategory.network,
          group: 'GPRS',
          name: 'APN',
          description: 'Access Point Name do operador celular',
          type: ParameterType.apn,
          defaultValue: 'internet',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 2002,
          category: ParameterCategory.network,
          group: 'GPRS',
          name: 'Username',
          description: 'Nome de usuário para autenticação APN',
          type: ParameterType.string,
          defaultValue: '',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 2003,
          category: ParameterCategory.network,
          group: 'GPRS',
          name: 'Password',
          description: 'Senha para autenticação APN',
          type: ParameterType.string,
          defaultValue: '',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2004,
          category: ParameterCategory.server,
          group: 'Server',
          name: 'Server Address',
          description: 'Endereço IP ou domínio do servidor de destino',
          type: ParameterType.ipAddress,
          defaultValue: '',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2005,
          category: ParameterCategory.server,
          group: 'Server',
          name: 'Server Port',
          description: 'Porta de destino do servidor',
          type: ParameterType.port,
          defaultValue: 5026,
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          validationStatus: 'official',
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 2006,
          category: ParameterCategory.server,
          group: 'Server',
          name: 'Transport Protocol',
          description: '0 = TCP, 1 = UDP, 3 = MQTT',
          type: ParameterType.enumValue,
          defaultValue: '0',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
          enumValues: {
            '0': 'TCP',
            '1': 'UDP',
            '3': 'MQTT',
          },
        ),

        // --- Parâmetros de backup/servidor ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2007,
          category: ParameterCategory.server,
          group: 'Server Backup',
          name: 'Backup Server Domain',
          description: 'Endereço IP ou domínio do servidor backup',
          type: ParameterType.string,
          defaultValue: '',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2008,
          category: ParameterCategory.server,
          group: 'Server Backup',
          name: 'Backup Server Port',
          description: 'Porta do servidor backup',
          type: ParameterType.number,
          defaultValue: 0,
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2009,
          category: ParameterCategory.server,
          group: 'Server Backup',
          name: 'Backup Server Protocol',
          description: '0 = TCP, 1 = UDP, 3 = MQTT',
          type: ParameterType.enumValue,
          defaultValue: '0',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
          enumValues: {
            '0': 'TCP',
            '1': 'UDP',
            '3': 'MQTT',
          },
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902'],
          parameterId: 2010,
          category: ParameterCategory.server,
          group: 'Server Backup',
          name: 'Backup Server Mode',
          description: '0 = Disable, 1 = Backup, 2 = Duplicate, 3 = EGTS',
          type: ParameterType.enumValue,
          defaultValue: '0',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
          enumValues: {
            '0': 'Disable',
            '1': 'Backup',
            '2': 'Duplicate',
            '3': 'EGTS',
          },
        ),

        // --- Parâmetros de aquisição de dados em movimento ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10050,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Min Period',
          description:
              'Período mínimo de aquisição enquanto movendo (segundos)',
          type: ParameterType.number,
          defaultValue: 300,
          unit: 's',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10051,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Min Distance',
          description:
              'Distância mínima de aquisição enquanto movendo (metros)',
          type: ParameterType.number,
          defaultValue: 100,
          unit: 'm',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10052,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Min Angle',
          description:
              'Mudança mínima de curso para registrar enquanto movendo (graus)',
          type: ParameterType.number,
          defaultValue: 10,
          unit: '°',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10053,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Min Speed Delta',
          description:
              'Mudança mínima de velocidade para registrar enquanto movendo (km/h)',
          type: ParameterType.number,
          defaultValue: 10,
          unit: 'km/h',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10054,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Min Saved Records',
          description:
              'Mínimo de registros para salvar antes de enviar (enquanto movendo)',
          type: ParameterType.number,
          defaultValue: 1,
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 10055,
          category: ParameterCategory.moving,
          group: 'Data Acquisition',
          name: 'Send Period',
          description: 'Período máximo de envio enquanto movendo (segundos)',
          type: ParameterType.number,
          defaultValue: 120,
          unit: 's',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),

        // --- Parâmetros de sistema ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 901,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'NTP Resync',
          description: 'Período de resync via NTP (horas)',
          type: ParameterType.number,
          defaultValue: 0,
          unit: 'h',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 902,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'NTP Server 1',
          description: 'Primary NTP server host',
          type: ParameterType.string,
          defaultValue: 'pool.ntp.org',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 903,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'NTP Server 2',
          description: 'Secondary NTP server host',
          type: ParameterType.string,
          defaultValue: 'time.nist.gov',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),

        // --- Parâmetros de energia e ignição ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 104,
          category: ParameterCategory.power,
          group: 'Sistema',
          name: 'High Voltage',
          description: 'Tensão de ignição alta (mV)',
          type: ParameterType.number,
          defaultValue: 30000,
          unit: 'mV',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640', 'FM5500', 'FMP100'],
          parameterId: 105,
          category: ParameterCategory.power,
          group: 'Sistema',
          name: 'Low Voltage',
          description: 'Tensão de ignição baixa (mV)',
          type: ParameterType.number,
          defaultValue: 13200,
          unit: 'mV',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),

        // --- Parâmetros de baixo consumo ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 19500,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'Low Power Mode',
          description:
              '0 = Disabled, 1 = Enabled (requires battery + deep sleep)',
          type: ParameterType.enumValue,
          defaultValue: '0',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
          enumValues: {
            '0': 'Disabled',
            '1': 'Enabled',
          },
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 19501,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'Min Period (Low Power)',
          description: 'Wake-up period while in Low Power Mode (seconds)',
          type: ParameterType.number,
          defaultValue: 3600,
          unit: 's',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 19502,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'GPS Search Period',
          description: 'Período de busca GPS após wake-up (segundos)',
          type: ParameterType.number,
          defaultValue: 60,
          unit: 's',
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140', 'FMB902', 'FMC640'],
          parameterId: 19504,
          category: ParameterCategory.system,
          group: 'Sistema',
          name: 'GPS Satellites Quantity',
          description: 'Minimum visible satellites to renew GPS data',
          type: ParameterType.number,
          defaultValue: 0,
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.safe,
          source: 'manual',
        ),

        // --- Parâmetros específicos de firmware ---
        TeltonikaParameterMapping(
          manufacturer: Manufacturer.teltonika,
          model: ['FMB140'],
          parameterId: 2001,
          category: ParameterCategory.network,
          group: 'GPRS',
          name: 'APN',
          description: 'APN para FMB140 (diferente dos outros modelos)',
          type: ParameterType.apn,
          defaultValue: 'internet',
          unit: null,
          readable: true,
          writable: true,
          requiresSave: true,
          requiresReboot: false,
          riskLevel: RiskLevel.configuration,
          source: 'manual',
        ),
      ];

  /// Retorna um mapeamento para um ID de parâmetro específico.
  static TeltonikaParameterMapping? getByParameterId(
    int parameterId, {
    required List<String> supportedModels,
  }) {
    for (final mapping in all) {
      if (mapping.parameterId == parameterId &&
          _isModelCompatible(mapping.model, supportedModels)) {
        return mapping;
      }
    }
    return null;
  }

  /// Verifica se um modelo é compatível com os modelos suportados.
  static bool _isModelCompatible(
    List<String>? parameterModels,
    List<String> supportedModels,
  ) {
    if (parameterModels == null || parameterModels.isEmpty) {
      return true;
    }

    for (final paramModel in parameterModels) {
      if (supportedModels.contains(paramModel)) {
        return true;
      }
    }

    return false;
  }
}

/// Representação de um único parâmetro de dispositivo Teltonika.
class TeltonikaParameterMapping {
  final Manufacturer manufacturer;
  final List<String> model;
  final int parameterId;
  final ParameterCategory category;
  final String group;
  final String name;
  final String description;
  final ParameterType type;
  final dynamic defaultValue;
  final String? unit;
  final bool readable;
  final bool writable;
  final bool requiresSave;
  final bool requiresReboot;
  final RiskLevel riskLevel;
  final String source;
  final Map<String, String>? enumValues;
  final String? validationStatus;

  const TeltonikaParameterMapping({
    required this.manufacturer,
    required this.model,
    required this.parameterId,
    required this.category,
    required this.group,
    required this.name,
    required this.description,
    required this.type,
    required this.defaultValue,
    this.unit,
    required this.readable,
    required this.writable,
    required this.requiresSave,
    required this.requiresReboot,
    required this.riskLevel,
    required this.source,
    this.enumValues,
    this.validationStatus,
  });

  /// Converte para JSON para armazenamento/persistência.
  Map<String, dynamic> toJson() {
    return {
      'manufacturer': manufacturer.name,
      'model': model,
      'parameterId': parameterId,
      'category': category.name,
      'group': group,
      'name': name,
      'description': description,
      'type': type.name,
      'defaultValue': defaultValue,
      'unit': unit,
      'readable': readable,
      'writable': writable,
      'requiresSave': requiresSave,
      'requiresReboot': requiresReboot,
      'riskLevel': riskLevel.name,
      'source': source,
      'enumValues': enumValues,
      'validationStatus': validationStatus,
    };
  }

  /// Cria uma cópia de si mesmo com valores atualizados.
  TeltonikaParameterMapping copyWith({
    dynamic defaultValue,
    bool? writable,
  }) {
    return TeltonikaParameterMapping(
      manufacturer: manufacturer,
      model: model,
      parameterId: parameterId,
      category: category,
      group: group,
      name: name,
      description: description,
      type: type,
      defaultValue: defaultValue ?? this.defaultValue,
      unit: unit,
      readable: readable,
      writable: writable ?? this.writable,
      requiresSave: requiresSave,
      requiresReboot: requiresReboot,
      riskLevel: riskLevel,
      source: source,
      enumValues: enumValues,
      validationStatus: validationStatus,
    );
  }

  /// Retorna uma descrição formatada para exibição ao usuário.
  String get displayDescription {
    final parts = <String>['$name (ID: $parameterId)'];

    if (unit != null) {
      parts.add(' • Unidade: $unit');
    }

    if (defaultValue != null) {
      parts.add(' • Padrão: $defaultValue');
    }

    if (enumValues != null && enumValues!.isNotEmpty) {
      final enumList =
          enumValues!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      parts.add(' • Valores: $enumList');
    }

    return parts.join('\n');
  }

  /// Retorna um indicador de risco baseado no nível de risco.
  String get riskIndicator {
    switch (riskLevel) {
      case RiskLevel.readOnly:
        return '🔒';
      case RiskLevel.safe:
        return '✅';
      case RiskLevel.configuration:
        return '⚙️';
      case RiskLevel.destructive:
        return '⚠️';
    }
  }

  /// Retorna um ícone de categoria baseado no tipo de categoria.
  String get categoryIcon {
    switch (category) {
      case ParameterCategory.network:
        return '📶';
      case ParameterCategory.server:
        return '🖥️';
      case ParameterCategory.moving:
        return '🚗';
      case ParameterCategory.gps:
        return '🧭';
      case ParameterCategory.power:
        return '⚡';
      case ParameterCategory.system:
        return '⚙️';
      default:
        return '📋';
    }
  }

  /// Retorna tags de destaque para o parâmetro.
  List<String> get highlightTags {
    final tags = <String>[];

    if (riskLevel == RiskLevel.destructive) {
      tags.add('HIGH RISK');
    } else if (riskLevel == RiskLevel.configuration) {
      tags.add('CONFIGURATION');
    }

    if (requiresSave) {
      tags.add('REQUIRES SAVE');
    }

    if (requiresReboot) {
      tags.add('REQUIRES REBOOT');
    }

    if (validationStatus == 'official') {
      tags.add('OFFICIAL');
    }

    return tags;
  }
}
