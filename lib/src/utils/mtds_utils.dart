import 'dart:convert';
import 'package:crypto/crypto.dart';

/// MTDS Protocol Utilities
///
/// Core utilities for Multi-Tenant Data Synchronization protocol:
/// - TXID generation (nanosecond timestamps)
/// - DeviceID packing/unpacking (48-bit support)
/// - PRAGMA value encoding
class MtdsUtils {
  /// Maximum value for 48-bit DeviceID
  static const int maxDeviceId = 0xFFFFFFFFFFFF; // 281,474,976,710,655

  // ============================================================================
  // TXID Generation
  // ============================================================================

  /// Generate mtds_lastUpdatedTxid value (nanosecond UTC timestamp)
  ///
  /// This generates a client-side timestamp used for ordering changes
  /// within a batch. The server will override this with an authoritative
  /// server-side timestamp during sync.
  ///
  /// Uses UTC to eliminate timezone confusion across devices.
  static int generateTxid() {
    // ✅ Force UTC to eliminate timezone issues
    final now = DateTime.now().toUtc();
    // Convert microseconds to nanoseconds
    return now.microsecondsSinceEpoch * 1000;
  }

  /// Get current UTC timestamp as ISO 8601 string (for debugging)
  static String getUtcTimestampString() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// Validate DeviceID is within 48-bit limit
  static bool isValidDeviceId(int deviceId) {
    return deviceId >= 0 && deviceId <= maxDeviceId;
  }

  /// Ensure DeviceID fits in 48 bits, throw if not
  static int validateDeviceId(int deviceId) {
    if (!isValidDeviceId(deviceId)) {
      throw ArgumentError(
        'DeviceID exceeds 48-bit limit: $deviceId (max: $maxDeviceId)',
      );
    }

    return deviceId;
  }

  // ============================================================================
  // DeviceID Packing (for SQLite PRAGMA values)
  // ============================================================================
  /// Pack App Version (16 bits) and MS 16 bits of DeviceID into user_version (32 bits)
  /// Layout: [App Version: 16 bits][DeviceID MS 16 bits: 16 bits]
  static int packUserVersion(int appVersion, int deviceId) {
    validateDeviceId(deviceId);

    final appVersionMasked = appVersion & 0xFFFF; // Mask to 16 bits
    final deviceIdMS16 = (deviceId >> 32) & 0xFFFF; // Get MS 16 bits

    return (appVersionMasked << 16) | deviceIdMS16;
  }

  /// Pack LS 32 bits of DeviceID into application_id (32 bits)
  /// Layout: [DeviceID LS 32 bits: 32 bits]
  static int packApplicationId(int deviceId) {
    validateDeviceId(deviceId);
    return deviceId & 0xFFFFFFFF; // Get LS 32 bits
  }

  /// Unpack user_version to extract App Version (16 bits)
  static int unpackAppVersion(int userVersion) {
    return (userVersion >> 16) & 0xFFFF;
  }

  /// Unpack user_version to extract MS 16 bits of DeviceID
  static int unpackDeviceIdMS16(int userVersion) {
    return userVersion & 0xFFFF;
  }

  /// Reconstruct 48-bit DeviceID from user_version and application_id
  static int reconstructDeviceId(int userVersion, int applicationId) {
    final deviceIdMS16 = unpackDeviceIdMS16(userVersion);
    final deviceIdLS32 = applicationId & 0xFFFFFFFF;

    // Reconstruct: [MS 16 bits][LS 32 bits]
    return (deviceIdMS16 << 32) | deviceIdLS32;
  }

  // ============================================================================
  // Database Name Generation (SHA256)
  // ============================================================================
  /// Generate database name using SHA256('sub:tid:app')
  /// Format: XXXX-XXXX-XXXX-...-XXXX.db (64 hex chars + hyphens)
  static String generateDatabaseName({
    required String subjectId,
    required String tenantId,
    required String appName,
  }) {
    // Validate inputs
    if (subjectId.isEmpty || tenantId.isEmpty || appName.isEmpty) {
      throw ArgumentError('subjectId, tenantId, and appName must not be empty');
    }

    // Create the string: 'sub:tid:app'
    final input = '$subjectId:$tenantId:$appName';

    // Generate SHA256 hash
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);

    // Convert to uppercase hex string (64 characters)
    final hexString = digest.toString().toUpperCase();

    // Format with hyphens every 4 characters
    final buffer = StringBuffer();

    for (int i = 0; i < hexString.length; i += 4) {
      if (i > 0) buffer.write('-');

      buffer.write(hexString.substring(i, i + 4));
    }

    return '${buffer.toString()}.db';
  }
}
