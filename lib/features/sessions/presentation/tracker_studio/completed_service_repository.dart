import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_service_database.dart';

class CompletedServiceRecord {
  final String id;
  final String? workOrderId;
  final String customerName;
  final String plate;
  final String serviceType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String status;
  final String resultSummary;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompletedServiceRecord({
    required this.id,
    required this.workOrderId,
    required this.customerName,
    required this.plate,
    required this.serviceType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.startedAt,
    required this.finishedAt,
    required this.status,
    required this.resultSummary,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toDatabase() => {
        'id': id,
        'work_order_id': workOrderId,
        'customer_name': customerName,
        'plate': plate,
        'service_type': serviceType,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'started_at': startedAt.toUtc().toIso8601String(),
        'finished_at': finishedAt.toUtc().toIso8601String(),
        'status': status,
        'result_summary': resultSummary,
        'sync_status': syncStatus,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory CompletedServiceRecord.fromDatabase(Map<String, Object?> row) {
    return CompletedServiceRecord(
      id: row['id']! as String,
      workOrderId: row['work_order_id'] as String?,
      customerName: row['customer_name']! as String,
      plate: row['plate']! as String,
      serviceType: row['service_type']! as String,
      vehicleBrand: row['vehicle_brand'] as String?,
      vehicleModel: row['vehicle_model'] as String?,
      startedAt: DateTime.parse(row['started_at']! as String),
      finishedAt: DateTime.parse(row['finished_at']! as String),
      status: row['status']! as String,
      resultSummary: row['result_summary']! as String,
      syncStatus: row['sync_status']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}

class CompletedServiceRepository {
  final LocalServiceDatabase _database;

  const CompletedServiceRepository(this._database);

  Future<void> saveCompletedService(CompletedServiceRecord record) async {
    final database = await _database.database;
    await database.insert(
      'completed_services',
      record.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CompletedServiceRecord>> listRecentCompletedServices(
      {int limit = 50}) async {
    final database = await _database.database;
    final rows = await database.query(
      'completed_services',
      orderBy: 'finished_at DESC',
      limit: limit,
    );
    return rows
        .map(CompletedServiceRecord.fromDatabase)
        .toList(growable: false);
  }

  Future<List<CompletedServiceRecord>> listPendingSync() async {
    final database = await _database.database;
    final rows = await database.query(
      'completed_services',
      where: 'sync_status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'finished_at ASC',
    );
    return rows
        .map(CompletedServiceRecord.fromDatabase)
        .toList(growable: false);
  }

  Future<void> markSynced(String id) => _updateSync(id, 'synced');

  Future<void> markSyncFailed(String id, String reason) async {
    final database = await _database.database;
    final current = await database.query(
      'completed_services',
      columns: ['result_summary'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final summary =
        current.isEmpty ? '' : current.first['result_summary'] as String;
    await database.update(
      'completed_services',
      {
        'sync_status': 'failed',
        'result_summary': '$summary · Falha de sync: $reason',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _updateSync(String id, String status) async {
    final database = await _database.database;
    await database.update(
      'completed_services',
      {
        'sync_status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
