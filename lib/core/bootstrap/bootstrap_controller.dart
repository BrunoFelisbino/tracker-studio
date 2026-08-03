import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/sessions/presentation/tracker_studio/installation_profiles.dart';
import '../../features/sessions/presentation/tracker_studio/suntech_newgen_commands.dart';
import 'bootstrap_logger.dart';
import 'bootstrap_models.dart';

typedef BootstrapTask = Future<void> Function();
typedef UsbBootstrapProbe = Future<SerialBootstrapStatus> Function();

class BootstrapController extends ChangeNotifier {
  final BootstrapTask checkSession;
  final BootstrapTask validateCatalog;
  final BootstrapTask validateProfiles;
  final BootstrapTask? checkApi;
  final UsbBootstrapProbe probeUsb;
  final DateTime Function() clock;
  final Map<BootstrapStep, Duration> timeouts;

  BootstrapState _state = const BootstrapState();
  BootstrapState get state => _state;

  Future<void>? _activeRun;
  int _generation = 0;

  BootstrapController({
    required this.checkSession,
    required this.validateCatalog,
    required this.validateProfiles,
    required this.probeUsb,
    this.checkApi,
    DateTime Function()? clock,
    Map<BootstrapStep, Duration>? timeouts,
  })  : clock = clock ?? DateTime.now,
        timeouts = timeouts ??
            const {
              BootstrapStep.preferences: Duration(seconds: 3),
              BootstrapStep.dependencyRegistration: Duration(seconds: 5),
              BootstrapStep.localDatabase: Duration(seconds: 5),
              BootstrapStep.localMigrations: Duration(seconds: 5),
              BootstrapStep.suntechCatalog: Duration(seconds: 5),
              BootstrapStep.installationProfiles: Duration(seconds: 5),
              BootstrapStep.session: Duration(seconds: 8),
              BootstrapStep.api: Duration(seconds: 8),
            };

  Future<void> start() {
    if (_activeRun != null) return _activeRun!;
    final run = _run(++_generation);
    _activeRun = run;
    return run.whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
  }

  Future<void> retry() => start();

  void continueLimited() {
    if (_state.status != BootstrapStatus.degraded) return;
    _state = _state.copyWith(limitedModeAccepted: true);
    notifyListeners();
  }

  Future<void> _run(int generation) async {
    final bootStartedAt = clock();
    _state = const BootstrapState(status: BootstrapStatus.running);
    notifyListeners();
    BootstrapLogger.log(
      'BOOT_START',
      timestamp: bootStartedAt,
      duration: Duration.zero,
    );

    _recordSkipped(BootstrapStep.preferences,
        'Sem preferencias obrigatorias no bootstrap atual.');
    _recordSkipped(BootstrapStep.localDatabase,
        'Banco local aberto sob demanda pelo Tracker Studio.');
    _recordSkipped(BootstrapStep.localMigrations,
        'Nenhuma migration local pendente no bootstrap.');
    _recordSkipped(BootstrapStep.supabase,
        'Cliente Supabase nao faz parte do aplicativo Flutter.');
    _recordSkipped(BootstrapStep.featureFlags,
        'Flags locais sao resolvidas de forma sincrona.');

    _startUsbProbe(generation);

    if (!await _requiredStep(
      BootstrapStep.dependencyRegistration,
      () async {},
    )) {
      return;
    }
    BootstrapStep? recoverableFailedStep;
    String? recoverableError;
    if (!await _recoverableStep(
      BootstrapStep.suntechCatalog,
      validateCatalog,
    )) {
      recoverableFailedStep = BootstrapStep.suntechCatalog;
      recoverableError = _step(BootstrapStep.suntechCatalog)?.error;
    }
    if (!await _recoverableStep(
      BootstrapStep.installationProfiles,
      validateProfiles,
    )) {
      recoverableFailedStep ??= BootstrapStep.installationProfiles;
      recoverableError ??= _step(BootstrapStep.installationProfiles)?.error;
    }

    var optionalFailure = false;
    if (checkApi == null) {
      _recordSkipped(
          BootstrapStep.api, 'API nao e requisito para abrir o aplicativo.');
    } else {
      optionalFailure = !await _optionalStep(BootstrapStep.api, checkApi!);
    }

    if (!await _requiredStep(BootstrapStep.session, checkSession)) return;
    if (generation != _generation) return;

    final degraded = recoverableFailedStep != null || optionalFailure;
    _state = _state.copyWith(
      status: degraded ? BootstrapStatus.degraded : BootstrapStatus.ready,
      clearCurrentStep: true,
      failedStep: recoverableFailedStep,
      clearFailedStep: recoverableFailedStep == null,
      error: recoverableError,
      clearError: recoverableError == null,
      limitedModeAccepted: optionalFailure && recoverableFailedStep == null,
    );
    notifyListeners();
    final bootFinishedAt = clock();
    BootstrapLogger.log(
      'BOOT_COMPLETE',
      timestamp: bootFinishedAt,
      duration: bootFinishedAt.difference(bootStartedAt),
    );
  }

  Future<bool> _requiredStep(BootstrapStep step, BootstrapTask task) async {
    try {
      await _runStep(step, task);
      return true;
    } catch (error) {
      _fail(step, error, degraded: false);
      return false;
    }
  }

  Future<bool> _recoverableStep(BootstrapStep step, BootstrapTask task) async {
    try {
      await _runStep(step, task);
      return true;
    } catch (e, st) {
      BootstrapLogger.log(
        'Recoverable step failed',
        step: step,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> _optionalStep(BootstrapStep step, BootstrapTask task) async {
    try {
      await _runStep(step, task);
      return true;
    } catch (e, st) {
      BootstrapLogger.log(
        'Optional step failed',
        step: step,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _runStep(BootstrapStep step, BootstrapTask task) async {
    final startedAt = clock();
    final running = BootstrapStepResult(
      step: step,
      status: BootstrapStepStatus.running,
      startedAt: startedAt,
    );
    _replaceStep(running);
    _state = _state.copyWith(currentStep: step);
    notifyListeners();
    BootstrapLogger.log('BOOT_STEP_START', step: step, timestamp: startedAt);

    try {
      final timeout = timeouts[step] ?? const Duration(seconds: 5);
      await task().timeout(timeout, onTimeout: () {
        throw BootstrapStepTimeout(step);
      });
      final finishedAt = clock();
      final result = running.finish(
        status: BootstrapStepStatus.success,
        finishedAt: finishedAt,
      );
      _replaceStep(result);
      notifyListeners();
      BootstrapLogger.log(
        'BOOT_STEP_SUCCESS',
        step: step,
        timestamp: finishedAt,
        duration: result.duration,
      );
    } catch (error, stackTrace) {
      final finishedAt = clock();
      final timedOut = error is BootstrapStepTimeout;
      final result = running.finish(
        status: timedOut
            ? BootstrapStepStatus.timedOut
            : BootstrapStepStatus.failed,
        finishedAt: finishedAt,
        error: _safeError(error),
      );
      _replaceStep(result);
      notifyListeners();
      BootstrapLogger.log(
        'BOOT_STEP_FAILURE',
        step: step,
        timestamp: finishedAt,
        duration: result.duration,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _fail(BootstrapStep step, Object error, {required bool degraded}) {
    _state = _state.copyWith(
      status: degraded ? BootstrapStatus.degraded : BootstrapStatus.failed,
      clearCurrentStep: true,
      failedStep: step,
      error: _safeError(error),
      limitedModeAccepted: false,
    );
    notifyListeners();
  }

  void _startUsbProbe(int generation) {
    final startedAt = clock();
    _replaceStep(BootstrapStepResult(
      step: BootstrapStep.usbDiscovery,
      status: BootstrapStepStatus.running,
      startedAt: startedAt,
    ));
    BootstrapLogger.log(
      'BOOT_STEP_START',
      step: BootstrapStep.usbDiscovery,
      timestamp: startedAt,
      duration: Duration.zero,
    );
    unawaited(() async {
      try {
        final status = await probeUsb().timeout(const Duration(seconds: 2));
        if (generation != _generation) return;
        final finishedAt = clock();
        final running = _step(BootstrapStep.usbDiscovery)!;
        _replaceStep(running.finish(
          status: BootstrapStepStatus.success,
          finishedAt: finishedAt,
        ));
        _state = _state.copyWith(usbStatus: status);
        notifyListeners();
        BootstrapLogger.log(
          'BOOT_STEP_SUCCESS',
          step: BootstrapStep.usbDiscovery,
          timestamp: finishedAt,
          duration: finishedAt.difference(startedAt),
        );
      } catch (error, stackTrace) {
        if (generation != _generation) return;
        final finishedAt = clock();
        final running = _step(BootstrapStep.usbDiscovery)!;
        _replaceStep(running.finish(
          status: error is TimeoutException
              ? BootstrapStepStatus.timedOut
              : BootstrapStepStatus.failed,
          finishedAt: finishedAt,
          error: _safeError(error),
        ));
        _state = _state.copyWith(usbStatus: _usbErrorStatus(error));
        notifyListeners();
        BootstrapLogger.log(
          'BOOT_STEP_FAILURE',
          step: BootstrapStep.usbDiscovery,
          timestamp: finishedAt,
          duration: finishedAt.difference(startedAt),
          error: error,
          stackTrace: stackTrace,
        );
      }
    }());
  }

  void _recordSkipped(BootstrapStep step, String reason) {
    final now = clock();
    _replaceStep(BootstrapStepResult(
      step: step,
      status: BootstrapStepStatus.skipped,
      startedAt: now,
      finishedAt: now,
      duration: Duration.zero,
      error: reason,
    ));
    BootstrapLogger.log(
      'BOOT_STEP_SUCCESS',
      step: step,
      timestamp: now,
      duration: Duration.zero,
    );
  }

  BootstrapStepResult? _step(BootstrapStep step) {
    for (final result in _state.steps) {
      if (result.step == step) return result;
    }
    return null;
  }

  void _replaceStep(BootstrapStepResult result) {
    final steps = [..._state.steps];
    final index = steps.indexWhere((item) => item.step == result.step);
    if (index == -1) {
      steps.add(result);
    } else {
      steps[index] = result;
    }
    _state = _state.copyWith(steps: List.unmodifiable(steps));
  }

  String _safeError(Object error) {
    if (error is BootstrapStepException) return error.safeMessage;
    return 'Nao foi possivel concluir esta etapa (${error.runtimeType}).';
  }

  SerialBootstrapStatus _usbErrorStatus(Object error) {
    final lower = '$error'.toLowerCase();
    if (lower.contains('permission') || lower.contains('permissao')) {
      return SerialBootstrapStatus.permissionDenied;
    }
    return SerialBootstrapStatus.error;
  }
}

final bootstrapProvider = ChangeNotifierProvider<BootstrapController>((ref) {
  final auth = ref.read(authProvider.notifier);
  return BootstrapController(
    checkSession: auth.checkAuth,
    validateCatalog: () async {
      final required = {
        'newgen_status',
        'newgen_preset',
        'newgen_imsi',
        'newgen_iccid',
        'newgen_network_state',
      };
      final available =
          SuntechNewGenCommands.all.map((command) => command.id).toSet();
      if (!available.containsAll(required)) {
        throw const BootstrapStepException(
          'Catalogo Suntech obrigatorio incompleto.',
        );
      }
    },
    validateProfiles: () async {
      const profiles = [
        InstallationProfiles.carStandard,
        InstallationProfiles.motorcycleStandard,
        InstallationProfiles.custom,
      ];
      if (profiles.isEmpty) {
        throw const BootstrapStepException(
          'Perfis de instalacao nao encontrados.',
        );
      }
    },
    probeUsb: () async {
      if (kIsWeb) return SerialBootstrapStatus.unavailable;
      final ports = SerialPort.availablePorts;
      return ports.isEmpty
          ? SerialBootstrapStatus.disconnected
          : SerialBootstrapStatus.available;
    },
  );
});
