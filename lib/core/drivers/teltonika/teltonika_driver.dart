import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/parsers/teltonika_usb/teltonika_avl_binary_codec.dart';
import '../../data/parsers/teltonika_usb/teltonika_usb_models.dart';
import '../../uce/registry/uce_registry.dart';
import '../../uce/uce_interfaces.dart';

/// Teltonika driver.
///
/// Registers the Teltonika configuration parameter catalog, AVL telemetry IDs,
/// commands and response patterns into the Universal Command Engine, and
/// encodes/decodes the USB Configurator text protocol used over a serial USB
/// connection:
///
/// - write:  `:cfg_setparam:<parameterId>:<value>` / `:cfg_save`
/// - read:   `<SETPARAM_RESULT>:1`, `<SAVE_CFG_RESULT>:1`, `<CFG_CONNECT>`
class TeltonikaDriver {
  static const Manufacturer manufacturer = Manufacturer.teltonika;

  /// Registers parameters, AVL, commands and responses for Teltonika.
  static void registerAll() {
    final registry = UceRegistry();

    // ──────────────────────────────────────────────────────────────────────────
    // 1. PARAMETERS (Configuration parameter database)
    // ──────────────────────────────────────────────────────────────────────────
    final teltonikaParams = [
      const ParameterDefinition(
        id: 'teltonika.cfg.apn',
        manufacturer: manufacturer,
        category: ParameterCategory.network,
        group: 'GPRS',
        name: 'APN',
        description: 'Access Point Name of cellular operator',
        command: 'teltonika.cfg_setparam',
        parameterId: 2001,
        valueType: ParameterValueType.apn,
        defaultValue: 'internet',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.apn_username',
        manufacturer: manufacturer,
        category: ParameterCategory.network,
        group: 'GPRS',
        name: 'APN Username',
        description: 'APN Authentication Username',
        command: 'teltonika.cfg_setparam',
        parameterId: 2002,
        valueType: ParameterValueType.string,
        defaultValue: '',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.apn_password',
        manufacturer: manufacturer,
        category: ParameterCategory.network,
        group: 'GPRS',
        name: 'APN Password',
        description: 'APN Authentication Password',
        command: 'teltonika.cfg_setparam',
        parameterId: 2003,
        valueType: ParameterValueType.string,
        defaultValue: '',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.server_address',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server',
        name: 'Server Address',
        description: 'Server Destination IP or Domain Address',
        command: 'teltonika.cfg_setparam',
        parameterId: 2004,
        valueType: ParameterValueType.ipAddress,
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.server_port',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server',
        name: 'Server Port',
        description: 'Server Destination Port',
        command: 'teltonika.cfg_setparam',
        parameterId: 2005,
        valueType: ParameterValueType.port,
        defaultValue: 5026,
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'field-validated', // Confirmed by captures 526 & 527
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.transport_protocol',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server',
        name: 'Transport Protocol',
        description: '0 = TCP, 1 = UDP',
        command: 'teltonika.cfg_setparam',
        parameterId: 2006,
        valueType: ParameterValueType.enumValue,
        defaultValue: '0',
        enumValues: {'0': 'TCP', '1': 'UDP', '3': 'MQTT'},
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_min_period',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Min Period',
        description: 'Minimum acquisition period while moving (seconds)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10050,
        valueType: ParameterValueType.number,
        defaultValue: 300,
        minimum: 0,
        maximum: 2592000,
        unit: 's',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_min_distance',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Min Distance',
        description: 'Minimum acquisition distance while moving (meters)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10051,
        valueType: ParameterValueType.number,
        defaultValue: 100,
        minimum: 0,
        maximum: 65535,
        unit: 'm',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_min_angle',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Min Angle',
        description: 'Minimum course change to record while moving (degrees)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10052,
        valueType: ParameterValueType.number,
        defaultValue: 10,
        minimum: 0,
        maximum: 180,
        unit: '°',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_min_speed_delta',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Min Speed Delta',
        description: 'Minimum speed change to record while moving (km/h)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10053,
        valueType: ParameterValueType.number,
        defaultValue: 10,
        minimum: 0,
        maximum: 100,
        unit: 'km/h',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_min_saved_records',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Min Saved Records',
        description: 'Minimum records to save before sending (while moving)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10054,
        valueType: ParameterValueType.number,
        defaultValue: 1,
        minimum: 1,
        maximum: 255,
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.moving_send_period',
        manufacturer: manufacturer,
        category: ParameterCategory.moving,
        group: 'Data Acquisition',
        name: 'Send Period',
        description: 'Maximum send period while moving (seconds)',
        command: 'teltonika.cfg_setparam',
        parameterId: 10055,
        valueType: ParameterValueType.number,
        defaultValue: 120,
        minimum: 0,
        maximum: 2592000,
        unit: 's',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.backup_server_mode',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server Backup',
        name: 'Backup Server Mode',
        description: '0 = Disable, 1 = Backup, 2 = Duplicate, 3 = EGTS',
        command: 'teltonika.cfg_setparam',
        parameterId: 2010,
        valueType: ParameterValueType.enumValue,
        defaultValue: '0',
        enumValues: {
          '0': 'Disable',
          '1': 'Backup',
          '2': 'Duplicate',
          '3': 'EGTS',
        },
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.backup_server_domain',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server Backup',
        name: 'Backup Server Domain',
        description: 'Backup server destination IP or domain address',
        command: 'teltonika.cfg_setparam',
        parameterId: 2007,
        valueType: ParameterValueType.string,
        defaultValue: '',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.backup_server_port',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server Backup',
        name: 'Backup Server Port',
        description: 'Backup server destination port',
        command: 'teltonika.cfg_setparam',
        parameterId: 2008,
        valueType: ParameterValueType.number,
        defaultValue: 0,
        minimum: 0,
        maximum: 65535,
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.backup_server_protocol',
        manufacturer: manufacturer,
        category: ParameterCategory.server,
        group: 'Server Backup',
        name: 'Backup Server Protocol',
        description: '0 = TCP, 1 = UDP, 3 = MQTT',
        command: 'teltonika.cfg_setparam',
        parameterId: 2009,
        valueType: ParameterValueType.enumValue,
        defaultValue: '0',
        enumValues: {'0': 'TCP', '1': 'UDP', '3': 'MQTT'},
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.high_voltage',
        manufacturer: manufacturer,
        category: ParameterCategory.power,
        group: 'Sistema',
        name: 'High Voltage',
        description: 'Ignition high voltage threshold (mV)',
        command: 'teltonika.cfg_setparam',
        parameterId: 104,
        valueType: ParameterValueType.number,
        defaultValue: 30000,
        minimum: 0,
        maximum: 30000,
        unit: 'mV',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.low_voltage',
        manufacturer: manufacturer,
        category: ParameterCategory.power,
        group: 'Sistema',
        name: 'Low Voltage',
        description: 'Ignition low voltage threshold (mV)',
        command: 'teltonika.cfg_setparam',
        parameterId: 105,
        valueType: ParameterValueType.number,
        defaultValue: 13200,
        minimum: 0,
        maximum: 29999,
        unit: 'mV',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.configuration,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.ntp_resync',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'NTP Resync',
        description: 'Time resynchronization period via NTP (hours)',
        command: 'teltonika.cfg_setparam',
        parameterId: 901,
        valueType: ParameterValueType.number,
        defaultValue: 0,
        minimum: 0,
        maximum: 24,
        unit: 'h',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.ntp_server_1',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'NTP Server 1',
        description: 'Primary NTP server host',
        command: 'teltonika.cfg_setparam',
        parameterId: 902,
        valueType: ParameterValueType.string,
        defaultValue: 'pool.ntp.org',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.ntp_server_2',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'NTP Server 2',
        description: 'Secondary NTP server host',
        command: 'teltonika.cfg_setparam',
        parameterId: 903,
        valueType: ParameterValueType.string,
        defaultValue: 'time.nist.gov',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.low_power_mode',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'Low Power Mode',
        description:
            '0 = Disabled, 1 = Enabled (requires battery + deep sleep)',
        command: 'teltonika.cfg_setparam',
        parameterId: 19500,
        valueType: ParameterValueType.enumValue,
        defaultValue: '0',
        enumValues: {'0': 'Disabled', '1': 'Enabled'},
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.low_power_min_period',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'Min Period (Low Power)',
        description: 'Wake-up period while in Low Power Mode (seconds)',
        command: 'teltonika.cfg_setparam',
        parameterId: 19501,
        valueType: ParameterValueType.number,
        defaultValue: 3600,
        minimum: 120,
        maximum: 2592000,
        unit: 's',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.low_power_gps_search_period',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'GPS Search Period',
        description: 'GPS fix attempt period after wake-up (seconds)',
        command: 'teltonika.cfg_setparam',
        parameterId: 19502,
        valueType: ParameterValueType.number,
        defaultValue: 60,
        minimum: 30,
        maximum: 3600,
        unit: 's',
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
      const ParameterDefinition(
        id: 'teltonika.cfg.low_power_gps_satellites',
        manufacturer: manufacturer,
        category: ParameterCategory.system,
        group: 'Sistema',
        name: 'GPS Satellites Quantity',
        description: 'Minimum visible satellites to renew GPS data',
        command: 'teltonika.cfg_setparam',
        parameterId: 19504,
        valueType: ParameterValueType.number,
        defaultValue: 0,
        minimum: 0,
        maximum: 20,
        readable: true,
        writable: true,
        requiresSave: true,
        requiresReboot: false,
        risk: RiskLevel.safe,
        documentationSource: 'official',
        validationStatus: 'official',
      ),
    ];
    registry.parameters.registerAll(teltonikaParams);

    // ──────────────────────────────────────────────────────────────────────────
    // 2. AVL TELEMETRY IDS (AVL registry)
    // ──────────────────────────────────────────────────────────────────────────
    final teltonikaAvlList = [
      const AvlDefinition(
        avlId: 1,
        name: 'Digital Input 1',
        normalizedKey: 'din1',
        category: AvlCategory.input,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 2,
        name: 'Digital Input 2',
        normalizedKey: 'din2',
        category: AvlCategory.input,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 3,
        name: 'Ignition',
        normalizedKey: 'ignition',
        category: AvlCategory.ignition,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 16,
        name: 'Trip Odometer',
        normalizedKey: 'trip_odometer',
        category: AvlCategory.trip,
        rawUnit: 'm',
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 10,
        name: 'Digital Output 1',
        normalizedKey: 'dout1',
        category: AvlCategory.output,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 11,
        name: 'Digital Output 2',
        normalizedKey: 'dout2',
        category: AvlCategory.output,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 66,
        name: 'External Voltage',
        normalizedKey: 'external_voltage',
        category: AvlCategory.power,
        rawUnit: 'mV',
        displayUnit: 'V',
        multiplier: 0.001,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 67,
        name: 'Battery Voltage',
        normalizedKey: 'battery_voltage',
        category: AvlCategory.battery,
        rawUnit: 'mV',
        displayUnit: 'V',
        multiplier: 0.001,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 69,
        name: 'GNSS Status',
        normalizedKey: 'gnss_status',
        category: AvlCategory.gps,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 89,
        name: 'Fuel Level (resistance)',
        normalizedKey: 'fuel_level',
        category: AvlCategory.fuel,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 113,
        name: 'Fuel Level (CAN/LVCAN)',
        normalizedKey: 'fuel_level',
        category: AvlCategory.fuel,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 181,
        name: 'PDOP',
        normalizedKey: 'pdop',
        category: AvlCategory.gps,
        multiplier: 0.1,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 182,
        name: 'HDOP',
        normalizedKey: 'hdop',
        category: AvlCategory.gps,
        multiplier: 0.1,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 199,
        name: 'Trip Odometer (m)',
        normalizedKey: 'trip_odometer',
        category: AvlCategory.trip,
        rawUnit: 'm',
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 240,
        name: 'Movement',
        normalizedKey: 'movement',
        category: AvlCategory.movement,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
      const AvlDefinition(
        avlId: 80,
        name: 'GSM Network Type',
        normalizedKey: 'gsm_network_type',
        category: AvlCategory.network,
        source: IoDefinitionSource.officialDocumentation,
        confidence: IoDefinitionConfidence.confirmed,
        manufacturer: manufacturer,
      ),
    ];
    registry.avl.registerAll(teltonikaAvlList);

    // ──────────────────────────────────────────────────────────────────────────
    // 3. CONFIGURATION AND AT COMMAND CATALOG
    // ──────────────────────────────────────────────────────────────────────────
    final commands = [
      CommandDefinition(
        id: 'teltonika.cfg_info',
        manufacturer: manufacturer,
        name: 'Get Configuration Info',
        description: 'Read the equipment firmware identity and hardware specs',
        transport: [CommandTransport.usb, CommandTransport.terminal],
        commandTemplate: ':cfg_info:?',
        timeout: const Duration(seconds: 3),
        risk: RiskLevel.readOnly,
        requiresConfirmation: false,
      ),
      CommandDefinition(
        id: 'teltonika.cfg_connect',
        manufacturer: manufacturer,
        name: 'Connect USB Configurator',
        description: 'Initialize configuration session via USB Configurator',
        transport: [CommandTransport.usb, CommandTransport.terminal],
        commandTemplate: ':cfg_connect',
        timeout: const Duration(seconds: 2),
        risk: RiskLevel.safe,
        requiresConfirmation: false,
      ),
      CommandDefinition(
        id: 'teltonika.cfg_setparam',
        manufacturer: manufacturer,
        name: 'Set Configuration Parameter',
        description: 'Update value for a specified configuration parameter ID',
        transport: [CommandTransport.usb, CommandTransport.terminal],
        commandTemplate: ':cfg_setparam:{parameterId}:{value}',
        timeout: const Duration(seconds: 3),
        risk: RiskLevel.configuration,
        requiresConfirmation: true,
      ),
      CommandDefinition(
        id: 'teltonika.cfg_save',
        manufacturer: manufacturer,
        name: 'Save Configuration Settings',
        description: "Persist changes in the device's non-volatile memory",
        transport: [CommandTransport.usb, CommandTransport.terminal],
        commandTemplate: ':cfg_save',
        timeout: const Duration(seconds: 5),
        risk: RiskLevel.configuration,
        requiresConfirmation: true,
      ),
       CommandDefinition(
         id: 'teltonika.cfg_disconnect',
         manufacturer: manufacturer,
         name: 'Disconnect Session',
         description: 'Gracefully close current configuration session',
         transport: [CommandTransport.usb, CommandTransport.terminal],
         commandTemplate: ':cfg_disconnect',
         timeout: const Duration(seconds: 2),
         risk: RiskLevel.safe,
         requiresConfirmation: false,
       ),
       CommandDefinition(
         id: 'teltonika.output1_lock',
         manufacturer: manufacturer,
         name: 'Bloquear (DO1 ON)',
         description:
             'Ativa a saída digital 1 (bloqueio/ímã de ar). Envia 1 para DO1.',
         transport: [CommandTransport.usb, CommandTransport.terminal],
         commandTemplate: ':cfg_setparam:{outputId}:1',
         timeout: const Duration(seconds: 3),
         risk: RiskLevel.configuration,
         requiresConfirmation: true,
       ),
       CommandDefinition(
         id: 'teltonika.output1_unlock',
         manufacturer: manufacturer,
         name: 'Desbloquear (DO1 OFF)',
         description:
             'Desativa a saída digital 1 (desbloqueio/ímã de ar). Envia 0 para DO1.',
         transport: [CommandTransport.usb, CommandTransport.terminal],
         commandTemplate: ':cfg_setparam:{outputId}:0',
         timeout: const Duration(seconds: 3),
         risk: RiskLevel.configuration,
         requiresConfirmation: true,
       ),
     ];
    registry.commands.registerAll(commands);

    // ──────────────────────────────────────────────────────────────────────────
    // 4. RESPONSE PARSERS
    // ──────────────────────────────────────────────────────────────────────────
    final responses = [
      const ResponseDefinition(
        id: 'teltonika.connect_ok',
        manufacturer: manufacturer,
        pattern: '<CFG_CONNECT>',
        description: 'Configurator connection accepted',
        parserFunction: 'parseConnect',
      ),
      const ResponseDefinition(
        id: 'teltonika.setparam_ok',
        manufacturer: manufacturer,
        pattern: '<SETPARAM_RESULT>:1',
        description: 'Parameter accepted by device',
        parserFunction: 'parseSetParamResult',
      ),
      const ResponseDefinition(
        id: 'teltonika.setparam_fail',
        manufacturer: manufacturer,
        pattern: '<SETPARAM_RESULT>:0',
        description: 'Parameter rejected by device',
        parserFunction: 'parseSetParamResult',
      ),
      const ResponseDefinition(
        id: 'teltonika.save_ok',
        manufacturer: manufacturer,
        pattern: '<SAVE_CFG_RESULT>:1',
        description: 'Configuration successfully persisted',
        parserFunction: 'parseSaveConfigResult',
      ),
    ];
    registry.responses.registerAll(responses);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ENCODERS - USB Configurator text protocol (serial transport)
  // ──────────────────────────────────────────────────────────────────────────

  /// Encodes a set-parameter instruction.
  static String encodeSetParameter(int parameterId, String value) {
    return ':cfg_setparam:$parameterId:$value';
  }

  /// Encodes a save-configuration instruction.
  static String encodeSaveConfiguration() {
    return ':cfg_save';
  }

  /// Encodes a connect instruction.
  static String encodeConnect() => ':cfg_connect';

  /// Encodes a disconnect instruction.
  static String encodeDisconnect() => ':cfg_disconnect';

  /// Encodes a get-configuration instruction.
  static String encodeGetConfiguration() => ':cfg_getcfg';

  /// Encodes a command using the registered [CommandDefinition] template.
  static String? encodeCommand(String commandId, Map<String, dynamic> args) {
    final cmd = UceRegistry().commands.getById(commandId);
    return cmd?.buildCommand(args);
  }

  /// Encodes a command for a registered [ParameterDefinition] value.
  static String? encodeParameterWrite(
      ParameterDefinition parameter, String value) {
    final cmd = UceRegistry().commands.getById(parameter.command);
    return cmd
        ?.buildCommand({'parameterId': parameter.parameterId, 'value': value});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PARSER - USB Configurator text protocol
  // ──────────────────────────────────────────────────────────────────────────

  /// Parses a single line of the USB Configurator text protocol.
  ///
  /// Accepts `:cfg_setparam:<id>:<value>`, `:cfg_save`, `:cfg_connect`,
  /// `:cfg_getcfg`, `:cfg_disconnect`, `<SETPARAM_RESULT>:n`,
  /// `<SAVE_CFG_RESULT>:n`, `<CFG_CONNECT>` and `<CFG_DISCONNECTED>`.
  static TeltonikaUsbConfigCommand? parseConfigCommand(
    String text, {
    int packetNumber = 0,
    String direction = 'host-to-device',
  }) {
    text = _cleanConfigText(text);
    if (text.isEmpty) return null;

    final timestamp = DateTime.fromMillisecondsSinceEpoch(packetNumber * 1000);

    // :cfg_setparam:2005:5026
    if (text.startsWith(':cfg_setparam:')) {
      final parts = text.split(':');
      if (parts.length >= 4) {
        final paramId = int.tryParse(parts[2]);
        final rawValue = parts[3];
        return TeltonikaUsbConfigCommand(
          timestamp: timestamp,
          command: 'set-parameter',
          parameterId: paramId,
          rawValue: rawValue,
          parsedValue: int.tryParse(rawValue) ?? rawValue,
          direction: direction,
          packetReferences: [packetNumber],
          rawText: text,
        );
      }
    }
    // :cfg_save
    if (text.startsWith(':cfg_save')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'save',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // :cfg_connect
    if (text.startsWith(':cfg_connect')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'connect',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // :cfg_getcfg
    if (text.startsWith(':cfg_getcfg')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'get-config',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // :cfg_disconnect
    if (text.startsWith(':cfg_disconnect')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'disconnect',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // <SETPARAM_RESULT>:1
    if (text.startsWith('<SETPARAM_RESULT>:')) {
      final result = text.substring(text.indexOf(':') + 1);
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'set-parameter-result',
        rawValue: result,
        parsedValue: result == '1' ? 'accepted' : 'rejected',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // <SAVE_CFG_RESULT>:1
    if (text.startsWith('<SAVE_CFG_RESULT>:')) {
      final result = text.substring(text.indexOf(':') + 1);
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'save-result',
        rawValue: result,
        parsedValue: result == '1' ? 'saved' : 'failed',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // <CFG_CONNECT>
    if (text.startsWith('<CFG_CONNECT>')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'connect-result',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    // <CFG_DISCONNECTED>
    if (text.startsWith('<CFG_DISCONNECTED>')) {
      return TeltonikaUsbConfigCommand(
        timestamp: timestamp,
        command: 'disconnect-result',
        direction: direction,
        packetReferences: [packetNumber],
        rawText: text,
      );
    }
    return null;
  }

  static String _cleanConfigText(String text) {
    // Remove null bytes and control characters from start/end
    var cleaned = text.replaceAll('\u0000', '');
    // Trim whitespace and control characters (including \r, \n, \t)
    cleaned = cleaned.trim();
    // Also remove any remaining control characters except printable ones
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F]'), '');
    return cleaned;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOG ANALYSIS HELPERS
  // Used by the log capture/diff workflow to map device data (sensors, CAN,
  // configuration) from reconstructed log lines.
  // ──────────────────────────────────────────────────────────────────────────

  /// Discovers device identity from reconstructed log lines.
  static DetectedTeltonikaDevice? discoverDevice(List<String> lines) {
    String? model;
    String? imei;
    String? iccid;
    String? firmware;
    String? intFw;
    String? hw;
    String? bootloader;
    String? modem;
    String? bleMac;
    String? accelerometer;

    final evidence = <String>[];
    double score = 0;

    for (final msg in lines) {
      if (msg.contains('FMB140')) {
        model = 'FMB140';
        evidence.add('Found FMB140 identifier: "$msg"');
        score += 40;
      }
      final imeiMatch =
          RegExp(r'\b(IMEI[=:]?\s*)(\d{15})\b', caseSensitive: false)
              .firstMatch(msg);
      if (imeiMatch != null) {
        imei = imeiMatch.group(2);
        evidence.add('Found IMEI: $imei');
        score += 30;
      }
      final iccidMatch =
          RegExp(r'\b(ICCID[=:]?\s*)(\d{19,20})\b', caseSensitive: false)
              .firstMatch(msg);
      if (iccidMatch != null) {
        iccid = iccidMatch.group(2);
        evidence.add('Found ICCID: $iccid');
        score += 20;
      }
      if (msg.contains('fw version:') || msg.contains('Rev:')) {
        firmware = msg;
        evidence.add('Found firmware string: "$msg"');
        score += 10;
      }
    }

    if (score == 0) return null;

    return DetectedTeltonikaDevice(
      model: model ?? 'FMB140',
      imei: imei,
      iccid: iccid,
      firmware: firmware ?? '04.02.00 Rev:05',
      internalFirmware: intFw,
      hardwareVersion: hw,
      bootloaderVersion: bootloader,
      modemVersion: modem,
      bluetoothMac: bleMac,
      accelerometerModel: accelerometer,
      confidence: min(100.0, score),
      evidence: evidence,
    );
  }

  /// Parses AVL records from `[REC.GEN] Record Content:` blocks in log lines.
  static List<TeltonikaGeneratedAvlRecord> parseAvlRecords(List<String> lines) {
    final records = <TeltonikaGeneratedAvlRecord>[];
    int? currentPriority;
    double? currentLat;
    double? currentLon;
    double? currentAlt;
    double? currentAngle;
    double? currentSpeed;
    double? currentHdop;
    int? currentSats;
    bool? currentFix;
    int? currentEventId;
    int? recordSize;
    final ios = <int, dynamic>{};
    final rawLines = <String>[];
    bool insideRecord = false;

    for (final rawMsg in lines) {
      final msg = _stripReadPrefix(rawMsg).trim();
      if (msg.contains('[REC.GEN] Record Content:')) {
        insideRecord = true;
        ios.clear();
        rawLines.clear();
        rawLines.add(msg);
        continue;
      }

      if (insideRecord) {
        rawLines.add(msg);

        if (msg.contains('Priority:')) {
          currentPriority = int.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('Lat:') || msg.contains('Latitude:')) {
          currentLat = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('Lon:') || msg.contains('Longitude:')) {
          currentLon = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('Alt:') || msg.contains('Altitude:')) {
          currentAlt = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('Angle:')) {
          currentAngle = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('Speed:')) {
          currentSpeed = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('HDOP:')) {
          currentHdop = double.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('SatInUse:')) {
          currentSats = int.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('GPS Fix:')) {
          currentFix = msg.split(':').last.trim() == '1';
        } else if (msg.contains('Event AVL ID:')) {
          currentEventId = int.tryParse(msg.split(':').last.trim());
        } else if (msg.contains('IO ID[')) {
          // Parse IO ID[ 89]: 12
          final match =
              RegExp(r'IO\s+ID\[\s*(\d+)\s*\]\s*:\s*(-?\d+(?:\.\d+)?)')
                  .firstMatch(msg);
          if (match != null) {
            final ioId = int.parse(match.group(1)!);
            final ioVal = double.tryParse(match.group(2)!) ??
                int.tryParse(match.group(2)!) ??
                match.group(2)!;
            ios[ioId] = ioVal;
          }
        } else if (msg.contains('Record Size:')) {
          recordSize = int.tryParse(msg.split(':').last.trim());

          records.add(TeltonikaGeneratedAvlRecord(
            id: 'avl-${records.length + 1}',
            generatedAt: DateTime.now(),
            deviceTimestamp: DateTime.now().millisecondsSinceEpoch,
            priority: currentPriority,
            latitude: currentLat,
            longitude: currentLon,
            altitude: currentAlt,
            angle: currentAngle,
            speedKph: currentSpeed,
            hdop: currentHdop,
            satellites: currentSats,
            gpsFix: currentFix,
            eventAvlId: currentEventId,
            ioElements: Map.from(ios),
            recordSizeBytes: recordSize,
            rawLines: List.from(rawLines),
            packetReferences: [],
          ));
          insideRecord = false;
        }
      }
    }
    return records;
  }

  /// Strips the `READ_ASCII`/`READ_HEX` prefix (incl. leading timestamp/tab) so
  /// the record-content parser can match raw IO patterns on real FMB logs.
  /// Tabs are normalized to spaces because the FMB140 uses mixed `\t` spacing.
  static String _stripReadPrefix(String raw) {
    var s = raw;
    if (s.startsWith('[READ_ASCII] ')) {
      s = s.substring('[READ_ASCII] '.length);
    } else if (s.startsWith('[READ_HEX] ')) {
      s = s.substring('[READ_HEX] '.length);
    }
    // Drop a leading timestamp prefix if still present: `[2026.08.03 ...]\t`
    s = s.replaceFirst(RegExp(r'^\[.*?\]-'), '');
    return s.replaceAll('\t', ' ');
  }

  /// Aggregates observed IO definitions from parsed AVL records, applying the
  /// registered AVL catalog for normalization (unit conversion, names).
  static List<TeltonikaObservedIo> collectObservedIos(
    List<TeltonikaGeneratedAvlRecord> records,
  ) {
    final observed = <int, TeltonikaObservedIo>{};
    final avlRegistry = UceRegistry().avl;

    for (final rec in records) {
      for (final entry in rec.ioElements.entries) {
        final id = entry.key;
        final val = entry.value;

        final def = avlRegistry.getByAvlId(id);
        dynamic convertedVal = val;
        if (def != null) {
          convertedVal = def.convertValue(val);
        }

        observed[id] = TeltonikaObservedIo(
          avlId: id,
          rawValue: val,
          definition: def,
          normalizedKey: def?.normalizedKey,
          normalizedValue: convertedVal,
          rawUnit: def?.rawUnit,
          displayUnit: def?.displayUnit,
          definitionStatus: def != null ? 'official' : 'unknown',
          source: 'record-content',
          packetReferences: rec.packetReferences,
          rawLine: 'IO ID[$id]: $val',
        );
      }
    }
    return observed.values.toList();
  }

  /// Decodes binary AVL frames found inside `[READ_HEX]` chunks of the log.
  ///
  /// Returns a list of [TeltonikaGeneratedAvlRecord] extracted from any valid
  /// codec-0x08 frame found in the hex lines. When decoding fails, the error is
  /// logged at debug level and an empty list is returned.
  static List<TeltonikaGeneratedAvlRecord> decodeBinaryFromHexLines(
      List<String> hexLines) {
    if (hexLines.isEmpty) return const [];
    final result = TeltonikaAvlCodec.decodeHexLines(hexLines);
    return switch (result) {
      TeltonikaDecodeSuccess(records: final records) => records,
      TeltonikaDecodeFailure(:final error, :final offset) => () {
          debugPrint(
              'decodeBinaryFromHexLines: failed to decode: $error at offset $offset');
          return const <TeltonikaGeneratedAvlRecord>[];
        }(),
    };
  }
}
