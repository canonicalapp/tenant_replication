import 'package:drift/drift.dart';

import 'state_table_service.dart';
import 'trigger_manager.dart';

const _metadataTable = 'mtds_metadata';
const _deviceIdKey = 'device_id';
const _changeLogTable = 'mtds_change_log';
const _stateTable = 'mtds_state';

/// Utility methods that prepare MTDS metadata inside a consumer's Drift database.
class SchemaManager {
  /// Ensures the metadata table exists for storing SDK-controlled values.
  static Future<void> ensureMetadataTable(GeneratedDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS $_metadataTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  /// Ensures the MTDS change log table exists and creates it if missing.
  ///
  /// This can be called safely from migrations (`onCreate`, `onUpgrade`) or
  /// right after opening the database.
  static Future<void> ensureChangeLogTable(GeneratedDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS $_changeLogTable (
        txid INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_pk TEXT NOT NULL,
        mtds_device_id INTEGER NOT NULL,
        action TEXT,
        payload TEXT
      );
    ''');

    await _migrateChangeLogSchema(db);
  }

  /// Ensures the MTDS state table exists for storing SDK state values.
  static Future<void> ensureStateTable(GeneratedDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS $_stateTable (
        attribute TEXT PRIMARY KEY,
        numValue INTEGER NOT NULL DEFAULT 0,
        textValue TEXT
      );
    ''');

    // Initialize core attributes if they don't exist
    final stateService = StateTableService(db: db);
    await _initializeStateTableAttributes(stateService);
  }

  /// Initialize core state table attributes.
  static Future<void> _initializeStateTableAttributes(
    StateTableService stateService,
  ) async {
    // Check if attributes exist, if not insert them
    final clientTs = await stateService.getNumValue('mtds:client_ts');
    if (clientTs == 0) {
      await stateService.upsertNumValue('mtds:client_ts', 0);
    }

    final lastSyncTs = await stateService.getTextValue('mtds:lastSyncTS');
    if (lastSyncTs == null) {
      await stateService.upsertTextValue('mtds:lastSyncTS', null);
    }

    final deviceId = await stateService.getNumValue('mtds:DeviceID');
    if (deviceId == 0) {
      await stateService.upsertNumValue('mtds:DeviceID', 0);
    }
  }

  /// Full preparation flow: create metadata + change log + state tables, then attach triggers.
  ///
  /// Call this after migrations have run so that user tables exist.
  static Future<void> prepareDatabase(GeneratedDatabase db) async {
    await ensureMetadataTable(db);
    await ensureChangeLogTable(db);
    await ensureStateTable(db);
    await TriggerManager.setupTriggers(db);
  }

  /// Convenience helper to upsert a metadata key/value pair.
  static Future<void> upsertMetadata(
    GeneratedDatabase db, {
    required String key,
    required String value,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO $_metadataTable (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      [key, value],
    );
  }

  /// Convenience helper to read a metadata value or null.
  static Future<String?> readMetadata(
    GeneratedDatabase db, {
    required String key,
  }) async {
    final result =
        await db
            .customSelect(
              'SELECT value FROM $_metadataTable WHERE key = ?',
              variables: [Variable.withString(key)],
            )
            .get();

    if (result.isEmpty) return null;
    return result.first.data['value'] as String?;
  }

  /// Returns the device-id key string (shared across helpers / triggers).
  static String get deviceIdKey => _deviceIdKey;

  static Future<void> _migrateChangeLogSchema(GeneratedDatabase db) async {
    final columns =
        await db.customSelect('PRAGMA table_info($_changeLogTable)').get();

    if (columns.isEmpty) {
      return;
    }

    final recordPkRow = columns.firstWhere(
      (col) => col.data['name'] == 'record_pk',
      orElse:
          () =>
              throw Exception(
                'record_pk column missing in $_changeLogTable schema',
              ),
    );

    final currentPkType = (recordPkRow.data['type'] as String?)?.toUpperCase();

    final actionRow = columns.firstWhere(
      (col) => col.data['name'] == 'action',
      orElse:
          () =>
              throw Exception(
                'action column missing in $_changeLogTable schema',
              ),
    );

    final currentActionType =
        (actionRow.data['type'] as String?)?.toUpperCase();

    final needsPkMigration = currentPkType != 'TEXT';
    final needsActionMigration = currentActionType != 'TEXT';

    if (!needsPkMigration && !needsActionMigration) {
      return;
    }

    print('🔧 Migrating $_changeLogTable schema (record_pk/action types)');
    await db.transaction(() async {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS ${_changeLogTable}_tmp (
          txid INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_pk TEXT NOT NULL,
          mtds_device_id INTEGER NOT NULL,
          action TEXT,
          payload TEXT
        );
      ''');

      await db.customStatement('''
        INSERT INTO ${_changeLogTable}_tmp (txid, table_name, record_pk, mtds_device_id, action, payload)
        SELECT 
          txid, 
          table_name, 
          CAST(record_pk AS TEXT), 
          mtds_device_id, 
          CASE 
            WHEN typeof(action) = 'integer' THEN 
              CASE action 
                WHEN 0 THEN 'insert'
                WHEN 1 THEN 'update'
                ELSE 'delete'
              END
            ELSE action
          END,
          payload
        FROM $_changeLogTable;
      ''');

      await db.customStatement('DROP TABLE $_changeLogTable;');
      await db.customStatement(
        'ALTER TABLE ${_changeLogTable}_tmp RENAME TO $_changeLogTable;',
      );
    });
  }
}
