import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_network_commands.dart';

void main() {
  group('Teltonika configuration flow', () {
    test('always activates USB, writes parameters, saves and disconnects', () {
      final plan = buildTeltonikaNetworkCommands(
        apn: 'internet.example',
        server: 'tracker.example.com',
        port: 6000,
      );

      expect(plan.steps.first.type,
          TeltonikaConfigurationStepType.activateUsb);
      expect(plan.steps.last.type,
          TeltonikaConfigurationStepType.disconnectUsb);
      expect(
        plan.steps[plan.steps.length - 2].type,
        TeltonikaConfigurationStepType.saveConfiguration,
      );
      expect(
        plan.steps
            .where((step) =>
                step.type == TeltonikaConfigurationStepType.writeParameter)
            .isNotEmpty,
        isTrue,
      );
      expect(plan.commands, plan.steps.map((step) => step.command).toList());
    });

    test('preview keeps the technician aware of the required order', () {
      final plan = buildTeltonikaConfigSequence(
        parameters: const [(2001, 'internet.example')],
      );

      expect(plan.preview, contains('1. ATIVAR USB CONFIGURATOR'));
      expect(plan.preview, contains('2. ALTERAR PARÂMETRO 2001'));
      expect(plan.preview, contains('3. SALVAR / PERSISTIR CONFIGURAÇÃO'));
      expect(plan.preview, contains('4. ENCERRAR USB CONFIGURATOR'));
    });

    test('rejects unsafe flows without activation or persistence', () {
      expect(
        () => buildTeltonikaConfigSequence(
          parameters: const [(2001, 'internet.example')],
          connectFirst: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildTeltonikaConfigSequence(
          parameters: const [(2001, 'internet.example')],
          saveLast: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
