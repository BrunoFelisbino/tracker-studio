import 'package:flutter/foundation.dart';

import 'suntech_legacy_commands.dart';

enum BenchExecutionState {
  notStarted,
  running,
  awaitingAck,
  awaitingReadback,
  awaitingRestart,
  awaitingFinalReadback,
  passed,
  failed,
  inconclusive,
  timedOut,
  interrupted,
}

class BenchSnapshot {
  final String? presetBefore;
  final String? presetAfter;
  final Map<String, String> deviceStateBefore;
  final Map<String, String> deviceStateAfter;
  final DateTime? timestamp;

  BenchSnapshot({
    this.presetBefore,
    this.presetAfter,
    this.deviceStateBefore = const {},
    this.deviceStateAfter = const {},
    this.timestamp,
  });
}

class BenchStepResult {
  final String commandSent;
  final String? rawResponse;
  final String? ack;
  final String? readback;
  final bool ackReceived;
  final bool readbackMatched;
  final String? error;
  final DateTime timestamp;
  final Duration? duration;

  BenchStepResult({
    required this.commandSent,
    this.rawResponse,
    this.ack,
    this.readback,
    this.ackReceived = false,
    this.readbackMatched = false,
    this.error,
    required this.timestamp,
    this.duration,
  });
}

class BenchExecution {
  final String id;
  final String commandId;
  final String commandLabel;
  final String commandRaw;
  final String model;
  final String? firmware;
  final String? esn;
  BenchExecutionState state;
  BenchSnapshot? snapshotBefore;
  BenchSnapshot? snapshotAfter;
  final List<BenchStepResult> steps;
  String? restartReadback;
  String? finalReadback;
  final bool rollbackAvailable;
  final String? rollbackCommand;
  final List<String> observations;
  final DateTime createdAt;
  DateTime? completedAt;
  Duration? totalDuration;

  BenchExecution({
    String? id,
    required this.commandId,
    required this.commandLabel,
    required this.commandRaw,
    required this.model,
    this.firmware,
    this.esn,
    this.state = BenchExecutionState.notStarted,
    this.snapshotBefore,
    this.snapshotAfter,
    List<BenchStepResult>? steps,
    this.restartReadback,
    this.finalReadback,
    this.rollbackAvailable = false,
    this.rollbackCommand,
    List<String>? observations,
    DateTime? createdAt,
    this.completedAt,
    this.totalDuration,
  })  : id = id ??
            DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        steps = steps ?? [],
        observations = observations ?? [],
        createdAt = createdAt ?? DateTime.now();
}

class BenchExecutionEngine {
  final List<BenchExecution> _executions = [];

  List<BenchExecution> get executions =>
      List.unmodifiable(_executions);

  BenchExecution createExecution({
    required String commandId,
    required String commandLabel,
    required String commandRaw,
    required String model,
    String? firmware,
    String? esn,
    bool rollbackAvailable = false,
    String? rollbackCommand,
  }) {
    final execution = BenchExecution(
      commandId: commandId,
      commandLabel: commandLabel,
      commandRaw: commandRaw,
      model: model,
      firmware: firmware,
      esn: esn,
      rollbackAvailable: rollbackAvailable,
      rollbackCommand: rollbackCommand,
    );
    _executions.add(execution);
    return execution;
  }

  void recordSnapshotBefore(String executionId, BenchSnapshot snapshot) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.snapshotBefore = snapshot;
  }

  void recordAck(String executionId, String ack, {String? rawResponse}) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.steps.add(
      BenchStepResult(
        commandSent: execution.commandRaw,
        rawResponse: rawResponse,
        ack: ack,
        ackReceived: true,
        timestamp: DateTime.now(),
      ),
    );
    execution.state = BenchExecutionState.awaitingReadback;
  }

  void recordReadback(String executionId, String readback,
      {bool matched = true}) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.steps.add(
      BenchStepResult(
        commandSent: execution.commandRaw,
        readback: readback,
        readbackMatched: matched,
        timestamp: DateTime.now(),
      ),
    );
  }

  void recordSnapshotAfter(String executionId, BenchSnapshot snapshot) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.snapshotAfter = snapshot;
  }

  void recordRestart(String executionId, String restartReadback) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.restartReadback = restartReadback;
    execution.state = BenchExecutionState.awaitingFinalReadback;
  }

  void recordFinalReadback(String executionId, String finalReadback) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.finalReadback = finalReadback;
  }

  void addObservation(String executionId, String observation) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.observations.add(observation);
  }

  void markPassed(String executionId) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.state = BenchExecutionState.passed;
    execution.completedAt = DateTime.now();
    execution.totalDuration =
        execution.completedAt!.difference(execution.createdAt);
  }

  void markFailed(String executionId, String reason) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.state = BenchExecutionState.failed;
    execution.observations.add('FAILED: $reason');
    execution.completedAt = DateTime.now();
    execution.totalDuration =
        execution.completedAt!.difference(execution.createdAt);
  }

  void markTimedOut(String executionId) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.state = BenchExecutionState.timedOut;
    execution.completedAt = DateTime.now();
    execution.totalDuration =
        execution.completedAt!.difference(execution.createdAt);
  }

  void markInterrupted(String executionId) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.state = BenchExecutionState.interrupted;
    execution.completedAt = DateTime.now();
    execution.totalDuration =
        execution.completedAt!.difference(execution.createdAt);
  }

  void transition(String executionId, BenchExecutionState newState) {
    final execution = findById(executionId);
    if (execution == null) return;
    execution.state = newState;
  }

  BenchExecution? findById(String executionId) {
    try {
      return _executions.firstWhere((e) => e.id == executionId);
    } catch (e) {
      debugPrint('BenchExecutionRegistry: findById failed: $e');
      return null;
    }
  }
}

class BenchRiskPolicy {
  static bool requiresConfirmation(String riskClassification) {
    return riskClassification == 'destructive' ||
        riskClassification == 'action';
  }

  static bool requiresFeatureFlag(String riskClassification) {
    return riskClassification == 'destructive';
  }

  static String describeImpact(SuntechCommandDefinition command) {
    if (command.critical) {
      return 'Critical command: ${command.label}. May affect device operation.';
    }
    if (command.requiresBackup) {
      return 'Destructive command: ${command.label}. Requires backup before execution.';
    }
    if (command.requiresEsn) {
      return 'Device-specific command: ${command.label}. Requires ESN targeting.';
    }
    return 'Standard command: ${command.label}.';
  }

  static bool canRollback(SuntechCommandDefinition command) {
    return command.requiresBackup;
  }
}
