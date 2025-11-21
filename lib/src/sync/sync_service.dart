import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../models/sync_result.dart';
import '../utils/bigint_utils.dart';
import '../database/state_table_service.dart';
import 'change_log_service.dart';
import 'row_upsert_service.dart';
import 'sync_payload_processor.dart';
import 'table_schema_helper.dart';

/// Service for handling synchronization with the server
///
/// Manages uploading local changes to the server and updating
/// local records with server-assigned timestamps.
///
/// This service orchestrates the sync process by coordinating:
/// - Change log operations
/// - Payload serialization/processing
/// - Row upsert operations
/// - Server communication
class SyncService {
  final GeneratedDatabase db;
  final Dio httpClient;
  final String serverUrl;
  final int deviceId;
  final StateTableService _stateService;
  final ChangeLogService _changeLogService;
  final SyncPayloadProcessor _payloadProcessor;
  final RowUpsertService _rowUpsertService;

  SyncService({
    required this.db,
    required this.httpClient,
    required this.serverUrl,
    required this.deviceId,
  }) : _stateService = StateTableService(db: db),
       _changeLogService = ChangeLogService(db: db),
       _payloadProcessor = SyncPayloadProcessor(db: db),
       _rowUpsertService = RowUpsertService(db: db);

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
      final changes = await _changeLogService.getChangeLogs();

      if (changes.isEmpty) {
        print('✅ No changes to sync');
        return SyncResult(success: true, processed: 0, errors: 0, total: 0);
      }

      print('📤 Syncing ${changes.length} changes to server...');

      // Normalize changes: rename txid → clientTxid and serialize payload
      final normalizedChanges = await _payloadProcessor
          .normalizeChangesForServer(changes);

      // Log changes being sent
      print('📋 Changes to sync:');
      for (var i = 0; i < normalizedChanges.length; i++) {
        final change = normalizedChanges[i];
        print(
          '   ${i + 1}. ${change['table_name']} [${change['action']}] '
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

      return _handleSyncResponse(response, normalizedChanges, changes);
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

  /// Handle server response from sync operation.
  Future<SyncResult> _handleSyncResponse(
    Response response,
    List<Map<String, dynamic>> normalizedChanges,
    List<Map<String, dynamic>> originalChanges,
  ) async {
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
        await _payloadProcessor.updateLocalWithServerTimestamps(serverUpdates);
      } else {
        print('⚠️ No server updates received');
      }

      // Process confirmed soft deletes (only for successful changes)
      if (success || processed > 0) {
        await _payloadProcessor.processConfirmedSoftDeletes(normalizedChanges);
      }

      // Clear change log only if all changes were processed successfully
      if (success && errors == 0) {
        print('🗑️ Clearing all changes from log (all succeeded)');
        await _changeLogService.clearChangeLog();
      } else if (processed > 0) {
        // Remove only successfully processed changes from log
        // Convert clientTxid to BigInt, then to int for change log comparison
        final processedClientTxids =
            serverUpdates
                ?.map((u) => BigIntUtils.toBigInt(u['clientTxid']))
                .whereType<BigInt>()
                .map((b) => b.toInt())
                .toList() ??
            [];
        if (processedClientTxids.isNotEmpty) {
          print(
            '🗑️ Removing ${processedClientTxids.length} processed changes from log',
          );
          await _changeLogService.removeProcessedChanges(processedClientTxids);
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
        total: originalChanges.length,
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
        errors: originalChanges.length,
        total: originalChanges.length,
        errorMessage: 'Server returned ${response.statusCode}',
      );
    }
  }

  /// Initial sync: Get updates since last sync for all tables.
  ///
  /// This method:
  /// 1. Gets MAX(mtds_server_ts) for each table from state table (cached)
  /// 2. Sends table names with max timestamps to server
  /// 3. Receives updates where mtds_server_ts > requested_timestamp
  /// 4. Filters by device ID to prevent loops
  /// 5. Applies updates to local database
  /// 6. Updates state table with new MAX timestamps
  ///
  /// **Device ID Filtering**: Updates from the same device are skipped to prevent
  /// infinite synchronization loops. Only updates from other devices are applied.
  ///
  /// Parameters:
  /// - `tableNames`: List of table names to sync
  ///
  /// Example:
  /// ```dart
  /// await syncService.initialSync(tableNames: ['users', 'products']);
  /// ```
  Future<void> initialSync({required List<String> tableNames}) async {
    if (tableNames.isEmpty) {
      return;
    }

    try {
      print('🔄 Starting initial sync for tables: $tableNames');

      // Get MAX timestamps for each table from state table (cached)
      final tableTimestamps = await _stateService.getMaxServerTimestamps(
        tableNames,
      );

      // Build request payload with table names and timestamps
      final requestPayload = <String, dynamic>{};
      for (final tableName in tableNames) {
        final maxTs = tableTimestamps[tableName] ?? BigInt.zero;
        requestPayload[tableName] = maxTs.toString();
        print('   $tableName: MAX timestamp = $maxTs');
      }

      // Send SyncAllTables request to server
      print(
        '📤 Sending initial sync request to: $serverUrl/mtdd/sync/sync-all-tables',
      );
      final response = await httpClient.post(
        '$serverUrl/mtdd/sync/sync-all-tables',
        data: {'tables': requestPayload},
      );

      if (response.statusCode != 200) {
        print('❌ initialSync failed: HTTP ${response.statusCode}');
        return;
      }

      final payload = response.data as Map<String, dynamic>?;
      if (payload == null) {
        print('⚠️ initialSync response missing payload');
        return;
      }

      // Process updates for each table
      for (final tableName in tableNames) {
        final rows = payload[tableName];
        if (rows is List) {
          print('📋 Processing ${rows.length} rows for table: $tableName');
          await _rowUpsertService.upsertRowsWithDeviceFilter(
            tableName,
            rows.cast<Map<String, dynamic>>(),
            deviceId,
          );

          // Update MAX timestamp in state table after sync
          if (rows.isNotEmpty) {
            final maxServerTs = TableSchemaHelper.findMaxServerTimestamp(
              rows.cast<Map<String, dynamic>>(),
            );
            if (maxServerTs != null && maxServerTs > BigInt.zero) {
              await _stateService.updateMaxServerTimestamp(
                tableName,
                maxServerTs,
              );
              print('   ✅ Updated MAX timestamp for $tableName: $maxServerTs');
            }
          }
        } else {
          print(
            '⚠️ Table $tableName: payload is not a List (type: ${rows.runtimeType})',
          );
        }
      }

      print('✅ Initial sync completed');
    } on DioException catch (e) {
      print('❌ initialSync Dio error: ${e.message}');
    } catch (e) {
      print('❌ initialSync error: $e');
    }
  }

  /// Load latest data from server for specified tables.
  ///
  /// For each table the server returns an array of rows (maps) which we
  /// upsert into Drift, respecting MTDS timestamps to avoid clobbering newer data.
  ///
  /// **Note**: This method does NOT filter by device ID. Use [initialSync] for
  /// device ID filtering. This method is kept for backward compatibility.
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
          await _rowUpsertService.upsertRows(
            table,
            rows.cast<Map<String, dynamic>>(),
          );
        } else {
          print(
            '⚠️ Table $table: payload is not a List (type: ${rows.runtimeType})',
          );
        }
      }

      // Update MAX timestamps in state table after load
      for (final tableName in tableNames) {
        final rows = payload[tableName];
        if (rows is List && rows.isNotEmpty) {
          final maxServerTs = TableSchemaHelper.findMaxServerTimestamp(
            rows.cast<Map<String, dynamic>>(),
          );
          if (maxServerTs != null && maxServerTs > BigInt.zero) {
            await _stateService.updateMaxServerTimestamp(
              tableName,
              maxServerTs,
            );
          }
        }
      }
    } on DioException catch (e) {
      print('❌ loadFromServer Dio error: ${e.message}');
    } catch (e) {
      print('❌ loadFromServer error: $e');
    }
  }
}
