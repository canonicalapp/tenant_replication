# Migration Guide: Legacy → Modern MTDS SDK

## 🎯 Overview

This guide helps you migrate from the legacy sqflite-based implementation to the modern Drift-based MTDS SDK.

**Version:** v0.0.5 (legacy) → v1.0.0 (modern)

---

## 📋 What Changed

### Architecture Changes

| Component | Legacy | Modern |
|-----------|--------|--------|
| **ORM** | sqflite (raw SQL) | Drift (type-safe) |
| **Main Class** | DBHelper + SyncManager | MTDS_SDK |
| **Table Name** | tbldmlog | mtds_change_log |
| **Delete API** | DBHelper.softDelete() | sdk.softDelete() |
| **Timestamps** | Client-only | Hybrid (client + server) |
| **SSE** | Partial | Complete |

---

## 🚀 Quick Migration Steps

### Step 1: Update Dependencies

**Old pubspec.yaml:**
```yaml
dependencies:
  mtds: ^0.0.5
  # sqflite was used internally
```

**New pubspec.yaml:**
```yaml
dependencies:
  mtds: ^1.0.0
  
  # Add explicitly (no longer re-exported)
  drift: ^2.13.0
  dio: ^5.9.0
  sqlite3_flutter_libs: ^0.5.19
```

### Step 2: Migrate Database Table

Run this migration once on app startup:

```dart
Future<void> migrateChangeLogTable(Database db) async {
  final oldExists = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='tbldmlog'"
  );
  
  if (oldExists.isNotEmpty) {
    print('📦 Migrating tbldmlog → mtds_change_log');
    
    await db.execute('''
      CREATE TABLE mtds_change_log AS 
      SELECT 
        TXID as txid,
        TableName as table_name,
        PK as record_pk,
        mtds_DeviceID as mtds_device_id,
        Action as action,
        PayLoad as payload
      FROM tbldmlog
    ''');
    
    await db.execute('DROP TABLE tbldmlog');
    
    print('✅ Migration complete');
  }
}
```

### Step 3: Replace Code

#### Initialization

**Old:**
```dart
import 'package:mtds/mtds.dart';

final db = await DBHelper.db;
await TriggerManager.setupTriggers();
```

**New:**
```dart
import 'package:mtds/mtds.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';

final sdk = MTDS_SDK(
  db: myDriftDatabase,  // Your Drift database instance
  httpClient: Dio(),
  serverUrl: 'https://api.example.com',
  authToken: jwtToken,
  deviceId: 12345,
);

await TriggerManager.setupTriggers();  // Still needed
```

#### Soft Delete

**Old:**
```dart
await DBHelper.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 123,
);
```

**New:**
```dart
await sdk.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 123,
);
```

#### Hard Delete

**Old:**
```dart
await DBHelper.hardDelete(
  tableName: 'cache',
  primaryKeyColumn: 'id',
  primaryKeyValue: 456,
);
```

**New:**
```dart
await sdk.hardDelete(
  tableName: 'cache',
  primaryKeyColumn: 'id',
  primaryKeyValue: 456,
);
```

#### Sync to Server

**Old:**
```dart
await SyncManager.syncWithServer('https://api.example.com');
```

**New:**
```dart
final result = await sdk.syncToServer();
if (result.success) {
  print('Synced ${result.processed} changes');
}
```

#### Real-Time Sync (SSE)

**Old:**
```dart
await SSEManager.initializeSSE(serverUrl, token);
```

**New:**
```dart
final eventStream = sdk.subscribeToSSE();
eventStream.listen((event) {
  print('Received: ${event.type} for ${event.table}');
  // Update applied automatically
});
```

---

## 📝 Detailed Migration

### 1. Database Setup

#### Legacy Approach

```dart
class LegacyApp {
  Future<void> init() async {
    final db = await DBHelper.db;
    await TriggerManager.setupTriggers();
  }
}
```

#### Modern Approach

```dart
// Define your Drift database
@DriftDatabase(tables: [Users, Products, MtdsChangeLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
}

// Initialize SDK
class ModernApp {
  late final MTDS_SDK sdk;
  late final AppDatabase database;
  
  Future<void> init() async {
    database = AppDatabase();
    
    sdk = MTDS_SDK(
      db: database,
      httpClient: Dio(),
      serverUrl: 'https://api.example.com',
      authToken: await getToken(),
      deviceId: await getDeviceId(),
    );
    
    await TriggerManager.setupTriggers();
    
    // Start real-time sync
    sdk.subscribeToSSE().listen((event) {
      // Handle events
    });
  }
  
  Future<void> dispose() async {
    await sdk.dispose();
    await database.close();
  }
}
```

### 2. Table Definitions

#### Legacy (Raw SQL)

```dart
await db.execute('''
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    mtds_lastUpdatedTxid INTEGER,
    mtds_DeviceID INTEGER,
    mtds_DeletedTXID INTEGER
  )
''');
```

#### Modern (Drift)

```dart
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  
  // MTDS required fields
  IntColumn get mtdsLastUpdatedTxid => integer().nullable()();
  IntColumn get mtdsDeviceID => integer().nullable()();
  IntColumn get mtdsDeletedTXID => integer().nullable()();
}
```

### 3. CRUD Operations

#### Insert

**Legacy:**
```dart
final txid = DBHelper.generateTxid();
final deviceId = await DBHelper.getDeviceId48Bit();

await db.insert('users', {
  'name': 'John',
  'mtds_lastUpdatedTxid': txid,
  'mtds_DeviceID': deviceId,
});
```

**Modern:**
```dart
final txid = MtdsUtils.generateTxid();

await database.into(database.users).insert(
  UsersCompanion(
    name: Value('John'),
    mtdsLastUpdatedTxid: Value(txid),
    mtdsDeviceID: Value(sdk.deviceId),
  ),
);
```

#### Update

**Legacy:**
```dart
await db.update('users', {
  'name': 'Jane',
  'mtds_lastUpdatedTxid': DBHelper.generateTxid(),
  'mtds_DeviceID': await DBHelper.getDeviceId48Bit(),
}, where: 'id = ?', whereArgs: [1]);
```

**Modern:**
```dart
await (database.update(database.users)
  ..where((t) => t.id.equals(1)))
  .write(UsersCompanion(
    name: Value('Jane'),
    mtdsLastUpdatedTxid: Value(MtdsUtils.generateTxid()),
    mtdsDeviceID: Value(sdk.deviceId),
  ));
```

#### Soft Delete

**Legacy:**
```dart
await DBHelper.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 1,
);
```

**Modern:**
```dart
await sdk.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 1,
);
```

### 4. Sync Operations

#### Legacy Flow

```dart
// 1. Make changes (triggers log to tbldmlog)
await db.insert('users', {...});

// 2. Sync
await SyncManager.syncWithServer(serverUrl);

// 3. SSE (manual setup)
await SSEManager.initializeSSE(serverUrl, token);
```

#### Modern Flow

```dart
// 1. Make changes (triggers log to mtds_change_log)
await database.into(database.users).insert(...);

// 2. Sync (hybrid timestamps)
final result = await sdk.syncToServer();
// Local records updated with server timestamps automatically

// 3. SSE (automatic)
sdk.subscribeToSSE().listen((event) {
  // Updates auto-applied
  refreshUI();
});
```

---

## 🔧 Server-Side Changes

### Update Endpoint

**Old:**
```javascript
app.post('/update', async (req, res) => {
  const changes = req.body;
  // Process changes...
  res.json({ success: true });
});
```

**New:**
```javascript
app.post('/sync', async (req, res) => {
  const changes = req.body.changes;
  const results = [];
  
  changes.sort((a, b) => a.clientTxid - b.clientTxid);
  
  for (const change of changes) {
    const serverTxid = Date.now() * 1000000 + process.hrtime()[1];
    
    // Override client timestamp
    change.payload.New.mtds_lastUpdatedTxid = serverTxid;
    
    await processChange(change);
    
    results.push({
      clientTxid: change.clientTxid,
      serverTxid: serverTxid,
      tableName: change.table_name,
      pk: change.record_pk
    });
  }
  
  res.json({ success: true, updates: results });
});
```

### Add SSE Endpoint

```javascript
app.get('/sse', authenticate, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  
  const deviceId = req.headers['deviceid'];
  
  res.write('data: {"type":"connected"}\\n\\n');
  
  sseManager.addClient(req.user.id, deviceId, res);
  
  req.on('close', () => {
    sseManager.removeClient(req.user.id, deviceId);
  });
});
```

---

## ⚠️ Breaking Changes

### 1. Table Name

**Impact:** High  
**Required:** Database migration script (provided above)

### 2. Dependencies

**Impact:** Medium  
**Required:** Update pubspec.yaml, add drift/dio explicitly

### 3. API Changes

**Impact:** Medium  
**Required:** Update all calls to DBHelper/SyncManager

### 4. Server Protocol

**Impact:** Low-Medium  
**Required:** Server must return `updates` array with timestamps

---

## ✅ Migration Checklist

### Client-Side

- [ ] Update `pubspec.yaml` dependencies
- [ ] Create Drift database class
- [ ] Define tables with Drift
- [ ] Run table migration script (tbldmlog → mtds_change_log)
- [ ] Replace `DBHelper` with `MTDS_SDK`
- [ ] Replace `SyncManager` with `sdk.syncToServer()`
- [ ] Update all CRUD operations to use Drift
- [ ] Replace SSE setup with `sdk.subscribeToSSE()`
- [ ] Test offline → online sync
- [ ] Test real-time updates between devices

### Server-Side

- [ ] Update `/update` endpoint to `/sync`
- [ ] Add `updates` array to response
- [ ] Implement server timestamp generation
- [ ] Add SSE endpoint `/sse`
- [ ] Implement SSE broadcast with deviceId filtering
- [ ] Update table names in queries
- [ ] Test hybrid timestamp protocol
- [ ] Test SSE connection and broadcasts

---

## 🧪 Testing Your Migration

### Test 1: Basic Sync

```dart
// Make change
await database.into(database.users).insert(...);

// Sync
final result = await sdk.syncToServer();

// Verify
assert(result.success);
assert(result.processed > 0);
```

### Test 2: Real-Time Sync

```dart
// Device A
await sdk.subscribeToSSE().first;  // Wait for connection
await database.into(database.users).insert(...);
await sdk.syncToServer();

// Device B (should receive via SSE)
final event = await sdk.subscribeToSSE().first;
assert(event.type == 'update');
assert(event.table == 'users');
```

### Test 3: Soft Delete

```dart
await sdk.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 1,
);
await sdk.syncToServer();

// Verify record marked
final record = await database.select(database.users).getSingle();
assert(record.mtdsDeletedTXID != null);
```

---

## 🆘 Troubleshooting

### Issue: "Table tbldmlog not found"

**Solution:** Run the migration script to rename table.

### Issue: "Cannot import drift/dio"

**Solution:** Add dependencies explicitly to pubspec.yaml.

### Issue: "Server returns 400"

**Solution:** Update server to accept new request format with `clientTxid`.

### Issue: "SSE not connecting"

**Solution:** Ensure server has `/sse` endpoint and returns correct headers.

### Issue: "Infinite loop in sync"

**Solution:** Verify DeviceID check in `_applyServerUpdate()` method.

---

## 📚 Additional Resources

- [MTDS_COMPLIANCE.md](MTDS_COMPLIANCE.md) - Protocol specification
- [SERVER_REQUIREMENTS.md](SERVER_REQUIREMENTS.md) - Server implementation
- [PHASE5_COMPLETED.md](PHASE5_COMPLETED.md) - Foundation changes
- [PHASE6_7_COMPLETED.md](PHASE6_7_COMPLETED.md) - Hybrid timestamps
- [PHASE8_COMPLETED.md](PHASE8_COMPLETED.md) - SSE implementation

---

## 💬 Support

If you encounter issues:

1. Check this migration guide
2. Review phase completion docs
3. Open GitHub issue with details
4. Include error logs and code samples

---

## 🎉 Benefits of Migration

| Benefit | Description |
|---------|-------------|
| **Type Safety** | Drift prevents runtime errors |
| **Better Performance** | Optimized queries |
| **Real-Time Sync** | Instant updates via SSE |
| **Clock Skew Fixed** | Server timestamps |
| **Cleaner API** | Single SDK class |
| **Better Documentation** | Complete guides |
| **Production Ready** | Tested and stable |

---

**Version:** 1.0  
**Last Updated:** 2025-11-13  
**Status:** Complete Migration Guide

