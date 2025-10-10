import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tenant_replication/tenant_replication.dart';

import 'sse_handler_web.dart' if (dart.library.io) 'sse_handler_native.dart';

class SSEManager {
  final Dio _dio = Dio();
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<void> initializeSSE(url, token) async {
    String? deviceId = await _secureStorage.read(key: "DeviceId");
    print('Initializing SSE.............................');

    // Create headers with deviceId and authorization token
    Map<String, String> headers = {};
    if (deviceId != null) {
      headers['deviceId'] = deviceId;
    }
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

  Future<dynamic> loadData({
    required String url,
    required String token,
    required String tableName,
    Map<String, dynamic>? extraParams, // 👈 optional query params
  }) async {
    final String? deviceId = await _secureStorage.read(key: "DeviceId");
    final lastUpdated = await getMaxLastUpdated(tableName);

    try {
      _dio.options.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      // Base query parameters
      final queryParams = {
        "tableName": tableName,
        "lastUpdated": lastUpdated ?? 0,
        "deviceId": deviceId,
      };

      // Add extra params if provided
      if (extraParams != null && extraParams.isNotEmpty) {
        queryParams.addAll(extraParams);
      }

      final response = await _dio.get(
        url,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final db = await DBHelper.db;

        final validCols = await getTableColumns(db, tableName);

        if (response.data is List) {
          for (final row in response.data) {
            final filteredRow = filterRow(
              Map<String, dynamic>.from(row),
              validCols,
            );
            await db.insert(
              tableName,
              filteredRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } else if (response.data is Map) {
          final filteredRow = filterRow(
            Map<String, dynamic>.from(response.data),
            validCols,
          );
          await db.insert(
            tableName,
            filteredRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

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
      "SELECT MAX(lastupdated) as maxVal FROM $tableName",
    );

    if (result.isNotEmpty && result.first["maxVal"] != null) {
      return int.tryParse(result.first["maxVal"].toString());
    }
    return null;
  }

  static Future<Set<String>> getTableColumns(Database db, String tableName) async {
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
