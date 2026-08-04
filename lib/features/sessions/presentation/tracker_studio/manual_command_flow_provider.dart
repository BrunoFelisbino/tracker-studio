import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'manual_commands_service.dart';

class ManualParameterState {
  final String parameterId;
  final String currentValue;
  final String? previousValue;
  final DateTime? changedAt;
  final bool isDirty;

  ManualParameterState({
    required this.parameterId,
    required this.currentValue,
    this.previousValue,
    this.changedAt,
    this.isDirty = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'parameterId': parameterId,
      'currentValue': currentValue,
      'previousValue': previousValue,
      'changedAt': changedAt?.toIso8601String(),
      'isDirty': isDirty,
    };
  }

  ManualParameterState copyWith({
    String? parameterId,
    String? currentValue,
    String? previousValue,
    DateTime? changedAt,
    bool? isDirty,
  }) {
    return ManualParameterState(
      parameterId: parameterId ?? this.parameterId,
      currentValue: currentValue ?? this.currentValue,
      previousValue: previousValue ?? this.previousValue,
      changedAt: changedAt ?? this.changedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class ManualCommandSession {
  final String sessionId;
  final String model;
  final String deviceId;
  final DateTime createdAt;
  final Map<String, ManualParameterState> parameters;
  final List<String> logs;
  final bool isConfirmed;

  ManualCommandSession({
    required this.sessionId,
    required this.model,
    required this.deviceId,
    required this.createdAt,
    this.parameters = const {},
    this.logs = const [],
    this.isConfirmed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'model': model,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
      'parameters':
          parameters.map((key, value) => MapEntry(key, value.toJson())),
      'logs': logs,
      'isConfirmed': isConfirmed,
    };
  }
}

class ManualCommandFlowState {
  final String? selectedModel;
  final DeviceManualConfig? currentManualConfig;
  final Map<String, ManualParameterState> currentParameters;
  final List<String> logs;
  final bool isLoading;
  final String? error;
  final CommandExecutionResult? lastCommandResult;

  ManualCommandFlowState({
    this.selectedModel,
    this.currentManualConfig,
    this.currentParameters = const {},
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.lastCommandResult,
  });

  factory ManualCommandFlowState.initial() {
    return ManualCommandFlowState(
      selectedModel: null,
      currentManualConfig: null,
      currentParameters: {},
      logs: [],
      isLoading: false,
      error: null,
      lastCommandResult: null,
    );
  }

  ManualCommandFlowState copyWith({
    String? selectedModel,
    DeviceManualConfig? currentManualConfig,
    Map<String, ManualParameterState>? currentParameters,
    List<String>? logs,
    bool? isLoading,
    String? error,
    CommandExecutionResult? lastCommandResult,
  }) {
    return ManualCommandFlowState(
      selectedModel: selectedModel ?? this.selectedModel,
      currentManualConfig: currentManualConfig ?? this.currentManualConfig,
      currentParameters: currentParameters ?? this.currentParameters,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastCommandResult: lastCommandResult ?? this.lastCommandResult,
    );
  }
}

class ManualCommandFlowProvider extends StateNotifier<ManualCommandFlowState> {
  ManualCommandFlowProvider() : super(ManualCommandFlowState.initial());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final supportedModels = ManualCommandFlowService.getSupportedModels();
      state = state.copyWith(
        selectedModel:
            supportedModels.isNotEmpty ? supportedModels.first : null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to initialize: $e',
        isLoading: false,
      );
    }
  }

  Future<void> loadManualConfig(String model) async {
    state = state.copyWith(isLoading: true);
    try {
      final manualConfig =
          await ManualCommandFlowService.getManualConfig(model);
      if (manualConfig == null) {
        throw Exception('No manual configuration found for model: $model');
      }

      final parameters = <String, ManualParameterState>{};
      manualConfig.parameters.forEach((key, param) {
        parameters[key] = ManualParameterState(
          parameterId: key,
          currentValue: param.currentState,
        );
      });

      state = state.copyWith(
        selectedModel: model,
        currentManualConfig: manualConfig,
        currentParameters: parameters,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load manual config: $e',
        isLoading: false,
      );
    }
  }

  void updateParameterValue(String parameterId, String newValue) {
    final parameters =
        Map<String, ManualParameterState>.from(state.currentParameters);

    if (parameters.containsKey(parameterId)) {
      final currentParam = parameters[parameterId]!;

      parameters[parameterId] = ManualParameterState(
        parameterId: parameterId,
        currentValue: newValue,
        previousValue: currentParam.currentValue,
        changedAt: DateTime.now(),
        isDirty: newValue != currentParam.currentValue,
      );
    }

    state = state.copyWith(currentParameters: parameters);
  }

  void addLog(String message) {
    final logs = List<String>.from(state.logs);
    logs.add('${DateTime.now().toIso8601String()}: $message');
    state = state.copyWith(logs: logs);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void resetSession() {
    state = ManualCommandFlowState.initial();
  }
}

final manualCommandFlowProvider =
    StateNotifierProvider<ManualCommandFlowProvider, ManualCommandFlowState>(
  (ref) => ManualCommandFlowProvider(),
);
