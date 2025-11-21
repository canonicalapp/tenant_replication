# MTDS Flutter SDK

Offline-first, multi-tenant data synchronization SDK for Flutter apps. Automatically tracks database changes, syncs to your server, and streams real-time updates via Server-Sent Events (SSE).

## ✨ Features

- **Automatic change tracking** via SQL triggers
- **Offline-first** with local change queue
- **Real-time sync** via Server-Sent Events (SSE)
- **Automatic synchronization** with configurable intervals
- **Soft & hard deletes** with device-aware conflict resolution
- **Hybrid timestamps** (client ordering + server authority)
- **Schema verification** with automatic column filtering

## 📦 Installation

```yaml
dependencies:
  mtds:
    path: ../mtds # or use pub.dev version
  drift: ^2.13.0
  dio: ^5.9.0
```

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## 🚀 Quick Start

### 1. Define Tables with `MtdsColumns` Mixin

```dart
import 'package:mtds/index.dart' show MtdsColumns;

class Users extends Table with MtdsColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text()();
}
```

The `MtdsColumns` mixin automatically adds:

- `mtds_last_updated_txid` (INTEGER, NOT NULL, default 0)
- `mtds_device_id` (INTEGER, NOT NULL, default 0)
- `mtds_deleted_txid` (INTEGER, nullable)

### 2. Configure Database Migrations

```dart
import 'package:mtds/index.dart' show SchemaManager;

@DriftDatabase(tables: [Users])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await SchemaManager.ensureMetadataTable(m.database);
      await SchemaManager.ensureChangeLogTable(m.database);
    },
    beforeOpen: (details) async {
      if (details.wasCreated || details.hadUpgrade) {
        await SchemaManager.prepareDatabase(this);
      }
    },
  );
}
```

### 3. Initialize SDK

```dart
// Configure Dio with authentication
final dio = Dio();
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Authorization'] = 'Bearer $yourToken';
    return handler.next(options);
  },
));

// Initialize SDK
final sdk = MTDS_SDK(
  db: db,
  httpClient: dio,
  serverUrl: 'https://api.example.com',
  deviceId: 12345, // 48-bit unique device ID
);

// Prepare database (creates change log and triggers)
await SchemaManager.prepareDatabase(db);

// Enable automatic synchronization
await sdk.enableAutoSync(
  syncInterval: Duration(seconds: 30),
  debounceDelay: Duration(seconds: 5),
);
```

### 4. Use SDK Methods

```dart
// Soft delete (syncs to server)
await sdk.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: userId,
);

// Hard delete (local only, no sync)
await sdk.hardDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: userId,
);

// Manual sync to server
final result = await sdk.syncToServer();
print('Synced ${result.processed} changes');

// Load data from server
await sdk.loadFromServer(tableNames: ['users', 'products']);

// Subscribe to real-time updates
sdk.subscribeToSSE().listen((event) {
  print('Update: ${event.table} -> ${event.type}');
});

// Listen to auto-sync events
sdk.autoSyncEventStream.listen((event) {
  if (event.type == AutoSyncEventType.completed) {
    print('Auto-sync completed: ${event.processed} changes');
  }
});
```

## 🔐 Authentication

The SDK **does not handle authentication**. Configure your Dio instance with interceptors:

```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    // Add your auth headers
    // in production use only Authorization header
    options.headers['Authorization'] = 'Bearer $token';
    // (optional) can remove them as these are intended to be for testing with server side library
    options.headers['tenant-id'] = tenantId;
    options.headers['user-id'] = userId;
    return handler.next(options);
  },
));
```

## 📡 Server Endpoints

The SDK expects these endpoints:

- `POST /mtdd/sync/changes` - Upload local changes
- `POST /mtdd/sync/bulk-load` - Load data from server
- `GET /mtdd/sync/events` - Server-Sent Events stream

See [SERVER_REQUIREMENTS.md](docs/SERVER_REQUIREMENTS.md) for detailed API specifications.

## 🔄 Automatic Synchronization

Enable automatic syncing with:

```dart
await sdk.enableAutoSync(
  syncInterval: Duration(seconds: 30),    // Check every 30s
  debounceDelay: Duration(seconds: 5),      // Wait 5s after last change
  autoSyncOnReconnect: true,                // Sync when network returns
  minChangesForSync: 1,                     // Minimum changes to trigger
);
```

Auto-sync triggers when:

- New changes are detected (debounced)
- Network comes back online (if pending changes exist)
- Periodic interval (if configured)

Listen to auto-sync events:

```dart
sdk.autoSyncEventStream.listen((event) {
  switch (event.type) {
    case AutoSyncEventType.started:
      // Sync started
      break;
    case AutoSyncEventType.completed:
      // Sync completed successfully
      break;
    case AutoSyncEventType.failed:
      // Sync failed
      break;
  }
});
```

## 📋 Schema Requirements

### Required MTDS Columns

Every replicated table must include:

| Column                   | Type    | Description                             |
| ------------------------ | ------- | --------------------------------------- |
| `mtds_last_updated_txid` | INTEGER | Transaction ID (NOT NULL, default 0)    |
| `mtds_device_id`         | INTEGER | Device identifier (NOT NULL, default 0) |
| `mtds_deleted_txid`      | INTEGER | Soft delete marker (nullable)           |

✅ Use the `MtdsColumns` mixin to add these automatically.

### Server-Only Columns

The server may return additional columns (e.g., `tenant_id`, `created_at`, `updated_at`). These are automatically filtered during synchronization.

See [SCHEMA_ALIGNMENT.md](docs/SCHEMA_ALIGNMENT.md) for details.

## 🏗️ Architecture

```
┌─────────────┐
│ Flutter UI  │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│   MTDS_SDK      │
│  ├ SyncService  │───▶ POST /mtdd/sync/changes
│  ├ SSEService   │◀──▶ GET /mtdd/sync/events
│  ├ DeleteService│
│  └ AutoSync     │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Drift Database  │
│  └ Triggers     │───▶ mtds_change_log
└─────────────────┘
```

## 📚 Documentation

- [Schema Alignment Guide](docs/SCHEMA_ALIGNMENT.md) - Client/server schema differences
- [Server Requirements](docs/SERVER_REQUIREMENTS.md) - API specifications
- [Migration Guide](docs/MIGRATION_GUIDE.md) - Migrating from legacy SDK
- [Testing Guide](docs/TESTING_GUIDE.md) - End-to-end testing
- [Example App](example/README.md) - Complete working example

## 🐛 Troubleshooting

| Issue                            | Solution                                                        |
| -------------------------------- | --------------------------------------------------------------- |
| Column `mtds_device_i_d` appears | Ensure tables use `MtdsColumns` mixin and regenerate Drift code |
| Triggers not working             | Call `SchemaManager.prepareDatabase(db)` after migrations       |
| No change log entries            | Verify device ID is set correctly in `mtds_metadata` table      |
| SSE not connecting               | Check authentication headers and server endpoint                |
| Schema mismatch errors           | Server-only columns are auto-filtered; check logs for warnings  |

## 📄 License

MIT © Canons Dev Team
