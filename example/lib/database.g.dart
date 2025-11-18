// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mtdsLastUpdatedTxidMeta =
      const VerificationMeta('mtdsLastUpdatedTxid');
  @override
  late final GeneratedColumn<int> mtdsLastUpdatedTxid = GeneratedColumn<int>(
    'mtds_last_updated_txid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtdsDeviceIdMeta = const VerificationMeta(
    'mtdsDeviceId',
  );
  @override
  late final GeneratedColumn<int> mtdsDeviceId = GeneratedColumn<int>(
    'mtds_device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtdsDeletedTxidMeta = const VerificationMeta(
    'mtdsDeletedTxid',
  );
  @override
  late final GeneratedColumn<int> mtdsDeletedTxid = GeneratedColumn<int>(
    'mtds_deleted_txid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mtdsLastUpdatedTxid,
    mtdsDeviceId,
    mtdsDeletedTxid,
    id,
    name,
    email,
    age,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mtds_last_updated_txid')) {
      context.handle(
        _mtdsLastUpdatedTxidMeta,
        mtdsLastUpdatedTxid.isAcceptableOrUnknown(
          data['mtds_last_updated_txid']!,
          _mtdsLastUpdatedTxidMeta,
        ),
      );
    }
    if (data.containsKey('mtds_device_id')) {
      context.handle(
        _mtdsDeviceIdMeta,
        mtdsDeviceId.isAcceptableOrUnknown(
          data['mtds_device_id']!,
          _mtdsDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('mtds_deleted_txid')) {
      context.handle(
        _mtdsDeletedTxidMeta,
        mtdsDeletedTxid.isAcceptableOrUnknown(
          data['mtds_deleted_txid']!,
          _mtdsDeletedTxidMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      mtdsLastUpdatedTxid:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}mtds_last_updated_txid'],
          )!,
      mtdsDeviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}mtds_device_id'],
          )!,
      mtdsDeletedTxid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtds_deleted_txid'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      email:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}email'],
          )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  /// UTC nanosecond timestamp of the last write (client-generated).
  /// Always present with a default of 0 so change detection never hits NULL.
  final int mtdsLastUpdatedTxid;

  /// 48-bit device identifier used for replication guardrails.
  /// Always present with a default of 0; SDK overwrites it on each write.
  final int mtdsDeviceId;

  /// Soft-delete marker (NULL = active, non-null = deleted at TXID)
  final int? mtdsDeletedTxid;
  final int id;
  final String name;
  final String email;
  final int? age;
  const User({
    required this.mtdsLastUpdatedTxid,
    required this.mtdsDeviceId,
    this.mtdsDeletedTxid,
    required this.id,
    required this.name,
    required this.email,
    this.age,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mtds_last_updated_txid'] = Variable<int>(mtdsLastUpdatedTxid);
    map['mtds_device_id'] = Variable<int>(mtdsDeviceId);
    if (!nullToAbsent || mtdsDeletedTxid != null) {
      map['mtds_deleted_txid'] = Variable<int>(mtdsDeletedTxid);
    }
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      mtdsLastUpdatedTxid: Value(mtdsLastUpdatedTxid),
      mtdsDeviceId: Value(mtdsDeviceId),
      mtdsDeletedTxid:
          mtdsDeletedTxid == null && nullToAbsent
              ? const Value.absent()
              : Value(mtdsDeletedTxid),
      id: Value(id),
      name: Value(name),
      email: Value(email),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      mtdsLastUpdatedTxid: serializer.fromJson<int>(
        json['mtdsLastUpdatedTxid'],
      ),
      mtdsDeviceId: serializer.fromJson<int>(json['mtdsDeviceId']),
      mtdsDeletedTxid: serializer.fromJson<int?>(json['mtdsDeletedTxid']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String>(json['email']),
      age: serializer.fromJson<int?>(json['age']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mtdsLastUpdatedTxid': serializer.toJson<int>(mtdsLastUpdatedTxid),
      'mtdsDeviceId': serializer.toJson<int>(mtdsDeviceId),
      'mtdsDeletedTxid': serializer.toJson<int?>(mtdsDeletedTxid),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String>(email),
      'age': serializer.toJson<int?>(age),
    };
  }

  User copyWith({
    int? mtdsLastUpdatedTxid,
    int? mtdsDeviceId,
    Value<int?> mtdsDeletedTxid = const Value.absent(),
    int? id,
    String? name,
    String? email,
    Value<int?> age = const Value.absent(),
  }) => User(
    mtdsLastUpdatedTxid: mtdsLastUpdatedTxid ?? this.mtdsLastUpdatedTxid,
    mtdsDeviceId: mtdsDeviceId ?? this.mtdsDeviceId,
    mtdsDeletedTxid:
        mtdsDeletedTxid.present ? mtdsDeletedTxid.value : this.mtdsDeletedTxid,
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    age: age.present ? age.value : this.age,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      mtdsLastUpdatedTxid:
          data.mtdsLastUpdatedTxid.present
              ? data.mtdsLastUpdatedTxid.value
              : this.mtdsLastUpdatedTxid,
      mtdsDeviceId:
          data.mtdsDeviceId.present
              ? data.mtdsDeviceId.value
              : this.mtdsDeviceId,
      mtdsDeletedTxid:
          data.mtdsDeletedTxid.present
              ? data.mtdsDeletedTxid.value
              : this.mtdsDeletedTxid,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      age: data.age.present ? data.age.value : this.age,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('mtdsLastUpdatedTxid: $mtdsLastUpdatedTxid, ')
          ..write('mtdsDeviceId: $mtdsDeviceId, ')
          ..write('mtdsDeletedTxid: $mtdsDeletedTxid, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('age: $age')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mtdsLastUpdatedTxid,
    mtdsDeviceId,
    mtdsDeletedTxid,
    id,
    name,
    email,
    age,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.mtdsLastUpdatedTxid == this.mtdsLastUpdatedTxid &&
          other.mtdsDeviceId == this.mtdsDeviceId &&
          other.mtdsDeletedTxid == this.mtdsDeletedTxid &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.age == this.age);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> mtdsLastUpdatedTxid;
  final Value<int> mtdsDeviceId;
  final Value<int?> mtdsDeletedTxid;
  final Value<int> id;
  final Value<String> name;
  final Value<String> email;
  final Value<int?> age;
  const UsersCompanion({
    this.mtdsLastUpdatedTxid = const Value.absent(),
    this.mtdsDeviceId = const Value.absent(),
    this.mtdsDeletedTxid = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.age = const Value.absent(),
  });
  UsersCompanion.insert({
    this.mtdsLastUpdatedTxid = const Value.absent(),
    this.mtdsDeviceId = const Value.absent(),
    this.mtdsDeletedTxid = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    required String email,
    this.age = const Value.absent(),
  }) : name = Value(name),
       email = Value(email);
  static Insertable<User> custom({
    Expression<int>? mtdsLastUpdatedTxid,
    Expression<int>? mtdsDeviceId,
    Expression<int>? mtdsDeletedTxid,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<int>? age,
  }) {
    return RawValuesInsertable({
      if (mtdsLastUpdatedTxid != null)
        'mtds_last_updated_txid': mtdsLastUpdatedTxid,
      if (mtdsDeviceId != null) 'mtds_device_id': mtdsDeviceId,
      if (mtdsDeletedTxid != null) 'mtds_deleted_txid': mtdsDeletedTxid,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (age != null) 'age': age,
    });
  }

  UsersCompanion copyWith({
    Value<int>? mtdsLastUpdatedTxid,
    Value<int>? mtdsDeviceId,
    Value<int?>? mtdsDeletedTxid,
    Value<int>? id,
    Value<String>? name,
    Value<String>? email,
    Value<int?>? age,
  }) {
    return UsersCompanion(
      mtdsLastUpdatedTxid: mtdsLastUpdatedTxid ?? this.mtdsLastUpdatedTxid,
      mtdsDeviceId: mtdsDeviceId ?? this.mtdsDeviceId,
      mtdsDeletedTxid: mtdsDeletedTxid ?? this.mtdsDeletedTxid,
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mtdsLastUpdatedTxid.present) {
      map['mtds_last_updated_txid'] = Variable<int>(mtdsLastUpdatedTxid.value);
    }
    if (mtdsDeviceId.present) {
      map['mtds_device_id'] = Variable<int>(mtdsDeviceId.value);
    }
    if (mtdsDeletedTxid.present) {
      map['mtds_deleted_txid'] = Variable<int>(mtdsDeletedTxid.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('mtdsLastUpdatedTxid: $mtdsLastUpdatedTxid, ')
          ..write('mtdsDeviceId: $mtdsDeviceId, ')
          ..write('mtdsDeletedTxid: $mtdsDeletedTxid, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('age: $age')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mtdsLastUpdatedTxidMeta =
      const VerificationMeta('mtdsLastUpdatedTxid');
  @override
  late final GeneratedColumn<int> mtdsLastUpdatedTxid = GeneratedColumn<int>(
    'mtds_last_updated_txid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtdsDeviceIdMeta = const VerificationMeta(
    'mtdsDeviceId',
  );
  @override
  late final GeneratedColumn<int> mtdsDeviceId = GeneratedColumn<int>(
    'mtds_device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtdsDeletedTxidMeta = const VerificationMeta(
    'mtdsDeletedTxid',
  );
  @override
  late final GeneratedColumn<int> mtdsDeletedTxid = GeneratedColumn<int>(
    'mtds_deleted_txid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mtdsLastUpdatedTxid,
    mtdsDeviceId,
    mtdsDeletedTxid,
    id,
    name,
    price,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mtds_last_updated_txid')) {
      context.handle(
        _mtdsLastUpdatedTxidMeta,
        mtdsLastUpdatedTxid.isAcceptableOrUnknown(
          data['mtds_last_updated_txid']!,
          _mtdsLastUpdatedTxidMeta,
        ),
      );
    }
    if (data.containsKey('mtds_device_id')) {
      context.handle(
        _mtdsDeviceIdMeta,
        mtdsDeviceId.isAcceptableOrUnknown(
          data['mtds_device_id']!,
          _mtdsDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('mtds_deleted_txid')) {
      context.handle(
        _mtdsDeletedTxidMeta,
        mtdsDeletedTxid.isAcceptableOrUnknown(
          data['mtds_deleted_txid']!,
          _mtdsDeletedTxidMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      mtdsLastUpdatedTxid:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}mtds_last_updated_txid'],
          )!,
      mtdsDeviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}mtds_device_id'],
          )!,
      mtdsDeletedTxid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtds_deleted_txid'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      price:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}price'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  /// UTC nanosecond timestamp of the last write (client-generated).
  /// Always present with a default of 0 so change detection never hits NULL.
  final int mtdsLastUpdatedTxid;

  /// 48-bit device identifier used for replication guardrails.
  /// Always present with a default of 0; SDK overwrites it on each write.
  final int mtdsDeviceId;

  /// Soft-delete marker (NULL = active, non-null = deleted at TXID)
  final int? mtdsDeletedTxid;
  final int id;
  final String name;
  final double price;
  final String? description;
  const Product({
    required this.mtdsLastUpdatedTxid,
    required this.mtdsDeviceId,
    this.mtdsDeletedTxid,
    required this.id,
    required this.name,
    required this.price,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mtds_last_updated_txid'] = Variable<int>(mtdsLastUpdatedTxid);
    map['mtds_device_id'] = Variable<int>(mtdsDeviceId);
    if (!nullToAbsent || mtdsDeletedTxid != null) {
      map['mtds_deleted_txid'] = Variable<int>(mtdsDeletedTxid);
    }
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      mtdsLastUpdatedTxid: Value(mtdsLastUpdatedTxid),
      mtdsDeviceId: Value(mtdsDeviceId),
      mtdsDeletedTxid:
          mtdsDeletedTxid == null && nullToAbsent
              ? const Value.absent()
              : Value(mtdsDeletedTxid),
      id: Value(id),
      name: Value(name),
      price: Value(price),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      mtdsLastUpdatedTxid: serializer.fromJson<int>(
        json['mtdsLastUpdatedTxid'],
      ),
      mtdsDeviceId: serializer.fromJson<int>(json['mtdsDeviceId']),
      mtdsDeletedTxid: serializer.fromJson<int?>(json['mtdsDeletedTxid']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mtdsLastUpdatedTxid': serializer.toJson<int>(mtdsLastUpdatedTxid),
      'mtdsDeviceId': serializer.toJson<int>(mtdsDeviceId),
      'mtdsDeletedTxid': serializer.toJson<int?>(mtdsDeletedTxid),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'description': serializer.toJson<String?>(description),
    };
  }

  Product copyWith({
    int? mtdsLastUpdatedTxid,
    int? mtdsDeviceId,
    Value<int?> mtdsDeletedTxid = const Value.absent(),
    int? id,
    String? name,
    double? price,
    Value<String?> description = const Value.absent(),
  }) => Product(
    mtdsLastUpdatedTxid: mtdsLastUpdatedTxid ?? this.mtdsLastUpdatedTxid,
    mtdsDeviceId: mtdsDeviceId ?? this.mtdsDeviceId,
    mtdsDeletedTxid:
        mtdsDeletedTxid.present ? mtdsDeletedTxid.value : this.mtdsDeletedTxid,
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    description: description.present ? description.value : this.description,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      mtdsLastUpdatedTxid:
          data.mtdsLastUpdatedTxid.present
              ? data.mtdsLastUpdatedTxid.value
              : this.mtdsLastUpdatedTxid,
      mtdsDeviceId:
          data.mtdsDeviceId.present
              ? data.mtdsDeviceId.value
              : this.mtdsDeviceId,
      mtdsDeletedTxid:
          data.mtdsDeletedTxid.present
              ? data.mtdsDeletedTxid.value
              : this.mtdsDeletedTxid,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('mtdsLastUpdatedTxid: $mtdsLastUpdatedTxid, ')
          ..write('mtdsDeviceId: $mtdsDeviceId, ')
          ..write('mtdsDeletedTxid: $mtdsDeletedTxid, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mtdsLastUpdatedTxid,
    mtdsDeviceId,
    mtdsDeletedTxid,
    id,
    name,
    price,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.mtdsLastUpdatedTxid == this.mtdsLastUpdatedTxid &&
          other.mtdsDeviceId == this.mtdsDeviceId &&
          other.mtdsDeletedTxid == this.mtdsDeletedTxid &&
          other.id == this.id &&
          other.name == this.name &&
          other.price == this.price &&
          other.description == this.description);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> mtdsLastUpdatedTxid;
  final Value<int> mtdsDeviceId;
  final Value<int?> mtdsDeletedTxid;
  final Value<int> id;
  final Value<String> name;
  final Value<double> price;
  final Value<String?> description;
  const ProductsCompanion({
    this.mtdsLastUpdatedTxid = const Value.absent(),
    this.mtdsDeviceId = const Value.absent(),
    this.mtdsDeletedTxid = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.description = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.mtdsLastUpdatedTxid = const Value.absent(),
    this.mtdsDeviceId = const Value.absent(),
    this.mtdsDeletedTxid = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    required double price,
    this.description = const Value.absent(),
  }) : name = Value(name),
       price = Value(price);
  static Insertable<Product> custom({
    Expression<int>? mtdsLastUpdatedTxid,
    Expression<int>? mtdsDeviceId,
    Expression<int>? mtdsDeletedTxid,
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? price,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (mtdsLastUpdatedTxid != null)
        'mtds_last_updated_txid': mtdsLastUpdatedTxid,
      if (mtdsDeviceId != null) 'mtds_device_id': mtdsDeviceId,
      if (mtdsDeletedTxid != null) 'mtds_deleted_txid': mtdsDeletedTxid,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (description != null) 'description': description,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? mtdsLastUpdatedTxid,
    Value<int>? mtdsDeviceId,
    Value<int?>? mtdsDeletedTxid,
    Value<int>? id,
    Value<String>? name,
    Value<double>? price,
    Value<String?>? description,
  }) {
    return ProductsCompanion(
      mtdsLastUpdatedTxid: mtdsLastUpdatedTxid ?? this.mtdsLastUpdatedTxid,
      mtdsDeviceId: mtdsDeviceId ?? this.mtdsDeviceId,
      mtdsDeletedTxid: mtdsDeletedTxid ?? this.mtdsDeletedTxid,
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mtdsLastUpdatedTxid.present) {
      map['mtds_last_updated_txid'] = Variable<int>(mtdsLastUpdatedTxid.value);
    }
    if (mtdsDeviceId.present) {
      map['mtds_device_id'] = Variable<int>(mtdsDeviceId.value);
    }
    if (mtdsDeletedTxid.present) {
      map['mtds_deleted_txid'] = Variable<int>(mtdsDeletedTxid.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('mtdsLastUpdatedTxid: $mtdsLastUpdatedTxid, ')
          ..write('mtdsDeviceId: $mtdsDeviceId, ')
          ..write('mtdsDeletedTxid: $mtdsDeletedTxid, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [users, products];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> mtdsLastUpdatedTxid,
      Value<int> mtdsDeviceId,
      Value<int?> mtdsDeletedTxid,
      Value<int> id,
      required String name,
      required String email,
      Value<int?> age,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> mtdsLastUpdatedTxid,
      Value<int> mtdsDeviceId,
      Value<int?> mtdsDeletedTxid,
      Value<int> id,
      Value<String> name,
      Value<String> email,
      Value<int?> age,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mtdsLastUpdatedTxid = const Value.absent(),
                Value<int> mtdsDeviceId = const Value.absent(),
                Value<int?> mtdsDeletedTxid = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int?> age = const Value.absent(),
              }) => UsersCompanion(
                mtdsLastUpdatedTxid: mtdsLastUpdatedTxid,
                mtdsDeviceId: mtdsDeviceId,
                mtdsDeletedTxid: mtdsDeletedTxid,
                id: id,
                name: name,
                email: email,
                age: age,
              ),
          createCompanionCallback:
              ({
                Value<int> mtdsLastUpdatedTxid = const Value.absent(),
                Value<int> mtdsDeviceId = const Value.absent(),
                Value<int?> mtdsDeletedTxid = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String name,
                required String email,
                Value<int?> age = const Value.absent(),
              }) => UsersCompanion.insert(
                mtdsLastUpdatedTxid: mtdsLastUpdatedTxid,
                mtdsDeviceId: mtdsDeviceId,
                mtdsDeletedTxid: mtdsDeletedTxid,
                id: id,
                name: name,
                email: email,
                age: age,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> mtdsLastUpdatedTxid,
      Value<int> mtdsDeviceId,
      Value<int?> mtdsDeletedTxid,
      Value<int> id,
      required String name,
      required double price,
      Value<String?> description,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> mtdsLastUpdatedTxid,
      Value<int> mtdsDeviceId,
      Value<int?> mtdsDeletedTxid,
      Value<int> id,
      Value<String> name,
      Value<double> price,
      Value<String?> description,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mtdsLastUpdatedTxid => $composableBuilder(
    column: $table.mtdsLastUpdatedTxid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mtdsDeviceId => $composableBuilder(
    column: $table.mtdsDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mtdsDeletedTxid => $composableBuilder(
    column: $table.mtdsDeletedTxid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mtdsLastUpdatedTxid = const Value.absent(),
                Value<int> mtdsDeviceId = const Value.absent(),
                Value<int?> mtdsDeletedTxid = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => ProductsCompanion(
                mtdsLastUpdatedTxid: mtdsLastUpdatedTxid,
                mtdsDeviceId: mtdsDeviceId,
                mtdsDeletedTxid: mtdsDeletedTxid,
                id: id,
                name: name,
                price: price,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> mtdsLastUpdatedTxid = const Value.absent(),
                Value<int> mtdsDeviceId = const Value.absent(),
                Value<int?> mtdsDeletedTxid = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String name,
                required double price,
                Value<String?> description = const Value.absent(),
              }) => ProductsCompanion.insert(
                mtdsLastUpdatedTxid: mtdsLastUpdatedTxid,
                mtdsDeviceId: mtdsDeviceId,
                mtdsDeletedTxid: mtdsDeletedTxid,
                id: id,
                name: name,
                price: price,
                description: description,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
}
