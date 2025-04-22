import 'db_helper.dart';
import 'package:sqflite/sqflite.dart';

class TriggerManager {
  static Future<void> setupTriggers() async {
    final Database db = await DBHelper.db;

    // Ensure tbldmlog table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tbldmlog (
        TXID INTEGER,
        TableName TEXT NOT NULL,
        PK INTEGER NOT NULL,
        Action INTEGER,
        PayLoad TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // Get all tables except system tables and tbldmlog
    List<Map<String, dynamic>> tables = await db.rawQuery('''
      SELECT name FROM sqlite_master 
      WHERE type = 'table' 
        AND name NOT LIKE 'sqlite_%' 
        AND name != 'tbldmlog'
    '''
    );

    for (var table in tables) {
      String tableName = table['name'];
      print('🔹 Setting up triggers for table: $tableName');

      // Retrieve table schema to determine the primary key
      List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($tableName);');
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
      String newJsonFields = columns.map((col) => "'${col['name']}', NEW.${col['name']}").join(', ');
      String oldJsonFields = columns.map((col) => "'${col['name']}', OLD.${col['name']}").join(', ');

      try {
        // INSERT Trigger
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_${tableName}_insert
          AFTER INSERT ON $tableName
          FOR EACH ROW
          WHEN (NEW.lastUpdatedTxid & 0xFFFFFF) = (SELECT application_id FROM pragma_application_id())
          BEGIN
              INSERT INTO tbldmlog (TXID, TableName, PK, Action, PayLoad)
              VALUES (
                NEW.lastUpdatedTxid,
                '$tableName',
                NEW.$pkColumn,
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
              OLD.lastUpdatedTxid <> NEW.lastUpdatedTxid 
              AND (NEW.lastUpdatedTxid & 0xFFFFFF) = (SELECT application_id FROM pragma_application_id())
            )
            OR
            (
              OLD.DeletedTXID IS NULL 
              AND NEW.DeletedTXID IS NOT NULL 
              AND (NEW.DeletedTXID & 0xFFFFFF) = (SELECT application_id FROM pragma_application_id())
            )
          )
          BEGIN
              INSERT INTO tbldmlog (TXID, TableName, PK, Action, PayLoad)
              VALUES (
                CASE 
                  WHEN OLD.DeletedTXID IS NULL AND NEW.DeletedTXID IS NOT NULL THEN NEW.DeletedTXID 
                  ELSE NEW.lastUpdatedTxid 
                END,
                '$tableName',
                NEW.$pkColumn,
                CASE 
                  WHEN OLD.DeletedTXID IS NULL AND NEW.DeletedTXID IS NOT NULL THEN NULL 
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
