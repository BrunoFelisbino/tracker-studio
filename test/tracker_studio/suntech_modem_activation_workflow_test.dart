import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_modem_activation_workflow.dart';

void main() {
  test('workflow is versioned and every step carries execution metadata', () {
    expect(SuntechModemActivationWorkflow.version, '1.0.0-source-v31');
    for (final step in SuntechModemActivationWorkflow.steps) {
      expect(step.id, isNotEmpty);
      expect(step.name, isNotEmpty);
      expect(step.command, isNotEmpty);
      expect(step.models, ['ST8210', 'ST8310UM']);
      expect(step.firmwareBounds.keys, containsAll(step.models));
      expect(step.preconditions, isNotEmpty);
      expect(step.expectedResponse, isNotEmpty);
      expect(step.timeout, greaterThan(Duration.zero));
      expect(step.retryCount, 0);
      expect(step.readback, isNotEmpty);
      expect(step.rollback, isNotEmpty);
      expect(step.sourceProvenance, isNotEmpty);
    }
  });

  test('workflow preserves proven detection write and validation ordering', () {
    expect(
      SuntechModemActivationWorkflow.steps.map((step) => step.id),
      [
        'detect_at',
        'detect_ready',
        'detect_version_1416',
        'detect_version_fallback',
        'schema_start',
        'schema_identity',
        'preset_backup',
        'network_prg_part_1',
        'network_prg_part_2',
        'network_readback',
        'validate_status_stt',
        'validate_imsi',
        'validate_iccid',
        'validate_network',
      ],
    );
  });

  test('workflow contains exact proven command wires and RPR gates', () {
    final byId = {
      for (final step in SuntechModemActivationWorkflow.steps) step.id: step,
    };

    expect(byId['detect_ready']?.command, r'AT^$PSTRdy');
    expect(byId['schema_start']?.command, r'AT^$PSTGetJson');
    expect(
        byId['schema_identity']?.command, r'AT^$ReqJsonPk;No;<PACKET_NUMBER>');
    expect(byId['preset_backup']?.command, 'AT^CMD;<ESN>;03;05');
    expect(byId['network_prg_part_1']?.command,
        startsWith('AT^PRG;<ESN>;10;00#<AUTH>;01#<APN>'));
    expect(byId['network_prg_part_1']?.command, endsWith(';63#300'));
    expect(byId['network_prg_part_2']?.command,
        'AT^PRG;<ESN>;10;16#<SCANNING_BAND>;52#00;53#60;14#<AGPS_ENABLED>;15#<AGPS_URL>');
    expect(byId['network_prg_part_1']?.expectedResponse, 'RPR;<ESN>;OK;10');
    expect(byId['network_prg_part_2']?.expectedResponse, 'RPR;<ESN>;OK;10');
    expect(byId['validate_status_stt']?.command, 'AT^CMD;<ESN>;03;01');
    expect(byId['validate_imsi']?.command, 'AT^CMD;<ESN>;01;02');
    expect(byId['validate_iccid']?.command, 'AT^CMD;<ESN>;01;03');
    expect(byId['validate_network']?.command, 'AT^CMD;<ESN>;01;04');
  });

  test('failure stops and rollback does not fabricate a device command', () {
    expect(SuntechModemActivationWorkflow.stopOnRequiredStepFailure, isTrue);
    expect(
        SuntechModemActivationWorkflow.automaticRollbackRepresented, isFalse);
    expect(SuntechModemActivationWorkflow.rollbackPolicy, contains('STOP'));
    expect(SuntechModemActivationWorkflow.rollbackPolicy,
        contains('No source-proven automatic rollback command'));
    expect(SuntechModemActivationWorkflow.requestedButUnprovenOperations,
        contains('dedicated modem activation command'));
    expect(SuntechModemActivationWorkflow.requestedButUnprovenOperations,
        contains('automatic rollback command'));
  });
}
