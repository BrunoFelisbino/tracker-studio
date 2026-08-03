import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/data/can_mapping/can_mapping_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('can_mapping_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CanMappingStore storeFor([String name = 'mapping.json']) =>
      CanMappingStore(pathResolver: () async => '${tempDir.path}/$name');

  test('round-trips mappings through a JSON file', () async {
    final store = storeFor();
    await store.load();
    expect(store.all, isEmpty);

    await store.upsert(const CanSensorMapping(avlId: 283, name: 'Engine RPM'));
    await store.upsert(const CanSensorMapping(
        avlId: 3845, name: 'Odometer', unit: 'km'));

    expect(store.byId(283)?.name, 'Engine RPM');
    expect(store.byId(3845)?.unit, 'km');
    expect(store.all.map((m) => m.avlId), [283, 3845]);

    final reloaded = storeFor();
    await reloaded.load();
    expect(reloaded.all, hasLength(2));
    expect(reloaded.byId(283)?.name, 'Engine RPM');
    expect(reloaded.byId(3845)?.unit, 'km');
  });

  test('upsert overwrites an existing mapping and removes entries', () async {
    final store = storeFor();
    await store.load();
    await store.upsert(const CanSensorMapping(avlId: 283, name: 'Old'));
    await store.upsert(const CanSensorMapping(avlId: 283, name: 'New'));
    expect(store.all, hasLength(1));
    expect(store.byId(283)?.name, 'New');

    await store.remove(283);
    expect(store.byId(283), isNull);
    expect(store.all, isEmpty);
  });

  test('keeps valid entries when the file is corrupt', () async {
    final file = File('${tempDir.path}/corrupt.json');
    await file.writeAsString('not json at all {');
    final store = storeFor('corrupt.json');
    await store.load();
    expect(store.all, isEmpty);
    expect(store.isLoaded, isTrue);

    await store.upsert(const CanSensorMapping(avlId: 1, name: 'ok'));
    final persisted =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect((persisted['mappings'] as List), hasLength(1));
  });

  test('ignores entries without a valid name or avlId', () async {
    final file = File('${tempDir.path}/dirty.json');
    await file.writeAsString(jsonEncode({
      'version': 1,
      'mappings': [
        {'avlId': 1, 'name': ''},
        {'avlId': 0, 'name': 'zero'},
        {'avlId': 2, 'name': 'kept'},
      ],
    }));
    final store = storeFor('dirty.json');
    await store.load();
    expect(store.all.map((m) => m.avlId), [2]);
  });
}
