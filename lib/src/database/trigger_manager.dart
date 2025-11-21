import 'package:drift/drift.dart';

import '../models/server_events.dart';

const String _deviceIdSelect =
    "(SELECT CAST(value AS INTEGER) FROM mtds_metadata WHERE key = 'device_id')";

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

    // Get all tables except system tables and mtds_change_log
    final tablesResult =
        await db.customSelect('''
      SELECT name FROM sqlite_master 
      WHERE type = 'table' 
        AND name NOT LIKE 'sqlite_%' 
        AND name NOT IN ('mtds_change_log', 'mtds_metadata')
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

        // BEFORE INSERT Trigger - Populate mtds_device_id automatically
        // Note: SQLite BEFORE INSERT triggers have limited ability to modify NEW.column
        // Application code should set mtds_device_id before insert for maximum compatibility
        // This trigger serves as documentation and may work in some SQLite versions
        await db.customStatement('''
          CREATE TRIGGER IF NOT EXISTS mtds_trigger_${tableName}_insert_before
          BEFORE INSERT ON $tableName
          FOR EACH ROW
          WHEN NEW.mtds_device_id = 0 OR NEW.mtds_device_id IS NULL
          BEGIN
            -- Attempt to set mtds_device_id from metadata
            -- Note: This may not work in all SQLite versions
            -- Application code should set mtds_device_id to ensure it's set
            SELECT $_deviceIdSelect;
          END;
        ''');

        // AFTER INSERT Trigger - Log changes to change log
        // Only capture local writes by matching metadata device_id
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
        // Only capture local writes by matching metadata device_id
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
  // Drop new naming
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_insert_before;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_insert;',
  );
  await db.customStatement(
    'DROP TRIGGER IF EXISTS mtds_trigger_${tableName}_update;',
  );
}
