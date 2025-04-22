import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class SyncManager {
  static Future<void> syncWithServer(
      Future<List<Map<String, dynamic>>> Function() fetchUpdatesFromServer,
      Future<void> Function(List<Map<String, dynamic>>) sendLocalChanges) async {
    
    final db = await DBHelper.db;

    try {
      // Step 1: Send local changes
      final localChanges = await db.query('tbldmlog');
      if (localChanges.isNotEmpty) {
        await sendLocalChanges(localChanges);
        await db.delete('tbldmlog'); // Clear tbldmlog after successful sync
      }

      // Step 2: Fetch remote changes
      final List<Map<String, dynamic>> remoteUpdates = await fetchUpdatesFromServer();
      await _applyServerUpdates(db, remoteUpdates);
    } catch (e) {
      print("❌ Sync failed: $e");
    }
  }

  static Future<void> _applyServerUpdates(
      Database db, List<Map<String, dynamic>> updates) async {
    await db.transaction((txn) async {
      for (var update in updates) {
        try {
          String tableName = update["TableName"]?.toString() ?? update["table"]?.toString() ?? "";
          int? primaryKey = update["PK"] is int ? update["PK"] : (update["id"] is int ? update["id"] : null);
          Map<String, dynamic> newData = Map<String, dynamic>.from(update["data"] ?? {});

          if (tableName.isEmpty || primaryKey == null) {
            print("⚠️ Skipping update due to missing TableName or PK: $update");
            continue;
          }

          newData.remove("TXID"); // Remove TXID if it exists
          await txn.update(
            tableName,
            newData,
            where: "id = ?",
            whereArgs: [primaryKey],
          );
        } catch (e) {
          print("⚠️ Error processing update: $e");
        }
      }
    });

    print("✅ Sync completed!");
  }
}

