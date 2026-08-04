// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EquipamentosTable extends Equipamentos
    with TableInfo<$EquipamentosTable, Equipamento> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipamentosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
      'nome', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descricaoMeta =
      const VerificationMeta('descricao');
  @override
  late final GeneratedColumn<String> descricao = GeneratedColumn<String>(
      'descricao', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, nome, descricao, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipamentos';
  @override
  VerificationContext validateIntegrity(Insertable<Equipamento> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
          _nomeMeta, nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta));
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('descricao')) {
      context.handle(_descricaoMeta,
          descricao.isAcceptableOrUnknown(data['descricao']!, _descricaoMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Equipamento map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Equipamento(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nome'])!,
      descricao: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}descricao']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $EquipamentosTable createAlias(String alias) {
    return $EquipamentosTable(attachedDatabase, alias);
  }
}

class Equipamento extends DataClass implements Insertable<Equipamento> {
  final int id;
  final String nome;
  final String? descricao;
  final DateTime createdAt;
  const Equipamento(
      {required this.id,
      required this.nome,
      this.descricao,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    if (!nullToAbsent || descricao != null) {
      map['descricao'] = Variable<String>(descricao);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EquipamentosCompanion toCompanion(bool nullToAbsent) {
    return EquipamentosCompanion(
      id: Value(id),
      nome: Value(nome),
      descricao: descricao == null && nullToAbsent
          ? const Value.absent()
          : Value(descricao),
      createdAt: Value(createdAt),
    );
  }

  factory Equipamento.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Equipamento(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      descricao: serializer.fromJson<String?>(json['descricao']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'descricao': serializer.toJson<String?>(descricao),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Equipamento copyWith(
          {int? id,
          String? nome,
          Value<String?> descricao = const Value.absent(),
          DateTime? createdAt}) =>
      Equipamento(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        descricao: descricao.present ? descricao.value : this.descricao,
        createdAt: createdAt ?? this.createdAt,
      );
  Equipamento copyWithCompanion(EquipamentosCompanion data) {
    return Equipamento(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      descricao: data.descricao.present ? data.descricao.value : this.descricao,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Equipamento(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('descricao: $descricao, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, descricao, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Equipamento &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.descricao == this.descricao &&
          other.createdAt == this.createdAt);
}

class EquipamentosCompanion extends UpdateCompanion<Equipamento> {
  final Value<int> id;
  final Value<String> nome;
  final Value<String?> descricao;
  final Value<DateTime> createdAt;
  const EquipamentosCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.descricao = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EquipamentosCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    this.descricao = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : nome = Value(nome);
  static Insertable<Equipamento> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? descricao,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (descricao != null) 'descricao': descricao,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EquipamentosCompanion copyWith(
      {Value<int>? id,
      Value<String>? nome,
      Value<String?>? descricao,
      Value<DateTime>? createdAt}) {
    return EquipamentosCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (descricao.present) {
      map['descricao'] = Variable<String>(descricao.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipamentosCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('descricao: $descricao, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AntenasTable extends Antenas with TableInfo<$AntenasTable, Antena> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AntenasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _modeloMeta = const VerificationMeta('modelo');
  @override
  late final GeneratedColumn<String> modelo = GeneratedColumn<String>(
      'modelo', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _potenciaMeta =
      const VerificationMeta('potencia');
  @override
  late final GeneratedColumn<int> potencia = GeneratedColumn<int>(
      'potencia', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, modelo, potencia, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'antenas';
  @override
  VerificationContext validateIntegrity(Insertable<Antena> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('modelo')) {
      context.handle(_modeloMeta,
          modelo.isAcceptableOrUnknown(data['modelo']!, _modeloMeta));
    } else if (isInserting) {
      context.missing(_modeloMeta);
    }
    if (data.containsKey('potencia')) {
      context.handle(_potenciaMeta,
          potencia.isAcceptableOrUnknown(data['potencia']!, _potenciaMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Antena map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Antena(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      modelo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modelo'])!,
      potencia: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}potencia']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AntenasTable createAlias(String alias) {
    return $AntenasTable(attachedDatabase, alias);
  }
}

class Antena extends DataClass implements Insertable<Antena> {
  final int id;
  final String modelo;
  final int? potencia;
  final DateTime createdAt;
  const Antena(
      {required this.id,
      required this.modelo,
      this.potencia,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['modelo'] = Variable<String>(modelo);
    if (!nullToAbsent || potencia != null) {
      map['potencia'] = Variable<int>(potencia);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AntenasCompanion toCompanion(bool nullToAbsent) {
    return AntenasCompanion(
      id: Value(id),
      modelo: Value(modelo),
      potencia: potencia == null && nullToAbsent
          ? const Value.absent()
          : Value(potencia),
      createdAt: Value(createdAt),
    );
  }

  factory Antena.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Antena(
      id: serializer.fromJson<int>(json['id']),
      modelo: serializer.fromJson<String>(json['modelo']),
      potencia: serializer.fromJson<int?>(json['potencia']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'modelo': serializer.toJson<String>(modelo),
      'potencia': serializer.toJson<int?>(potencia),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Antena copyWith(
          {int? id,
          String? modelo,
          Value<int?> potencia = const Value.absent(),
          DateTime? createdAt}) =>
      Antena(
        id: id ?? this.id,
        modelo: modelo ?? this.modelo,
        potencia: potencia.present ? potencia.value : this.potencia,
        createdAt: createdAt ?? this.createdAt,
      );
  Antena copyWithCompanion(AntenasCompanion data) {
    return Antena(
      id: data.id.present ? data.id.value : this.id,
      modelo: data.modelo.present ? data.modelo.value : this.modelo,
      potencia: data.potencia.present ? data.potencia.value : this.potencia,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Antena(')
          ..write('id: $id, ')
          ..write('modelo: $modelo, ')
          ..write('potencia: $potencia, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, modelo, potencia, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Antena &&
          other.id == this.id &&
          other.modelo == this.modelo &&
          other.potencia == this.potencia &&
          other.createdAt == this.createdAt);
}

class AntenasCompanion extends UpdateCompanion<Antena> {
  final Value<int> id;
  final Value<String> modelo;
  final Value<int?> potencia;
  final Value<DateTime> createdAt;
  const AntenasCompanion({
    this.id = const Value.absent(),
    this.modelo = const Value.absent(),
    this.potencia = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AntenasCompanion.insert({
    this.id = const Value.absent(),
    required String modelo,
    this.potencia = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : modelo = Value(modelo);
  static Insertable<Antena> custom({
    Expression<int>? id,
    Expression<String>? modelo,
    Expression<int>? potencia,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modelo != null) 'modelo': modelo,
      if (potencia != null) 'potencia': potencia,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AntenasCompanion copyWith(
      {Value<int>? id,
      Value<String>? modelo,
      Value<int?>? potencia,
      Value<DateTime>? createdAt}) {
    return AntenasCompanion(
      id: id ?? this.id,
      modelo: modelo ?? this.modelo,
      potencia: potencia ?? this.potencia,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (modelo.present) {
      map['modelo'] = Variable<String>(modelo.value);
    }
    if (potencia.present) {
      map['potencia'] = Variable<int>(potencia.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AntenasCompanion(')
          ..write('id: $id, ')
          ..write('modelo: $modelo, ')
          ..write('potencia: $potencia, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TestesTable extends Testes with TableInfo<$TestesTable, Teste> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _equipamentoIdMeta =
      const VerificationMeta('equipamentoId');
  @override
  late final GeneratedColumn<int> equipamentoId = GeneratedColumn<int>(
      'equipamento_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'REFERENCES equipamentos(id) NOT NULL');
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<DateTime> data = GeneratedColumn<DateTime>(
      'data', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resultadoMeta =
      const VerificationMeta('resultado');
  @override
  late final GeneratedColumn<String> resultado = GeneratedColumn<String>(
      'resultado', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, equipamentoId, data, resultado];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'testes';
  @override
  VerificationContext validateIntegrity(Insertable<Teste> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('equipamento_id')) {
      context.handle(
          _equipamentoIdMeta,
          equipamentoId.isAcceptableOrUnknown(
              data['equipamento_id']!, _equipamentoIdMeta));
    } else if (isInserting) {
      context.missing(_equipamentoIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('resultado')) {
      context.handle(_resultadoMeta,
          resultado.isAcceptableOrUnknown(data['resultado']!, _resultadoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Teste map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Teste(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      equipamentoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}equipamento_id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}data'])!,
      resultado: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resultado']),
    );
  }

  @override
  $TestesTable createAlias(String alias) {
    return $TestesTable(attachedDatabase, alias);
  }
}

class Teste extends DataClass implements Insertable<Teste> {
  final int id;
  final int equipamentoId;
  final DateTime data;
  final String? resultado;
  const Teste(
      {required this.id,
      required this.equipamentoId,
      required this.data,
      this.resultado});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['equipamento_id'] = Variable<int>(equipamentoId);
    map['data'] = Variable<DateTime>(data);
    if (!nullToAbsent || resultado != null) {
      map['resultado'] = Variable<String>(resultado);
    }
    return map;
  }

  TestesCompanion toCompanion(bool nullToAbsent) {
    return TestesCompanion(
      id: Value(id),
      equipamentoId: Value(equipamentoId),
      data: Value(data),
      resultado: resultado == null && nullToAbsent
          ? const Value.absent()
          : Value(resultado),
    );
  }

  factory Teste.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Teste(
      id: serializer.fromJson<int>(json['id']),
      equipamentoId: serializer.fromJson<int>(json['equipamentoId']),
      data: serializer.fromJson<DateTime>(json['data']),
      resultado: serializer.fromJson<String?>(json['resultado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'equipamentoId': serializer.toJson<int>(equipamentoId),
      'data': serializer.toJson<DateTime>(data),
      'resultado': serializer.toJson<String?>(resultado),
    };
  }

  Teste copyWith(
          {int? id,
          int? equipamentoId,
          DateTime? data,
          Value<String?> resultado = const Value.absent()}) =>
      Teste(
        id: id ?? this.id,
        equipamentoId: equipamentoId ?? this.equipamentoId,
        data: data ?? this.data,
        resultado: resultado.present ? resultado.value : this.resultado,
      );
  Teste copyWithCompanion(TestesCompanion data) {
    return Teste(
      id: data.id.present ? data.id.value : this.id,
      equipamentoId: data.equipamentoId.present
          ? data.equipamentoId.value
          : this.equipamentoId,
      data: data.data.present ? data.data.value : this.data,
      resultado: data.resultado.present ? data.resultado.value : this.resultado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Teste(')
          ..write('id: $id, ')
          ..write('equipamentoId: $equipamentoId, ')
          ..write('data: $data, ')
          ..write('resultado: $resultado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, equipamentoId, data, resultado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Teste &&
          other.id == this.id &&
          other.equipamentoId == this.equipamentoId &&
          other.data == this.data &&
          other.resultado == this.resultado);
}

class TestesCompanion extends UpdateCompanion<Teste> {
  final Value<int> id;
  final Value<int> equipamentoId;
  final Value<DateTime> data;
  final Value<String?> resultado;
  const TestesCompanion({
    this.id = const Value.absent(),
    this.equipamentoId = const Value.absent(),
    this.data = const Value.absent(),
    this.resultado = const Value.absent(),
  });
  TestesCompanion.insert({
    this.id = const Value.absent(),
    required int equipamentoId,
    required DateTime data,
    this.resultado = const Value.absent(),
  })  : equipamentoId = Value(equipamentoId),
        data = Value(data);
  static Insertable<Teste> custom({
    Expression<int>? id,
    Expression<int>? equipamentoId,
    Expression<DateTime>? data,
    Expression<String>? resultado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (equipamentoId != null) 'equipamento_id': equipamentoId,
      if (data != null) 'data': data,
      if (resultado != null) 'resultado': resultado,
    });
  }

  TestesCompanion copyWith(
      {Value<int>? id,
      Value<int>? equipamentoId,
      Value<DateTime>? data,
      Value<String?>? resultado}) {
    return TestesCompanion(
      id: id ?? this.id,
      equipamentoId: equipamentoId ?? this.equipamentoId,
      data: data ?? this.data,
      resultado: resultado ?? this.resultado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (equipamentoId.present) {
      map['equipamento_id'] = Variable<int>(equipamentoId.value);
    }
    if (data.present) {
      map['data'] = Variable<DateTime>(data.value);
    }
    if (resultado.present) {
      map['resultado'] = Variable<String>(resultado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestesCompanion(')
          ..write('id: $id, ')
          ..write('equipamentoId: $equipamentoId, ')
          ..write('data: $data, ')
          ..write('resultado: $resultado')
          ..write(')'))
        .toString();
  }
}

class $UsuariosTable extends Usuarios with TableInfo<$UsuariosTable, Usuario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsuariosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
      'nome', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, nome, email, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usuarios';
  @override
  VerificationContext validateIntegrity(Insertable<Usuario> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
          _nomeMeta, nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta));
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Usuario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Usuario(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nome'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsuariosTable createAlias(String alias) {
    return $UsuariosTable(attachedDatabase, alias);
  }
}

class Usuario extends DataClass implements Insertable<Usuario> {
  final int id;
  final String nome;
  final String? email;
  final DateTime createdAt;
  const Usuario(
      {required this.id,
      required this.nome,
      this.email,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsuariosCompanion toCompanion(bool nullToAbsent) {
    return UsuariosCompanion(
      id: Value(id),
      nome: Value(nome),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      createdAt: Value(createdAt),
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Usuario(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      email: serializer.fromJson<String?>(json['email']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'email': serializer.toJson<String?>(email),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Usuario copyWith(
          {int? id,
          String? nome,
          Value<String?> email = const Value.absent(),
          DateTime? createdAt}) =>
      Usuario(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        email: email.present ? email.value : this.email,
        createdAt: createdAt ?? this.createdAt,
      );
  Usuario copyWithCompanion(UsuariosCompanion data) {
    return Usuario(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      email: data.email.present ? data.email.value : this.email,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Usuario(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, email, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Usuario &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.email == this.email &&
          other.createdAt == this.createdAt);
}

class UsuariosCompanion extends UpdateCompanion<Usuario> {
  final Value<int> id;
  final Value<String> nome;
  final Value<String?> email;
  final Value<DateTime> createdAt;
  const UsuariosCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.email = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsuariosCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    this.email = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : nome = Value(nome);
  static Insertable<Usuario> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? email,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (email != null) 'email': email,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsuariosCompanion copyWith(
      {Value<int>? id,
      Value<String>? nome,
      Value<String?>? email,
      Value<DateTime>? createdAt}) {
    return UsuariosCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsuariosCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FinanceirosTable extends Financeiros
    with TableInfo<$FinanceirosTable, Financeiro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinanceirosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<double> valor = GeneratedColumn<double>(
      'valor', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<DateTime> data = GeneratedColumn<DateTime>(
      'data', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _descricaoMeta =
      const VerificationMeta('descricao');
  @override
  late final GeneratedColumn<String> descricao = GeneratedColumn<String>(
      'descricao', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, valor, data, descricao];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'financeiros';
  @override
  VerificationContext validateIntegrity(Insertable<Financeiro> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('valor')) {
      context.handle(
          _valorMeta, valor.isAcceptableOrUnknown(data['valor']!, _valorMeta));
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('descricao')) {
      context.handle(_descricaoMeta,
          descricao.isAcceptableOrUnknown(data['descricao']!, _descricaoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Financeiro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Financeiro(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      valor: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}valor'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}data'])!,
      descricao: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}descricao']),
    );
  }

  @override
  $FinanceirosTable createAlias(String alias) {
    return $FinanceirosTable(attachedDatabase, alias);
  }
}

class Financeiro extends DataClass implements Insertable<Financeiro> {
  final int id;
  final double valor;
  final DateTime data;
  final String? descricao;
  const Financeiro(
      {required this.id,
      required this.valor,
      required this.data,
      this.descricao});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['valor'] = Variable<double>(valor);
    map['data'] = Variable<DateTime>(data);
    if (!nullToAbsent || descricao != null) {
      map['descricao'] = Variable<String>(descricao);
    }
    return map;
  }

  FinanceirosCompanion toCompanion(bool nullToAbsent) {
    return FinanceirosCompanion(
      id: Value(id),
      valor: Value(valor),
      data: Value(data),
      descricao: descricao == null && nullToAbsent
          ? const Value.absent()
          : Value(descricao),
    );
  }

  factory Financeiro.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Financeiro(
      id: serializer.fromJson<int>(json['id']),
      valor: serializer.fromJson<double>(json['valor']),
      data: serializer.fromJson<DateTime>(json['data']),
      descricao: serializer.fromJson<String?>(json['descricao']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'valor': serializer.toJson<double>(valor),
      'data': serializer.toJson<DateTime>(data),
      'descricao': serializer.toJson<String?>(descricao),
    };
  }

  Financeiro copyWith(
          {int? id,
          double? valor,
          DateTime? data,
          Value<String?> descricao = const Value.absent()}) =>
      Financeiro(
        id: id ?? this.id,
        valor: valor ?? this.valor,
        data: data ?? this.data,
        descricao: descricao.present ? descricao.value : this.descricao,
      );
  Financeiro copyWithCompanion(FinanceirosCompanion data) {
    return Financeiro(
      id: data.id.present ? data.id.value : this.id,
      valor: data.valor.present ? data.valor.value : this.valor,
      data: data.data.present ? data.data.value : this.data,
      descricao: data.descricao.present ? data.descricao.value : this.descricao,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Financeiro(')
          ..write('id: $id, ')
          ..write('valor: $valor, ')
          ..write('data: $data, ')
          ..write('descricao: $descricao')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, valor, data, descricao);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Financeiro &&
          other.id == this.id &&
          other.valor == this.valor &&
          other.data == this.data &&
          other.descricao == this.descricao);
}

class FinanceirosCompanion extends UpdateCompanion<Financeiro> {
  final Value<int> id;
  final Value<double> valor;
  final Value<DateTime> data;
  final Value<String?> descricao;
  const FinanceirosCompanion({
    this.id = const Value.absent(),
    this.valor = const Value.absent(),
    this.data = const Value.absent(),
    this.descricao = const Value.absent(),
  });
  FinanceirosCompanion.insert({
    this.id = const Value.absent(),
    required double valor,
    required DateTime data,
    this.descricao = const Value.absent(),
  })  : valor = Value(valor),
        data = Value(data);
  static Insertable<Financeiro> custom({
    Expression<int>? id,
    Expression<double>? valor,
    Expression<DateTime>? data,
    Expression<String>? descricao,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (valor != null) 'valor': valor,
      if (data != null) 'data': data,
      if (descricao != null) 'descricao': descricao,
    });
  }

  FinanceirosCompanion copyWith(
      {Value<int>? id,
      Value<double>? valor,
      Value<DateTime>? data,
      Value<String?>? descricao}) {
    return FinanceirosCompanion(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      descricao: descricao ?? this.descricao,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (valor.present) {
      map['valor'] = Variable<double>(valor.value);
    }
    if (data.present) {
      map['data'] = Variable<DateTime>(data.value);
    }
    if (descricao.present) {
      map['descricao'] = Variable<String>(descricao.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinanceirosCompanion(')
          ..write('id: $id, ')
          ..write('valor: $valor, ')
          ..write('data: $data, ')
          ..write('descricao: $descricao')
          ..write(')'))
        .toString();
  }
}

class $DeviceSessionsTableTable extends DeviceSessionsTable
    with TableInfo<$DeviceSessionsTableTable, DeviceSessionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _manufacturerMeta =
      const VerificationMeta('manufacturer');
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
      'manufacturer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _identityJsonMeta =
      const VerificationMeta('identityJson');
  @override
  late final GeneratedColumn<String> identityJson = GeneratedColumn<String>(
      'identity_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _capabilitiesJsonMeta =
      const VerificationMeta('capabilitiesJson');
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
      'capabilities_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedStateJsonMeta =
      const VerificationMeta('normalizedStateJson');
  @override
  late final GeneratedColumn<String> normalizedStateJson =
      GeneratedColumn<String>('normalized_state_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _measurementsJsonMeta =
      const VerificationMeta('measurementsJson');
  @override
  late final GeneratedColumn<String> measurementsJson = GeneratedColumn<String>(
      'measurements_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rawDataJsonMeta =
      const VerificationMeta('rawDataJson');
  @override
  late final GeneratedColumn<String> rawDataJson = GeneratedColumn<String>(
      'raw_data_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _responsesJsonMeta =
      const VerificationMeta('responsesJson');
  @override
  late final GeneratedColumn<String> responsesJson = GeneratedColumn<String>(
      'responses_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _configurationSnapshotsJsonMeta =
      const VerificationMeta('configurationSnapshotsJson');
  @override
  late final GeneratedColumn<String> configurationSnapshotsJson =
      GeneratedColumn<String>(
          'configuration_snapshots_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _diagnosticsJsonMeta =
      const VerificationMeta('diagnosticsJson');
  @override
  late final GeneratedColumn<String> diagnosticsJson = GeneratedColumn<String>(
      'diagnostics_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdateMeta =
      const VerificationMeta('lastUpdate');
  @override
  late final GeneratedColumn<DateTime> lastUpdate = GeneratedColumn<DateTime>(
      'last_update', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        manufacturer,
        identityJson,
        capabilitiesJson,
        normalizedStateJson,
        measurementsJson,
        rawDataJson,
        responsesJson,
        configurationSnapshotsJson,
        diagnosticsJson,
        createdAt,
        lastUpdate,
        isActive
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_sessions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<DeviceSessionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
          _manufacturerMeta,
          manufacturer.isAcceptableOrUnknown(
              data['manufacturer']!, _manufacturerMeta));
    } else if (isInserting) {
      context.missing(_manufacturerMeta);
    }
    if (data.containsKey('identity_json')) {
      context.handle(
          _identityJsonMeta,
          identityJson.isAcceptableOrUnknown(
              data['identity_json']!, _identityJsonMeta));
    } else if (isInserting) {
      context.missing(_identityJsonMeta);
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
          _capabilitiesJsonMeta,
          capabilitiesJson.isAcceptableOrUnknown(
              data['capabilities_json']!, _capabilitiesJsonMeta));
    } else if (isInserting) {
      context.missing(_capabilitiesJsonMeta);
    }
    if (data.containsKey('normalized_state_json')) {
      context.handle(
          _normalizedStateJsonMeta,
          normalizedStateJson.isAcceptableOrUnknown(
              data['normalized_state_json']!, _normalizedStateJsonMeta));
    } else if (isInserting) {
      context.missing(_normalizedStateJsonMeta);
    }
    if (data.containsKey('measurements_json')) {
      context.handle(
          _measurementsJsonMeta,
          measurementsJson.isAcceptableOrUnknown(
              data['measurements_json']!, _measurementsJsonMeta));
    } else if (isInserting) {
      context.missing(_measurementsJsonMeta);
    }
    if (data.containsKey('raw_data_json')) {
      context.handle(
          _rawDataJsonMeta,
          rawDataJson.isAcceptableOrUnknown(
              data['raw_data_json']!, _rawDataJsonMeta));
    } else if (isInserting) {
      context.missing(_rawDataJsonMeta);
    }
    if (data.containsKey('responses_json')) {
      context.handle(
          _responsesJsonMeta,
          responsesJson.isAcceptableOrUnknown(
              data['responses_json']!, _responsesJsonMeta));
    } else if (isInserting) {
      context.missing(_responsesJsonMeta);
    }
    if (data.containsKey('configuration_snapshots_json')) {
      context.handle(
          _configurationSnapshotsJsonMeta,
          configurationSnapshotsJson.isAcceptableOrUnknown(
              data['configuration_snapshots_json']!,
              _configurationSnapshotsJsonMeta));
    } else if (isInserting) {
      context.missing(_configurationSnapshotsJsonMeta);
    }
    if (data.containsKey('diagnostics_json')) {
      context.handle(
          _diagnosticsJsonMeta,
          diagnosticsJson.isAcceptableOrUnknown(
              data['diagnostics_json']!, _diagnosticsJsonMeta));
    } else if (isInserting) {
      context.missing(_diagnosticsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_update')) {
      context.handle(
          _lastUpdateMeta,
          lastUpdate.isAcceptableOrUnknown(
              data['last_update']!, _lastUpdateMeta));
    } else if (isInserting) {
      context.missing(_lastUpdateMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceSessionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSessionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      manufacturer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manufacturer'])!,
      identityJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identity_json'])!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}capabilities_json'])!,
      normalizedStateJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}normalized_state_json'])!,
      measurementsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}measurements_json'])!,
      rawDataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_data_json'])!,
      responsesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}responses_json'])!,
      configurationSnapshotsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}configuration_snapshots_json'])!,
      diagnosticsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}diagnostics_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_update'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $DeviceSessionsTableTable createAlias(String alias) {
    return $DeviceSessionsTableTable(attachedDatabase, alias);
  }
}

class DeviceSessionsTableData extends DataClass
    implements Insertable<DeviceSessionsTableData> {
  final String id;
  final String manufacturer;
  final String identityJson;
  final String capabilitiesJson;
  final String normalizedStateJson;
  final String measurementsJson;
  final String rawDataJson;
  final String responsesJson;
  final String configurationSnapshotsJson;
  final String diagnosticsJson;
  final DateTime createdAt;
  final DateTime lastUpdate;
  final bool isActive;
  const DeviceSessionsTableData(
      {required this.id,
      required this.manufacturer,
      required this.identityJson,
      required this.capabilitiesJson,
      required this.normalizedStateJson,
      required this.measurementsJson,
      required this.rawDataJson,
      required this.responsesJson,
      required this.configurationSnapshotsJson,
      required this.diagnosticsJson,
      required this.createdAt,
      required this.lastUpdate,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['manufacturer'] = Variable<String>(manufacturer);
    map['identity_json'] = Variable<String>(identityJson);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['normalized_state_json'] = Variable<String>(normalizedStateJson);
    map['measurements_json'] = Variable<String>(measurementsJson);
    map['raw_data_json'] = Variable<String>(rawDataJson);
    map['responses_json'] = Variable<String>(responsesJson);
    map['configuration_snapshots_json'] =
        Variable<String>(configurationSnapshotsJson);
    map['diagnostics_json'] = Variable<String>(diagnosticsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_update'] = Variable<DateTime>(lastUpdate);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  DeviceSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return DeviceSessionsTableCompanion(
      id: Value(id),
      manufacturer: Value(manufacturer),
      identityJson: Value(identityJson),
      capabilitiesJson: Value(capabilitiesJson),
      normalizedStateJson: Value(normalizedStateJson),
      measurementsJson: Value(measurementsJson),
      rawDataJson: Value(rawDataJson),
      responsesJson: Value(responsesJson),
      configurationSnapshotsJson: Value(configurationSnapshotsJson),
      diagnosticsJson: Value(diagnosticsJson),
      createdAt: Value(createdAt),
      lastUpdate: Value(lastUpdate),
      isActive: Value(isActive),
    );
  }

  factory DeviceSessionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSessionsTableData(
      id: serializer.fromJson<String>(json['id']),
      manufacturer: serializer.fromJson<String>(json['manufacturer']),
      identityJson: serializer.fromJson<String>(json['identityJson']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      normalizedStateJson:
          serializer.fromJson<String>(json['normalizedStateJson']),
      measurementsJson: serializer.fromJson<String>(json['measurementsJson']),
      rawDataJson: serializer.fromJson<String>(json['rawDataJson']),
      responsesJson: serializer.fromJson<String>(json['responsesJson']),
      configurationSnapshotsJson:
          serializer.fromJson<String>(json['configurationSnapshotsJson']),
      diagnosticsJson: serializer.fromJson<String>(json['diagnosticsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdate: serializer.fromJson<DateTime>(json['lastUpdate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'manufacturer': serializer.toJson<String>(manufacturer),
      'identityJson': serializer.toJson<String>(identityJson),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'normalizedStateJson': serializer.toJson<String>(normalizedStateJson),
      'measurementsJson': serializer.toJson<String>(measurementsJson),
      'rawDataJson': serializer.toJson<String>(rawDataJson),
      'responsesJson': serializer.toJson<String>(responsesJson),
      'configurationSnapshotsJson':
          serializer.toJson<String>(configurationSnapshotsJson),
      'diagnosticsJson': serializer.toJson<String>(diagnosticsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdate': serializer.toJson<DateTime>(lastUpdate),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  DeviceSessionsTableData copyWith(
          {String? id,
          String? manufacturer,
          String? identityJson,
          String? capabilitiesJson,
          String? normalizedStateJson,
          String? measurementsJson,
          String? rawDataJson,
          String? responsesJson,
          String? configurationSnapshotsJson,
          String? diagnosticsJson,
          DateTime? createdAt,
          DateTime? lastUpdate,
          bool? isActive}) =>
      DeviceSessionsTableData(
        id: id ?? this.id,
        manufacturer: manufacturer ?? this.manufacturer,
        identityJson: identityJson ?? this.identityJson,
        capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
        normalizedStateJson: normalizedStateJson ?? this.normalizedStateJson,
        measurementsJson: measurementsJson ?? this.measurementsJson,
        rawDataJson: rawDataJson ?? this.rawDataJson,
        responsesJson: responsesJson ?? this.responsesJson,
        configurationSnapshotsJson:
            configurationSnapshotsJson ?? this.configurationSnapshotsJson,
        diagnosticsJson: diagnosticsJson ?? this.diagnosticsJson,
        createdAt: createdAt ?? this.createdAt,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        isActive: isActive ?? this.isActive,
      );
  DeviceSessionsTableData copyWithCompanion(DeviceSessionsTableCompanion data) {
    return DeviceSessionsTableData(
      id: data.id.present ? data.id.value : this.id,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      identityJson: data.identityJson.present
          ? data.identityJson.value
          : this.identityJson,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      normalizedStateJson: data.normalizedStateJson.present
          ? data.normalizedStateJson.value
          : this.normalizedStateJson,
      measurementsJson: data.measurementsJson.present
          ? data.measurementsJson.value
          : this.measurementsJson,
      rawDataJson:
          data.rawDataJson.present ? data.rawDataJson.value : this.rawDataJson,
      responsesJson: data.responsesJson.present
          ? data.responsesJson.value
          : this.responsesJson,
      configurationSnapshotsJson: data.configurationSnapshotsJson.present
          ? data.configurationSnapshotsJson.value
          : this.configurationSnapshotsJson,
      diagnosticsJson: data.diagnosticsJson.present
          ? data.diagnosticsJson.value
          : this.diagnosticsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdate:
          data.lastUpdate.present ? data.lastUpdate.value : this.lastUpdate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSessionsTableData(')
          ..write('id: $id, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('identityJson: $identityJson, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('normalizedStateJson: $normalizedStateJson, ')
          ..write('measurementsJson: $measurementsJson, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('responsesJson: $responsesJson, ')
          ..write('configurationSnapshotsJson: $configurationSnapshotsJson, ')
          ..write('diagnosticsJson: $diagnosticsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdate: $lastUpdate, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      manufacturer,
      identityJson,
      capabilitiesJson,
      normalizedStateJson,
      measurementsJson,
      rawDataJson,
      responsesJson,
      configurationSnapshotsJson,
      diagnosticsJson,
      createdAt,
      lastUpdate,
      isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSessionsTableData &&
          other.id == this.id &&
          other.manufacturer == this.manufacturer &&
          other.identityJson == this.identityJson &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.normalizedStateJson == this.normalizedStateJson &&
          other.measurementsJson == this.measurementsJson &&
          other.rawDataJson == this.rawDataJson &&
          other.responsesJson == this.responsesJson &&
          other.configurationSnapshotsJson == this.configurationSnapshotsJson &&
          other.diagnosticsJson == this.diagnosticsJson &&
          other.createdAt == this.createdAt &&
          other.lastUpdate == this.lastUpdate &&
          other.isActive == this.isActive);
}

class DeviceSessionsTableCompanion
    extends UpdateCompanion<DeviceSessionsTableData> {
  final Value<String> id;
  final Value<String> manufacturer;
  final Value<String> identityJson;
  final Value<String> capabilitiesJson;
  final Value<String> normalizedStateJson;
  final Value<String> measurementsJson;
  final Value<String> rawDataJson;
  final Value<String> responsesJson;
  final Value<String> configurationSnapshotsJson;
  final Value<String> diagnosticsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUpdate;
  final Value<bool> isActive;
  final Value<int> rowid;
  const DeviceSessionsTableCompanion({
    this.id = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.identityJson = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.normalizedStateJson = const Value.absent(),
    this.measurementsJson = const Value.absent(),
    this.rawDataJson = const Value.absent(),
    this.responsesJson = const Value.absent(),
    this.configurationSnapshotsJson = const Value.absent(),
    this.diagnosticsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSessionsTableCompanion.insert({
    required String id,
    required String manufacturer,
    required String identityJson,
    required String capabilitiesJson,
    required String normalizedStateJson,
    required String measurementsJson,
    required String rawDataJson,
    required String responsesJson,
    required String configurationSnapshotsJson,
    required String diagnosticsJson,
    required DateTime createdAt,
    required DateTime lastUpdate,
    required bool isActive,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        manufacturer = Value(manufacturer),
        identityJson = Value(identityJson),
        capabilitiesJson = Value(capabilitiesJson),
        normalizedStateJson = Value(normalizedStateJson),
        measurementsJson = Value(measurementsJson),
        rawDataJson = Value(rawDataJson),
        responsesJson = Value(responsesJson),
        configurationSnapshotsJson = Value(configurationSnapshotsJson),
        diagnosticsJson = Value(diagnosticsJson),
        createdAt = Value(createdAt),
        lastUpdate = Value(lastUpdate),
        isActive = Value(isActive);
  static Insertable<DeviceSessionsTableData> custom({
    Expression<String>? id,
    Expression<String>? manufacturer,
    Expression<String>? identityJson,
    Expression<String>? capabilitiesJson,
    Expression<String>? normalizedStateJson,
    Expression<String>? measurementsJson,
    Expression<String>? rawDataJson,
    Expression<String>? responsesJson,
    Expression<String>? configurationSnapshotsJson,
    Expression<String>? diagnosticsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdate,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (identityJson != null) 'identity_json': identityJson,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (normalizedStateJson != null)
        'normalized_state_json': normalizedStateJson,
      if (measurementsJson != null) 'measurements_json': measurementsJson,
      if (rawDataJson != null) 'raw_data_json': rawDataJson,
      if (responsesJson != null) 'responses_json': responsesJson,
      if (configurationSnapshotsJson != null)
        'configuration_snapshots_json': configurationSnapshotsJson,
      if (diagnosticsJson != null) 'diagnostics_json': diagnosticsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdate != null) 'last_update': lastUpdate,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSessionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? manufacturer,
      Value<String>? identityJson,
      Value<String>? capabilitiesJson,
      Value<String>? normalizedStateJson,
      Value<String>? measurementsJson,
      Value<String>? rawDataJson,
      Value<String>? responsesJson,
      Value<String>? configurationSnapshotsJson,
      Value<String>? diagnosticsJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastUpdate,
      Value<bool>? isActive,
      Value<int>? rowid}) {
    return DeviceSessionsTableCompanion(
      id: id ?? this.id,
      manufacturer: manufacturer ?? this.manufacturer,
      identityJson: identityJson ?? this.identityJson,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      normalizedStateJson: normalizedStateJson ?? this.normalizedStateJson,
      measurementsJson: measurementsJson ?? this.measurementsJson,
      rawDataJson: rawDataJson ?? this.rawDataJson,
      responsesJson: responsesJson ?? this.responsesJson,
      configurationSnapshotsJson:
          configurationSnapshotsJson ?? this.configurationSnapshotsJson,
      diagnosticsJson: diagnosticsJson ?? this.diagnosticsJson,
      createdAt: createdAt ?? this.createdAt,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (identityJson.present) {
      map['identity_json'] = Variable<String>(identityJson.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (normalizedStateJson.present) {
      map['normalized_state_json'] =
          Variable<String>(normalizedStateJson.value);
    }
    if (measurementsJson.present) {
      map['measurements_json'] = Variable<String>(measurementsJson.value);
    }
    if (rawDataJson.present) {
      map['raw_data_json'] = Variable<String>(rawDataJson.value);
    }
    if (responsesJson.present) {
      map['responses_json'] = Variable<String>(responsesJson.value);
    }
    if (configurationSnapshotsJson.present) {
      map['configuration_snapshots_json'] =
          Variable<String>(configurationSnapshotsJson.value);
    }
    if (diagnosticsJson.present) {
      map['diagnostics_json'] = Variable<String>(diagnosticsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdate.present) {
      map['last_update'] = Variable<DateTime>(lastUpdate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('identityJson: $identityJson, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('normalizedStateJson: $normalizedStateJson, ')
          ..write('measurementsJson: $measurementsJson, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('responsesJson: $responsesJson, ')
          ..write('configurationSnapshotsJson: $configurationSnapshotsJson, ')
          ..write('diagnosticsJson: $diagnosticsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdate: $lastUpdate, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EquipamentosTable equipamentos = $EquipamentosTable(this);
  late final $AntenasTable antenas = $AntenasTable(this);
  late final $TestesTable testes = $TestesTable(this);
  late final $UsuariosTable usuarios = $UsuariosTable(this);
  late final $FinanceirosTable financeiros = $FinanceirosTable(this);
  late final $DeviceSessionsTableTable deviceSessionsTable =
      $DeviceSessionsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        equipamentos,
        antenas,
        testes,
        usuarios,
        financeiros,
        deviceSessionsTable
      ];
}

typedef $$EquipamentosTableCreateCompanionBuilder = EquipamentosCompanion
    Function({
  Value<int> id,
  required String nome,
  Value<String?> descricao,
  Value<DateTime> createdAt,
});
typedef $$EquipamentosTableUpdateCompanionBuilder = EquipamentosCompanion
    Function({
  Value<int> id,
  Value<String> nome,
  Value<String?> descricao,
  Value<DateTime> createdAt,
});

final class $$EquipamentosTableReferences
    extends BaseReferences<_$AppDatabase, $EquipamentosTable, Equipamento> {
  $$EquipamentosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TestesTable, List<Teste>> _testesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.testes,
          aliasName: $_aliasNameGenerator(
              db.equipamentos.id, db.testes.equipamentoId));

  $$TestesTableProcessedTableManager get testesRefs {
    final manager = $$TestesTableTableManager($_db, $_db.testes)
        .filter((f) => f.equipamentoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_testesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$EquipamentosTableFilterComposer
    extends Composer<_$AppDatabase, $EquipamentosTable> {
  $$EquipamentosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> testesRefs(
      Expression<bool> Function($$TestesTableFilterComposer f) f) {
    final $$TestesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testes,
        getReferencedColumn: (t) => t.equipamentoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestesTableFilterComposer(
              $db: $db,
              $table: $db.testes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$EquipamentosTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipamentosTable> {
  $$EquipamentosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$EquipamentosTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipamentosTable> {
  $$EquipamentosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get descricao =>
      $composableBuilder(column: $table.descricao, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> testesRefs<T extends Object>(
      Expression<T> Function($$TestesTableAnnotationComposer a) f) {
    final $$TestesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testes,
        getReferencedColumn: (t) => t.equipamentoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestesTableAnnotationComposer(
              $db: $db,
              $table: $db.testes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$EquipamentosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EquipamentosTable,
    Equipamento,
    $$EquipamentosTableFilterComposer,
    $$EquipamentosTableOrderingComposer,
    $$EquipamentosTableAnnotationComposer,
    $$EquipamentosTableCreateCompanionBuilder,
    $$EquipamentosTableUpdateCompanionBuilder,
    (Equipamento, $$EquipamentosTableReferences),
    Equipamento,
    PrefetchHooks Function({bool testesRefs})> {
  $$EquipamentosTableTableManager(_$AppDatabase db, $EquipamentosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipamentosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipamentosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipamentosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nome = const Value.absent(),
            Value<String?> descricao = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              EquipamentosCompanion(
            id: id,
            nome: nome,
            descricao: descricao,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nome,
            Value<String?> descricao = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              EquipamentosCompanion.insert(
            id: id,
            nome: nome,
            descricao: descricao,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$EquipamentosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({testesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (testesRefs) db.testes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (testesRefs)
                    await $_getPrefetchedData<Equipamento, $EquipamentosTable,
                            Teste>(
                        currentTable: table,
                        referencedTable:
                            $$EquipamentosTableReferences._testesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$EquipamentosTableReferences(db, table, p0)
                                .testesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.equipamentoId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$EquipamentosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EquipamentosTable,
    Equipamento,
    $$EquipamentosTableFilterComposer,
    $$EquipamentosTableOrderingComposer,
    $$EquipamentosTableAnnotationComposer,
    $$EquipamentosTableCreateCompanionBuilder,
    $$EquipamentosTableUpdateCompanionBuilder,
    (Equipamento, $$EquipamentosTableReferences),
    Equipamento,
    PrefetchHooks Function({bool testesRefs})>;
typedef $$AntenasTableCreateCompanionBuilder = AntenasCompanion Function({
  Value<int> id,
  required String modelo,
  Value<int?> potencia,
  Value<DateTime> createdAt,
});
typedef $$AntenasTableUpdateCompanionBuilder = AntenasCompanion Function({
  Value<int> id,
  Value<String> modelo,
  Value<int?> potencia,
  Value<DateTime> createdAt,
});

class $$AntenasTableFilterComposer
    extends Composer<_$AppDatabase, $AntenasTable> {
  $$AntenasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelo => $composableBuilder(
      column: $table.modelo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get potencia => $composableBuilder(
      column: $table.potencia, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AntenasTableOrderingComposer
    extends Composer<_$AppDatabase, $AntenasTable> {
  $$AntenasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelo => $composableBuilder(
      column: $table.modelo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get potencia => $composableBuilder(
      column: $table.potencia, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AntenasTableAnnotationComposer
    extends Composer<_$AppDatabase, $AntenasTable> {
  $$AntenasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelo =>
      $composableBuilder(column: $table.modelo, builder: (column) => column);

  GeneratedColumn<int> get potencia =>
      $composableBuilder(column: $table.potencia, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AntenasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AntenasTable,
    Antena,
    $$AntenasTableFilterComposer,
    $$AntenasTableOrderingComposer,
    $$AntenasTableAnnotationComposer,
    $$AntenasTableCreateCompanionBuilder,
    $$AntenasTableUpdateCompanionBuilder,
    (Antena, BaseReferences<_$AppDatabase, $AntenasTable, Antena>),
    Antena,
    PrefetchHooks Function()> {
  $$AntenasTableTableManager(_$AppDatabase db, $AntenasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AntenasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AntenasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AntenasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> modelo = const Value.absent(),
            Value<int?> potencia = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AntenasCompanion(
            id: id,
            modelo: modelo,
            potencia: potencia,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String modelo,
            Value<int?> potencia = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AntenasCompanion.insert(
            id: id,
            modelo: modelo,
            potencia: potencia,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AntenasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AntenasTable,
    Antena,
    $$AntenasTableFilterComposer,
    $$AntenasTableOrderingComposer,
    $$AntenasTableAnnotationComposer,
    $$AntenasTableCreateCompanionBuilder,
    $$AntenasTableUpdateCompanionBuilder,
    (Antena, BaseReferences<_$AppDatabase, $AntenasTable, Antena>),
    Antena,
    PrefetchHooks Function()>;
typedef $$TestesTableCreateCompanionBuilder = TestesCompanion Function({
  Value<int> id,
  required int equipamentoId,
  required DateTime data,
  Value<String?> resultado,
});
typedef $$TestesTableUpdateCompanionBuilder = TestesCompanion Function({
  Value<int> id,
  Value<int> equipamentoId,
  Value<DateTime> data,
  Value<String?> resultado,
});

final class $$TestesTableReferences
    extends BaseReferences<_$AppDatabase, $TestesTable, Teste> {
  $$TestesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EquipamentosTable _equipamentoIdTable(_$AppDatabase db) =>
      db.equipamentos.createAlias(
          $_aliasNameGenerator(db.testes.equipamentoId, db.equipamentos.id));

  $$EquipamentosTableProcessedTableManager get equipamentoId {
    final $_column = $_itemColumn<int>('equipamento_id')!;

    final manager = $$EquipamentosTableTableManager($_db, $_db.equipamentos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_equipamentoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TestesTableFilterComposer
    extends Composer<_$AppDatabase, $TestesTable> {
  $$TestesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultado => $composableBuilder(
      column: $table.resultado, builder: (column) => ColumnFilters(column));

  $$EquipamentosTableFilterComposer get equipamentoId {
    final $$EquipamentosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.equipamentoId,
        referencedTable: $db.equipamentos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EquipamentosTableFilterComposer(
              $db: $db,
              $table: $db.equipamentos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestesTableOrderingComposer
    extends Composer<_$AppDatabase, $TestesTable> {
  $$TestesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultado => $composableBuilder(
      column: $table.resultado, builder: (column) => ColumnOrderings(column));

  $$EquipamentosTableOrderingComposer get equipamentoId {
    final $$EquipamentosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.equipamentoId,
        referencedTable: $db.equipamentos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EquipamentosTableOrderingComposer(
              $db: $db,
              $table: $db.equipamentos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestesTable> {
  $$TestesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get resultado =>
      $composableBuilder(column: $table.resultado, builder: (column) => column);

  $$EquipamentosTableAnnotationComposer get equipamentoId {
    final $$EquipamentosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.equipamentoId,
        referencedTable: $db.equipamentos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EquipamentosTableAnnotationComposer(
              $db: $db,
              $table: $db.equipamentos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestesTable,
    Teste,
    $$TestesTableFilterComposer,
    $$TestesTableOrderingComposer,
    $$TestesTableAnnotationComposer,
    $$TestesTableCreateCompanionBuilder,
    $$TestesTableUpdateCompanionBuilder,
    (Teste, $$TestesTableReferences),
    Teste,
    PrefetchHooks Function({bool equipamentoId})> {
  $$TestesTableTableManager(_$AppDatabase db, $TestesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> equipamentoId = const Value.absent(),
            Value<DateTime> data = const Value.absent(),
            Value<String?> resultado = const Value.absent(),
          }) =>
              TestesCompanion(
            id: id,
            equipamentoId: equipamentoId,
            data: data,
            resultado: resultado,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int equipamentoId,
            required DateTime data,
            Value<String?> resultado = const Value.absent(),
          }) =>
              TestesCompanion.insert(
            id: id,
            equipamentoId: equipamentoId,
            data: data,
            resultado: resultado,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TestesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({equipamentoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (equipamentoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.equipamentoId,
                    referencedTable:
                        $$TestesTableReferences._equipamentoIdTable(db),
                    referencedColumn:
                        $$TestesTableReferences._equipamentoIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TestesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TestesTable,
    Teste,
    $$TestesTableFilterComposer,
    $$TestesTableOrderingComposer,
    $$TestesTableAnnotationComposer,
    $$TestesTableCreateCompanionBuilder,
    $$TestesTableUpdateCompanionBuilder,
    (Teste, $$TestesTableReferences),
    Teste,
    PrefetchHooks Function({bool equipamentoId})>;
typedef $$UsuariosTableCreateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  required String nome,
  Value<String?> email,
  Value<DateTime> createdAt,
});
typedef $$UsuariosTableUpdateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  Value<String> nome,
  Value<String?> email,
  Value<DateTime> createdAt,
});

class $$UsuariosTableFilterComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UsuariosTableOrderingComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsuariosTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsuariosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, BaseReferences<_$AppDatabase, $UsuariosTable, Usuario>),
    Usuario,
    PrefetchHooks Function()> {
  $$UsuariosTableTableManager(_$AppDatabase db, $UsuariosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsuariosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsuariosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsuariosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nome = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsuariosCompanion(
            id: id,
            nome: nome,
            email: email,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nome,
            Value<String?> email = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsuariosCompanion.insert(
            id: id,
            nome: nome,
            email: email,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsuariosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, BaseReferences<_$AppDatabase, $UsuariosTable, Usuario>),
    Usuario,
    PrefetchHooks Function()>;
typedef $$FinanceirosTableCreateCompanionBuilder = FinanceirosCompanion
    Function({
  Value<int> id,
  required double valor,
  required DateTime data,
  Value<String?> descricao,
});
typedef $$FinanceirosTableUpdateCompanionBuilder = FinanceirosCompanion
    Function({
  Value<int> id,
  Value<double> valor,
  Value<DateTime> data,
  Value<String?> descricao,
});

class $$FinanceirosTableFilterComposer
    extends Composer<_$AppDatabase, $FinanceirosTable> {
  $$FinanceirosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get valor => $composableBuilder(
      column: $table.valor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnFilters(column));
}

class $$FinanceirosTableOrderingComposer
    extends Composer<_$AppDatabase, $FinanceirosTable> {
  $$FinanceirosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get valor => $composableBuilder(
      column: $table.valor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnOrderings(column));
}

class $$FinanceirosTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinanceirosTable> {
  $$FinanceirosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);

  GeneratedColumn<DateTime> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get descricao =>
      $composableBuilder(column: $table.descricao, builder: (column) => column);
}

class $$FinanceirosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FinanceirosTable,
    Financeiro,
    $$FinanceirosTableFilterComposer,
    $$FinanceirosTableOrderingComposer,
    $$FinanceirosTableAnnotationComposer,
    $$FinanceirosTableCreateCompanionBuilder,
    $$FinanceirosTableUpdateCompanionBuilder,
    (Financeiro, BaseReferences<_$AppDatabase, $FinanceirosTable, Financeiro>),
    Financeiro,
    PrefetchHooks Function()> {
  $$FinanceirosTableTableManager(_$AppDatabase db, $FinanceirosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinanceirosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinanceirosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinanceirosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<double> valor = const Value.absent(),
            Value<DateTime> data = const Value.absent(),
            Value<String?> descricao = const Value.absent(),
          }) =>
              FinanceirosCompanion(
            id: id,
            valor: valor,
            data: data,
            descricao: descricao,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required double valor,
            required DateTime data,
            Value<String?> descricao = const Value.absent(),
          }) =>
              FinanceirosCompanion.insert(
            id: id,
            valor: valor,
            data: data,
            descricao: descricao,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FinanceirosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FinanceirosTable,
    Financeiro,
    $$FinanceirosTableFilterComposer,
    $$FinanceirosTableOrderingComposer,
    $$FinanceirosTableAnnotationComposer,
    $$FinanceirosTableCreateCompanionBuilder,
    $$FinanceirosTableUpdateCompanionBuilder,
    (Financeiro, BaseReferences<_$AppDatabase, $FinanceirosTable, Financeiro>),
    Financeiro,
    PrefetchHooks Function()>;
typedef $$DeviceSessionsTableTableCreateCompanionBuilder
    = DeviceSessionsTableCompanion Function({
  required String id,
  required String manufacturer,
  required String identityJson,
  required String capabilitiesJson,
  required String normalizedStateJson,
  required String measurementsJson,
  required String rawDataJson,
  required String responsesJson,
  required String configurationSnapshotsJson,
  required String diagnosticsJson,
  required DateTime createdAt,
  required DateTime lastUpdate,
  required bool isActive,
  Value<int> rowid,
});
typedef $$DeviceSessionsTableTableUpdateCompanionBuilder
    = DeviceSessionsTableCompanion Function({
  Value<String> id,
  Value<String> manufacturer,
  Value<String> identityJson,
  Value<String> capabilitiesJson,
  Value<String> normalizedStateJson,
  Value<String> measurementsJson,
  Value<String> rawDataJson,
  Value<String> responsesJson,
  Value<String> configurationSnapshotsJson,
  Value<String> diagnosticsJson,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdate,
  Value<bool> isActive,
  Value<int> rowid,
});

class $$DeviceSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTableTable> {
  $$DeviceSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get identityJson => $composableBuilder(
      column: $table.identityJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
      column: $table.capabilitiesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedStateJson => $composableBuilder(
      column: $table.normalizedStateJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get measurementsJson => $composableBuilder(
      column: $table.measurementsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get responsesJson => $composableBuilder(
      column: $table.responsesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get configurationSnapshotsJson => $composableBuilder(
      column: $table.configurationSnapshotsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diagnosticsJson => $composableBuilder(
      column: $table.diagnosticsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
}

class $$DeviceSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTableTable> {
  $$DeviceSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get identityJson => $composableBuilder(
      column: $table.identityJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
      column: $table.capabilitiesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedStateJson => $composableBuilder(
      column: $table.normalizedStateJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get measurementsJson => $composableBuilder(
      column: $table.measurementsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get responsesJson => $composableBuilder(
      column: $table.responsesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get configurationSnapshotsJson => $composableBuilder(
      column: $table.configurationSnapshotsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diagnosticsJson => $composableBuilder(
      column: $table.diagnosticsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$DeviceSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTableTable> {
  $$DeviceSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer, builder: (column) => column);

  GeneratedColumn<String> get identityJson => $composableBuilder(
      column: $table.identityJson, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
      column: $table.capabilitiesJson, builder: (column) => column);

  GeneratedColumn<String> get normalizedStateJson => $composableBuilder(
      column: $table.normalizedStateJson, builder: (column) => column);

  GeneratedColumn<String> get measurementsJson => $composableBuilder(
      column: $table.measurementsJson, builder: (column) => column);

  GeneratedColumn<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => column);

  GeneratedColumn<String> get responsesJson => $composableBuilder(
      column: $table.responsesJson, builder: (column) => column);

  GeneratedColumn<String> get configurationSnapshotsJson => $composableBuilder(
      column: $table.configurationSnapshotsJson, builder: (column) => column);

  GeneratedColumn<String> get diagnosticsJson => $composableBuilder(
      column: $table.diagnosticsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$DeviceSessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeviceSessionsTableTable,
    DeviceSessionsTableData,
    $$DeviceSessionsTableTableFilterComposer,
    $$DeviceSessionsTableTableOrderingComposer,
    $$DeviceSessionsTableTableAnnotationComposer,
    $$DeviceSessionsTableTableCreateCompanionBuilder,
    $$DeviceSessionsTableTableUpdateCompanionBuilder,
    (
      DeviceSessionsTableData,
      BaseReferences<_$AppDatabase, $DeviceSessionsTableTable,
          DeviceSessionsTableData>
    ),
    DeviceSessionsTableData,
    PrefetchHooks Function()> {
  $$DeviceSessionsTableTableTableManager(
      _$AppDatabase db, $DeviceSessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSessionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSessionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> manufacturer = const Value.absent(),
            Value<String> identityJson = const Value.absent(),
            Value<String> capabilitiesJson = const Value.absent(),
            Value<String> normalizedStateJson = const Value.absent(),
            Value<String> measurementsJson = const Value.absent(),
            Value<String> rawDataJson = const Value.absent(),
            Value<String> responsesJson = const Value.absent(),
            Value<String> configurationSnapshotsJson = const Value.absent(),
            Value<String> diagnosticsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdate = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceSessionsTableCompanion(
            id: id,
            manufacturer: manufacturer,
            identityJson: identityJson,
            capabilitiesJson: capabilitiesJson,
            normalizedStateJson: normalizedStateJson,
            measurementsJson: measurementsJson,
            rawDataJson: rawDataJson,
            responsesJson: responsesJson,
            configurationSnapshotsJson: configurationSnapshotsJson,
            diagnosticsJson: diagnosticsJson,
            createdAt: createdAt,
            lastUpdate: lastUpdate,
            isActive: isActive,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String manufacturer,
            required String identityJson,
            required String capabilitiesJson,
            required String normalizedStateJson,
            required String measurementsJson,
            required String rawDataJson,
            required String responsesJson,
            required String configurationSnapshotsJson,
            required String diagnosticsJson,
            required DateTime createdAt,
            required DateTime lastUpdate,
            required bool isActive,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceSessionsTableCompanion.insert(
            id: id,
            manufacturer: manufacturer,
            identityJson: identityJson,
            capabilitiesJson: capabilitiesJson,
            normalizedStateJson: normalizedStateJson,
            measurementsJson: measurementsJson,
            rawDataJson: rawDataJson,
            responsesJson: responsesJson,
            configurationSnapshotsJson: configurationSnapshotsJson,
            diagnosticsJson: diagnosticsJson,
            createdAt: createdAt,
            lastUpdate: lastUpdate,
            isActive: isActive,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeviceSessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeviceSessionsTableTable,
    DeviceSessionsTableData,
    $$DeviceSessionsTableTableFilterComposer,
    $$DeviceSessionsTableTableOrderingComposer,
    $$DeviceSessionsTableTableAnnotationComposer,
    $$DeviceSessionsTableTableCreateCompanionBuilder,
    $$DeviceSessionsTableTableUpdateCompanionBuilder,
    (
      DeviceSessionsTableData,
      BaseReferences<_$AppDatabase, $DeviceSessionsTableTable,
          DeviceSessionsTableData>
    ),
    DeviceSessionsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EquipamentosTableTableManager get equipamentos =>
      $$EquipamentosTableTableManager(_db, _db.equipamentos);
  $$AntenasTableTableManager get antenas =>
      $$AntenasTableTableManager(_db, _db.antenas);
  $$TestesTableTableManager get testes =>
      $$TestesTableTableManager(_db, _db.testes);
  $$UsuariosTableTableManager get usuarios =>
      $$UsuariosTableTableManager(_db, _db.usuarios);
  $$FinanceirosTableTableManager get financeiros =>
      $$FinanceirosTableTableManager(_db, _db.financeiros);
  $$DeviceSessionsTableTableTableManager get deviceSessionsTable =>
      $$DeviceSessionsTableTableTableManager(_db, _db.deviceSessionsTable);
}
