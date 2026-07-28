import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> catalog;
  late List<dynamic> commands;

  setUpAll(() {
    var file = File('${Directory.current.path}/assets/catalogs/suntech_commands.json');
    if (!file.existsSync()) {
      file = File('assets/catalogs/suntech_commands.json');
    }
    final content = file.readAsStringSync();
    catalog = jsonDecode(content) as Map<String, dynamic>;
    commands = catalog['commands'] as List<dynamic>;
  });

  group('Catalog structure', () {
    test('has required top-level fields', () {
      expect(catalog.containsKey('version'), isTrue);
      expect(catalog.containsKey('generatedAt'), isTrue);
      expect(catalog.containsKey('commands'), isTrue);
    });

    test('commands is a non-empty list', () {
      expect(commands, isNotEmpty);
    });

    test('contains 79 commands', () {
      expect(commands.length, 79);
    });
  });

  group('Command IDs', () {
    test('all commands have required fields', () {
      for (final cmd in commands) {
        expect(cmd.containsKey('id'), isTrue, reason: 'Missing id');
        expect(cmd.containsKey('family'), isTrue, reason: 'Missing family');
        expect(cmd.containsKey('name'), isTrue, reason: 'Missing name');
        expect(cmd.containsKey('code'), isTrue, reason: 'Missing code');
        expect(cmd.containsKey('rawCommand'), isTrue, reason: 'Missing rawCommand');
        expect(cmd.containsKey('category'), isTrue, reason: 'Missing category');
        expect(cmd.containsKey('risk'), isTrue, reason: 'Missing risk');
        expect(cmd.containsKey('status'), isTrue, reason: 'Missing status');
      }
    });

    test('IDs are unique', () {
      final ids = commands.map((c) => c['id'] as String).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length, reason: 'Duplicate IDs found');
    });

    test('IDs follow snake_case pattern', () {
      for (final cmd in commands) {
        final id = cmd['id'] as String;
        expect(id, matches(RegExp(r'^[a-z][a-z0-9_]*$')),
            reason: 'Invalid ID: $id');
      }
    });
  });

  group('Valid families', () {
    const validFamilies = {
      'newgen_st8210', 'newgen_st8310', 'newgen_st8310u', 'newgen_st8310um',
      'legacy_st300', 'legacy_st310', 'legacy_st310u',
      'handshake', 'cross_family',
    };

    test('all families are valid', () {
      for (final cmd in commands) {
        final family = cmd['family'] as String;
        expect(validFamilies, contains(family),
            reason: 'Invalid family: $family');
      }
    });
  });

  group('Valid categories', () {
    const validCategories = {
      'identification', 'network', 'sim', 'apn', 'server', 'gps',
      'ignition', 'inputs', 'outputs', 'blocking', 'unblocking',
      'power', 'battery', 'times', 'events', 'sensors', 'position',
      'maintenance', 'reset', 'preset', 'diagnostic', 'encoding',
      'geofence', 'security', 'calibration', 'odometer', 'messaging',
      'work', 'schema', 'config',
    };

    test('all categories are valid', () {
      for (final cmd in commands) {
        final category = cmd['category'] as String;
        expect(validCategories, contains(category),
            reason: 'Invalid category: $category');
      }
    });
  });

  group('Valid risk levels', () {
    const validRisks = {'read', 'config', 'action', 'destructive'};

    test('all risk levels are valid', () {
      for (final cmd in commands) {
        final risk = cmd['risk'] as String;
        expect(validRisks, contains(risk),
            reason: 'Invalid risk: $risk');
      }
    });
  });

  group('Valid statuses', () {
    const validStatuses = {
      'supported', 'partial', 'legacy', 'not_validated'
    };

    test('all statuses are valid', () {
      for (final cmd in commands) {
        final status = cmd['status'] as String;
        expect(validStatuses, contains(status),
            reason: 'Invalid status: $status');
      }
    });
  });

  group('Models', () {
    const validModels = {
      'ST8210', 'ST8310', 'ST8310U', 'ST8310UM',
      'ST300', 'ST310', 'ST310U',
    };

    test('all commands have at least one model', () {
      for (final cmd in commands) {
        final models = cmd['models'] as List<dynamic>;
        expect(models, isNotEmpty, reason: 'No models');
      }
    });

    test('all models are valid', () {
      for (final cmd in commands) {
        final models = (cmd['models'] as List<dynamic>).cast<String>();
        for (final model in models) {
          expect(validModels, contains(model),
              reason: 'Invalid model: $model');
        }
      }
    });
  });

  group('Channels', () {
    const validChannels = {'usb', 'serial', 'sms', 'gprs'};

    test('all commands have at least one channel', () {
      for (final cmd in commands) {
        final channels = cmd['channels'] as List<dynamic>;
        expect(channels, isNotEmpty, reason: 'No channels');
      }
    });

    test('all channels are valid', () {
      for (final cmd in commands) {
        final channels = (cmd['channels'] as List<dynamic>).cast<String>();
        for (final channel in channels) {
          expect(validChannels, contains(channel),
              reason: 'Invalid channel: $channel');
        }
      }
    });
  });

  group('Destructive commands', () {
    test('destructive commands are marked critical', () {
      for (final cmd in commands) {
        if (cmd['risk'] == 'destructive') {
          expect(cmd['destructive'], isTrue,
              reason: 'Destructive command not marked destructive');
        }
      }
    });

    test('critical destructive configuration commands require readback', () {
      for (final cmd in commands) {
        if (cmd['risk'] == 'destructive' && cmd['critical'] == true &&
            cmd['category'] != 'reset' && cmd['category'] != 'messaging') {
          expect(cmd['requiresReadback'], isTrue,
              reason: 'Critical destructive config command does not require readback');
        }
      }
    });
  });

  group('Not validated commands', () {
    test('not validated commands are marked with notes', () {
      for (final cmd in commands) {
        if (cmd['status'] == 'not_validated') {
          expect(cmd.containsKey('notes'), isTrue,
              reason: 'Not validated command has no notes');
        }
      }
    });
  });

  group('Command code format', () {
    test('codes are 4 digits', () {
      for (final cmd in commands) {
        final code = cmd['code'] as String;
        expect(code, matches(RegExp(r'^\d{4}$')),
            reason: 'Invalid code: $code');
      }
    });
  });

  group('Handshake commands', () {
    test('handshake commands have no ESN parameter', () {
      for (final cmd in commands) {
        if (cmd['family'] == 'handshake') {
          final params = cmd['parameters'] as List<dynamic>;
          final hasEsn = params.any((p) => p['name'] == 'ESN');
          expect(hasEsn, isFalse,
              reason: 'Handshake command has ESN parameter');
        }
      }
    });
  });

  group('New Gen commands', () {
    test('non-probe new gen commands have ESN parameter', () {
      for (final cmd in commands) {
        final family = cmd['family'] as String;
        if (family.startsWith('newgen_') && cmd['category'] != 'identification') {
          final params = cmd['parameters'] as List<dynamic>;
          final hasEsn = params.any((p) => p['name'] == 'ESN');
          expect(hasEsn, isTrue,
              reason: 'New Gen command missing ESN parameter');
        }
      }
    });
  });
}
