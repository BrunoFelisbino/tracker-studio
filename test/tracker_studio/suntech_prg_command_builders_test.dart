import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_prg_command_builders.dart';

void main() {
  group('SuntechPrgCommandBuilders', () {
    group('keepAlive', () {
      test('builds command with 0 minutes (disabled)', () {
        final cmd = SuntechPrgCommandBuilders.keepAlive(intervalMinutes: 0);
        expect(cmd.command(esn: 'TEST123'), contains('60#00'));
        expect(cmd.critical, isFalse);
        expect(cmd.requiresEsn, isTrue);
        expect(cmd.riskClassification, 'config');
      });

      test('builds command with 30 minutes', () {
        final cmd = SuntechPrgCommandBuilders.keepAlive(intervalMinutes: 30);
        expect(cmd.command(esn: 'TEST123'), contains('60#1E'));
      });

      test('builds command with 60 minutes (max)', () {
        final cmd = SuntechPrgCommandBuilders.keepAlive(intervalMinutes: 60);
        expect(cmd.command(esn: 'TEST123'), contains('60#3C'));
      });

      test('rejects negative interval', () {
        expect(
          () => SuntechPrgCommandBuilders.keepAlive(intervalMinutes: -1),
          throwsArgumentError,
        );
      });

      test('rejects interval above 60', () {
        expect(
          () => SuntechPrgCommandBuilders.keepAlive(intervalMinutes: 61),
          throwsArgumentError,
        );
      });

      test('supports all New Gen models', () {
        final cmd = SuntechPrgCommandBuilders.keepAlive(intervalMinutes: 10);
        expect(cmd.supportedModels, containsAll(['ST8210', 'ST8310', 'ST8310U', 'ST8310UM']));
      });
    });

    group('voltageThreshold', () {
      test('builds command with valid thresholds', () {
        final cmd = SuntechPrgCommandBuilders.voltageThreshold(
          highThreshold: 80,
          lowThreshold: 40,
        );
        expect(cmd.command(esn: 'TEST123'), contains('15#50'));
        expect(cmd.command(esn: 'TEST123'), contains('16#28'));
      });

      test('rejects high below 30', () {
        expect(
          () => SuntechPrgCommandBuilders.voltageThreshold(
            highThreshold: 29,
            lowThreshold: 30,
          ),
          throwsArgumentError,
        );
      });

      test('rejects low above 100', () {
        expect(
          () => SuntechPrgCommandBuilders.voltageThreshold(
            highThreshold: 100,
            lowThreshold: 101,
          ),
          throwsArgumentError,
        );
      });

      test('rejects low >= high', () {
        expect(
          () => SuntechPrgCommandBuilders.voltageThreshold(
            highThreshold: 50,
            lowThreshold: 50,
          ),
          throwsArgumentError,
        );
      });

      test('rejects low > high', () {
        expect(
          () => SuntechPrgCommandBuilders.voltageThreshold(
            highThreshold: 40,
            lowThreshold: 80,
          ),
          throwsArgumentError,
        );
      });

      test('includes voltage description in notes', () {
        final cmd = SuntechPrgCommandBuilders.voltageThreshold(
          highThreshold: 80,
          lowThreshold: 40,
        );
        expect(cmd.notes, contains('8.0V'));
        expect(cmd.notes, contains('4.0V'));
      });
    });

    group('inputReadTime', () {
      test('builds command with valid times', () {
        final cmd = SuntechPrgCommandBuilders.inputReadTime(
          input1Time: 500,
          input2Time: 1000,
        );
        expect(cmd.command(esn: 'TEST123'), contains('01#01F4'));
        expect(cmd.command(esn: 'TEST123'), contains('02#03E8'));
      });

      test('builds command with zero times', () {
        final cmd = SuntechPrgCommandBuilders.inputReadTime(
          input1Time: 0,
          input2Time: 0,
        );
        expect(cmd.command(esn: 'TEST123'), contains('01#0000'));
        expect(cmd.command(esn: 'TEST123'), contains('02#0000'));
      });

      test('rejects input1 above 10000', () {
        expect(
          () => SuntechPrgCommandBuilders.inputReadTime(
            input1Time: 10001,
            input2Time: 0,
          ),
          throwsArgumentError,
        );
      });

      test('rejects input2 above 10000', () {
        expect(
          () => SuntechPrgCommandBuilders.inputReadTime(
            input1Time: 0,
            input2Time: 10001,
          ),
          throwsArgumentError,
        );
      });

      test('rejects negative input1', () {
        expect(
          () => SuntechPrgCommandBuilders.inputReadTime(
            input1Time: -1,
            input2Time: 0,
          ),
          throwsArgumentError,
        );
      });
    });

    group('sleepMode', () {
      test('builds command to enable sleep', () {
        final cmd = SuntechPrgCommandBuilders.sleepMode(enabled: true);
        expect(cmd.command(esn: 'TEST123'), contains('30#01'));
        expect(cmd.notes, contains('ativado'));
      });

      test('builds command to disable sleep', () {
        final cmd = SuntechPrgCommandBuilders.sleepMode(enabled: false);
        expect(cmd.command(esn: 'TEST123'), contains('30#00'));
        expect(cmd.notes, contains('desativado'));
      });

      test('is not critical', () {
        final cmd = SuntechPrgCommandBuilders.sleepMode(enabled: true);
        expect(cmd.critical, isFalse);
      });
    });

    group('zipCompression', () {
      test('builds command to enable ZIP', () {
        final cmd = SuntechPrgCommandBuilders.zipCompression(enabled: true);
        expect(cmd.command(esn: 'TEST123'), contains('55#01'));
        expect(cmd.notes, contains('ativado'));
      });

      test('builds command to disable ZIP', () {
        final cmd = SuntechPrgCommandBuilders.zipCompression(enabled: false);
        expect(cmd.command(esn: 'TEST123'), contains('55#00'));
        expect(cmd.notes, contains('desativado'));
      });

      test('is not critical', () {
        final cmd = SuntechPrgCommandBuilders.zipCompression(enabled: true);
        expect(cmd.critical, isFalse);
      });
    });
  });
}
