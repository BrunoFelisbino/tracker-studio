import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/bench_execution_engine.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_legacy_commands.dart';

void main() {
  group('BenchExecutionEngine', () {
    late BenchExecutionEngine engine;

    setUp(() {
      engine = BenchExecutionEngine();
    });

    test('starts with empty executions', () {
      expect(engine.executions, isEmpty);
    });

    test('creates execution with generated id', () {
      final exec = engine.createExecution(
        commandId: 'newgen_keep_alive',
        commandLabel: 'Keep Alive',
        commandRaw: 'AT^PRG;ESN;10;60#0A',
        model: 'ST8310UM',
        firmware: '1.0.13',
        esn: 'TEST123',
      );
      expect(exec.id, isNotEmpty);
      expect(exec.commandId, 'newgen_keep_alive');
      expect(exec.model, 'ST8310UM');
      expect(exec.state, BenchExecutionState.notStarted);
      expect(engine.executions, hasLength(1));
    });

    test('records snapshot before', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      final snapshot = BenchSnapshot(
        presetBefore: 'RES;TEST',
        timestamp: DateTime.now(),
      );
      engine.recordSnapshotBefore(exec.id, snapshot);
      expect(engine.findById(exec.id)!.snapshotBefore, isNotNull);
    });

    test('records ack', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.recordAck(exec.id, 'RPR', rawResponse: 'AT\nRPR');
      final updated = engine.findById(exec.id)!;
      expect(updated.steps, hasLength(1));
      expect(updated.steps.first.ack, 'RPR');
      expect(updated.steps.first.ackReceived, isTrue);
    });

    test('records readback', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.recordReadback(exec.id, 'RES;PRESET', matched: true);
      final updated = engine.findById(exec.id)!;
      expect(updated.steps, hasLength(1));
      expect(updated.steps.first.readback, 'RES;PRESET');
      expect(updated.steps.first.readbackMatched, isTrue);
    });

    test('transitions through states', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.transition(exec.id, BenchExecutionState.running);
      expect(engine.findById(exec.id)!.state, BenchExecutionState.running);
      engine.transition(exec.id, BenchExecutionState.awaitingAck);
      expect(engine.findById(exec.id)!.state, BenchExecutionState.awaitingAck);
    });

    test('marks passed', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.markPassed(exec.id);
      final updated = engine.findById(exec.id)!;
      expect(updated.state, BenchExecutionState.passed);
      expect(updated.completedAt, isNotNull);
    });

    test('marks failed with reason', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.markFailed(exec.id, 'Readback mismatch');
      final updated = engine.findById(exec.id)!;
      expect(updated.state, BenchExecutionState.failed);
      expect(updated.observations, contains('FAILED: Readback mismatch'));
    });

    test('marks timed out', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.markTimedOut(exec.id);
      expect(engine.findById(exec.id)!.state, BenchExecutionState.timedOut);
    });

    test('adds observations', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
      );
      engine.addObservation(exec.id, 'Device responded slowly');
      engine.addObservation(exec.id, 'No errors detected');
      expect(engine.findById(exec.id)!.observations, hasLength(2));
    });

    test('returns null for unknown id', () {
      expect(engine.findById('nonexistent'), isNull);
    });

    test('records rollback info', () {
      final exec = engine.createExecution(
        commandId: 'test',
        commandLabel: 'Test',
        commandRaw: 'AT',
        model: 'ST8310UM',
        rollbackAvailable: true,
        rollbackCommand: 'AT^PRG;ESN;10;60#00',
      );
      expect(exec.rollbackAvailable, isTrue);
      expect(exec.rollbackCommand, 'AT^PRG;ESN;10;60#00');
    });
  });

  group('BenchRiskPolicy', () {
    test('requires confirmation for destructive commands', () {
      const cmd = SuntechCommandDefinition(
        id: 'test',
        label: 'Test',
        commandTemplate: 'AT',
        requiresEsn: false,
        critical: true,
        requiresBackup: true,
        notes: 'test',
        riskClassification: 'destructive',
      );
      expect(BenchRiskPolicy.requiresConfirmation(cmd.riskClassification), isTrue);
    });

    test('requires confirmation for action commands', () {
      expect(BenchRiskPolicy.requiresConfirmation('action'), isTrue);
    });

    test('does not require confirmation for config commands', () {
      expect(BenchRiskPolicy.requiresConfirmation('config'), isFalse);
    });

    test('does not require confirmation for read commands', () {
      expect(BenchRiskPolicy.requiresConfirmation('read'), isFalse);
    });

    test('requires feature flag for destructive commands', () {
      expect(BenchRiskPolicy.requiresFeatureFlag('destructive'), isTrue);
    });

    test('does not require feature flag for action commands', () {
      expect(BenchRiskPolicy.requiresFeatureFlag('action'), isFalse);
    });

    test('describes impact for command', () {
      const cmd = SuntechCommandDefinition(
        id: 'test',
        label: 'Test Command',
        commandTemplate: 'AT',
        requiresEsn: false,
        critical: true,
        requiresBackup: true,
        notes: 'test',
        riskClassification: 'destructive',
      );
      final impact = BenchRiskPolicy.describeImpact(cmd);
      expect(impact, isNotEmpty);
    });
  });
}
