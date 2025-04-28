import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

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

  static Future<String> _getDatabaseName() async {
    String? databaseName = await _secureStorage.read(key: "DatabaseName");
    String? dbName = databaseName?.replaceAll("@", "_").replaceAll(".", "_");
    print("DB Name: $dbName" );
    if (dbName == null || dbName.isEmpty) {
      return "app.db"; // Default DB name
    }
    return dbName.endsWith(".db") ? dbName : "$dbName.db";
  }

  static Future<Database> _initDB() async {
    int deviceId = await _getDeviceId();
    String dbName = await _getDatabaseName();
    String dbPath = join(await getDatabasesPath(), dbName);
    print("DB path: ${dbPath}");
    Database database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tbldmlog (
            TXID INTEGER PRIMARY KEY AUTOINCREMENT,
            TableName TEXT NOT NULL,
            PK INTEGER NOT NULL,
            Action INTEGER,
            PayLoad TEXT
          );
        ''');
      },
    );

    // Execute PRAGMA statement after the DB is initialized
    await database.execute("PRAGMA application_id = $deviceId;");

    return database;
  }
}
