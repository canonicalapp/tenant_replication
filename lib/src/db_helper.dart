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

  static Future<int> _getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: "DeviceId");
    if (deviceId == null || deviceId.isEmpty) {
      print("Device ID is not set in secure storage.");
      // throw Exception("Device ID is not set in secure storage.");
    }
    return int.parse(deviceId!);
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
    int deviceId = await _getDeviceId();
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

    // Execute PRAGMA statement after the DB is initialized
    await database.execute("PRAGMA application_id = $deviceId;");

    return database;
  }
}
