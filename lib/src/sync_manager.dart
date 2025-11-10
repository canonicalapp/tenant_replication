import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class SyncManager {
  static Future<void> syncWithServer(url) async {
    final db = await DBHelper.db;
    try {
      final List<Map<String, dynamic>> remoteUpdates = await db.query(
        "tbldmlog",
      );
      await _applyServerUpdates(db, remoteUpdates, url);
    } catch (e) {
      print("❌ Sync failed: $e");
    }
  }

  static Future<bool> _applyServerUpdates(
    Database db,
    List<Map<String, dynamic>> updates,
    String url,
  ) async {
    final normalizedUpdates =
        updates.map((update) {
          final normalized = Map<String, dynamic>.from(update);
          if (normalized['PayLoad'] is String) {
            try {
              normalized['PayLoad'] = jsonDecode(normalized['PayLoad']);
            } catch (e) {
              print("⚠️ Failed to parse PayLoad: ${normalized['PayLoad']}");
              rethrow;
            }
          }
          return normalized;
        }).toList();
    if (normalizedUpdates.isNotEmpty) {
      print("📝 Sample update (first of ${normalizedUpdates.length}):");
      print(jsonEncode(normalizedUpdates.first));
    }

    final dio = Dio();
    try {
      final response = await dio.post(
        "$url/update",
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
        data: normalizedUpdates,
      );
      if (response.statusCode == 200) {
        // Process soft-deletes: actually delete records marked with mtds_DeletedTXID
        await _processConfirmedDeletes(db, normalizedUpdates);

        final localChanges = await db.query('tbldmlog');
        if (localChanges.isNotEmpty) {
          await db.delete('tbldmlog'); // Clear tbldmlog after successful sync
        }
        print("✅ Server updates applied successfully");
        return true;
      }

      print("❌ Server responded with error:");
      print("Status: ${response.statusCode}");
      print("Body: ${response.data}");
      return false;
    } on DioException catch (e) {
      print("‼️ Dio error occurred:");
      print("Type: ${e.type}");
      print("Message: ${e.message}");

      if (e.response != null) {
        print("Status: ${e.response!.statusCode}");
        print("Data: ${e.response!.data}");
      } else {
        print("No response received");
      }

      print("Request: ${e.requestOptions.method} ${e.requestOptions.path}");
      print("Request data: ${e.requestOptions.data}");
      return false;
    } catch (e) {
      print("‼️ Unexpected error: $e");
      return false;
    }
  }

  /// Process confirmed soft-deletes by actually deleting records from local database
  /// This is called after server confirms the soft-delete sync
  static Future<void> _processConfirmedDeletes(
    Database db,
    List<Map<String, dynamic>> updates,
  ) async {
    final deletesToProcess =
        updates.where((update) {
          // Action == null indicates a soft-delete operation
          return update['Action'] == null;
        }).toList();

    if (deletesToProcess.isEmpty) {
      return;
    }

    print(
      "🗑️ Processing ${deletesToProcess.length} confirmed soft-deletes...",
    );

    for (final deleteEntry in deletesToProcess) {
      try {
        final tableName = deleteEntry['TableName'] as String;
        final pk = deleteEntry['PK'];

        // Get the primary key column name for this table
        final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
        final pkColumn = tableInfo.firstWhere(
          (col) => col['pk'] == 1,
          orElse: () => {'name': 'id'},
        );
        final pkColumnName = pkColumn['name'] as String;

        // Actually delete the record from the table
        final deletedRows = await db.delete(
          tableName,
          where: '$pkColumnName = ?',
          whereArgs: [pk],
        );

        if (deletedRows > 0) {
          print(
            "✅ Soft-delete confirmed: $tableName[$pkColumnName=$pk] permanently removed",
          );
        } else {
          print(
            "⚠️ Soft-delete: $tableName[$pkColumnName=$pk] not found (may have been already deleted)",
          );
        }
      } catch (e) {
        print(
          "❌ Error processing soft-delete for ${deleteEntry['TableName']}: $e",
        );
      }
    }

    print("✅ Confirmed soft-deletes processed");
  }
}
