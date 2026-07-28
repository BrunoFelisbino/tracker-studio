import 'suntech_command_family.dart';

class SuntechFirmwareBounds {
  final String min;
  final String max;

  const SuntechFirmwareBounds({required this.min, required this.max});
}

class SuntechModemActivationStep {
  final String id;
  final String name;
  final String command;
  final SuntechCommandFamily family;
  final List<String> models;
  final Map<String, SuntechFirmwareBounds> firmwareBounds;
  final List<String> preconditions;
  final String expectedResponse;
  final Duration timeout;
  final int retryCount;
  final String readback;
  final String rollback;
  final String sourceProvenance;

  const SuntechModemActivationStep({
    required this.id,
    required this.name,
    required this.command,
    required this.family,
    required this.models,
    required this.firmwareBounds,
    required this.preconditions,
    required this.expectedResponse,
    required this.timeout,
    required this.retryCount,
    required this.readback,
    required this.rollback,
    required this.sourceProvenance,
  });
}

class SuntechModemActivationWorkflow {
  static const version = '1.0.0-source-v31';
  static const family = SuntechCommandFamily.newGenSt8210St8310;
  static const models = ['ST8210', 'ST8310UM'];
  static const firmwareBounds = {
    'ST8210': SuntechFirmwareBounds(min: '1.0.14', max: '1.0.14'),
    'ST8310UM': SuntechFirmwareBounds(min: '1.0.13', max: '1.0.13'),
  };

  static const stopOnRequiredStepFailure = true;
  static const automaticRollbackRepresented = false;
  static const rollbackPolicy =
      'STOP; retain the pre-write PRESET backup for reviewed restoration. '
      'No source-proven automatic rollback command is represented.';
  static const requestedButUnprovenOperations = [
    'dedicated modem activation command',
    'carrier or SIM provisioning command',
    'automatic rollback command',
  ];

  static const steps = <SuntechModemActivationStep>[
    SuntechModemActivationStep(
      id: 'detect_at',
      name: 'Validate serial port',
      command: 'AT',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['serial port open'],
      expectedResponse: 'standalone OK; echo alone is not accepted',
      timeout: Duration(seconds: 2),
      retryCount: 0,
      readback: 'none',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'suntech_handshake_engine.dart:121-126,407-410',
    ),
    SuntechModemActivationStep(
      id: 'detect_ready',
      name: 'Probe ST8 readiness',
      command: r'AT^$PSTRdy',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['serial port open'],
      expectedResponse:
          'ST8 response or model evidence; echo alone is not accepted',
      timeout: Duration(milliseconds: 1800),
      retryCount: 0,
      readback: 'none',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'tracker_configurator/protocol.py:294-305',
    ),
    SuntechModemActivationStep(
      id: 'detect_version_1416',
      name: 'Probe ST8 version with selector',
      command: r'AT^$PSTVer;1416',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['serial port open'],
      expectedResponse: r'$PST;Ver;<MODEL>[;<FIRMWARE>]',
      timeout: Duration(milliseconds: 5500),
      retryCount: 0,
      readback: 'none',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'tracker_configurator/protocol.py:296-315',
    ),
    SuntechModemActivationStep(
      id: 'detect_version_fallback',
      name: 'Probe ST8 version fallback',
      command: r'AT^$PSTVer',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['selector version probe did not identify the model'],
      expectedResponse: r'$PST;Ver;<MODEL>[;<FIRMWARE>]',
      timeout: Duration(seconds: 3),
      retryCount: 0,
      readback: 'none',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'tracker_configurator/protocol.py:296-315',
    ),
    SuntechModemActivationStep(
      id: 'schema_start',
      name: 'Request schema packet count',
      command: r'AT^$PSTGetJson',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['ST8 model identified'],
      expectedResponse: 'TotalGrpNo;<COUNT>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: r'AT^$ReqJsonPk;No;<PACKET_NUMBER>',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'tracker_configurator/protocol.py:367-400',
    ),
    SuntechModemActivationStep(
      id: 'schema_identity',
      name: 'Collect schema and identity packets',
      command: r'AT^$ReqJsonPk;No;<PACKET_NUMBER>',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: [
        'TotalGrpNo parsed',
        'request every packet from 1 through COUNT'
      ],
      expectedResponse:
          'JSON object, optionally ETX-terminated; identity S/I/P/V',
      timeout: Duration(seconds: 15),
      retryCount: 0,
      readback: 'all packet numbers through TotalGrpNo',
      rollback: 'not represented; read-only step',
      sourceProvenance: 'tracker_configurator/protocol.py:367-449',
    ),
    SuntechModemActivationStep(
      id: 'preset_backup',
      name: 'Read PRESET before writing',
      command: 'AT^CMD;<ESN>;03;05',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['model and ESN identified'],
      expectedResponse: 'RES;<ESN>;03;05;10;<NETWORK_PAIRS>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'persist immutable PRESET network backup before PRG',
      rollback:
          'backup is retained; no automatic rollback command is source-proven',
      sourceProvenance:
          'ST8210_1.0.14.json; ST8310UM_1.0.13.json; gui.py:2526-2545',
    ),
    SuntechModemActivationStep(
      id: 'network_prg_part_1',
      name: 'Write network PRG part 1',
      command:
          'AT^PRG;<ESN>;10;00#<AUTH>;01#<APN>;02#<USER>;03#<PASSWORD>;04#;05#<SERVER>;06#<PORT>;07#<SERVER_TYPE>;08#<BACKUP_SERVER>;09#<BACKUP_PORT>;10#<BACKUP_TYPE>;11#0;12#0;13#00;60#10;70#01;71#600;61#00;62#500;63#300',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: [
        'PRESET backup persisted',
        'network values validated',
        'ESN identified'
      ],
      expectedResponse: 'RPR;<ESN>;OK;10',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'exact RPR confirmation before part 2',
      rollback:
          'STOP on missing RPR; retain PRESET backup; no automatic command',
      sourceProvenance: 'tracker_configurator/protocol.py:1063-1120',
    ),
    SuntechModemActivationStep(
      id: 'network_prg_part_2',
      name: 'Write network PRG part 2',
      command:
          'AT^PRG;<ESN>;10;16#<SCANNING_BAND>;52#00;53#60;14#<AGPS_ENABLED>;15#<AGPS_URL>',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['part 1 returned exact RPR confirmation'],
      expectedResponse: 'RPR;<ESN>;OK;10',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'exact RPR confirmation, followed by PRESET comparison',
      rollback:
          'STOP on missing RPR; retain PRESET backup; no automatic command',
      sourceProvenance: 'tracker_configurator/protocol.py:1109-1126',
    ),
    SuntechModemActivationStep(
      id: 'network_readback',
      name: 'Verify network with PRESET',
      command: 'AT^CMD;<ESN>;03;05',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['both PRG parts returned exact RPR confirmation'],
      expectedResponse: 'all requested network fields compare unchanged',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'parse first section 10 and compare every requested field',
      rollback:
          'STOP on mismatch; retain PRESET backup; reviewed restoration only',
      sourceProvenance:
          'tracker_configurator/gui.py:2558-2575; protocol.py:940-1006',
    ),
    SuntechModemActivationStep(
      id: 'validate_status_stt',
      name: 'Validate status/STT',
      command: 'AT^CMD;<ESN>;03;01',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['network readback verified'],
      expectedResponse: 'RES;STT;<...>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'parse STT status fields',
      rollback: 'not represented; read-only validation',
      sourceProvenance:
          'tracker_configurator/protocol.py:582-583,738-841,1038-1061',
    ),
    SuntechModemActivationStep(
      id: 'validate_imsi',
      name: 'Validate IMSI',
      command: 'AT^CMD;<ESN>;01;02',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['status/STT requested'],
      expectedResponse: 'RES;<ESN>;01;02;<IMSI>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'identity value must not be 0, 255, or NotReady',
      rollback: 'not represented; read-only validation',
      sourceProvenance:
          'tracker_configurator/protocol.py:594-595,1008-1021,1044-1061',
    ),
    SuntechModemActivationStep(
      id: 'validate_iccid',
      name: 'Validate ICCID',
      command: 'AT^CMD;<ESN>;01;03',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['IMSI requested'],
      expectedResponse: 'RES;<ESN>;01;03;<ICCID>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'identity value must not be 0, 255, or NotReady',
      rollback: 'not represented; read-only validation',
      sourceProvenance:
          'tracker_configurator/protocol.py:597-598,1008-1021,1044-1061',
    ),
    SuntechModemActivationStep(
      id: 'validate_network',
      name: 'Validate network registration',
      command: 'AT^CMD;<ESN>;01;04',
      family: family,
      models: models,
      firmwareBounds: firmwareBounds,
      preconditions: ['ICCID requested'],
      expectedResponse: 'RES;<ESN>;01;04;<STATE>',
      timeout: Duration(seconds: 12),
      retryCount: 0,
      readback: 'state must not be empty, 0, 255, or NotReady',
      rollback: 'not represented; read-only validation',
      sourceProvenance: 'tracker_configurator/protocol.py:600-602,1023-1061',
    ),
  ];

  const SuntechModemActivationWorkflow._();
}
