import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../utils/bigint_utils.dart';

/// Helper class for table schema operations.
///
/// Provides utilities for querying table schema information,
/// finding primary keys, column types, and other schema-related operations.
class TableSchemaHelper {
  final GeneratedDatabase db;

  TableSchemaHelper({required this.db});

  /// Get the primary key column name for a table.
  ///
  /// Throws an exception if no primary key is found.
  Future<String> getPrimaryKeyColumn(String tableName) async {
    final tableInfo = await db.customSelect('PRAGMA table_info($tableName)').get();
    final pkColumn = tableInfo.firstWhere(
      (col) => col.data['pk'] == 1,
      orElse: () => throw Exception('No PK for table $tableName'),
    );
    return pkColumn.data['name'] as String;
  }

  /// Get column types for a table.
  ///
  /// Returns a map of column names to their SQLite types (e.g., 'BLOB', 'INTEGER', 'TEXT').
  Future<Map<String, String>> getColumnTypes(String tableName) async {
    try {
      final tableInfo =
          await db.customSelect('PRAGMA table_info($tableName)').get();

      final columnTypes = <String, String>{};
      for (final col in tableInfo) {
        final name = col.data['name'] as String?;
        final type = col.data['type'] as String?;
        if (name != null && type != null) {
          columnTypes[name] = type;
        }
      }

      return columnTypes;
    } catch (e) {
      print('⚠️ Error getting column types for $tableName: $e');
      return {};
    }
  }

  /// Get all column names for a table.
  Future<List<String>> getTableColumns(String tableName) async {
    final tableInfo =
        await db.customSelect('PRAGMA table_info($tableName)').get();
    return tableInfo.map((col) => col.data['name'] as String).toList();
  }

  /// Find the maximum server timestamp in a list of rows.
  ///
  /// Returns the maximum `mtds_server_ts` value found, or null if none exist.
  static BigInt? findMaxServerTimestamp(List<Map<String, dynamic>> rows) {
    BigInt? maxTs;

    for (final row in rows) {
      final serverTs = BigIntUtils.toBigInt(row['mtds_server_ts']);
      if (serverTs != null) {
        if (maxTs == null || serverTs > maxTs) {
          maxTs = serverTs;
        }
      }
    }

    return maxTs;
  }

  /// Convert a value to a Drift Variable for use in queries.
  ///
  /// Handles various Dart types and converts them to appropriate Drift Variable types.
  static Variable variableForValue(Object? value) {
    if (value is int) return Variable.withInt(value);
    if (value is double) return Variable.withReal(value);
    if (value is num) return Variable.withReal(value.toDouble());
    if (value is bool) return Variable.withBool(value);
    if (value is Uint8List) return Variable.withBlob(value);
    if (value is String) return Variable.withString(value);
    return Variable.withString(value?.toString() ?? '');
  }
}

