import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mtds/index.dart' show SchemaManager, MtdsColumns;

import 'database.steps.dart';

part 'database.g.dart';

/// Sample Users table with MTDS required fields
class Users extends Table with MtdsColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  IntColumn get age => integer().nullable()();
}

/// Sample Products table with MTDS required fields
class Products extends Table with MtdsColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get description => text().nullable()();
}

@DriftDatabase(tables: [Users, Products])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9; // Drift-managed schema with auto migrations

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      print('📋 Creating database schema with Drift migrator...');
      await m.createAll();
      await SchemaManager.ensureMetadataTable(m.database);
      await SchemaManager.ensureChangeLogTable(m.database);
      print('✅ Tables created via Drift');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      print('🔄 Auto-migrating database schema...');
      await _runLegacyMigrations(m, from);
      if (from >= 8) {
        await _stepByStepUpgrade(m, from, to);
      }
      print('✅ Database upgrade complete');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated || details.hadUpgrade) {
        await SchemaManager.ensureMetadataTable(this);
        await SchemaManager.ensureChangeLogTable(this);
        await _logUsersSchema(details.wasCreated ? 'creation' : 'upgrade');
      }
    },
  );

  Future<void> _logUsersSchema(String reason) async {
    final schema = await customSelect('PRAGMA table_info(users)').get();
    print('📋 Users table schema after $reason:');
    for (final row in schema) {
      print('   Column: ${row.data['name']} (${row.data['type']})');
    }
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'client_test_db.sqlite'));
      print('📁 MTDS example database: ${file.path}');
      return NativeDatabase(file, logStatements: true);
    });
  }

  Future<void> _runLegacyMigrations(Migrator m, int from) async {
    if (from < 2) {
      await m.addColumn(users, users.mtdsLastUpdatedTxid);
      await m.addColumn(users, users.mtdsDeviceId);
      await m.addColumn(users, users.mtdsDeletedTxid);
      await m.addColumn(products, products.mtdsLastUpdatedTxid);
      await m.addColumn(products, products.mtdsDeviceId);
      await m.addColumn(products, products.mtdsDeletedTxid);
    }
    if (from < 3) {
      await SchemaManager.ensureMetadataTable(m.database);
      await SchemaManager.ensureChangeLogTable(m.database);
    }
  }

  OnUpgrade get _stepByStepUpgrade => stepByStep(
    from8To9: (m, schema) async {
      await SchemaManager.ensureMetadataTable(m.database);
      await SchemaManager.ensureChangeLogTable(m.database);
    },
  );

  // Helper method to query change log
  Future<List<Map<String, Object?>>> getChangeLogs() async {
    final result =
        await customSelect(
          'SELECT * FROM mtds_change_log ORDER BY txid DESC',
        ).get();
    return result.map((row) => row.data).toList();
  }

  // Helper method to clear change log
  Future<void> clearChangeLogs() async {
    await customStatement('DELETE FROM mtds_change_log');
  }
}
