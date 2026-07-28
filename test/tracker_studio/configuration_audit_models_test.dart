import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/configuration_audit_models.dart';

void main() {
  test('configuration change identifies confirmed readback', () {
    const change = ConfigurationChangeItem(
      key: 'apn',
      label: 'APN',
      previousValue: 'apn.antiga',
      requestedValue: 'apn.nova',
      confirmedValue: 'apn.nova',
      status: ConfigurationValueStatus.confirmed,
    );

    expect(change.changed, isTrue);
    expect(change.readbackMatches, isTrue);
  });

  test('report flags unconfirmed changes and pending tests', () {
    final report = TechnicalSessionReportData(
      sessionId: 'SESSION-1',
      startedAt: DateTime.utc(2026, 7, 22, 10),
      changes: const [
        ConfigurationChangeItem(
          key: 'primaryServer',
          label: 'Servidor primário',
          previousValue: 'old.example.com',
          requestedValue: 'new.example.com',
          status: ConfigurationValueStatus.pendingReadback,
        ),
      ],
      tests: const [
        TechnicalTestRecord(
          id: 'ignition',
          label: 'Ignição',
          status: TechnicalTestStatus.pending,
          pendingReason: 'Veículo indisponível para teste seguro.',
        ),
      ],
    );

    expect(report.hasUnconfirmedChanges, isTrue);
    expect(report.hasPendingTests, isTrue);
    expect(report.hasFailedTests, isFalse);
  });

  test('snapshot serializes before and after values without secrets', () {
    final snapshot = DeviceConfigurationSnapshot(
      id: 'SNAPSHOT-1',
      sessionId: 'SESSION-1',
      source: 'readback',
      capturedAt: DateTime.utc(2026, 7, 22, 10),
      apn: 'hinova.br',
      apnUsername: 'user',
      apnPasswordMasked: '***',
      primaryServer: 'device.example.com',
      primaryPort: 5011,
      vehicleProfile: 'moto',
      sleepEnabled: true,
    );

    final json = snapshot.toJson();

    expect(json['apn'], 'hinova.br');
    expect(json['apnPasswordMasked'], '***');
    expect(json['primaryPort'], 5011);
    expect(json['vehicleProfile'], 'moto');
  });

  test('command audit stores only masked command', () {
    final entry = DeviceCommandAuditEntry(
      id: 'CMD-1',
      sessionId: 'SESSION-1',
      createdAt: DateTime.utc(2026, 7, 22, 10),
      channel: DeviceCommandChannel.usb,
      purpose: 'Alterar APN',
      commandId: 'network-prg',
      commandMasked: 'AT^PRG;ESN;10;APN;***',
      status: DeviceCommandExecutionStatus.sent,
      readbackRequired: true,
    );

    expect(entry.toJson()['commandMasked'], contains('***'));
    expect(entry.readbackRequired, isTrue);
    expect(entry.readbackConfirmed, isFalse);
  });

  test('mask helper hides named secrets', () {
    final masked = maskSensitiveCommand(
      'APN=internet;password=minhaSenha;token=abc123',
    );

    expect(masked, contains('password=***'));
    expect(masked, contains('token=***'));
    expect(masked, isNot(contains('minhaSenha')));
    expect(masked, isNot(contains('abc123')));
  });
}
