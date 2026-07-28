import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_controller.dart';
import 'package:tracker_studio/core/bootstrap/bootstrap_models.dart';

void main() {
  BootstrapController controller({
    BootstrapTask? session,
    BootstrapTask? catalog,
    BootstrapTask? api,
    UsbBootstrapProbe? usb,
    Map<BootstrapStep, Duration>? timeouts,
  }) {
    return BootstrapController(
      checkSession: session ?? () async {},
      validateCatalog: catalog ?? () async {},
      validateProfiles: () async {},
      checkApi: api,
      probeUsb: usb ?? () async => SerialBootstrapStatus.disconnected,
      timeouts: timeouts,
    );
  }

  test('complete bootstrap reaches ready', () async {
    final subject = controller();

    await subject.start();

    expect(subject.state.status, BootstrapStatus.ready);
    expect(subject.state.canEnterApp, isTrue);
  });

  test('USB absence does not block bootstrap', () async {
    final subject = controller(
      usb: () async => SerialBootstrapStatus.disconnected,
    );

    await subject.start();

    expect(subject.state.status, BootstrapStatus.ready);
    expect(subject.state.usbStatus, SerialBootstrapStatus.disconnected);
  });

  test('USB discovery Future never blocks bootstrap', () async {
    final never = Completer<SerialBootstrapStatus>();
    final subject = controller(usb: () => never.future);

    await subject.start();

    expect(subject.state.status, BootstrapStatus.ready);
  });

  test('missing catalog creates recoverable degraded state', () async {
    var sessionChecked = false;
    final subject = controller(
      catalog: () async => throw const BootstrapStepException(
        'Arquivo de catalogo nao encontrado.',
      ),
      session: () async => sessionChecked = true,
    );

    await subject.start();

    expect(subject.state.status, BootstrapStatus.degraded);
    expect(subject.state.failedStep, BootstrapStep.suntechCatalog);
    expect(subject.state.error, 'Arquivo de catalogo nao encontrado.');
    expect(subject.state.canEnterApp, isFalse);
    expect(sessionChecked, isTrue);

    subject.continueLimited();
    expect(subject.state.canEnterApp, isTrue);
  });

  test('session exception cannot leave bootstrap running', () async {
    final subject = controller(
      session: () async => throw StateError('storage unavailable'),
    );

    await subject.start();

    expect(subject.state.status, BootstrapStatus.failed);
    expect(subject.state.failedStep, BootstrapStep.session);
    expect(subject.state.isTerminalFailure, isTrue);
  });

  test('step timeout becomes a visible terminal failure', () async {
    final subject = controller(
      session: () => Completer<void>().future,
      timeouts: const {BootstrapStep.session: Duration(milliseconds: 10)},
    );

    await subject.start();

    expect(subject.state.status, BootstrapStatus.failed);
    final result = subject.state.steps.singleWhere(
      (item) => item.step == BootstrapStep.session,
    );
    expect(result.status, BootstrapStepStatus.timedOut);
    expect(subject.state.error, contains('Tempo limite'));
  });

  test('retry starts a new flow after catalog failure', () async {
    var attempts = 0;
    final subject = controller(catalog: () async {
      attempts += 1;
      if (attempts == 1) {
        throw const BootstrapStepException('Catalogo indisponivel.');
      }
    });

    await subject.start();
    expect(subject.state.status, BootstrapStatus.degraded);

    await subject.retry();
    expect(subject.state.status, BootstrapStatus.ready);
    expect(attempts, 2);
  });

  test('API failure enters app in degraded offline mode', () async {
    final subject = controller(
      api: () async => throw StateError('offline'),
    );

    await subject.start();

    expect(subject.state.status, BootstrapStatus.degraded);
    expect(subject.state.limitedModeAccepted, isTrue);
    expect(subject.state.canEnterApp, isTrue);
  });
}
