import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/core/drivers/teltonika/teltonika_driver.dart';
import 'package:tracker_studio/core/uce/registry/uce_registry.dart';
import 'package:tracker_studio/core/uce/uce_interfaces.dart';

void main() {
  group('Teltonika UCE catalog', () {
    setUpAll(() {
      UceRegistry.initialize();
      TeltonikaDriver.registerAll();
    });

    test('registers GPRS and Server configuration parameters', () {
      final apn = UceRegistry().parameters.getByParameterId(2001);
      expect(apn, isNotNull);
      expect(apn!.id, 'teltonika.cfg.apn');
      expect(apn.valueType, ParameterValueType.apn);
      expect(apn.manufacturer, Manufacturer.teltonika);

      final port = UceRegistry().parameters.getByParameterId(2005);
      expect(port, isNotNull);
      expect(port!.id, 'teltonika.cfg.server_port');
      expect(port.valueType, ParameterValueType.port);
    });

    test('registers AVL telemetry definitions with unit conversion', () {
      final voltage = UceRegistry().avl.getByAvlId(66);
      expect(voltage, isNotNull);
      expect(voltage!.normalizedKey, 'external_voltage');
      expect(voltage.convertValue(12000), 12.0);

      final ignition = UceRegistry().avl.getByAvlId(3);
      expect(ignition, isNotNull);
      expect(ignition!.normalizedKey, 'ignition');
    });

    test('registers server backup parameters', () {
      final mode = UceRegistry().parameters.getByParameterId(2010);
      expect(mode, isNotNull);
      expect(mode!.group, 'Server Backup');
      expect(mode.defaultValue, '0');
      expect(mode.enumValues!.keys, containsAll(['0', '1', '2', '3']));

      final domain = UceRegistry().parameters.getByParameterId(2007);
      expect(domain, isNotNull);
      expect(domain!.defaultValue, '');

      final port = UceRegistry().parameters.getByParameterId(2008);
      expect(port, isNotNull);
      expect(port!.minimum, 0);
      expect(port.maximum, 65535);

      final protocol = UceRegistry().parameters.getByParameterId(2009);
      expect(protocol, isNotNull);
      expect(protocol!.enumValues!.keys, containsAll(['0', '1', '3']));
    });

    test('registers data acquisition parameters with PDF defaults', () {
      final minPeriod = UceRegistry().parameters.getByParameterId(10050);
      expect(minPeriod, isNotNull);
      expect(minPeriod!.defaultValue, 300);
      expect(minPeriod.maximum, 2592000);

      final minDistance = UceRegistry().parameters.getByParameterId(10051);
      expect(minDistance, isNotNull);
      expect(minDistance!.defaultValue, 100);
      expect(minDistance.maximum, 65535);

      final minAngle = UceRegistry().parameters.getByParameterId(10052);
      expect(minAngle, isNotNull);
      expect(minAngle!.defaultValue, 10);
      expect(minAngle.unit, '°');

      final minSpeedDelta = UceRegistry().parameters.getByParameterId(10053);
      expect(minSpeedDelta, isNotNull);
      expect(minSpeedDelta!.defaultValue, 10);

      final minSavedRecords = UceRegistry().parameters.getByParameterId(10054);
      expect(minSavedRecords, isNotNull);
      expect(minSavedRecords!.defaultValue, 1);
      expect(minSavedRecords.minimum, 1);
      expect(minSavedRecords.maximum, 255);

      final sendPeriod = UceRegistry().parameters.getByParameterId(10055);
      expect(sendPeriod, isNotNull);
      expect(sendPeriod!.defaultValue, 120);
      expect(sendPeriod.maximum, 2592000);
    });

    test('registers voltage and system parameters', () {
      final highVoltage = UceRegistry().parameters.getByParameterId(104);
      expect(highVoltage, isNotNull);
      expect(highVoltage!.defaultValue, 30000);
      expect(highVoltage.unit, 'mV');

      final lowVoltage = UceRegistry().parameters.getByParameterId(105);
      expect(lowVoltage, isNotNull);
      expect(lowVoltage!.defaultValue, 13200);

      final ntpResync = UceRegistry().parameters.getByParameterId(901);
      expect(ntpResync, isNotNull);
      expect(ntpResync!.defaultValue, 0);
      expect(ntpResync.maximum, 24);

      final ntpServer1 = UceRegistry().parameters.getByParameterId(902);
      expect(ntpServer1, isNotNull);
      expect(ntpServer1!.defaultValue, 'pool.ntp.org');

      final ntpServer2 = UceRegistry().parameters.getByParameterId(903);
      expect(ntpServer2, isNotNull);
      expect(ntpServer2!.defaultValue, 'time.nist.gov');
    });

    test('registers low power mode parameters', () {
      final mode = UceRegistry().parameters.getByParameterId(19500);
      expect(mode, isNotNull);
      expect(mode!.defaultValue, '0');
      expect(mode.enumValues!.keys, containsAll(['0', '1']));

      final minPeriod = UceRegistry().parameters.getByParameterId(19501);
      expect(minPeriod, isNotNull);
      expect(minPeriod!.defaultValue, 3600);
      expect(minPeriod.minimum, 120);
      expect(minPeriod.maximum, 2592000);

      final gpsSearch = UceRegistry().parameters.getByParameterId(19502);
      expect(gpsSearch, isNotNull);
      expect(gpsSearch!.defaultValue, 60);
      expect(gpsSearch.minimum, 30);
      expect(gpsSearch.maximum, 3600);

      final satellites = UceRegistry().parameters.getByParameterId(19504);
      expect(satellites, isNotNull);
      expect(satellites!.defaultValue, 0);
      expect(satellites.maximum, 20);
    });

    test('registers commands and builds wire templates', () {
      final setParam = UceRegistry().commands.getById('teltonika.cfg_setparam');
      expect(setParam, isNotNull);
      expect(
        setParam!.buildCommand({'parameterId': 2005, 'value': 5026}),
        ':cfg_setparam:2005:5026',
      );

      final save = UceRegistry().commands.getById('teltonika.cfg_save');
      expect(save!.buildCommand({}), ':cfg_save');
    });

    test('registers response patterns', () {
      expect(
        UceRegistry().responses.getById('teltonika.setparam_ok'),
        isNotNull,
      );
      expect(
        UceRegistry()
            .responses
            .getById('teltonika.setparam_ok')!
            .matches('<SETPARAM_RESULT>:1'),
        true,
      );
    });
  });

  group('Teltonika USB Configurator text protocol', () {
    test('encodes set parameter and save commands', () {
      expect(TeltonikaDriver.encodeSetParameter(2005, '5026'),
          ':cfg_setparam:2005:5026');
      expect(TeltonikaDriver.encodeSaveConfiguration(), ':cfg_save');
      expect(TeltonikaDriver.encodeConnect(), ':cfg_connect');
      expect(TeltonikaDriver.encodeDisconnect(), ':cfg_disconnect');
      expect(TeltonikaDriver.encodeGetConfiguration(), ':cfg_getcfg');
    });

    test('encodes parameter write through the UCE catalog', () {
      final port = UceRegistry().parameters.getByParameterId(2005);
      expect(port, isNotNull);
      expect(TeltonikaDriver.encodeParameterWrite(port!, '5026'),
          ':cfg_setparam:2005:5026');
    });

    test('parses set-parameter commands with trailing CR', () {
      final cmd =
          TeltonikaDriver.parseConfigCommand(':cfg_setparam:2005:5026\r');
      expect(cmd, isNotNull);
      expect(cmd!.command, 'set-parameter');
      expect(cmd.parameterId, 2005);
      expect(cmd.rawValue, '5026');
      expect(cmd.parsedValue, 5026);
      expect(cmd.direction, 'host-to-device');
    });

    test('parses save and connect commands', () {
      final save = TeltonikaDriver.parseConfigCommand(':cfg_save\r');
      expect(save!.command, 'save');

      final connect = TeltonikaDriver.parseConfigCommand(':cfg_connect\r');
      expect(connect!.command, 'connect');
    });

    test('parses device responses (accepted / rejected / saved)', () {
      final ok =
          TeltonikaDriver.parseConfigCommand('<SETPARAM_RESULT>:1\r',
              direction: 'device-to-host');
      expect(ok!.command, 'set-parameter-result');
      expect(ok.parsedValue, 'accepted');

      final fail =
          TeltonikaDriver.parseConfigCommand('<SETPARAM_RESULT>:0\r');
      expect(fail!.parsedValue, 'rejected');

      final saved =
          TeltonikaDriver.parseConfigCommand('<SAVE_CFG_RESULT>:1\r');
      expect(saved!.command, 'save-result');
      expect(saved.parsedValue, 'saved');

      final connected = TeltonikaDriver.parseConfigCommand('<CFG_CONNECT>\r');
      expect(connected!.command, 'connect-result');
    });

    test('returns null for unknown payloads', () {
      expect(TeltonikaDriver.parseConfigCommand('junk payload'), isNull);
    });
  });
}
