enum LockFlowState {
  unavailable,
  available,
  sent,
  accepted,
  confirmed,
  failed,
  inconclusive,
}

enum LockOperation { block, unblock }

class LockCommandSemantics {
  static const enable1 = 'Enable1';
  static const enable1Code = '0401';
  static const disable1 = 'Disable1';
  static const disable1Code = '0402';

  const LockCommandSemantics._();
}

class LockFlow {
  final LockOperation operation;
  final LockFlowState state;
  final String evidence;

  const LockFlow._({
    required this.operation,
    required this.state,
    this.evidence = '',
  });

  const LockFlow.unavailable({required LockOperation operation})
      : this._(operation: operation, state: LockFlowState.unavailable);

  const LockFlow.available({required LockOperation operation})
      : this._(operation: operation, state: LockFlowState.available);

  String get commandName => operation == LockOperation.block
      ? LockCommandSemantics.enable1
      : LockCommandSemantics.disable1;

  String get commandCode => operation == LockOperation.block
      ? LockCommandSemantics.enable1Code
      : LockCommandSemantics.disable1Code;

  bool get isConfirmed => state == LockFlowState.confirmed;

  LockFlow markSent() {
    _requireState(LockFlowState.available);
    return LockFlow._(operation: operation, state: LockFlowState.sent);
  }

  LockFlow recordAcknowledgement(String response) {
    _requireState(LockFlowState.sent);
    final acknowledged =
        RegExp(r'(^|;)RPR(?:;|$)|(^|;)OK(?:;|$)', caseSensitive: false)
            .hasMatch(response.trim());
    return LockFlow._(
      operation: operation,
      state: acknowledged ? LockFlowState.accepted : LockFlowState.inconclusive,
      evidence: response,
    );
  }

  LockFlow recordOutputReadback({required bool? output1Active}) {
    if (state != LockFlowState.sent && state != LockFlowState.accepted) {
      throw StateError('Output readback is not valid from ${state.name}.');
    }
    if (output1Active == null) {
      return LockFlow._(
        operation: operation,
        state: LockFlowState.inconclusive,
        evidence: 'Output 1 was not available in readback.',
      );
    }
    final expectedActive = operation == LockOperation.block;
    return LockFlow._(
      operation: operation,
      state: output1Active == expectedActive
          ? LockFlowState.confirmed
          : LockFlowState.failed,
      evidence: 'Output 1 readback: ${output1Active ? 'ON' : 'OFF'}',
    );
  }

  LockFlow markFailed(String error) => LockFlow._(
        operation: operation,
        state: LockFlowState.failed,
        evidence: error,
      );

  LockFlow markInconclusive(String reason) => LockFlow._(
        operation: operation,
        state: LockFlowState.inconclusive,
        evidence: reason,
      );

  void _requireState(LockFlowState expected) {
    if (state != expected) {
      throw StateError(
          '${expected.name} state required; current: ${state.name}.');
    }
  }
}
