import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tenant_replication/tenant_replication.dart';

import 'sse_handler_web.dart' if (dart.library.io) 'sse_handler_native.dart';

class SSEManager {
  final Dio _dio = Dio();

  static Future<void> initializeSSE(url, token) async {
    final deviceId = await DBHelper.getDeviceId48Bit();
    print('Initializing SSE.............................');

    // Create headers with deviceId and authorization token
    Map<String, String> headers = {};
    headers['deviceId'] = deviceId.toString();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // final SSEHandler _sseHandler = SSEHandler('$url/events?deviceId=$deviceId');
    final SSEHandler _sseHandler = SSEHandler(
      '$url/mtdd/events',
      headers: headers,
    );

    _sseHandler.startListening();
    print(
      'SSE started listening for events.............................deviceId=$deviceId',
    );

    _sseHandler.stream.listen((data) async {
      try {
        print('Raw event received: $data'); // Debug print of the raw event
        if (data != 'Connected') {
          final firstDecode = jsonDecode(data);
          final event = jsonDecode(firstDecode);
          final eventData = event['data'];
          final tableName = event['table'];

          print('Event data: $eventData');
          print("Event table: $tableName");

          final db = await DBHelper.db;

          // 🔹 Get valid columns for this table
          final validCols = await getTableColumns(db, tableName);

          // 🔹 Filter row to match table schema
          final filteredRow = filterRow(
            Map<String, dynamic>.from(eventData),
            validCols,
          );

          // 🔹 Insert into table
          await db.insert(
            tableName,
            filteredRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        print('Error processing event: $e');
      }
    });
  }

  /// Load all tables sequentially on system start
  /// Each table is loaded in its own transaction
  Future<Map<String, int>> loadAllTables({
    required String url,
    required String token,
    required List<String> tableNames,
    Map<String, dynamic>? extraParams,
  }) async {
    final results = <String, int>{};

    print("🔄 Starting initial data load for ${tableNames.length} tables...");

    for (final tableName in tableNames) {
      try {
        print("📋 Loading table: $tableName");
        final data = await loadData(
          url: url,
          token: token,
          tableName: tableName,
          extraParams: extraParams,
        );

        final count = data is List ? data.length : 1;
        results[tableName] = count;
        print("✅ $tableName: $count records loaded");
      } catch (e) {
        print("❌ Failed to load $tableName: $e");
        results[tableName] = -1; // Mark as failed
      }
    }

    final totalRecords = results.values
        .where((v) => v > 0)
        .fold(0, (a, b) => a + b);
    final failedTables = results.entries.where((e) => e.value == -1).length;

    print(
      "✅ Initial data load complete: $totalRecords records across ${results.length} tables",
    );
    if (failedTables > 0) {
      print("⚠️ $failedTables table(s) failed to load");
    }

    return results;
  }

  /// Load data for a specific table
  Future<dynamic> loadData({
    required String url,
    required String token,
    required String tableName,
    Map<String, dynamic>? extraParams, // 👈 optional query params
  }) async {
    final deviceId = await DBHelper.getDeviceId48Bit();
    final lastUpdated = await getMaxLastUpdated(tableName);

    try {
      _dio.options.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      // Base query parameters
      final queryParams = <String, dynamic>{
        "tableName": tableName,
        "lastUpdated": lastUpdated ?? 0,
        "deviceId": deviceId.toString(),
      };

      // Add extra params if provided
      if (extraParams != null && extraParams.isNotEmpty) {
        queryParams.addAll(extraParams);
      }

      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final db = await DBHelper.db;
        final validCols = await getTableColumns(db, tableName);

        // Load data in a single transaction for atomicity
        await db.transaction((txn) async {
          if (response.data is List) {
            print(
              "📥 Loading ${response.data.length} records into $tableName (single transaction)",
            );
            for (final row in response.data) {
              final filteredRow = filterRow(
                Map<String, dynamic>.from(row),
                validCols,
              );
              await txn.insert(
                tableName,
                filteredRow,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          } else if (response.data is Map) {
            print("📥 Loading 1 record into $tableName");
            final filteredRow = filterRow(
              Map<String, dynamic>.from(response.data),
              validCols,
            );
            await txn.insert(
              tableName,
              filteredRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        print("✅ Data loaded into $tableName successfully");
        return response.data;
      } else {
        throw Exception("❌ Failed with status code: ${response.statusCode}");
      }
    } on DioException catch (e) {
      print("❌ Dio error: ${e.message}");
      print("Response: ${e.response?.data}");
      rethrow;
    } catch (e) {
      print("❌ Unknown error: $e");
      rethrow;
    }
  }

  static Future<int?> getMaxLastUpdated(String tableName) async {
    final db = await DBHelper.db;
    final result = await db.rawQuery(
      "SELECT MAX(mtds_lastUpdatedTxid) as maxVal FROM $tableName",
    );

    if (result.isNotEmpty && result.first["maxVal"] != null) {
      return int.tryParse(result.first["maxVal"].toString());
    }
    return null;
  }

  static Future<Set<String>> getTableColumns(
    Database db,
    String tableName,
  ) async {
    final result = await db.rawQuery("PRAGMA table_info($tableName)");
    return result.map((row) => row["name"] as String).toSet();
  }

  static Map<String, dynamic> filterRow(
    Map<String, dynamic> row,
    Set<String> validCols,
  ) {
    final filtered = <String, dynamic>{};

    row.forEach((key, value) {
      if (validCols.contains(key)) {
        if (value is bool) {
          filtered[key] = value ? 1 : 0; // SQLite stores bool as 0/1
        } else if (value is Map) {
          // 👇 Fix: convert Map (like {type: Buffer, data: [...]}) to JSON string
          filtered[key] = jsonEncode(value);
        } else if (value is List) {
          filtered[key] = jsonEncode(value);
        } else {
          filtered[key] = value;
        }
      }
    });

    return filtered;
  }

  // static Map<String, dynamic> filterRow(
  //   Map<String, dynamic> row,
  //   Set<String> validCols,
  // ) {
  //   final filtered = <String, dynamic>{};

  //   row.forEach((key, value) {
  //     if (validCols.contains(key)) {
  //       if (value is bool) {
  //         filtered[key] = value ? 1 : 0; // SQLite stores bool as 0/1
  //       } else {
  //         filtered[key] = value;
  //       }
  //     }
  //   });

  //   return filtered;
  // }
}
