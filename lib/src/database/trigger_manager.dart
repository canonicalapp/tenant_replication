import 'package:drift/drift.dart';

import '../models/server_events.dart';

// Read device ID from state table (triggers use raw SQL as required)
const String _deviceIdSelect =
    "(SELECT numValue FROM mtds_state WHERE attribute = 'mtds:DeviceID')";

// Client epoch: January 1, 2025 (timestamp: 1735689600000 milliseconds)
const int _clientEpochMs = 1735689600000;

class TriggerManager {
  /// Setup triggers on the provided Drift database
  ///
  /// This method creates INSERT and UPDATE triggers on all user tables
  /// to automatically log changes to the mtds_change_log table.
  ///
  /// Usage:
  /// ```dart
  /// final driftDb = AppDatabase();
  /// await TriggerManager.setupTriggers(driftDb);
  /// ```
  static Future<void> setupTriggers(GeneratedDatabase db) async {
    print("🔄 Setting up triggers...");

    // Get all tables except system tables and MTDS internal tables
    final tablesResult =
        await db.customSelect('''
      SELECT name FROM sqlite_master 
      WHERE type = 'table' 
        AND name NOT LIKE 'sqlite_%' 
        AND name NOT IN ('mtds_change_log', 'mtds_metadata', 'mtds_state')
    ''').get();

    List<Map<String, dynamic>> tables =
        tablesResult.map((row) => row.data).toList();

    // Drop legacy triggers that may have been created before exclusions existed.
    await _dropTriggersForTable(db, 'mtds_metadata');

    for (var table in tables) {
      String tableName = table['name'];
      print('🔹 Setting up triggers for table: $tableName');

      // Retrieve table schema to determine the primary key
      final columnsResult =
          await db.customSelect('PRAGMA table_info($tableName);').get();

      List<Map<String, dynamic>> columns =
          columnsResult.map((row) => row.data).toList();

      Map<String, dynamic> primaryKeyColumn = columns.firstWhere(
        (col) => col['pk'] > 0,
        orElse: () => {},
      );

      if (primaryKeyColumn.isEmpty) {
        print("⚠️ Skipping $tableName, no primary key found.");
        continue;
      }

      String pkColumn = primaryKeyColumn['name'];
      print('   ✅ Primary key column: $pkColumn');

      // Construct JSON fields for NEW and OLD
      String newJsonFields = columns
          .map((col) => "'${col['name']}', NEW.${col['name']}")
          .join(', ');
      String oldJsonFields = columns
          .map((col) => "'${col['name']}', OLD.${col['name']}")
          .join(', ');

      final pkValueExpression = "CAST(NEW.$pkColumn AS TEXT)";

      try {
        await _dropTriggersForTable(db, tableName);

        // BEFORE INSERT Trigger - Update client timestamp
        // Note: SQLite BEFORE INSERT triggers update the state table atomically
        // Application code should read the updated timestamp and set mtds_client_ts and mtds_device_id
        // This ensures monotonic timestamp increments even under concurrent operations
        // **Why Triggers Update State Table But Don't Set NEW Values:**
        //
        // SQLite triggers have limitations that prevent direct assignment to NEW values:
        // 1. No RETURNING clause in UPDATE statements
        // 2. Complex syntax for modifying NEW values (unreliable across SQLite versions)
        // 3. Limited support for complex bitwise operations needed for PK generation
        //
        // **Solution**: Hybrid approach
        // - Triggers: Update state table atomically (ensures monotonic timestamps under concurrency)
        // - Application: Use RecordHelper.prepareForInsert() to set mtds_device_id and mtds_client_ts
        //
        // This ensures:
        // - Atomic state table updates (triggers handle this)
        // - Correct values set before insert (RecordHelper handles this)
        // - Works reliably across all SQLite versions
        //
        // See RecordHelper documentation for details on why this approach is used.
        await db.customStatement('''
          CREATE TRIGGER IF NOT EXISTS mtds_trigger_${tableName}_insert_before
          BEFORE INSERT ON $tableName
          FOR EACH ROW
          BEGIN
            -- Update client timestamp in state table (monotonic increment)
            UPDATE mtds_state
            SET numValue = MAX(
              COALESCE((SELECT numValue FROM mtds_state WHERE attribute = 'mtds:client_ts'), 0) + 1,
              CAST((julianday('now', 'subsec') * 86400000 - $_clientEpochMs) AS INTEGER)
            )
            WHERE attribute = 'mtds:client_ts';
          END;
        ''');

        // BEFORE UPDATE Trigger - Update client timestamp atomically
        //
        // Similar to BEFORE INSERT trigger, this updates the state table atomically.
        // Application code should use RecordHelper.prepareForUpdate() to set values.
        await db.customStatement('''
          CREATE TRIGGER IF NOT EXISTS mtds_trigger_${tableName}_update_before
          BEFORE UPDATE ON $tableName
          FOR EACH ROW
          BEGIN
            -- Update client timestamp in state table (monotonic increment)
            -- This ensures atomic updates even under concurrent operations
            -- Application code (RecordHelper) will read this value and set NEW.mtds_client_ts
            UPDATE mtds_state
            SET numValue = MAX(
              COALESCE((SELECT numValue FROM mtds_state WHERE attribute = 'mtds:client_ts'), 0) + 1,
              CAST((julianday('now', 'subsec') * 86400000 - $_clientEpochMs) AS INTEGER)
            )
            WHERE attribute = 'mtds:client_ts';
          END;
        ''');

        // AFTER INSERT Trigger - Log changes to change log
        // Only capture local writes by matching state table device_id
        await db.customStatement('''
          CREATE TRIGGER IF NOT EXISTS mtds_trigger_${tableName}_insert
          AFTER INSERT ON $tableName
          FOR EACH ROW
          WHEN (
            COALESCE($_deviceIdSelect, -1) = NEW.mtds_device_id
          )
          BEGIN
              INSERT INTO mtds_change_log (txid, table_name, record_pk, mtds_device_id, action, payload)
              VALUES (
                NEW.mtds_client_ts,
                '$tableName',
                $pkValueExpression,
                NEW.mtds_device_id,
                '${ServerAction.insert.name}',
                json_object('New', json_object($newJsonFields), 'old', NULL)
              );
          END;
        ''');

        // AFTER UPDATE Trigger - Log changes to change log
        // Only capture local writes by matching state table device_id
        await db.customStatement('''
          CREATE TRIGGER IF NOT EXISTS mtds_trigger_${tableName}_update
          AFTER UPDATE ON $tableName
          FOR EACH ROW
          WHEN (
            (
              OLD.mtds_client_ts <> NEW.mtds_client_ts 
              AND COALESCE($_deviceIdSelect, -1) = NEW.mtds_device_id
            )
            OR
            (
              OLD.mtds_delete_ts IS NULL 
              AND NEW.mtds_delete_ts IS NOT NULL 
              AND COALESCE($_deviceIdSelect, -1) = NEW.mtds_device_id
            )
          )
          BEGIN
              INSERT INTO mtds_change_log (txid, table_name, record_pk, mtds_device_id, action, payload)
              VALUES (
                CASE 
                  WHEN OLD.mtds_delete_ts IS NULL AND NEW.mtds_delete_ts IS NOT NULL THEN NEW.mtds_delete_ts 
                  ELSE NEW.mtds_client_ts 
                END,
                '$tableName',
                $pkValueExpression,
                NEW.mtds_device_id,
                CASE 
                  WHEN OLD.mtds_delete_ts IS NULL AND NEW.mtds_delete_ts IS NOT NULL THEN '${ServerAction.delete.name}' 
                  ELSE '${ServerAction.update.name}' 
                END,
                json_object('New', json_object($newJsonFields), 'old', json_object($oldJsonFields))
              );
          END;
        ''');
      } catch (e) {
        print('❌ Error creating triggers for $tableName: $e');
      }
    }
    print("✅ Triggers created successfully.");
  }
}

Future<void> _dropTriggersForTable(
  GeneratedDatabase db,
  String tableName,
) async {
  // Drop old naming (for migration)
  await db.customStatement(
    'DROP TRIGGER IF EXISTS trigger_${tableName}_insert;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS trigger_${tableName}_update;',
  );
  // Drop new naming - all trigger types
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_insert_before;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_insert;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_update_before;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_update;',
  );
}
