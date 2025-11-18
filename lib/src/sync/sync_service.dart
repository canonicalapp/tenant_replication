import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../models/sync_result.dart';

/// Service for handling synchronization with the server
///
/// Manages uploading local changes to the server and updating
/// local records with server-assigned timestamps.
class SyncService {
  final GeneratedDatabase db;
  final Dio httpClient;
  final String serverUrl;
  final int deviceId;

  SyncService({
    required this.db,
    required this.httpClient,
    required this.serverUrl,
    required this.deviceId,
  });

  /// Sync local changes to the server
  ///
  /// 1. Fetches all changes from mtds_change_log
  /// 2. Sends changes to server with clientTxid
  /// 3. Receives serverTxid for each change
  /// 4. Updates local records with server timestamps
  /// 5. Clears the change log
  ///
  /// Returns a [SyncResult] with success status and count of processed changes.
  ///
  /// Example:
  /// ```dart
  /// final result = await syncService.syncToServer();
  /// if (result.success) {
  ///   print('Synced ${result.processed} changes');
  /// }
  /// ```
  Future<SyncResult> syncToServer() async {
    try {
      print('🔄 Starting sync to server...');

      // Get all pending changes
      final changes = await _getChangeLogs();

      if (changes.isEmpty) {
        print('✅ No changes to sync');
        return SyncResult(success: true, processed: 0, errors: 0, total: 0);
      }

      print('📤 Syncing ${changes.length} changes to server...');

      // Normalize changes: rename txid → clientTxid
      final normalizedChanges =
          changes.map((change) {
            final normalized = Map<String, dynamic>.from(change);

            // Parse payload if it's a string
            if (normalized['payload'] is String) {
              try {
                normalized['payload'] = jsonDecode(
                  normalized['payload'] as String,
                );
              } catch (e) {
                print('⚠️ Failed to parse payload: $e');
              }
            }

            // Rename txid to clientTxid for server
            normalized['clientTxid'] = normalized['txid'];

            return normalized;
          }).toList();

      // Log changes being sent
      print('📋 Changes to sync:');
      for (var i = 0; i < normalizedChanges.length; i++) {
        final change = normalizedChanges[i];
        print(
          '   ${i + 1}. ${change['table']} [${change['action']}] '
          'PK=${change['record_pk']} txid=${change['clientTxid']}',
        );
      }

      // Send to server
      print('📤 Sending changes to: $serverUrl/mtdd/sync/changes');
      final response = await httpClient.post(
        '$serverUrl/mtdd/sync/changes',
        data: {'changes': normalizedChanges},
      );

      print('📥 Server response: HTTP ${response.statusCode}');
      print('   Response data: ${response.data}');

      // HTTP 200 = full success, HTTP 207 = partial success (some failures)
      // Both are valid responses - check the response body for actual status
      if (response.statusCode == 200 || response.statusCode == 207) {
        final responseData = response.data as Map<String, dynamic>;
        final success = responseData['success'] as bool? ?? false;
        final processed = responseData['processed'] as int? ?? 0;
        final errors = responseData['errors'] as int? ?? 0;
        final errorDetails = responseData['errorDetails'] as List<dynamic>?;
        final failedChanges = responseData['failed'] as List<dynamic>?;

        // Log error details if available
        if (errorDetails != null && errorDetails.isNotEmpty) {
          print('❌ Server error details:');
          for (var error in errorDetails) {
            print('   - $error');
          }
        }

        if (failedChanges != null && failedChanges.isNotEmpty) {
          print('❌ Failed changes:');
          for (var failed in failedChanges) {
            print('   - $failed');
          }
        }

        // Update local records with server timestamps
        final serverUpdates = responseData['updates'] as List<dynamic>?;
        if (serverUpdates != null && serverUpdates.isNotEmpty) {
          print('🔄 Received ${serverUpdates.length} server updates');
          await _updateLocalWithServerTxids(serverUpdates);
        } else {
          print('⚠️ No server updates received');
        }

        // Process confirmed soft deletes (only for successful changes)
        if (success || processed > 0) {
          await _processConfirmedSoftDeletes(normalizedChanges);
        }

        // Clear change log only if all changes were processed successfully
        if (success && errors == 0) {
          print('🗑️ Clearing all changes from log (all succeeded)');
          await db.customStatement('DELETE FROM mtds_change_log');
        } else if (processed > 0) {
          // Remove only successfully processed changes from log
          final processedClientTxids =
              serverUpdates
                  ?.map((u) => u['clientTxid'] as int?)
                  .whereType<int>()
                  .toList() ??
              [];
          if (processedClientTxids.isNotEmpty) {
            print(
              '🗑️ Removing ${processedClientTxids.length} processed changes from log',
            );
            final placeholders = List.filled(
              processedClientTxids.length,
              '?',
            ).join(',');
            await db.customStatement(
              'DELETE FROM mtds_change_log WHERE txid IN ($placeholders)',
              processedClientTxids,
            );
          } else {
            print('⚠️ No processed clientTxids found in server updates');
          }
        } else {
          print('⚠️ No changes were processed, keeping all in log');
        }

        if (success) {
          print('✅ Sync complete: $processed changes processed');
        } else {
          print('⚠️ Sync partial: $processed succeeded, $errors failed');
        }

        return SyncResult(
          success: success,
          processed: processed,
          errors: errors,
          total: changes.length,
          errorMessage:
              success
                  ? null
                  : 'Some changes failed (processed: $processed, errors: $errors)',
        );
      } else {
        print('❌ Sync failed: HTTP ${response.statusCode}');
        return SyncResult(
          success: false,
          processed: 0,
          errors: changes.length,
          total: changes.length,
          errorMessage: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Sync DioException:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status Code: ${e.response?.statusCode}');
      if (e.response != null) {
        print('   Response Data: ${e.response!.data}');
        print('   Response Headers: ${e.response!.headers}');
      }
      print('   Request URL: ${e.requestOptions.uri}');
      print('   Request Data: ${e.requestOptions.data}');
      return SyncResult(
        success: false,
        processed: 0,
        errors: 0,
        total: 0,
        errorMessage: e.message ?? 'Unknown Dio error',
      );
    } catch (e, stackTrace) {
      print('❌ Sync unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return SyncResult(
        success: false,
        processed: 0,
        errors: 0,
        total: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load latest data from server for specified tables.
  ///
  /// For each table the server returns an array of rows (maps) which we
  /// upsert into Drift, respecting MTDS timestamps to avoid clobbering newer data.
  Future<void> loadFromServer({required List<String> tableNames}) async {
    if (tableNames.isEmpty) {
      return;
    }

    try {
      print('🌐 Loading data from server for tables: $tableNames');
      final response = await httpClient.post(
        '$serverUrl/mtdd/sync/bulk-load',
        data: {'tables': tableNames},
      );

      if (response.statusCode != 200) {
        print('❌ loadFromServer failed: HTTP ${response.statusCode}');
        return;
      }

      final payload = response.data as Map<String, dynamic>?;
      if (payload == null) {
        print('⚠️ loadFromServer response missing payload');
        return;
      }

      for (final table in tableNames) {
        final rows = payload[table];
        if (rows is List) {
          print('📋 Processing ${rows.length} rows for table: $table');
          await _upsertRows(table, rows.cast<Map<String, dynamic>>());
        } else {
          print(
            '⚠️ Table $table: payload is not a List (type: ${rows.runtimeType})',
          );
        }
      }
    } on DioException catch (e) {
      print('❌ loadFromServer Dio error: ${e.message}');
    } catch (e) {
      print('❌ loadFromServer error: $e');
    }
  }

  /// Get all pending changes from the change log
  Future<List<Map<String, dynamic>>> _getChangeLogs() async {
    final result =
        await db
            .customSelect('SELECT * FROM mtds_change_log ORDER BY txid ASC')
            .get();

    return result.map((row) => row.data).toList();
  }

  /// Update local records with server-assigned timestamps
  ///
  /// For each change, updates the local record's mtds_lastUpdatedTxid
  /// with the authoritative timestamp from the server.
  Future<void> _updateLocalWithServerTxids(List<dynamic> serverUpdates) async {
    print('🔄 Updating local records with server timestamps...');

    for (final update in serverUpdates) {
      try {
        final clientTxid = update['clientTxid'] as int;
        final serverTxid = update['serverTxid'] as int;
        final tableName = update['tableName'] as String;
        final pk = update['pk'];

        // Clock skew detection
        final skew = serverTxid - clientTxid;
        if (skew.abs() > 5000000000) {
          // More than 5 seconds difference
          print(
            '⚠️ Clock skew detected: ${skew ~/ 1000000}ms '
            '(client: $clientTxid, server: $serverTxid)',
          );
        }

        // Get primary key column name
        final tableInfo =
            await db.customSelect('PRAGMA table_info($tableName)').get();

        final pkColumn =
            tableInfo
                    .firstWhere(
                      (col) => col.data['pk'] == 1,
                      orElse:
                          () =>
                              throw Exception(
                                'No primary key found for table $tableName',
                              ),
                    )
                    .data['name']
                as String;

        // Update local record with server timestamp
        await db.customStatement(
          'UPDATE $tableName SET mtds_last_updated_txid = ? WHERE $pkColumn = ?',
          [serverTxid, pk],
        );

        print('✅ Updated $tableName[$pkColumn=$pk]: $clientTxid → $serverTxid');
      } catch (e) {
        print('❌ Error updating local record: $e');
      }
    }
  }

  /// Process confirmed soft deletes
  ///
  /// After server confirms sync, permanently remove soft-deleted records
  /// from the local database.
  Future<void> _processConfirmedSoftDeletes(
    List<Map<String, dynamic>> changes,
  ) async {
    for (final change in changes) {
      try {
        final payload = change['payload'] as Map<String, dynamic>?;
        if (payload == null) continue;

        final newData = payload['New'] as Map<String, dynamic>?;
        if (newData == null) continue;

        final deletedTxid = newData['mtds_deleted_txid'];
        if (deletedTxid != null) {
          final tableName = change['table_name'] as String;
          final pk = change['record_pk'];

          // Get primary key column name
          final tableInfo =
              await db.customSelect('PRAGMA table_info($tableName)').get();

          final pkColumn =
              tableInfo
                      .firstWhere(
                        (col) => col.data['pk'] == 1,
                        orElse:
                            () =>
                                throw Exception(
                                  'No primary key found for table $tableName',
                                ),
                      )
                      .data['name']
                  as String;

          // Permanently remove soft-deleted record
          await db.customStatement(
            'DELETE FROM $tableName WHERE $pkColumn = ?',
            [pk],
          );

          print(
            '🗑️ Permanently removed soft-deleted record: $tableName[$pkColumn=$pk]',
          );
        }
      } catch (e) {
        print('❌ Error processing soft delete: $e');
      }
    }
  }

  Future<void> _upsertRows(
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

    for (final row in rows) {
      final pkValue = row[pkName];

      // Handle serverTxid - could be int, String, or null
      int? serverTxid;
      final serverTxidRaw = row['mtds_last_updated_txid'];
      if (serverTxidRaw != null) {
        if (serverTxidRaw is int) {
          serverTxid = serverTxidRaw;
        } else if (serverTxidRaw is String) {
          serverTxid = int.tryParse(serverTxidRaw);
        } else if (serverTxidRaw is num) {
          serverTxid = serverTxidRaw.toInt();
        }
      }

      if (pkValue == null) {
        print('   ⚠️ Skipping row: missing PK value ($pkName)');
        print('      Row keys: ${row.keys.toList()}');
        skipped++;
        continue;
      }

      if (serverTxid == null) {
        print(
          '   ⚠️ Skipping row: missing or invalid mtds_last_updated_txid for PK=$pkValue '
          '(value: $serverTxidRaw, type: ${serverTxidRaw.runtimeType})',
        );
        skipped++;
        continue;
      }

      final existing =
          await db
              .customSelect(
                'SELECT mtds_last_updated_txid AS txid FROM $tableName WHERE $pkName = ?',
                variables: [_variableForValue(pkValue)],
              )
              .get();

      // Handle localTxid - could be int or null from database
      int? localTxid;
      if (!existing.isEmpty) {
        final txidValue = existing.first.data['txid'];
        if (txidValue is int) {
          localTxid = txidValue;
        } else if (txidValue is String) {
          localTxid = int.tryParse(txidValue);
        } else if (txidValue is num) {
          localTxid = txidValue.toInt();
        }
      }

      if (localTxid != null && localTxid >= serverTxid) {
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

      // Filter columns to only include those that exist in local schema
      // and are present in the server response
      final validColumns =
          columns.where((col) {
            // Only include columns that exist in local schema AND in server response
            return row.containsKey(col);
          }).toList();

      if (validColumns.isEmpty) {
        print('   ⚠️ Skipping row: no valid columns found for PK=$pkValue');
        print('      Local columns: $columns');
        print('      Server row keys: ${row.keys.toList()}');
        skipped++;
        continue;
      }

      final placeholders = List.filled(validColumns.length, '?').join(', ');
      final columnNames = validColumns.join(', ');
      final values =
          validColumns.map((col) {
            final value = row[col];
            if (value == null && !row.containsKey(col)) {
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

  Variable _variableForValue(Object? value) {
    if (value is int) return Variable.withInt(value);
    if (value is double) return Variable.withReal(value);
    if (value is num) return Variable.withReal(value.toDouble());
    if (value is bool) return Variable.withBool(value);
    if (value is Uint8List) return Variable.withBlob(value);
    if (value is String) return Variable.withString(value);
    return Variable.withString(value?.toString() ?? '');
  }
}
