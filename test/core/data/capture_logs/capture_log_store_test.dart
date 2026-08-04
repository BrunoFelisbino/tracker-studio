import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/capture_logs/capture_log_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_logs_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CaptureLogStore storeFor([String name = 'logs.json']) =>
      CaptureLogStore(pathResolver: () async => '${tempDir.path}/$name');

  test('appends records and reloads them from disk, most recent first',
      () async {
    final store = storeFor();
    await store.load();
    expect(store.all, isEmpty);

    await store.append(const CaptureLogRecord(
      id: '1',
      sessionCode: 'S-001',
      startedAt: '10:00:00',
      stoppedAt: '10:01:00',
      lines: [':cfg_connect'],
      analysis: {
        'parameterValues': {'2001': 'internet'}
      },
    ));
    await store.append(const CaptureLogRecord(
      id: '2',
      sessionCode: 'S-002',
      startedAt: '11:00:00',
      stoppedAt: '11:01:00',
      lines: [':cfg_setparam:2005:5026'],
    ));

    expect(store.all, hasLength(2));
    expect(store.all.first.id, '2');
    expect(store.all.last.sessionCode, 'S-001');
    expect(
      store.all.last.analysis!['parameterValues'],
      containsPair('2001', 'internet'),
    );

    final reloaded = storeFor();
    await reloaded.load();
    expect(reloaded.all, hasLength(2));
    expect(reloaded.all.first.id, '2');
    expect(reloaded.all.last.lines, contains(':cfg_connect'));
  });

  test('survives a corrupt file and overwrites on next append', () async {
    await File('${tempDir.path}/corrupt.json').writeAsString('not json {');
    final store = storeFor('corrupt.json');
    await store.load();
    expect(store.all, isEmpty);

    await store.append(const CaptureLogRecord(
      id: '1',
      sessionCode: 'S-001',
      startedAt: '10:00:00',
      stoppedAt: '10:01:00',
      lines: [':cfg_connect'],
    ));
    final decoded =
        jsonDecode(await File('${tempDir.path}/corrupt.json').readAsString())
            as Map<String, dynamic>;
    expect((decoded['records'] as List), hasLength(1));
  });
}
