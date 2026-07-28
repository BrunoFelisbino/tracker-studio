import 'suntech_legacy_commands.dart';

const _profileRoot = 'tracker_configurator/profiles';

class SuntechNewGenCommands {
  static const at = SuntechCommandDefinition(
    id: 'newgen_at',
    label: 'AT básico',
    commandTemplate: 'AT',
    requiresEsn: false,
    critical: false,
    requiresBackup: false,
    notes: 'Valida somente a porta serial.',
    sourceProvenance: 'tracker_configurator/protocol.py:281-305',
    namespace: 'serial',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
  );

  static const status = SuntechCommandDefinition(
    id: 'newgen_status',
    label: 'StatusReq',
    commandTemplate: 'AT^CMD;<ESN>;03;01',
    requiresEsn: true,
    critical: false,
    requiresBackup: false,
    notes: 'Status ST8; a resposta observada usa RES;STT.',
    code: '0301',
    sourceProvenance:
        'ST8210_1.0.14.json; ST8310UM_1.0.13.json; protocol.py:582-583,738-841',
    namespace: 'ST8',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
    responseParser: 'suntech-st8-status-v1',
  );

  static const preset = SuntechCommandDefinition(
    id: 'newgen_preset',
    label: 'Preset',
    commandTemplate: 'AT^CMD;<ESN>;03;05',
    requiresEsn: true,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura da configuração ST8.',
    code: '0305',
    sourceProvenance:
        'ST8210_1.0.14.json; ST8310UM_1.0.13.json; protocol.py:591-592,940-1006',
    namespace: 'ST8',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
    responseParser: 'suntech-st8210-network-section-v3',
  );

  static const imsi = SuntechCommandDefinition(
    id: 'newgen_imsi',
    label: 'ReqIMSI',
    commandTemplate: 'AT^CMD;<ESN>;01;02',
    requiresEsn: true,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura do IMSI do modem.',
    code: '0102',
    sourceProvenance:
        'ST8210_1.0.14.json; ST8310UM_1.0.13.json; protocol.py:594-595,1008-1021',
    namespace: 'ST8',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
    responseParser: 'suntech-st8-identity-v1',
  );

  static const iccid = SuntechCommandDefinition(
    id: 'newgen_iccid',
    label: 'ReqICCID',
    commandTemplate: 'AT^CMD;<ESN>;01;03',
    requiresEsn: true,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura do ICCID do SIM.',
    code: '0103',
    sourceProvenance:
        'ST8210_1.0.14.json; ST8310UM_1.0.13.json; protocol.py:597-598,1008-1021',
    namespace: 'ST8',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
    responseParser: 'suntech-st8-identity-v1',
  );

  static const networkState = SuntechCommandDefinition(
    id: 'newgen_network_state',
    label: 'ReqConNtw',
    commandTemplate: 'AT^CMD;<ESN>;01;04',
    requiresEsn: true,
    critical: false,
    requiresBackup: false,
    notes: 'Leitura do registro de rede.',
    code: '0104',
    sourceProvenance:
        'ST8210_1.0.14.json; ST8310UM_1.0.13.json; protocol.py:600-602,1023-1036',
    namespace: 'ST8',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
    responseParser: 'suntech-st8-network-v1',
  );

  static const networkPrg = SuntechCommandDefinition(
    id: 'newgen_network_prg',
    label: 'PRG Rede (duas partes)',
    commandTemplate: 'AT^PRG;<ESN>;10;<PARAMETROS_HOMOLOGADOS>',
    requiresEsn: true,
    critical: true,
    requiresBackup: true,
    notes: 'A fonte exige duas escritas, RPR em ambas e PRESET de readback.',
    sourceProvenance:
        'tracker_configurator/protocol.py:1063-1126; gui.py:2499-2577',
    namespace: 'ST8-PRG',
    supportedModels: ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'],
  );

  static const all = [
    at,
    status,
    preset,
    imsi,
    iccid,
    networkState,
    networkPrg
  ];
}

Map<String, SuntechCommandDefinition>? newGenCommandCatalogForModel(
  String? model,
) {
  final normalized = model?.trim().toUpperCase();
  if (normalized == 'ST8210') {
    return _buildProfileCatalog(
      model: 'ST8210',
      firmware: '1.0.14',
      profile: 'ST8210_1.0.14.json',
      entries: _st8210Entries,
    );
  }
  if (const {'ST8310', 'ST8310U', 'ST8310UM'}.contains(normalized)) {
    return _buildProfileCatalog(
      model: 'ST8310UM',
      firmware: '1.0.13',
      profile: 'ST8310UM_1.0.13.json',
      entries: _st8310UmEntries,
    );
  }
  return null;
}

Map<String, SuntechCommandDefinition> _buildProfileCatalog({
  required String model,
  required String firmware,
  required String profile,
  required List<String> entries,
}) {
  final catalog = <String, SuntechCommandDefinition>{};
  for (final raw in entries) {
    final parts = raw.split(';');
    if (parts.length != 5 || !RegExp(r'^\d{4}$').hasMatch(parts[4])) {
      throw StateError('Invalid bundled Suntech command metadata: $raw');
    }
    final name = parts[1];
    final code = parts[4];
    catalog[name] = SuntechCommandDefinition(
      id: 'newgen_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      label: name,
      commandTemplate:
          'AT^CMD;<ESN>;${code.substring(0, 2)};${code.substring(2)}',
      requiresEsn: true,
      critical: _conservativelyCritical(name),
      requiresBackup: false,
      notes: 'Entrada literal do perfil histórico obrigatório.',
      catalogIndex: parts[0],
      parameterLength: parts[2],
      mode: parts[3],
      code: code,
      sourceProvenance: '$_profileRoot/$profile',
      namespace: 'ST8',
      supportedModels: [model],
      firmwareMin: firmware,
      firmwareMax: firmware,
      riskClassification: 'unverified',
      responseParser: _parserFor(name),
    );
  }
  if (catalog.length != entries.length) {
    throw StateError('Duplicate command names in bundled profile $profile.');
  }
  return Map.unmodifiable(catalog);
}

bool _conservativelyCritical(String name) {
  final normalized = name.toLowerCase();
  return const [
    'reset',
    'reboot',
    'erase',
    'init',
    'set',
    'activate',
    'deactivation',
    'disable',
    'outputpulse',
    'calibration',
  ].any(normalized.contains);
}

String _parserFor(String name) => switch (name) {
      'Preset' => 'suntech-st8210-network-section-v3',
      'StatusReq' => 'suntech-st8-status-v1',
      'ReqIMSI' || 'ReqICCID' => 'suntech-st8-identity-v1',
      'ReqConNtw' => 'suntech-st8-network-v1',
      _ => 'unverified',
    };

const _st8210Entries = [
  '0;Preset;0;2;0305',
  '1;PresetP;1;1;0306',
  '2;ReqConMntSvr;0;2;0101',
  '3;ReqIMSI;0;2;0102',
  '4;ReqICCID;0;2;0103',
  '5;ReqConNtw;0;2;0104',
  '6;SetGoogleMap;96;0;0202',
  '7;ReqGoogleMap;0;2;0203',
  '8;StatusReq;0;2;0301',
  '9;Reset;0;2;0302',
  '10;Reboot;0;2;0303',
  '11;ReqVer;1;1;0304',
  '12;Enable1;0;2;0401',
  '13;Disable1;0;2;0402',
  '14;EraseAll;0;2;0502',
  '15;SetOdometer;10;0;0503',
  '16;InitMsgNo;0;2;0504',
  '17;ReqOverspeedThres;0;2;0311',
  '18;SetHMeter;7;0;0505',
  '19;InitCircleGeo;0;2;0506',
  '20;InitAllPolygonGeo;0;2;0517',
  '21;Request Server Lock;0;2;0109',
  '22;ReqSttAssignmap;0;2;0507',
  '23;ReqAltAssignmap;0;2;0508',
  '24;Encoding Type;1;0;0700',
  '25;Encoding Key;16;0;0701',
  '26;Set Geofence Area Jamming;1;1;0725',
  '27;Get Geofence Area Jamming;0;2;0726',
  '28;Set buzzer pulse off;1;0;0738',
  '29;Get buzzer pulse off;0;2;0739',
  '30;Get anti theft status;0;2;0737',
  '31;ReqPolyInfo;2;1;0515',
  '32;Set immobilizer always pulsed;1;0;0749',
  '33;Set Immob. Cycle Time;9;0;0422',
  '34;Req Immob. Cycle;0;2;0423',
  '35;Set immob speed limit;3;0;0750',
  '36;InitIDPolygonGeo;5;0;0518',
  '37;InitIDCircularGeo;5;0;0519',
  '38;ReqCircInfo;3;0;0520',
  '39;ActivateAntiTheft;1;1;0524',
  '40;Req Circular ID;2;0;0526',
  '41;ReqDPAParam;0;2;0580',
  '42;ReqDPADefault;0;2;0581',
  '43;Start DPA Calibration;0;2;0582',
  '44;Stop DPA Calibration;0;2;0583',
  '45;InitParkOdometer;0;2;0529',
  '46;OutputPulse2;0;2;0453',
  '47;OutputPulse3;0;2;0454',
  '48;ResetP;0;2;0307',
  '49;Overtime Work Activation;0;2;0801',
  '50;Overtime Work Deactivation;0;2;0802',
];

const _st8310UmEntries = [
  '0;Preset;0;2;0305',
  '1;PresetP;1;1;0306',
  '2;ReqConMntSvr;0;2;0101',
  '3;ReqIMSI;0;2;0102',
  '4;ReqICCID;0;2;0103',
  '5;ReqConNtw;0;2;0104',
  '6;SetGoogleMap;96;0;0202',
  '7;ReqGoogleMap;0;2;0203',
  '8;StatusReq;0;2;0301',
  '9;Reset;0;2;0302',
  '10;Reboot;0;2;0303',
  '11;ReqVer;1;1;0304',
  '12;Enable1;0;2;0401',
  '13;Disable1;0;2;0402',
  '14;EraseAll;0;2;0502',
  '15;SetOdometer;4000000000;0;0503',
  '16;InitMsgNo;0;2;0504',
  '17;ReqOverspeedThres;0;2;0311',
  '18;SetHMeter;9999999;0;0505',
  '19;InitCircleGeo;0;2;0506',
  '20;InitAllPolygonGeo;0;2;0517',
  '21;Request Server Lock;0;2;0109',
  '22;ReqSttAssignmap;0;2;0507',
  '23;ReqAltAssignmap;0;2;0508',
  '24;Encoding Type;1;0;0700',
  '25;Encoding Key;16;0;0701',
  '26;Set Geofence Area Jamming;1;1;0725',
  '27;Get Geofence Area Jamming;0;2;0726',
  '28;Set buzzer pulse off;1;0;0738',
  '29;Get buzzer pulse off;0;2;0739',
  '30;Get anti theft status;0;2;0737',
  '31;ReqPolyInfo;2;1;0515',
  '32;Set immobilizer always pulsed;1;0;0749',
  '33;Set Immob. Cycle Time;9;0;0422',
  '34;Req Immob. Cycle;0;2;0423',
  '35;Set immob speed limit;3;0;0750',
  '36;InitIDPolygonGeo;5;0;0518',
  '37;InitIDCircularGeo;5;0;0519',
  '38;ReqCircInfo;3;0;0520',
  '39;ActivateAntiTheft;1;1;0524',
  '40;Req Circular ID;2;0;0526',
  '41;ReqDPAParam;0;2;0580',
  '42;ReqDPADefault;0;2;0581',
  '43;Start DPA Calibration;0;2;0582',
  '44;Stop DPA Calibration;0;2;0583',
  '45;InitParkOdometer;0;2;0529',
  '46;OutputPulse2;0;2;0453',
  '47;OutputPulse3;0;2;0454',
];
