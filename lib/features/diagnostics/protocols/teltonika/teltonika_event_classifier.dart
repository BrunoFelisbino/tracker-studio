import '../../core/diagnostic_types.dart';
import 'teltonika_line_normalizer.dart';

/// Dicionário de interpretação das categorias Teltonika.
class TeltonikaCategoryInfo {
  final DiagnosticCategory category;
  final String label;
  final String icon;
  final String description;

  const TeltonikaCategoryInfo({
    required this.category,
    required this.label,
    required this.icon,
    required this.description,
  });
}

const teltonikaCategoryInfo = <String, TeltonikaCategoryInfo>{
  'NETWORK': TeltonikaCategoryInfo(
    category: DiagnosticCategory.network,
    label: 'Rede e socket',
    icon: 'Icons.wifi',
    description: 'Conexão TCP, resolução de domínio e estado do socket.',
  ),
  'REC.SEND.1': TeltonikaCategoryInfo(
    category: DiagnosticCategory.avl,
    label: 'Envio de registros AVL',
    icon: 'Icons.cloud_upload',
    description: 'Transmissão de registros AVL ao servidor.',
  ),
  'REC.SEND.2': TeltonikaCategoryInfo(
    category: DiagnosticCategory.avl,
    label: 'Envio de registros AVL (2)',
    icon: 'Icons.cloud_upload',
    description: 'Transmissão de registros AVL ao servidor secundário.',
  ),
  'REC.GEN': TeltonikaCategoryInfo(
    category: DiagnosticCategory.avl,
    label: 'Geração de registro AVL',
    icon: 'Icons.note_add',
    description: 'Criação de registro AVL na memória do equipamento.',
  ),
  'TRACK': TeltonikaCategoryInfo(
    category: DiagnosticCategory.movement,
    label: 'Rastreamento periódico',
    icon: 'Icons.directions_car',
    description: 'Ação de registro periódico por tempo ou distância.',
  ),
  'GPS.API': TeltonikaCategoryInfo(
    category: DiagnosticCategory.gps,
    label: 'GPS e qualidade da posição',
    icon: 'Icons.gps_fixed',
    description: 'Fixação, HDOP, satélites e qualidade da posição.',
  ),
  'TSYNC': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Sincronização de horário',
    icon: 'Icons.schedule',
    description: 'Sincronização de relógio com o servidor.',
  ),
  'TSYNC.SWITCH': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Troca de sincronização de horário',
    icon: 'Icons.update',
    description: 'Mudança da fonte de sincronização de horário.',
  ),
  'LiPo': TeltonikaCategoryInfo(
    category: DiagnosticCategory.battery,
    label: 'Alimentação e bateria',
    icon: 'Icons.battery_charging_full',
    description: 'Tensão externa e bateria interna LiPo.',
  ),
  'LVCAN': TeltonikaCategoryInfo(
    category: DiagnosticCategory.can,
    label: 'Comunicação CAN',
    icon: 'Icons.connected_tv',
    description: 'Módulo CAN J1939/CANopen e comunicação com a central.',
  ),
  'AXL.CLBR': TeltonikaCategoryInfo(
    category: DiagnosticCategory.accelerometer,
    label: 'Acelerômetro e calibração',
    icon: 'Icons.vibration',
    description: 'Calibração do acelerômetro e detecção de movimento.',
  ),
  'MODEM.ACTION': TeltonikaCategoryInfo(
    category: DiagnosticCategory.modem,
    label: 'Ação do modem',
    icon: 'Icons.settings_cell',
    description: 'Operações executadas no modem GSM.',
  ),
  'MODEM.STATUS': TeltonikaCategoryInfo(
    category: DiagnosticCategory.modem,
    label: 'Estado do modem',
    icon: 'Icons.signal_cellular_alt',
    description: 'Registro na rede móvel, SIM e tecnologia.',
  ),
  'ATCMD': TeltonikaCategoryInfo(
    category: DiagnosticCategory.modem,
    label: 'Comandos AT executados',
    icon: 'Icons.terminal',
    description: 'Comandos AT executados internamente no modem.',
  ),
  'UNPLUG': TeltonikaCategoryInfo(
    category: DiagnosticCategory.power,
    label: 'Alimentação externa removida',
    icon: 'Icons.power_off',
    description: 'Remoção da alimentação externa.',
  ),
  'SLEEP': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Modo de repouso',
    icon: 'Icons.bedtime',
    description: 'Transição de modo de operação/repouso.',
  ),
  'OVERSPD': TeltonikaCategoryInfo(
    category: DiagnosticCategory.movement,
    label: 'Excesso de velocidade',
    icon: 'Icons.speed',
    description: 'Velocidade acima do limite configurado.',
  ),
  'WD.FUNC': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Watchdog',
    icon: 'Icons.security',
    description: 'Eventos do watchdog do sistema.',
  ),
  'MTHL': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Health check',
    icon: 'Icons.monitor_heart',
    description: 'Mensagens de manutenção do sistema.',
  ),
  'SCH': TeltonikaCategoryInfo(
    category: DiagnosticCategory.system,
    label: 'Agendamento',
    icon: 'Icons.event',
    description: 'Tarefas agendadas do firmware.',
  ),
  'FC.CALC': TeltonikaCategoryInfo(
    category: DiagnosticCategory.movement,
    label: 'Cálculo de consumo',
    icon: 'Icons.local_gas_station',
    description: 'Cálculo de consumo de combustível.',
  ),
  'REC.BLK': TeltonikaCategoryInfo(
    category: DiagnosticCategory.avl,
    label: 'Bloco de registros',
    icon: 'Icons.inventory_2',
    description: 'Bloco de registros AVL na memória.',
  ),
  'REC.NEW': TeltonikaCategoryInfo(
    category: DiagnosticCategory.avl,
    label: 'Novo registro AVL',
    icon: 'Icons.add_box',
    description: 'Novo registro AVL criado.',
  ),
  'GPRS': TeltonikaCategoryInfo(
    category: DiagnosticCategory.network,
    label: 'Sessão GPRS',
    icon: 'Icons.data_usage',
    description: 'Estado da sessão de dados GPRS.',
  ),
  'ACC': TeltonikaCategoryInfo(
    category: DiagnosticCategory.ignition,
    label: 'Ignição',
    icon: 'Icons.key',
    description: 'Detecção de ignição (ACC).',
  ),
  'UNKNOWN': TeltonikaCategoryInfo(
    category: DiagnosticCategory.unknown,
    label: 'Desconhecido',
    icon: 'Icons.help_outline',
    description: 'Evento sem categoria reconhecida.',
  ),
};

class TeltonikaEventClassifier {
  const TeltonikaEventClassifier();

  NormalizedDiagnosticEvent classify(
    NormalizedTeltonikaLine line,
    int index, {
    required SupportedManufacturer manufacturer,
    Map<String, dynamic>? manufacturerSpecific,
  }) {
    final info = teltonikaCategoryInfo[line.category] ??
        const TeltonikaCategoryInfo(
          category: DiagnosticCategory.unknown,
          label: 'Desconhecido',
          icon: 'Icons.help_outline',
          description: 'Evento sem categoria reconhecida.',
        );
    final parsed = _ParsedContent.parse(
      category: line.category,
      content: line.content,
    );
    final severity = _severityFor(line.category, parsed);
    final eventName = _eventNameFor(line.category, parsed);
    final title = _titleFor(line.category, parsed);
    final details = _detailsFor(line.category, parsed);
    final value = parsed.value;
    final unit = parsed.unit;

    return NormalizedDiagnosticEvent(
      id: 'tl-${index + 1}',
      timestamp: line.appTimestamp != null
          ? DateTime.tryParse(line.appTimestamp!)
          : null,
      deviceTimestamp: line.deviceTimestamp,
      severity: severity,
      category: info.category,
      source: line.category,
      event: eventName,
      title: title,
      message: line.content,
      value: value,
      unit: unit,
      details: details,
      raw: NormalizedEventRaw(
        original: line.original,
        hex: line.rawHex,
        line: line.line,
      ),
      manufacturer: manufacturer,
      manufacturerSpecific: manufacturerSpecific ?? const {},
    );
  }

  DiagnosticSeverity _severityFor(String category, _ParsedContent parsed) {
    switch (category) {
      case 'GPS.API':
        if (parsed.content.contains('HDOP')) {
          final hdop = parsed.hdop;
          if (hdop != null && hdop > 10) return DiagnosticSeverity.critical;
          if (hdop != null && hdop > 5) return DiagnosticSeverity.warning;
        }
        if (parsed.content.contains('fail') ||
            parsed.content.contains('error')) {
          return DiagnosticSeverity.error;
        }
        return DiagnosticSeverity.info;
      case 'UNPLUG':
        return DiagnosticSeverity.critical;
      case 'OVERSPD':
        return DiagnosticSeverity.warning;
      case 'LiPo':
        if (parsed.content.toLowerCase().contains('batt')) {
          if (parsed.value != null && parsed.value! < 3.3) {
            return DiagnosticSeverity.error;
          }
        }
        return DiagnosticSeverity.info;
      case 'NETWORK':
        if (parsed.content.contains('Socket Opened') ||
            parsed.content.contains('connected')) {
          return DiagnosticSeverity.success;
        }
        if (parsed.content.contains('fail') ||
            parsed.content.contains('error') ||
            parsed.content.contains('timeout')) {
          return DiagnosticSeverity.error;
        }
        return DiagnosticSeverity.info;
      case 'REC.SEND.1':
      case 'REC.SEND.2':
        if (parsed.content.contains('OK') || parsed.content.contains('ok')) {
          return DiagnosticSeverity.success;
        }
        if (parsed.content.contains('fail') ||
            parsed.content.contains('error')) {
          return DiagnosticSeverity.error;
        }
        return DiagnosticSeverity.info;
      case 'REC.GEN':
        return DiagnosticSeverity.info;
      case 'MODEM.STATUS':
        if (parsed.content.contains('fail') ||
            parsed.content.contains('error')) {
          return DiagnosticSeverity.error;
        }
        if (parsed.content.contains('PIN') && parsed.content.contains('OK')) {
          return DiagnosticSeverity.success;
        }
        return DiagnosticSeverity.info;
      default:
        if (parsed.content.contains('fail') ||
            parsed.content.contains('error')) {
          return DiagnosticSeverity.error;
        }
        return DiagnosticSeverity.info;
    }
  }

  String _eventNameFor(String category, _ParsedContent parsed) {
    switch (category) {
      case 'NETWORK':
        if (parsed.content.contains('Socket Opened')) return 'socket_opened';
        if (parsed.content.contains('connecting') ||
            parsed.content.contains('Connecting')) {
          return 'connecting';
        }
        if (parsed.content.contains('Domain:') ||
            parsed.content.contains('IP:')) {
          return 'server_resolved';
        }
        return 'network_event';
      case 'REC.SEND.1':
      case 'REC.SEND.2':
        if (parsed.content.contains('imei send OK')) return 'imei_sent';
        if (parsed.content.contains('answer')) return 'server_answered';
        if (parsed.content.contains('record') ||
            parsed.content.contains('records')) {
          return 'avl_sent';
        }
        return 'record_send';
      case 'REC.GEN':
        return 'record_generated';
      case 'GPS.API':
        if (parsed.hdop != null) return 'hdop';
        if (parsed.latitude != null) return 'position';
        if (parsed.content.contains('fail')) return 'gps_failure';
        return 'gps_event';
      case 'LiPo':
        return 'power_state';
      case 'ATCMD':
        if (parsed.content.startsWith('<<')) return 'at_command_sent';
        return 'at_command';
      default:
        return '${category.toLowerCase()}_event';
    }
  }

  String _titleFor(String category, _ParsedContent parsed) {
    final info = teltonikaCategoryInfo[category];
    switch (category) {
      case 'NETWORK':
        if (parsed.content.contains('Socket Opened')) {
          return 'Socket TCP aberto';
        }
        if (parsed.content.contains('Connecting')) {
          return 'Conectando ao servidor';
        }
        if (parsed.content.contains('Domain:')) {
          return 'Servidor resolvido';
        }
        return info?.label ?? 'Rede';
      case 'REC.SEND.1':
      case 'REC.SEND.2':
        if (parsed.content.contains('imei send OK')) {
          return 'IMEI enviado ao servidor';
        }
        if (parsed.content.contains('answer')) {
          return 'Servidor respondeu';
        }
        return info?.label ?? 'Envio AVL';
      case 'REC.GEN':
        return 'Registro AVL criado';
      case 'GPS.API':
        if (parsed.hdop != null) {
          final label = _hdopLabel(parsed.hdop!);
          return 'HDOP $label';
        }
        if (parsed.latitude != null) return 'Posição GPS';
        if (parsed.content.contains('fail')) return 'Falha no GPS';
        return info?.label ?? 'GPS';
      case 'LiPo':
        return 'Alimentação / bateria';
      case 'UNPLUG':
        return 'Alimentação externa removida';
      case 'OVERSPD':
        return 'Excesso de velocidade';
      case 'ATCMD':
        return 'Comando AT';
      default:
        return info?.label ?? 'Evento ${category.toUpperCase()}';
    }
  }

  String _hdopLabel(double hdop) {
    if (hdop <= 1) return 'excelente';
    if (hdop <= 2) return 'muito bom';
    if (hdop <= 5) return 'aceitável';
    if (hdop <= 10) return 'ruim';
    return 'crítico';
  }

  Map<String, dynamic> _detailsFor(String category, _ParsedContent parsed) {
    return {
      if (parsed.ip != null) 'ip': parsed.ip,
      if (parsed.port != null) 'port': parsed.port,
      if (parsed.protocol != null) 'protocol': parsed.protocol,
      if (parsed.domain != null) 'domain': parsed.domain,
      if (parsed.timeoutSeconds != null)
        'timeoutSeconds': parsed.timeoutSeconds,
      if (parsed.recordAddress != null) 'recordAddress': parsed.recordAddress,
      if (parsed.latitude != null) 'latitude': parsed.latitude,
      if (parsed.longitude != null) 'longitude': parsed.longitude,
      if (parsed.altitude != null) 'altitude': parsed.altitude,
      if (parsed.hdop != null) 'hdop': parsed.hdop,
      if (parsed.satellites != null) 'satellites': parsed.satellites,
      if (parsed.speed != null) 'speed': parsed.speed,
      if (parsed.fixStatus != null) 'fixStatus': parsed.fixStatus,
      if (parsed.imei != null) 'imei': parsed.imei,
      if (parsed.command != null) 'command': parsed.command,
      if (parsed.firmware != null) 'firmware': parsed.firmware,
      if (parsed.bootloader != null) 'bootloader': parsed.bootloader,
      if (parsed.ble != null) 'ble': parsed.ble,
      if (parsed.nand != null) 'nand': parsed.nand,
      if (parsed.accelerometer != null) 'accelerometer': parsed.accelerometer,
      if (parsed.iccid != null) 'iccid': parsed.iccid,
      if (parsed.phone != null) 'phone': parsed.phone,
      if (parsed.simLock != null) 'simLock': parsed.simLock,
      if (parsed.operatorName != null) 'operator': parsed.operatorName,
      if (parsed.mcc != null) 'mcc': parsed.mcc,
      if (parsed.mnc != null) 'mnc': parsed.mnc,
      if (parsed.roaming != null) 'roaming': parsed.roaming,
      if (parsed.networkReg != null) 'networkReg': parsed.networkReg,
    };
  }

  static String? _readAsciiValue(String label, String text) {
    final m = RegExp('$label[=:]\\s*([^\\s,;]+)', caseSensitive: false)
        .firstMatch(text);
    return m?.group(1);
  }
}

class _ParsedContent {
  final String category;
  final String content;
  final num? value;
  final String? unit;
  final String? ip;
  final int? port;
  final String? protocol;
  final String? domain;
  final int? timeoutSeconds;
  final String? recordAddress;
  final double? latitude;
  final double? longitude;
  final double? hdop;
  final double? altitude;
  final int? satellites;
  final double? speed;
  final int? fixStatus;
  final String? imei;
  final String? command;
  final String? firmware;
  final String? bootloader;
  final String? ble;
  final String? nand;
  final String? accelerometer;
  final String? iccid;
  final String? phone;
  final String? simLock;
  final String? operatorName;
  final String? mcc;
  final String? mnc;
  final String? roaming;
  final String? networkReg;

  const _ParsedContent({
    required this.category,
    required this.content,
    this.value,
    this.unit,
    this.ip,
    this.port,
    this.protocol,
    this.domain,
    this.timeoutSeconds,
    this.recordAddress,
    this.latitude,
    this.longitude,
    this.hdop,
    this.altitude,
    this.satellites,
    this.speed,
    this.fixStatus,
    this.imei,
    this.command,
    this.firmware,
    this.bootloader,
    this.ble,
    this.nand,
    this.accelerometer,
    this.iccid,
    this.phone,
    this.simLock,
    this.operatorName,
    this.mcc,
    this.mnc,
    this.roaming,
    this.networkReg,
  });

  factory _ParsedContent.parse(
      {required String category, required String content}) {
    final text = content;

    // Rede: "Connecting to 192.0.2.10:5027@TCP" (exemplo: IP reservado para documentação)
    final netMatch =
        RegExp(r'(\d{1,3}(?:\.\d{1,3}){3}):(\d+)(?:@(\w+))?').firstMatch(text);
    String? ip;
    int? port;
    String? protocol;
    if (netMatch != null) {
      ip = netMatch.group(1);
      port = int.tryParse(netMatch.group(2) ?? '');
      protocol = netMatch.group(3);
    }

    // "Domain: device1.example.com, IP: 192.0.2.10" (exemplo: IP reservado para documentação)
    final domainMatch = RegExp(r'Domain:\s*([^\s,]+)').firstMatch(text);
    final domain = domainMatch?.group(1);

    // "waiting 120 sec for imei answer"
    final timeoutMatch = RegExp(r'waiting\s+(\d+)\s+sec').firstMatch(text);
    final timeout =
        timeoutMatch != null ? int.tryParse(timeoutMatch.group(1) ?? '') : null;

    // "record saved @ 0x0005C7A5"
    final recordMatch = RegExp(r'@\s*(0x[0-9A-Fa-f]+)').firstMatch(text);
    final recordAddress = recordMatch?.group(1);

    // "Lat: -16.7118, Lon: -49.2542" / "Latitude: x, Longitude: y"
    double? lat;
    double? lon;
    final coordMatch = RegExp(
      r'(?:Lat(?:itude)?[=:]\s*)(-?\d+\.\d+).*?(?:Lon(?:gitude)?[=:]\s*)(-?\d+\.\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (coordMatch != null) {
      lat = double.tryParse(coordMatch.group(1)!);
      lon = double.tryParse(coordMatch.group(2)!);
    }

    // "HDOP: 62.12" / "hdop=62.12"
    final hdopMatch =
        RegExp(r'HDOP[=:]\s*(\d+(?:\.\d+)?)', caseSensitive: false)
            .firstMatch(text);
    final hdop =
        hdopMatch != null ? double.tryParse(hdopMatch.group(1)!) : null;

    // "Alt: 851.5" / "Altitude: 851.5"
    final altMatch = RegExp(r'(?:Alt(?:itude)?[=:]\s*)(-?\d+(?:\.\d+)?)',
            caseSensitive: false)
        .firstMatch(text);
    final altitude =
        altMatch != null ? double.tryParse(altMatch.group(1)!) : null;

    // "Sat: 0" / "sat=0"
    final satMatch = RegExp(r'(?:Sat(?:s)?[=:]\s*)(\d+)', caseSensitive: false)
        .firstMatch(text);
    final satellites =
        satMatch != null ? int.tryParse(satMatch.group(1)!) : null;

    // "Speed: 0.0" / "Spd: 12.5" / "Spd: 1km/h" / "0km/h"
    final speedMatch =
        RegExp(r'(?:Speed|Spd|SPD)[=:]\s*(\d+(?:\.\d+)?)', caseSensitive: false)
            .firstMatch(text);
    final speedKmh = RegExp(r'(\d+(?:\.\d+)?)\s*km/h', caseSensitive: false)
        .firstMatch(text);
    final speed = speedMatch != null
        ? double.tryParse(speedMatch.group(1)!)
        : speedKmh != null
            ? double.tryParse(speedKmh.group(1)!)
            : null;

    // "fix status: 1" / "FixStatus: 0"
    final fixMatch =
        RegExp(r'(?:Fix\s*status|FixStatus)[=:]\s*(\d)', caseSensitive: false)
            .firstMatch(text);
    final fixStatus =
        fixMatch != null ? int.tryParse(fixMatch.group(1)!) : null;

    // "IMEI: 869842..." / "imei send OK"
    final imeiMatch =
        RegExp(r'IMEI[=:]\s*(\d{15})', caseSensitive: false).firstMatch(text);
    final imei = imeiMatch?.group(1);

    // Detalhes de hardware/modem: "FW Ver: AXN_5.1.9", "BL ver: 1.10",
    // "BLE: 1", "NAND: 1", "AXL: 2/LIS2DH", "ICCID: 89550000000000000000",
    // "Phone: +5500000000000", "SIM lock: OFF", "Operadora: TIM",
    // "MCC: 724", "MNC: 02", "Roaming: OFF", "Registro de rede: 38497".
    final firmware =
        TeltonikaEventClassifier._readAsciiValue(r'FW\s*Ver', text);
    final bootloader =
        TeltonikaEventClassifier._readAsciiValue(r'BL\s*ver', text);
    final ble = TeltonikaEventClassifier._readAsciiValue(r'BLE', text);
    final nand = TeltonikaEventClassifier._readAsciiValue(r'NAND', text);
    final accelerometer =
        TeltonikaEventClassifier._readAsciiValue(r'AXL', text);
    final iccid = TeltonikaEventClassifier._readAsciiValue(r'ICCID', text);
    final phone = TeltonikaEventClassifier._readAsciiValue(r'Phone', text);
    final simLock =
        TeltonikaEventClassifier._readAsciiValue(r'SIM\s*lock', text);
    final operatorName =
        TeltonikaEventClassifier._readAsciiValue(r'Operadora', text);
    final mcc = TeltonikaEventClassifier._readAsciiValue(r'MCC', text);
    final mnc = TeltonikaEventClassifier._readAsciiValue(r'MNC', text);
    final roaming = TeltonikaEventClassifier._readAsciiValue(r'Roaming', text);
    final networkReg =
        TeltonikaEventClassifier._readAsciiValue(r'Registro\s*de\s*rede', text);

    // "AT+CMGL=4" / "AT+EPINC?"
    final commandMatch = RegExp(r'(AT\+[\w=?]+)').firstMatch(text);
    final command = commandMatch?.group(1);

    // Tensão/corrente: "12368mV" -> 12.368 V, "3953mV" -> 3.953 V,
    // "93mA" -> 0.093 A.
    num? value;
    String? unit;
    final ampMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(mA|A)\b', caseSensitive: false)
        .firstMatch(text);
    if (ampMatch != null) {
      final raw = double.tryParse(ampMatch.group(1) ?? '');
      final ampUnit = ampMatch.group(2)!.toLowerCase();
      if (raw != null) {
        value = ampUnit == 'ma' ? raw / 1000 : raw;
        unit = 'A';
      }
    } else {
      final voltMatch =
          RegExp(r'(\d+)\s*(mV|V)\b', caseSensitive: false).firstMatch(text);
      if (voltMatch != null) {
        final raw = int.tryParse(voltMatch.group(1) ?? '');
        final voltUnit = voltMatch.group(2)!.toLowerCase();
        if (raw != null) {
          value = voltUnit == 'mv' ? raw / 1000 : raw.toDouble();
          unit = 'V';
        }
      }
    }

    return _ParsedContent(
      category: category,
      content: text,
      value: value,
      unit: unit,
      ip: ip,
      port: port,
      protocol: protocol,
      domain: domain,
      timeoutSeconds: timeout,
      recordAddress: recordAddress,
      latitude: lat,
      longitude: lon,
      hdop: hdop,
      altitude: altitude,
      satellites: satellites,
      speed: speed,
      fixStatus: fixStatus,
      imei: imei,
      command: command,
      firmware: firmware,
      bootloader: bootloader,
      ble: ble,
      nand: nand,
      accelerometer: accelerometer,
      iccid: iccid,
      phone: phone,
      simLock: simLock,
      operatorName: operatorName,
      mcc: mcc,
      mnc: mnc,
      roaming: roaming,
      networkReg: networkReg,
    );
  }
}
