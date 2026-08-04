import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/drivers/driver_contracts.dart';
import '../../../../core/sessions/device_session.dart';
import '../../../../core/sessions/device_session_provider.dart';

/// Provider para o status CAN runtime e status.
final canStatusProvider = Provider.family<CanRuntimeStatus, String>(
  (ref, deviceId) {
    final deviceStateAsync = ref.watch(deviceSessionProvider(deviceId));
    return deviceStateAsync.when(
      loading: () => CanRuntimeStatus.unsupported(),
      error: (_, __) => CanRuntimeStatus.unsupported(),
      data: (deviceState) {
        if (deviceState == null) {
          return CanRuntimeStatus.unsupported();
        }
        return CanRuntimeStatus.fromSession(
          deviceId: deviceId,
          session: deviceState,
        );
      },
    );
  },
);

/// Estado CAN runtime e utilitários.
class CanRuntimeStatus {
  final String deviceId;
  final bool supportsCan;
  final bool isActive;
  final bool isReceiving;
  final DateTime? lastSampleAt;
  final DateTime? lastSampleReceivedAt;
  final int changeCount;
  final Map<String, dynamic> sampleCount;

  CanRuntimeStatus({
    required this.deviceId,
    required this.supportsCan,
    required this.isActive,
    required this.isReceiving,
    this.lastSampleAt,
    this.lastSampleReceivedAt,
    required this.changeCount,
    required this.sampleCount,
  });

  /// Indica que o CAN não é suportado.
  factory CanRuntimeStatus.unsupported() {
    return CanRuntimeStatus(
      deviceId: '',
      supportsCan: false,
      isActive: false,
      isReceiving: false,
      lastSampleAt: null,
      lastSampleReceivedAt: null,
      changeCount: 0,
      sampleCount: {},
    );
  }

  /// Indica que o CAN está suportado mas não há dados.
  factory CanRuntimeStatus.waiting() {
    return CanRuntimeStatus(
      deviceId: '',
      supportsCan: true,
      isActive: true,
      isReceiving: false,
      lastSampleAt: null,
      lastSampleReceivedAt: null,
      changeCount: 0,
      sampleCount: {},
    );
  }

  /// Indica que o CAN detectou dados.
  factory CanRuntimeStatus.detected({
    required String deviceId,
    required Map<String, dynamic> sampleCount,
  }) {
    final now = DateTime.now();
    return CanRuntimeStatus(
      deviceId: deviceId,
      supportsCan: true,
      isActive: true,
      isReceiving: false,
      lastSampleAt: now,
      lastSampleReceivedAt: now,
      changeCount: 0,
      sampleCount: sampleCount,
    );
  }

  /// Indica que o CAN está recebendo dados em tempo real.
  factory CanRuntimeStatus.receiving({
    required String deviceId,
    required Map<String, dynamic> sampleCount,
    required DateTime lastSampleAt,
  }) {
    return CanRuntimeStatus(
      deviceId: deviceId,
      supportsCan: true,
      isActive: true,
      isReceiving: true,
      lastSampleAt: lastSampleAt,
      lastSampleReceivedAt: DateTime.now(),
      changeCount: 0,
      sampleCount: sampleCount,
    );
  }

  /// Indica que o CAN possui dados antigos.
  factory CanRuntimeStatus.stale({
    required String deviceId,
    required Map<String, dynamic> sampleCount,
    required DateTime lastSampleAt,
  }) {
    return CanRuntimeStatus(
      deviceId: deviceId,
      supportsCan: true,
      isActive: true,
      isReceiving: false,
      lastSampleAt: lastSampleAt,
      lastSampleReceivedAt: null,
      changeCount: 0,
      sampleCount: sampleCount,
    );
  }

  /// Indica um erro no CAN.
  factory CanRuntimeStatus.error() {
    return CanRuntimeStatus(
      deviceId: '',
      supportsCan: true,
      isActive: false,
      isReceiving: false,
      lastSampleAt: null,
      lastSampleReceivedAt: null,
      changeCount: 0,
      sampleCount: {},
    );
  }

  /// Factory para criar a partir de um DeviceSession.
  static CanRuntimeStatus fromSession({
    required String deviceId,
    required DeviceSession session,
  }) {
    final capabilities = session.capabilities;
    final measurements = session.measurements;

    // Filtrar medições com origem/can
    final canMeasurements = measurements.where((m) {
      final category = m.category.toLowerCase();
      final key = m.key.toLowerCase();
      return category.contains('can') ||
          key.contains('can') ||
          key.contains('obd') ||
          key.contains('rpm') ||
          key.contains('speed') ||
          key.contains('odometer');
    }).toList();

    final now = DateTime.now();
    final lastSampleAt = canMeasurements.isNotEmpty
        ? canMeasurements.last.timestamp
        : null;

    final sampleCount = <String, dynamic>{};
    for (final measurement in canMeasurements) {
      sampleCount[measurement.key] = (sampleCount[measurement.key] ?? 0) + 1;
    }

    // Correção: se supportsCan == false, retornar unsupported
    if (!capabilities.can) {
      return CanRuntimeStatus.unsupported();
    }

    if (canMeasurements.isEmpty) {
      return CanRuntimeStatus.waiting();
    }

    final lastReceivedAt = canMeasurements.last.timestamp;
    final timeSinceLastReceived = now.difference(lastReceivedAt).inSeconds;

    if (timeSinceLastReceived < 60) {
      return CanRuntimeStatus.receiving(
        deviceId: deviceId,
        sampleCount: sampleCount,
        lastSampleAt: lastSampleAt!,
      );
    } else {
      return CanRuntimeStatus.stale(
        deviceId: deviceId,
        sampleCount: sampleCount,
        lastSampleAt: lastSampleAt!,
      );
    }
  }

  /// Obtém a cor do status CAN.
  Color get statusColor {
    if (!supportsCan) return Colors.grey;
    if (!isActive) return Colors.red;
    if (isReceiving) return Colors.green;
    if (lastSampleReceivedAt == null) return Colors.amber;
    return Colors.blue;
  }

  /// Obtém a descrição do status CAN.
  String get statusDescription {
    if (!supportsCan) {
      return 'CAN não suportado por este equipamento';
    }
    if (!isActive) {
      return 'CAN não ativo';
    }
    if (isReceiving) {
      return 'CAN ativo - recebendo dados';
    }
    if (lastSampleReceivedAt == null) {
      return 'CAN suportado - aguardando dados';
    }
    return 'CAN suportado - dados antigos';
  }
}

/// Provider para gerenciar dados CAN por dispositivo.
final canDataProvider = Provider.family<Map<String, dynamic>, String>(
  (ref, deviceId) {
    final deviceStateAsync = ref.watch(deviceSessionProvider(deviceId));
    return deviceStateAsync.when(
      loading: () => {},
      error: (_, __) => {},
      data: (deviceState) {
        if (deviceState == null) {
          return {};
        }

        final canMeasurements = deviceState.measurements.where((m) {
          final category = m.category.toLowerCase();
          final key = m.key.toLowerCase();
          return category.contains('can') ||
              key.contains('can') ||
              key.contains('obd') ||
              key.contains('rpm') ||
              key.contains('speed') ||
              key.contains('odometer');
        }).toList();

        final canData = <String, dynamic>{};
        for (final measurement in canMeasurements) {
          canData[measurement.key] = {
            'value': measurement.value,
        'unit': measurement.unit,
        'timestamp': measurement.timestamp.toIso8601String(),
        'name': measurement.name,
        'category': measurement.category,
      };
    }

    return canData;
      },
    );
  },
);

/// Provider para atualizar o CAN por dispositivo.
final canUpdaterProvider = Provider.family<CanUpdater, String>(
  (ref, deviceId) => CanUpdater(ref, deviceId),
);

/// Gerenciador para atualizar dados CAN.
class CanUpdater {
  final Ref _ref;
  final String _deviceId;

  CanUpdater(this._ref, this._deviceId);

  /// Processa um novo dado CAN.
  void processCanData({
    required String key,
    required dynamic value,
    required DateTime timestamp,
    required String category,
    required String name,
    String? unit,
  }) {
final deviceStateAsync = _ref.read(deviceSessionProvider(_deviceId));
    deviceStateAsync.when(
      loading: () {},
      error: (_, __) {},
      data: (deviceState) {
        if (deviceState == null) return;
        final normalized = NormalizedMeasurement(
          key: key,
          rawKey: key,
          category: category,
          name: name,
          unit: unit,
          value: value,
          timestamp: timestamp,
          metadata: {'source': 'can'},
        );
        final newSession = deviceState.updateState(
          newState: deviceState.normalizedState,
          newMeasurements: [normalized],
          newRawData: {
            'can_$key': {
              'value': value,
              'timestamp': timestamp.toIso8601String(),
              'category': category,
            },
          },
          timestamp: timestamp,
        );
        _ref.read(deviceSessionProvider(_deviceId).notifier).updateSession(newSession);
      },
    );
  }
}
