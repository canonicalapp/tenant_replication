import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class SyncManager {
  static Future<void> syncWithServer(url) async {
    final db = await DBHelper.db;
    try {
      final List<Map<String, dynamic>> remoteUpdates = await db.query("tbldmlog");
      await _applyServerUpdates(db, remoteUpdates,url);
    } catch (e) {
      print("❌ Sync failed: $e");
    }
  }

  static Future<bool> _applyServerUpdates(Database db,List<Map<String, dynamic>> updates,String url) async {
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
}
