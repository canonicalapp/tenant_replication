import 'db_helper.dart';
import 'package:sqflite/sqflite.dart';

class TriggerManager {
  static Future<void> setupTriggers() async {
    final Database db = await DBHelper.db;
    print("🔄 Setting up triggers...");

    // Get all tables except system tables and tbldmlog
    List<Map<String, dynamic>> tables = await db.rawQuery('''
      SELECT name FROM sqlite_master 
      WHERE type = 'table' 
        AND name NOT LIKE 'sqlite_%' 
        AND name != 'tbldmlog'
    ''');

    for (var table in tables) {
      String tableName = table['name'];
      print('🔹 Setting up triggers for table: $tableName');

      // Retrieve table schema to determine the primary key
      List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info($tableName);',
      );
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

      try {
        // INSERT Trigger
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_${tableName}_insert
          AFTER INSERT ON $tableName
          FOR EACH ROW
          WHEN NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
          BEGIN
              INSERT INTO tbldmlog (TXID, TableName, PK, mtds_DeviceID, Action, PayLoad)
              VALUES (
                NEW.mtds_lastUpdatedTxid,
                '$tableName',
                NEW.$pkColumn,
                NEW.mtds_DeviceID,
                0,
                json_object('New', json_object($newJsonFields), 'old', NULL)
              );
          END;
        ''');

        // UPDATE Trigger
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_${tableName}_update
          AFTER UPDATE ON $tableName
          FOR EACH ROW
          WHEN (
            (
              OLD.mtds_lastUpdatedTxid <> NEW.mtds_lastUpdatedTxid 
              AND NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
            )
            OR
            (
              OLD.mtds_DeletedTXID IS NULL 
              AND NEW.mtds_DeletedTXID IS NOT NULL 
              AND NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
            )
          )
          BEGIN
              INSERT INTO tbldmlog (TXID, TableName, PK, mtds_DeviceID, Action, PayLoad)
              VALUES (
                CASE 
                  WHEN OLD.mtds_DeletedTXID IS NULL AND NEW.mtds_DeletedTXID IS NOT NULL THEN NEW.mtds_DeletedTXID 
                  ELSE NEW.mtds_lastUpdatedTxid 
                END,
                '$tableName',
                NEW.$pkColumn,
                NEW.mtds_DeviceID,
                CASE 
                  WHEN OLD.mtds_DeletedTXID IS NULL AND NEW.mtds_DeletedTXID IS NOT NULL THEN NULL 
                  ELSE 1 
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
