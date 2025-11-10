import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'auth/auth_service.dart';
import 'auth/default_auth_service.dart';

class DBHelper {
  static Database? _db;
  static String? _currentDbName;
  static AuthService? _authService;

  /// Set a custom auth service implementation
  /// If not set, DefaultAuthService will be used
  static void setAuthService(AuthService authService) {
    _authService = authService;
  }

  /// Get the current auth service (creates default if not set)
  static AuthService get authService {
    _authService ??= DefaultAuthService();
    return _authService!;
  }

  // Constants
  static const int _appVersion = 1; // Application schema version

  /// Pack App Version (16 bits) and MS 16 bits of DeviceID (48 bits total) into user_version (32 bits)
  /// Layout: [App Version: 16 bits][DeviceID MS 16 bits: 16 bits]
  static int packUserVersion(int appVersion, int deviceId) {
    // Mask to 16 bits each
    final appVersionMasked = appVersion & 0xFFFF;
    final deviceIdMS16 =
        (deviceId >> 32) & 0xFFFF; // Get MS 16 bits of 48-bit DeviceID

    // Pack: [App Version][DeviceID MS 16 bits]
    return (appVersionMasked << 16) | deviceIdMS16;
  }

  /// Pack LS 32 bits of DeviceID (48 bits total) into application_id (32 bits)
  /// Layout: [DeviceID LS 32 bits: 32 bits]
  static int packApplicationId(int deviceId) {
    // Get LS 32 bits of 48-bit DeviceID
    return deviceId & 0xFFFFFFFF;
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

  /// Generate 64-bit nanosecond timestamp since epoch
  static int generateNanosecondTimestamp() {
    final now = DateTime.now();
    // Get microseconds since epoch and convert to nanoseconds
    return now.microsecondsSinceEpoch * 1000;
  }

  /// Generate mtds_lastUpdatedTxid value (nanosecond timestamp)
  /// This should be used when creating or updating records
  static int generateTxid() {
    return generateNanosecondTimestamp();
  }

  /// Perform a soft delete on a record
  /// Sets mtds_DeletedTXID to mark for deletion
  /// The record will be replicated to server and then deleted locally on sync confirmation
  static Future<void> softDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    final db = await DBHelper.db;
    final deviceId = await getDeviceId48Bit();
    final deletedTxid = generateTxid();

    await db.update(
      tableName,
      {'mtds_DeletedTXID': deletedTxid, 'mtds_DeviceID': deviceId},
      where: '$primaryKeyColumn = ?',
      whereArgs: [primaryKeyValue],
    );

    print(
      "🗑️ Soft delete: $tableName[$primaryKeyColumn=$primaryKeyValue] marked with DeletedTXID=$deletedTxid",
    );
  }

  /// Perform a hard delete on a record
  /// Directly deletes from table without replication
  /// Use this for local-only deletions that should NOT sync to server
  static Future<void> hardDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    final db = await DBHelper.db;

    await db.delete(
      tableName,
      where: '$primaryKeyColumn = ?',
      whereArgs: [primaryKeyValue],
    );

    print(
      "🗑️ Hard delete: $tableName[$primaryKeyColumn=$primaryKeyValue] permanently removed (no replication)",
    );
  }

  /// Get current 48-bit DeviceID from database PRAGMA values
  static Future<int> getCurrentDeviceId() async {
    final db = await DBHelper.db;

    final userVersionResult = await db.rawQuery('PRAGMA user_version');
    final appIdResult = await db.rawQuery('PRAGMA application_id');

    final userVersion = userVersionResult.first['user_version'] as int;
    final applicationId = appIdResult.first['application_id'] as int;

    return reconstructDeviceId(userVersion, applicationId);
  }

  /// Get current app version from database PRAGMA
  static Future<int> getCurrentAppVersion() async {
    final db = await DBHelper.db;

    final userVersionResult = await db.rawQuery('PRAGMA user_version');
    final userVersion = userVersionResult.first['user_version'] as int;

    return unpackAppVersion(userVersion);
  }

  /// Get DeviceID as 48-bit integer (supports MAC addresses)
  static Future<int> getDeviceId48Bit() async {
    final deviceId = await authService.getDeviceId();

    if (deviceId == null) {
      print("⚠️ Device ID is not set in auth service.");
      throw Exception("Device ID is not set in auth service.");
    }

    // Ensure it fits in 48 bits (max value: 281474976710655)
    if (deviceId > 0xFFFFFFFFFFFF) {
      throw Exception("DeviceID exceeds 48-bit limit: $deviceId");
    }

    return deviceId;
  }

  static Future<Database> get db async {
    String newDbName = await _getDatabaseName();
    if (_db != null && _currentDbName == newDbName) return _db!;

    // Close the existing database if the name has changed
    if (_db != null && _currentDbName != newDbName) {
      await _db!.close();
      _db = null;
    }

    _currentDbName = newDbName;
    _db = await _initDB();
    return _db!;
  }

  /// Extract tenant ID from auth service
  static Future<String?> _getTenantId() async {
    return await authService.getTenantId();
  }

  /// Extract subject ID from auth service
  static Future<String?> _getSubjectId() async {
    return await authService.getSubjectId();
  }

  /// Extract app name from auth service
  static Future<String?> _getAppName() async {
    return await authService.getAppName();
  }

  /// Generate database name using HEX(SHA256('sub:tid:app'))
  /// Format: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX.db
  /// Total: 64 hex characters + 15 hyphens + 3 (.db) = 82 characters
  static Future<String> _getDatabaseName() async {
    final sub = await _getSubjectId();
    final tid = await _getTenantId();
    final app = await _getAppName();

    // TODO: verify that we should support the legacy fallback database name!
    // If any value is missing, fall back to legacy database name
    if (sub == null ||
        tid == null ||
        app == null ||
        sub.isEmpty ||
        tid.isEmpty ||
        app.isEmpty) {
      print("⚠️ Missing sub, tid, or app - using legacy database name");
      print("   Hint: Ensure JWT token is set with 'tid', 'sub', 'app' claims");

      // Fallback: try to use DefaultAuthService with legacy keys
      if (_authService is DefaultAuthService) {
        final defaultAuth = _authService as DefaultAuthService;
        // Check if we have a valid token to parse
        final token = await defaultAuth.getAuthToken();
        if (token != null) {
          print("   Found auth token, but missing required claims");
        }
      }

      return "app.db"; // Default DB name
    }

    // Create the string: 'sub:tid:app'
    final input = '$sub:$tid:$app';

    // Generate SHA256 hash
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);

    // Convert to hex string (64 characters)
    final hexString = digest.toString().toUpperCase();

    // Format with hyphens every 4 characters
    final buffer = StringBuffer();

    for (int i = 0; i < hexString.length; i += 4) {
      if (i > 0) buffer.write('-');

      buffer.write(hexString.substring(i, i + 4));
    }

    final dbName = '${buffer.toString()}.db';

    print("📦 DB Name (SHA256): $dbName");

    return dbName;
  }

  static Future<Database> _initDB() async {
    final deviceId48 = await getDeviceId48Bit();
    String dbName = await _getDatabaseName();

    // Use path_provider to get app's support directory
    final Directory appSupportDir = await getApplicationSupportDirectory();

    String dbPath = join(appSupportDir.path, dbName);
    print("📂 DB path: $dbPath");

    Database database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tbldmlog (
            TXID INTEGER PRIMARY KEY AUTOINCREMENT,
            TableName TEXT NOT NULL,
            PK INTEGER NOT NULL,
            mtds_DeviceID INTEGER NOT NULL,
            Action INTEGER,
            PayLoad TEXT
          );
        ''');
      },
    );

    // Disable foreign keys for replication to work properly
    await database.execute("PRAGMA foreign_keys = OFF;");

    // Pack and set user_version (App Version + MS 16 bits of DeviceID)
    final packedUserVersion = packUserVersion(_appVersion, deviceId48);
    await database.execute("PRAGMA user_version = $packedUserVersion;");

    print(
      "📊 user_version set: $packedUserVersion (App: $_appVersion, DeviceID MS16: ${unpackDeviceIdMS16(packedUserVersion)})",
    );

    // Pack and set application_id (LS 32 bits of DeviceID)
    final packedAppId = packApplicationId(deviceId48);
    await database.execute("PRAGMA application_id = $packedAppId;");
    print("📊 application_id set: $packedAppId (DeviceID LS32)");

    // Verify reconstruction
    final reconstructed = reconstructDeviceId(packedUserVersion, packedAppId);
    print(
      "✅ DeviceID verification: Original=$deviceId48, Reconstructed=$reconstructed",
    );

    if (reconstructed != deviceId48) {
      throw Exception(
        "DeviceID packing/unpacking failed! Original: $deviceId48, Reconstructed: $reconstructed",
      );
    }

    return database;
  }
}
