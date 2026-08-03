import '../../core/diagnostic_types.dart';

class TeltonikaRules {
  const TeltonikaRules();

  List<DiagnosticFinding> diagnose(List<NormalizedDiagnosticEvent> events) {
    final findings = <DiagnosticFinding>[];
    final gps = _gpsSnapshot(events);
    final power = _powerSnapshot(events);
    final comm = _commSnapshot(events);

    // Regra: IMEI enviado sem ACK.
    if (comm.imeiSent && !comm.ackReceived) {
      findings.add(const DiagnosticFinding(
        code: 'IMEI_NO_ACK',
        severity: DiagnosticSeverity.warning,
        title: 'IMEI enviado sem confirmação',
        message: 'O equipamento abriu o socket e enviou o IMEI, mas não foi '
            'encontrada confirmação de autorização pelo servidor.',
      ));
    }

    // Regra: GPS crítico.
    if (gps.maxHdop != null && gps.maxHdop! > 10) {
      findings.add(DiagnosticFinding(
        code: 'GPS_HDOP_CRITICAL',
        severity: gps.maxHdop! > 30
            ? DiagnosticSeverity.critical
            : DiagnosticSeverity.warning,
        title: 'Precisão GPS ruim',
        message: gps.maxHdop! > 30
            ? 'A posição GPS está extremamente imprecisa (HDOP ${gps.maxHdop!.toStringAsFixed(1)}). '
                'Verifique a instalação da antena, ambiente fechado, '
                'interferência ou ausência de visada do céu.'
            : 'A precisão GPS está ruim (HDOP máximo ${gps.maxHdop!.toStringAsFixed(1)}).',
      ));
    }

    // Regra: perda de GPS.
    if (gps.fixLossCount > 0) {
      findings.add(DiagnosticFinding(
        code: 'GPS_FIX_LOST',
        severity: DiagnosticSeverity.warning,
        title: 'Perda de fixação GPS',
        message:
            'Foi detectada perda de fixação GPS ($gps.fixLossCountx) durante o período analisado.',
      ));
    }

    // Regra: alimentação normal.
    if (power.externalVoltage != null) {
      if (power.externalVoltage! >= 10 && power.externalVoltage! <= 30) {
        findings.add(DiagnosticFinding(
          code: 'POWER_OK',
          severity: DiagnosticSeverity.success,
          title: 'Alimentação externa normal',
          message:
              'Tensão externa de ${power.externalVoltage!.toStringAsFixed(2)} V dentro da faixa operacional.',
        ));
      } else {
        findings.add(DiagnosticFinding(
          code: 'POWER_ABNORMAL',
          severity: DiagnosticSeverity.error,
          title: 'Alimentação externa anormal',
          message:
              'Tensão externa de ${power.externalVoltage!.toStringAsFixed(2)} V fora da faixa esperada.',
        ));
      }
    }

    // Regra: bateria interna.
    if (power.batteryVoltage != null) {
      final battery = power.batteryVoltage!;
      if (battery < 3.3) {
        findings.add(DiagnosticFinding(
          code: 'BATTERY_CRITICAL',
          severity: DiagnosticSeverity.error,
          title: 'Bateria interna crítica',
          message:
              'Bateria interna em ${battery.toStringAsFixed(2)} V. Considere trocar a bateria.',
        ));
      } else if (battery >= 3.3 && battery <= 4.3) {
        findings.add(DiagnosticFinding(
          code: 'BATTERY_OK',
          severity: DiagnosticSeverity.success,
          title: 'Bateria interna normal',
          message:
              'Bateria interna em ${battery.toStringAsFixed(2)} V dentro do esperado.',
        ));
      }
    }

    // Regra: CAN em repouso (não é erro).
    final canSleep = events.any((e) =>
        e.source == 'LVCAN' && e.message.toLowerCase().contains('sleep'));
    if (canSleep) {
      findings.add(const DiagnosticFinding(
        code: 'CAN_SLEEP',
        severity: DiagnosticSeverity.info,
        title: 'Módulo CAN em repouso',
        message:
            'O módulo CAN está em repouso. Isso pode ser normal dependendo '
            'da ignição e do estado do veículo.',
      ));
    }

    // Regra: socket nunca aberto.
    if (!comm.socketOpened && comm.attempted) {
      findings.add(const DiagnosticFinding(
        code: 'SOCKET_NOT_OPENED',
        severity: DiagnosticSeverity.error,
        title: 'Socket não foi aberto',
        message:
            'Houve tentativas de conexão, mas o socket TCP não abriu com sucesso.',
      ));
    }

    return findings;
  }

  ({bool attempted, bool socketOpened, bool imeiSent, bool ackReceived})
      _commSnapshot(List<NormalizedDiagnosticEvent> events) {
    var attempted = false;
    var socketOpened = false;
    var imeiSent = false;
    var ackReceived = false;
    for (final event in events) {
      final message = event.message.toLowerCase();
      if (event.source == 'NETWORK' &&
          (message.contains('connecting') || message.contains('connect'))) {
        attempted = true;
      }
      if (event.source == 'NETWORK' && message.contains('socket opened')) {
        socketOpened = true;
      }
      if (message.contains('imei send ok') || message.contains('imei sent')) {
        imeiSent = true;
      }
      if (message.contains('imei answer:') ||
          message.contains('ack') ||
          message.contains('imei answer ok')) {
        ackReceived = true;
      }
    }
    return (
      attempted: attempted,
      socketOpened: socketOpened,
      imeiSent: imeiSent,
      ackReceived: ackReceived
    );
  }

  ({double? maxHdop, int fixLossCount}) _gpsSnapshot(
      List<NormalizedDiagnosticEvent> events) {
    double? maxHdop;
    var fixLossCount = 0;
    for (final event in events) {
      if (event.source == 'GPS.API') {
        final hdop = event.details['hdop'];
        if (hdop is num) {
          final value = hdop.toDouble();
          maxHdop =
              maxHdop == null ? value : (maxHdop > value ? maxHdop : value);
        }
        if (event.message.toLowerCase().contains('fix lost') ||
            event.message.toLowerCase().contains('fix loss') ||
            event.event == 'fix_status' && event.details['fixStatus'] == 0) {
          fixLossCount++;
        }
      }
    }
    return (maxHdop: maxHdop, fixLossCount: fixLossCount);
  }

  ({double? externalVoltage, double? batteryVoltage}) _powerSnapshot(
      List<NormalizedDiagnosticEvent> events) {
    double? externalVoltage;
    double? batteryVoltage;
    for (final event in events) {
      if (event.source == 'LiPo' && event.value != null) {
        final value = event.value!.toDouble();
        if (value >= 5) {
          externalVoltage = value;
        } else if (value > 2.5 && value < 5) {
          batteryVoltage = value;
        }
      }
    }
    return (externalVoltage: externalVoltage, batteryVoltage: batteryVoltage);
  }
}
