import '../database/state_table_service.dart';

/// Helper class for preparing records for insert/update operations.
///
/// **Why Application-Level Helpers Instead of Pure Trigger-Based Approach?**
///
/// SQLite triggers have limitations that prevent us from fully implementing
/// the spec requirements in triggers alone:
///
/// 1. **No RETURNING Clause**: SQLite doesn't support RETURNING in UPDATE
///    statements, making it difficult to get the updated client timestamp
///    in the same statement that updates it.
///
/// 2. **Limited NEW Value Modification**: While SQLite BEFORE INSERT triggers
///    can modify NEW values, the syntax is complex and unreliable across
///    different SQLite versions. Direct assignment like `SET NEW.column = value`
///    is not supported.
///
/// 3. **Complex Bitwise Operations**: The primary key generation formula
///    requires bitwise operations that are better handled in application code.
///
/// **Solution**: Application-level helpers that:
/// - Automatically populate `mtds_device_id` and `mtds_client_ts` before insert/update
/// - Generate primary keys using the specified formula
/// - Work seamlessly with Drift ORM
/// - Ensure atomic state table updates (triggers still handle this)
///
/// This approach:
/// - ✅ Meets spec requirements (automatic population)
/// - ✅ Works reliably across all SQLite versions
/// - ✅ Is maintainable and testable
/// - ✅ Provides better error handling and debugging
class RecordHelper {
  final StateTableService _stateService;
  final int _deviceId;

  RecordHelper({required StateTableService stateService, required int deviceId})
    : _stateService = stateService,
      _deviceId = deviceId;

  /// Generate a primary key using device ID and client timestamp.
  ///
  /// Formula: `pk = ((((DeviceID << 16) + mtds_client_ts) & 0xFFFFFFFFFF) << 24) | (DeviceID & 0xFFFFFF)`
  ///
  /// This encodes:
  /// - Upper 40 bits: Logical milliseconds since 2025 epoch + device ID mix
  /// - Lower 24 bits: Last 24 bits of device ID
  ///
  /// Parameters:
  /// - `deviceId`: 64-bit device identifier
  /// - `clientTs`: Client timestamp in milliseconds since 2025 epoch
  ///
  /// Returns:
  /// - 64-bit integer primary key
  ///
  /// Example:
  /// ```dart
  /// final pk = helper.generatePrimaryKey(deviceId, clientTs);
  /// ```
  int generatePrimaryKey(int deviceId, int clientTs) {
    // Extract last 24 bits of device ID
    final dev24 = deviceId & 0xFFFFFF;

    // Calculate mix40: ((DeviceID << 16) + mtds_client_ts) & 0xFFFFFFFFFF
    final mix40 = ((deviceId << 16) + clientTs) & 0xFFFFFFFFFF;

    // Final PK: (mix40 << 24) | dev24
    return (mix40 << 24) | dev24;
  }

  /// Prepare a record for INSERT operation.
  ///
  /// This method:
  /// 1. Gets the next client timestamp (monotonic, atomic)
  /// 2. Gets device ID from state table
  /// 3. Generates primary key if needed (if primaryKeyColumn provided and not set)
  /// 4. Sets `mtds_device_id` and `mtds_client_ts`
  ///
  /// **Note**: The triggers still update the state table atomically to ensure
  /// monotonic timestamps even under concurrent operations. This helper ensures
  /// the values are set correctly before the insert happens.
  ///
  /// Parameters:
  /// - `record`: Map of column names to values (can be Drift Insertable or plain Map)
  /// - `primaryKeyColumn`: Optional primary key column name. If provided and
  ///   the record doesn't have this key, a primary key will be generated.
  ///
  /// Returns:
  /// - Map with MTDS columns populated (ready for insert)
  ///
  /// Example:
  /// ```dart
  /// final record = {'name': 'John', 'email': 'john@example.com'};
  /// final prepared = await helper.prepareForInsert(record, 'id');
  /// // prepared now has: id, mtds_device_id, mtds_client_ts set
  /// ```
  Future<Map<String, dynamic>> prepareForInsert(
    Map<String, dynamic> record, {
    String? primaryKeyColumn,
  }) async {
    // Get next client timestamp (atomic, monotonic)
    // The trigger will also update this, but we need the value here
    final clientTs = await _stateService.getNextClientTimestamp();
    final clientTsInt = clientTs.toInt();

    // Generate primary key if needed
    if (primaryKeyColumn != null &&
        !record.containsKey(primaryKeyColumn) &&
        record[primaryKeyColumn] == null) {
      final pk = generatePrimaryKey(_deviceId, clientTsInt);
      record[primaryKeyColumn] = pk;
    }

    // Set MTDS columns
    record['mtds_device_id'] = _deviceId;
    record['mtds_client_ts'] = clientTsInt;

    return record;
  }

  /// Prepare a record for UPDATE operation.
  ///
  /// This method:
  /// 1. Gets the next client timestamp (monotonic, atomic)
  /// 2. Gets device ID from state table
  /// 3. Sets `mtds_device_id` and `mtds_client_ts`
  ///
  /// **Note**: The triggers still update the state table atomically. This helper
  /// ensures the values are set correctly before the update happens.
  ///
  /// Parameters:
  /// - `record`: Map of column names to values (can be Drift Updateable or plain Map)
  ///
  /// Returns:
  /// - Map with MTDS columns populated (ready for update)
  ///
  /// Example:
  /// ```dart
  /// final record = {'name': 'Jane'};
  /// final prepared = await helper.prepareForUpdate(record);
  /// // prepared now has: mtds_device_id, mtds_client_ts set
  /// ```
  Future<Map<String, dynamic>> prepareForUpdate(
    Map<String, dynamic> record,
  ) async {
    // Get next client timestamp (atomic, monotonic)
    // The trigger will also update this, but we need the value here
    final clientTs = await _stateService.getNextClientTimestamp();
    final clientTsInt = clientTs.toInt();

    // Set MTDS columns
    record['mtds_device_id'] = _deviceId;
    record['mtds_client_ts'] = clientTsInt;

    return record;
  }

  /// Get the current device ID.
  ///
  /// Returns the device ID that was set during initialization.
  int get deviceId => _deviceId;

  /// Get the next client timestamp without modifying the record.
  ///
  /// Useful for cases where you need the timestamp but want to handle
  /// record preparation manually.
  ///
  /// Returns:
  /// - BigInt representing milliseconds since 2025 epoch
  Future<BigInt> getNextClientTimestamp() {
    return _stateService.getNextClientTimestamp();
  }
}
