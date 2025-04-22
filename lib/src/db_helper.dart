import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<int> _getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: "DeviceId");
    return int.tryParse(deviceId ?? '') ?? 123456;
  }

  static Future<String> _getDatabaseName() async {
    String? dbName = await _secureStorage.read(key: "DatabaseName");
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
            PayLoad TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        ''');
      },
    );

    // Execute PRAGMA statement after the DB is initialized
    await database.execute("PRAGMA application_id = $deviceId;");

    return database;
  }
}
