enum BootstrapStatus { idle, running, ready, degraded, failed }

enum BootstrapStepStatus {
  pending,
  running,
  success,
  failed,
  timedOut,
  skipped,
}

enum BootstrapStep {
  preferences,
  dependencyRegistration,
  localDatabase,
  localMigrations,
  suntechCatalog,
  installationProfiles,
  session,
  api,
  supabase,
  featureFlags,
  usbDiscovery,
}

enum SerialBootstrapStatus {
  disconnected,
  available,
  unavailable,
  permissionDenied,
  error,
}

extension BootstrapStepLabel on BootstrapStep {
  String get label => switch (this) {
        BootstrapStep.preferences => 'Preferencias locais',
        BootstrapStep.dependencyRegistration => 'Servicos locais',
        BootstrapStep.localDatabase => 'Banco local',
        BootstrapStep.localMigrations => 'Migrations locais',
        BootstrapStep.suntechCatalog => 'Catalogo Suntech',
        BootstrapStep.installationProfiles => 'Perfis de instalacao',
        BootstrapStep.session => 'Sessao local',
        BootstrapStep.api => 'API',
        BootstrapStep.supabase => 'Supabase',
        BootstrapStep.featureFlags => 'Feature flags',
        BootstrapStep.usbDiscovery => 'USB/serial',
      };

  String get loadingMessage => switch (this) {
        BootstrapStep.suntechCatalog =>
          'Carregando catalogo de equipamentos...',
        BootstrapStep.session => 'Verificando sessao...',
        BootstrapStep.usbDiscovery => 'Verificando servico USB...',
        _ => 'Inicializando servicos locais...',
      };
}

class BootstrapStepResult {
  final BootstrapStep step;
  final BootstrapStepStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final Duration? duration;
  final String? error;

  const BootstrapStepResult({
    required this.step,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.duration,
    this.error,
  });

  BootstrapStepResult finish({
    required BootstrapStepStatus status,
    required DateTime finishedAt,
    String? error,
  }) {
    return BootstrapStepResult(
      step: step,
      status: status,
      startedAt: startedAt,
      finishedAt: finishedAt,
      duration: finishedAt.difference(startedAt),
      error: error,
    );
  }
}

class BootstrapState {
  final BootstrapStatus status;
  final BootstrapStep? currentStep;
  final List<BootstrapStepResult> steps;
  final String? error;
  final BootstrapStep? failedStep;
  final bool limitedModeAccepted;
  final SerialBootstrapStatus usbStatus;

  const BootstrapState({
    this.status = BootstrapStatus.idle,
    this.currentStep,
    this.steps = const [],
    this.error,
    this.failedStep,
    this.limitedModeAccepted = false,
    this.usbStatus = SerialBootstrapStatus.disconnected,
  });

  bool get canEnterApp =>
      status == BootstrapStatus.ready ||
      (status == BootstrapStatus.degraded && limitedModeAccepted);

  bool get isTerminalFailure =>
      status == BootstrapStatus.failed ||
      (status == BootstrapStatus.degraded && !limitedModeAccepted);

  BootstrapState copyWith({
    BootstrapStatus? status,
    BootstrapStep? currentStep,
    bool clearCurrentStep = false,
    List<BootstrapStepResult>? steps,
    String? error,
    bool clearError = false,
    BootstrapStep? failedStep,
    bool clearFailedStep = false,
    bool? limitedModeAccepted,
    SerialBootstrapStatus? usbStatus,
  }) {
    return BootstrapState(
      status: status ?? this.status,
      currentStep: clearCurrentStep ? null : currentStep ?? this.currentStep,
      steps: steps ?? this.steps,
      error: clearError ? null : error ?? this.error,
      failedStep: clearFailedStep ? null : failedStep ?? this.failedStep,
      limitedModeAccepted: limitedModeAccepted ?? this.limitedModeAccepted,
      usbStatus: usbStatus ?? this.usbStatus,
    );
  }
}

class BootstrapStepException implements Exception {
  final String safeMessage;

  const BootstrapStepException(this.safeMessage);

  @override
  String toString() => safeMessage;
}

class BootstrapStepTimeout extends BootstrapStepException {
  final BootstrapStep step;

  BootstrapStepTimeout(this.step)
      : super('Tempo limite excedido em ${step.label}.');
}
