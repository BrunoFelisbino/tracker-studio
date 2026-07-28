import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalServiceDatabase {
  final DatabaseFactory _factory;
  final Future<String> Function() _pathResolver;
  Database? _database;

  LocalServiceDatabase({
    DatabaseFactory? factory,
    Future<String> Function()? pathResolver,
  })  : _factory = factory ?? databaseFactoryFfi,
        _pathResolver = pathResolver ?? _defaultPath;

  static LocalServiceDatabase createDefault() {
    sqfliteFfiInit();
    return LocalServiceDatabase();
  }

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    final databasePath = await _pathResolver();
    _database = await _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE completed_services (
              id TEXT PRIMARY KEY,
              work_order_id TEXT NULL,
              customer_name TEXT NOT NULL,
              plate TEXT NOT NULL,
              service_type TEXT NOT NULL,
              vehicle_brand TEXT NULL,
              vehicle_model TEXT NULL,
              started_at TEXT NOT NULL,
              finished_at TEXT NOT NULL,
              status TEXT NOT NULL,
              result_summary TEXT NOT NULL,
              sync_status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await database.execute(
              'CREATE INDEX idx_completed_services_plate ON completed_services(plate)');
          await database.execute(
              'CREATE INDEX idx_completed_services_customer ON completed_services(customer_name)');
          await database.execute(
              'CREATE INDEX idx_completed_services_finished ON completed_services(finished_at)');
          await database.execute(
              'CREATE INDEX idx_completed_services_sync ON completed_services(sync_status)');
        },
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current?.isOpen == true) await current!.close();
  }

  static Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    return path.join(directory.path, 'tracker_studio_services.sqlite');
  }
}
