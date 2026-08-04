import 'suntech_legacy_commands.dart';

class SuntechPrgCommandBuilders {
  static const _st8Models = ['ST8210', 'ST8310', 'ST8310U', 'ST8310UM'];

  static SuntechCommandDefinition keepAlive({
    required int intervalMinutes,
  }) {
    if (intervalMinutes < 0 || intervalMinutes > 60) {
      throw ArgumentError(
        'Keep alive interval must be 0-60 minutes, got: $intervalMinutes',
      );
    }

    final hex = intervalMinutes.toRadixString(16).toUpperCase().padLeft(2, '0');

    return SuntechCommandDefinition(
      id: 'prg_keep_alive',
      label: 'PRG Keep Alive (Grupo 10 / Param 60)',
      commandTemplate: 'AT^PRG;<ESN>;10;60#$hex',
      requiresEsn: true,
      critical: false,
      requiresBackup: false,
      namespace: 'ST8-PRG',
      code: '1060',
      notes:
          'Intervalo: ${intervalMinutes == 0 ? "desativado" : "$intervalMinutes min"}. '
          'Valid range: 0-60 minutos (0=desativado).',
      supportedModels: _st8Models,
      firmwareMin: '1.0.13',
      firmwareMax: '1.0.14',
      riskClassification: 'config',
      responseParser: 'suntech-st8-prg-ack-v1',
      sourceProvenance: 'ST8210_1.0.14.json; ST8310UM_1.0.13.json',
    );
  }

  static SuntechCommandDefinition voltageThreshold({
    required int highThreshold,
    required int lowThreshold,
  }) {
    if (highThreshold < 30 || highThreshold > 100) {
      throw ArgumentError(
        'High threshold must be 30-100 (3.0-10.0V), got: $highThreshold',
      );
    }
    if (lowThreshold < 30 || lowThreshold > 100) {
      throw ArgumentError(
        'Low threshold must be 30-100 (3.0-10.0V), got: $lowThreshold',
      );
    }
    if (lowThreshold >= highThreshold) {
      throw ArgumentError(
        'Low threshold ($lowThreshold) must be less than high ($highThreshold)',
      );
    }

    final hexHigh =
        highThreshold.toRadixString(16).toUpperCase().padLeft(2, '0');
    final hexLow = lowThreshold.toRadixString(16).toUpperCase().padLeft(2, '0');

    final highVoltage = (highThreshold / 10).toStringAsFixed(1);
    final lowVoltage = (lowThreshold / 10).toStringAsFixed(1);

    return SuntechCommandDefinition(
      id: 'prg_voltage_threshold',
      label: 'PRG Voltage Threshold (Grupo 17 / Params 15-16)',
      commandTemplate: 'AT^PRG;<ESN>;17;15#$hexHigh;16#$hexLow',
      requiresEsn: true,
      critical: false,
      requiresBackup: false,
      namespace: 'ST8-PRG',
      code: '1715',
      notes:
          'High: ${highVoltage}V ($highThreshold), Low: ${lowVoltage}V ($lowThreshold). '
          'Range: 30-100 cada (3.0V-10.0V). low < high obrigatório.',
      supportedModels: _st8Models,
      firmwareMin: '1.0.13',
      firmwareMax: '1.0.14',
      riskClassification: 'config',
      responseParser: 'suntech-st8-prg-ack-v1',
      sourceProvenance: 'ST8210_1.0.14.json; ST8310UM_1.0.13.json',
    );
  }

  static SuntechCommandDefinition inputReadTime({
    required int input1Time,
    required int input2Time,
  }) {
    if (input1Time < 0 || input1Time > 10000) {
      throw ArgumentError(
        'Input 1 time must be 0-10000ms, got: $input1Time',
      );
    }
    if (input2Time < 0 || input2Time > 10000) {
      throw ArgumentError(
        'Input 2 time must be 0-10000ms, got: $input2Time',
      );
    }

    final hexIn1 = input1Time.toRadixString(16).toUpperCase().padLeft(4, '0');
    final hexIn2 = input2Time.toRadixString(16).toUpperCase().padLeft(4, '0');

    return SuntechCommandDefinition(
      id: 'prg_input_read_time',
      label: 'PRG Input Read Time (Grupo 18 / Params 01-02)',
      commandTemplate: 'AT^PRG;<ESN>;18;01#$hexIn1;02#$hexIn2',
      requiresEsn: true,
      critical: false,
      requiresBackup: false,
      namespace: 'ST8-PRG',
      code: '1801',
      notes: 'Input1: $input1Time ms, Input2: $input2Time ms. '
          'Range: 0-10000ms cada.',
      supportedModels: _st8Models,
      firmwareMin: '1.0.13',
      firmwareMax: '1.0.14',
      riskClassification: 'config',
      responseParser: 'suntech-st8-prg-ack-v1',
      sourceProvenance: 'ST8210_1.0.14.json; ST8310UM_1.0.13.json',
    );
  }

  static SuntechCommandDefinition sleepMode({required bool enabled}) {
    final value = enabled ? '01' : '00';

    return SuntechCommandDefinition(
      id: 'prg_sleep_mode',
      label: 'PRG Sleep Mode (Grupo 19 / Param 30)',
      commandTemplate: 'AT^PRG;<ESN>;19;30#$value',
      requiresEsn: true,
      critical: false,
      requiresBackup: false,
      namespace: 'ST8-PRG',
      code: '1930',
      notes: 'Sleep mode: ${enabled ? "ativado" : "desativado"}.',
      supportedModels: _st8Models,
      firmwareMin: '1.0.13',
      firmwareMax: '1.0.14',
      riskClassification: 'config',
      responseParser: 'suntech-st8-prg-ack-v1',
      sourceProvenance: 'ST8210_1.0.14.json; ST8310UM_1.0.13.json',
    );
  }

  static SuntechCommandDefinition zipCompression({required bool enabled}) {
    final value = enabled ? '01' : '00';

    return SuntechCommandDefinition(
      id: 'prg_zip_compression',
      label: 'PRG Zip Compression (Grupo 10 / Param 55)',
      commandTemplate: 'AT^PRG;<ESN>;10;55#$value',
      requiresEsn: true,
      critical: false,
      requiresBackup: false,
      namespace: 'ST8-PRG',
      code: '1055',
      notes: 'Zip compression: ${enabled ? "ativado" : "desativado"}.',
      supportedModels: _st8Models,
      firmwareMin: '1.0.13',
      firmwareMax: '1.0.14',
      riskClassification: 'config',
      responseParser: 'suntech-st8-prg-ack-v1',
      sourceProvenance: 'ST8210_1.0.14.json; ST8310UM_1.0.13.json',
    );
  }
}
