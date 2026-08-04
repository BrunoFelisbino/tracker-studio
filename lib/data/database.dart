// lib/data/database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

// Define tables
class Equipamentos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text().withLength(min: 1, max: 100)();
  TextColumn get descricao => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Antenas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get modelo => text().withLength(min: 1, max: 100)();
  IntColumn get potencia => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Testes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get equipamentoId =>
      integer().customConstraint('REFERENCES equipamentos(id) NOT NULL')();
  DateTimeColumn get data => dateTime()();
  TextColumn get resultado => text().nullable()();
}

class Usuarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Financeiros extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get valor => real()();
  DateTimeColumn get data => dateTime()();
  TextColumn get descricao => text().nullable()();
}

@DriftDatabase(tables: [Equipamentos, Antenas, Testes, Usuarios, Financeiros])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Example CRUD operations
  Future<int> insertEquipamento(EquipamentosCompanion entry) =>
      into(equipamentos).insert(entry);
  Future<List<Equipamento>> getAllEquipamentos() => select(equipamentos).get();

  Future<int> insertAntena(AntenasCompanion entry) =>
      into(antenas).insert(entry);
  Future<List<Antena>> getAllAntenas() => select(antenas).get();

  Future<int> insertTeste(TestesCompanion entry) => into(testes).insert(entry);
  Future<List<Teste>> getAllTestes() => select(testes).get();

  Future<int> insertUsuario(UsuariosCompanion entry) =>
      into(usuarios).insert(entry);
  Future<List<Usuario>> getAllUsuarios() => select(usuarios).get();

  Future<int> insertFinanceiro(FinanceirosCompanion entry) =>
      into(financeiros).insert(entry);
  Future<List<Financeiro>> getAllFinanceiros() => select(financeiros).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tracker_studio.sqlite'));
    return NativeDatabase(file);
  });
}
