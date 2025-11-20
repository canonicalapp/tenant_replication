import 'package:drift/drift.dart';

import '../database/schema_manager.dart';

/// Helper class for storing MTDS-specific metadata inside SQLite.
///
/// Stores device ID and other metadata in the `mtds_metadata` table
/// managed by [SchemaManager]. This approach avoids conflicts with
/// Drift's usage of PRAGMA values.
class PragmaHelper {
  static const _deviceIdKey = 'device_id';

  /// Store the 48-bit DeviceID in `mtds_metadata`.
  static Future<void> setDeviceId(GeneratedDatabase db, int deviceId) async {
    await SchemaManager.ensureMetadataTable(db);
    await SchemaManager.upsertMetadata(
      db,
      key: _deviceIdKey,
      value: deviceId.toString(),
    );
    print('✅ DeviceID stored in metadata table: $deviceId');
  }

  /// Retrieve the DeviceID from `mtds_metadata`, or null if missing.
  static Future<int?> getDeviceId(GeneratedDatabase db) async {
    try {
      await SchemaManager.ensureMetadataTable(db);

      final value = await SchemaManager.readMetadata(db, key: _deviceIdKey);
      if (value == null) {
        return null;
      }
      return int.tryParse(value);
    } catch (e) {
      print('⚠️ Error retrieving DeviceID from metadata: $e');
      return null;
    }
  }

  /// Initialize or retrieve DeviceID.
  ///
  /// If already present in metadata, that value wins. Otherwise we store
  /// the provided [deviceId] and return it.
  static Future<int> initializeDeviceId(
    GeneratedDatabase db,
    int deviceId,
  ) async {
    final existing = await getDeviceId(db);

    if (existing != null) {
      print('✅ Using existing DeviceID from metadata: $existing');
      return existing;
    }

    print('📝 Storing new DeviceID in metadata: $deviceId');
    await setDeviceId(db, deviceId);

    return deviceId;
  }
}
