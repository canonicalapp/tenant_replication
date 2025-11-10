import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DBHelper {
  static Database? _db;
  static String? _currentDbName;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  /// Get DeviceID as 48-bit integer (supports MAC addresses)
  static Future<int> getDeviceId48Bit() async {
    String? deviceId = await _secureStorage.read(key: "DeviceId");
    if (deviceId == null || deviceId.isEmpty) {
      print("Device ID is not set in secure storage.");
      throw Exception("Device ID is not set in secure storage.");
    }

    final id = int.parse(deviceId);

    // Ensure it fits in 48 bits (max value: 281474976710655)
    if (id > 0xFFFFFFFFFFFF) {
      throw Exception("DeviceID exceeds 48-bit limit: $id");
    }

    return id;
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

  /// Extract tenant ID from secure storage
  static Future<String?> _getTenantId() async {
    return await _secureStorage.read(key: "TenantId");
  }

  /// Extract subject ID from secure storage
  static Future<String?> _getSubjectId() async {
    return await _secureStorage.read(key: "SubjectId");
  }

  /// Extract app name from secure storage
  static Future<String?> _getAppName() async {
    return await _secureStorage.read(key: "AppName");
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

      String? databaseName = await _secureStorage.read(key: "DatabaseName");
      String? dbName = databaseName?.replaceAll("@", "_").replaceAll(".", "_");

      if (dbName == null || dbName.isEmpty) {
        return "app.db"; // Default DB name
      }

      return dbName.endsWith(".db") ? dbName : "$dbName.db";
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
