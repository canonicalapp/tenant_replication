import 'dart:convert';
import 'package:crypto/crypto.dart';

/// MTDS Protocol Utilities
///
/// Core utilities for Multi-Tenant Data Synchronization protocol:
/// - DeviceID validation (48-bit support)
/// - Database name generation
class MtdsUtils {
  /// Maximum value for 48-bit DeviceID
  static const int maxDeviceId = 0xFFFFFFFFFFFF; // 281,474,976,710,655

  // ============================================================================
  // Utilities
  // ============================================================================

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

  /// Generate a random device ID within the 48-bit limit
  ///
  /// Returns a random integer between 1 and maxDeviceId (inclusive).
  /// Uses DateTime-based seed for randomness.
  static int generateRandomDeviceId() {
    final random = DateTime.now().microsecondsSinceEpoch % maxDeviceId;
    // Ensure non-zero (0 is reserved/invalid)
    return random == 0 ? 1 : random;
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
