import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/configuration_audit_models.dart';

void main() {
  test('records executions for USB, SMS and GPRS', () {
    for (final channel in DeviceCommandChannel.values) {
      final record = CommandExecutionRecord.sent(
        channel: channel,
        rawCommand: 'AT',
        transport: channel.name,
        correlationId: 'correlation-${channel.name}',
      );

      expect(record.channel, channel);
      expect(record.sentAt, isNot(DateTime.fromMillisecondsSinceEpoch(0)));
    }
  });

  test('uses injected clock for sent time, response time and duration', () {
    final sentAt = DateTime.utc(2026, 7, 22, 10);
    final responseAt = sentAt.add(const Duration(milliseconds: 275));
    final sent = CommandExecutionRecord.sent(
      channel: DeviceCommandChannel.usb,
      rawCommand: 'AT',
      transport: 'serial:/dev/ttyUSB0',
      correlationId: 'correlation-1',
      clock: () => sentAt,
    );
    final completed = sent.recordResponse(
      rawResponse: 'OK',
      parsedResult: const {'accepted': true},
      clock: () => responseAt,
    );

    expect(sent.sentAt, sentAt);
    expect(completed.responseAt, responseAt);
    expect(completed.duration, const Duration(milliseconds: 275));
  });

  test('default clock records a real current timestamp', () {
    final before = DateTime.now();
    final record = CommandExecutionRecord.sent(
      channel: DeviceCommandChannel.sms,
      rawCommand: 'AT',
      transport: 'sms',
      correlationId: 'correlation-2',
    );
    final after = DateTime.now();

    expect(record.sentAt.isBefore(before), isFalse);
    expect(record.sentAt.isAfter(after), isFalse);
  });

  test('masks PRG parameter 03 and secrets in all audit data', () {
    const password = 'senha-completa';
    final sent = CommandExecutionRecord.sent(
      channel: DeviceCommandChannel.gprs,
      rawCommand: 'AT^PRG;123;10;01#apn;03#$password;04#;05#server',
      transport: 'gprs',
      correlationId: 'correlation-3',
      commandMetadata: const {
        'password': password,
        'nested': {'token': 'abc123'},
      },
    );
    final completed = sent.recordResponse(
      rawResponse: 'password=$password;OK',
      parsedResult: const {'secret': password},
      error: 'token=abc123',
    );
    final serialized = completed.toJson().toString();

    expect(sent.maskedRawCommand, contains(';03#***;'));
    expect(serialized, isNot(contains(password)));
    expect(serialized, isNot(contains('abc123')));
  });
}
