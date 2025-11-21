import 'package:drift/drift.dart';

import '../helpers/serialization_helper.dart';
import '../utils/bigint_utils.dart';
import 'table_schema_helper.dart';

/// Service for upserting rows from server.
///
/// Handles the logic for inserting/updating rows received from the server,
/// including device ID filtering, timestamp comparison, and data deserialization.
class RowUpsertService {
  final GeneratedDatabase db;
  final TableSchemaHelper _schemaHelper;

  RowUpsertService({required this.db})
      : _schemaHelper = TableSchemaHelper(db: db);

  /// Upsert rows with device ID filtering to prevent loops.
  ///
  /// This method filters out updates from the same device to prevent
  /// infinite synchronization loops.
  ///
  /// Parameters:
  /// - `tableName`: Name of the table
  /// - `rows`: List of rows to upsert
  /// - `deviceId`: Current device ID (rows from this device are filtered out)
  Future<void> upsertRowsWithDeviceFilter(
    String tableName,
    List<Map<String, dynamic>> rows,
    int deviceId,
  ) async {
    if (rows.isEmpty) {
      return;
    }

    // Get primary key column name once
    final pkColumn = await _schemaHelper.getPrimaryKeyColumn(tableName);

    // Filter rows by device ID
    final filteredRows = <Map<String, dynamic>>[];
    int filteredCount = 0;

    for (final row in rows) {
      final rowDeviceId = BigIntUtils.toBigInt(row['mtds_device_id']);
      final rowDeviceIdInt = rowDeviceId?.toInt() ?? 0;

      // Skip updates from the same device (prevent loops)
      if (rowDeviceIdInt == deviceId) {
        filteredCount++;
        final pkValue = row[pkColumn];
        print(
          '   ⏭️ Skipping row from same device (device_id=$rowDeviceIdInt): '
          'PK=$pkValue',
        );
        continue;
      }

      filteredRows.add(row);
    }

    if (filteredCount > 0) {
      print('   🔒 Filtered out $filteredCount rows from same device');
    }

    // Process filtered rows
    if (filteredRows.isNotEmpty) {
      await upsertRows(tableName, filteredRows);
    } else {
      print('   ✅ No rows to process after device ID filtering');
    }
  }

  /// Upsert rows into a table.
  ///
  /// This method:
  /// 1. Validates table schema and row data
  /// 2. Compares local vs server timestamps (skips if local is newer)
  /// 3. Deserializes row data (Base64 decoding, BigInt conversion)
  /// 4. Performs INSERT OR REPLACE operation
  ///
  /// Parameters:
  /// - `tableName`: Name of the table
  /// - `rows`: List of rows to upsert
  Future<void> upsertRows(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      print('⚠️ No rows to upsert for $tableName');
      return;
    }

    print('📥 Processing ${rows.length} rows for $tableName');

    final tableInfo =
        await db.customSelect('PRAGMA table_info($tableName)').get();
    if (tableInfo.isEmpty) {
      print('⚠️ Table $tableName not found locally; skipping load');
      return;
    }

    final pkColumn = tableInfo.firstWhere(
      (col) => col.data['pk'] == 1,
      orElse: () => throw Exception('No PK for table $tableName'),
    );
    final pkName = pkColumn.data['name'] as String;
    print('   Primary key: $pkName');

    final columns = tableInfo.map((col) => col.data['name'] as String).toList();
    print('   Local columns (${columns.length}): ${columns.join(', ')}');

    // Schema verification: Log server-only columns that will be ignored
    if (rows.isNotEmpty) {
      final serverColumns = rows.first.keys.toSet();
      final localColumnsSet = columns.toSet();
      final serverOnlyColumns =
          serverColumns.difference(localColumnsSet).toList();
      if (serverOnlyColumns.isNotEmpty) {
        print(
          '   ⚠️ Server-only columns (will be ignored): ${serverOnlyColumns.join(', ')}',
        );
      }
      final missingColumns = localColumnsSet.difference(serverColumns).toList();
      if (missingColumns.isNotEmpty) {
        print(
          '   ⚠️ Missing server columns (will use defaults): ${missingColumns.join(', ')}',
        );
      }
    }

    int skipped = 0;
    int upserted = 0;
    int errors = 0;

    // Get column types for deserialization
    final columnTypes = await _schemaHelper.getColumnTypes(tableName);
    final binaryFields = columnTypes.entries
        .where((e) => e.value.toUpperCase() == 'BLOB')
        .map((e) => e.key)
        .toList();

    for (final row in rows) {
      final pkValue = row[pkName];

      // Handle serverTxid - convert to BigInt using utility
      final serverTxidRaw = row['mtds_server_ts'];
      final serverTxid = BigIntUtils.toBigInt(serverTxidRaw);

      if (pkValue == null) {
        print('   ⚠️ Skipping row: missing PK value ($pkName)');
        print('      Row keys: ${row.keys.toList()}');
        skipped++;
        continue;
      }

      if (serverTxid == null) {
        print(
          '   ⚠️ Skipping row: missing or invalid mtds_server_ts for PK=$pkValue '
          '(value: $serverTxidRaw, type: ${serverTxidRaw?.runtimeType})',
        );
        skipped++;
        continue;
      }

      // Check if local record exists and compare timestamps
      final existing =
          await db
              .customSelect(
                'SELECT mtds_client_ts AS txid FROM $tableName WHERE $pkName = ?',
                variables: [TableSchemaHelper.variableForValue(pkValue)],
              )
              .get();

      // Handle localTxid - convert to BigInt using utility
      final localTxidRaw =
          existing.isEmpty ? null : existing.first.data['txid'];
      final localTxid = BigIntUtils.toBigInt(localTxidRaw);

      // Check if this is a soft delete update (mtds_delete_ts is set)
      final deleteTs = BigIntUtils.toBigInt(row['mtds_delete_ts']);
      final isSoftDelete = deleteTs != null;

      // If soft delete, perform hard delete instead of upsert
      if (isSoftDelete) {
        try {
          await db.customStatement(
            'DELETE FROM $tableName WHERE $pkName = ?',
            [pkValue],
          );
          print(
            '   🗑️ Hard deleted (soft delete confirmed): $tableName[$pkName=$pkValue]',
          );
          // Count as upserted for summary
          upserted++;
          continue;
        } catch (e) {
          errors++;
          print('   ❌ Error hard deleting $tableName[$pkName=$pkValue]: $e');
          continue;
        }
      }

      // Skip if local timestamp is newer or equal (local wins)
      if (localTxid != null &&
          BigIntUtils.isGreaterOrEqual(localTxid, serverTxid)) {
        print(
          '   ⏭️ Skipping $tableName[$pkName=$pkValue]: '
          'local txid ($localTxid) >= server txid ($serverTxid)',
        );
        skipped++;
        continue;
      }

      if (existing.isEmpty) {
        print('   ➕ Inserting new record: $tableName[$pkName=$pkValue]');
      } else {
        print(
          '   🔄 Updating existing record: $tableName[$pkName=$pkValue] '
          '(local: $localTxid, server: $serverTxid)',
        );
      }

      // Deserialize row data (decode Base64, convert BigInt strings)
      final deserializedRow = SerializationHelper.deserializeRow(
        row,
        binaryFields: binaryFields,
      );

      // Filter columns to only include those that exist in local schema
      // and are present in the server response
      final validColumns =
          columns.where((col) {
            // Only include columns that exist in local schema AND in server response
            return deserializedRow.containsKey(col);
          }).toList();

      if (validColumns.isEmpty) {
        print('   ⚠️ Skipping row: no valid columns found for PK=$pkValue');
        print('      Local columns: $columns');
        print('      Server row keys: ${deserializedRow.keys.toList()}');
        skipped++;
        continue;
      }

      final placeholders = List.filled(validColumns.length, '?').join(', ');
      final columnNames = validColumns.join(', ');
      final values =
          validColumns.map((col) {
            final value = deserializedRow[col];
            if (value == null && !deserializedRow.containsKey(col)) {
              print(
                '   ⚠️ Missing column "$col" in server response for PK=$pkValue',
              );
            }
            return value;
          }).toList();

      try {
        await db.customStatement(
          'INSERT OR REPLACE INTO $tableName ($columnNames) VALUES ($placeholders)',
          values,
        );
        upserted++;
        print('   ✅ Upserted $tableName[$pkName=$pkValue] from server');
      } catch (e, stackTrace) {
        errors++;
        print('   ❌ Error upserting $tableName[$pkName=$pkValue]: $e');
        print('      Columns: $columns');
        print('      Row keys: ${row.keys.toList()}');
        print(
          '      Values count: ${values.length}, Columns count: ${columns.length}',
        );
        print('      Stack trace: $stackTrace');
      }
    }

    print(
      '📊 Summary for $tableName: $upserted upserted, $skipped skipped, $errors errors',
    );
  }
}

