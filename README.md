# Tenant Replication

A Flutter SDK for multi-tenant data replication and synchronization across distributed systems using SQLite on the client side.

## ✨ Features

- **Multi-Tenant Support**: Isolated data replication per tenant with SHA256-based database naming
- **Bidirectional Sync**: Real-time synchronization between client (SQLite) and server
- **Conflict Resolution**: Last-Write-Wins (LWW) strategy based on nanosecond timestamps
- **Offline-First**: Full SQLite database on device, syncs when online
- **Automatic Change Tracking**: SQL triggers automatically log all changes
- **Soft-Delete Support**: Replicate deletions before permanent removal
- **48-bit DeviceID**: Supports MAC addresses as device identifiers
- **JWT Auth Integration**: Pluggable auth service with automatic JWT parsing
- **MTDS Compliant**: Fully compliant with Multi-Tenant Data Synchronization protocol

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  tenant_replication: ^0.0.5
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Setup Authentication

```dart
import 'package:tenant_replication/tenant_replication.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Option A: Using JWT Token (Recommended)
final storage = FlutterSecureStorage();
await storage.write(key: 'AuthToken', value: yourJwtToken);
await storage.write(key: 'DeviceId', value: '12345');

// Option B: Using Direct Values (Legacy)
await storage.write(key: 'TenantId', value: 'tenant123');
await storage.write(key: 'SubjectId', value: 'user456');
await storage.write(key: 'AppName', value: 'myapp');
await storage.write(key: 'DeviceId', value: '12345');
```

### 2. Initialize Database

```dart
// Get database instance (auto-creates if needed)
final db = await DBHelper.db;

// Setup triggers for change tracking
await TriggerManager.setupTriggers();
```

### 3. Create Tables

Ensure your tables include MTDS required fields:

```dart
await db.execute('''
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    
    -- MTDS required fields
    mtds_lastUpdatedTxid INTEGER,
    mtds_DeviceID INTEGER,
    mtds_DeletedTXID INTEGER
  )
''');
```

### 4. Insert/Update Data

```dart
final deviceId = await DBHelper.getDeviceId48Bit();
final txid = DBHelper.generateTxid();

await db.insert('users', {
  'id': 1,
  'name': 'John Doe',
  'email': 'john@example.com',
  'mtds_lastUpdatedTxid': txid,
  'mtds_DeviceID': deviceId,
  'mtds_DeletedTXID': null,
});
```

### 5. Sync with Server

```dart
// Send local changes to server
await SyncManager.syncWithServer('https://your-server.com');

// Initialize real-time sync (SSE)
await SSEManager.initializeSSE('https://your-server.com', authToken);

// Load initial data
final sseManager = SSEManager();
await sseManager.loadAllTables(
  url: 'https://your-server.com/sync/data',
  token: authToken,
  tableNames: ['users', 'products', 'orders'],
);
```

## 📚 Core Concepts

### Database Naming

Database names are generated using SHA256 hash of `'sub:tid:app'`:

```
Input: 'user123:tenant456:myapp'
Output: A1B2-C3D4-E5F6-...-X9Y0.db
```

### Field Naming Convention

All MTDS special fields use the `mtds_` prefix:

| Field | Type | Purpose |
|-------|------|---------|
| `mtds_lastUpdatedTxid` | INTEGER | Nanosecond timestamp of last update |
| `mtds_DeviceID` | INTEGER | 48-bit device identifier |
| `mtds_DeletedTXID` | INTEGER | Soft-delete timestamp (NULL = active) |

### Delete Operations

**Soft Delete** (Replicates):
```dart
await DBHelper.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 123,
);
// Marks record, syncs to server, then deletes on confirmation
```

**Hard Delete** (Local Only):
```dart
await DBHelper.hardDelete(
  tableName: 'temp_cache',
  primaryKeyColumn: 'id',
  primaryKeyValue: 456,
);
// Immediate deletion, no replication
```

### Custom Auth Service

Implement your own auth provider:

```dart
class MyAuthService implements AuthService {
  @override
  Future<String?> getTenantId() async => 'my-tenant';
  
  @override
  Future<String?> getSubjectId() async => 'my-user';
  
  @override
  Future<String?> getAppName() async => 'my-app';
  
  @override
  Future<int?> getDeviceId() async => 12345;
  
  // ... implement other methods
}

// Use it
DBHelper.setAuthService(MyAuthService());
```

## 🏗️ Architecture

### Client Components

- **DBHelper**: Database management, device ID, auth service
- **TriggerManager**: Automatic change tracking via SQL triggers
- **SyncManager**: Push local changes to server
- **SSEManager**: Real-time updates via Server-Sent Events

### Data Flow

```
Local SQLite ←→ Triggers → tbldmlog → SyncManager → Server
     ↑                                                    ↓
     └────────────── SSEManager ←───────────────────────┘
```

## 🔐 Security

- **JWT Support**: Automatic token parsing and validation
- **Secure Storage**: Sensitive data stored in Flutter Secure Storage
- **Tenant Isolation**: SHA256-based database separation
- **Device Authentication**: 48-bit DeviceID validation

## 📖 Documentation

### Implementation Guides
- [Phase 1: Core Infrastructure](PHASE1_CHANGES.md)
- [Phase 2: DeviceID & Versioning](PHASE2_CHANGES.md)
- [Phase 3: Sync & Replication](PHASE3_CHANGES.md)
- [Phase 4: Auth Service Integration](PHASE4_CHANGES.md)

### Reference
- [MTDS Compliance Status](MTDS_COMPLIANCE.md)
- [Server Requirements](SERVER_REQUIREMENTS.md)

## 🧪 Testing

### Example Application (Recommended)

A complete Flutter example app is available to test all SDK features:

```bash
cd example
flutter pub get
flutter run
```

**Quick Start:**
- [5-Minute Quick Start](example/QUICK_START.md) - Fastest path to testing
- [Complete Setup Guide](example/MTDD_ECOSYSTEM_SETUP.md) - Full backend setup
- [Architecture Guide](example/ARCHITECTURE.md) - Understand the system
- [Example README](example/README.md) - Detailed documentation

The example includes:
- ✅ Authentication setup (JWT + Direct mode)
- ✅ Database operations with CRUD
- ✅ Real-time sync demonstration
- ✅ SSE integration
- ✅ Complete MTDD backend integration

### Unit Tests

Testing suite is available in git stash. To restore:

```bash
git stash list
git stash apply stash@{0}  # Adjust index as needed
flutter test
```

## 🌐 Server Requirements

Your server must:

1. **Use `mtds_` prefix** for special fields
2. **Include `mtds_DeviceID`** in all replicated tables
3. **Add `mtds_DeletedTXID`** to unique indexes:
   ```sql
   CREATE UNIQUE INDEX idx_users_email 
   ON users(email, mtds_DeletedTXID);
   ```

See [SERVER_REQUIREMENTS.md](SERVER_REQUIREMENTS.md) for complete details.

## 🔧 Advanced Usage

### Transactional Bulk Loading

```dart
final results = await sseManager.loadAllTables(
  url: serverUrl,
  token: authToken,
  tableNames: ['users', 'products', 'orders'],
);
print('Loaded ${results.values.fold(0, (a, b) => a + b)} records');
```

### DeviceID from PRAGMA

```dart
final deviceId = await DBHelper.getCurrentDeviceId();
final appVersion = await DBHelper.getCurrentAppVersion();
```

### Token Parsing

```dart
final authService = DBHelper.authService as DefaultAuthService;
final claims = authService.parseToken(jwtToken);
print('Tenant: ${claims['tid']}');
print('Subject: ${claims['sub']}');
```

## 🐛 Troubleshooting

### Database Not Found
Ensure authentication is set up before accessing database:
```dart
await storage.write(key: 'AuthToken', value: token);
// OR provide TenantId, SubjectId, AppName manually
```

### DeviceID Exceeds Limit
DeviceID must fit in 48 bits (max: 281,474,976,710,655):
```dart
// Use MAC address or sequential ID
await storage.write(key: 'DeviceId', value: '12345');
```

### Triggers Not Firing
Tables must have required fields:
```sql
ALTER TABLE my_table 
ADD COLUMN mtds_lastUpdatedTxid INTEGER,
ADD COLUMN mtds_DeviceID INTEGER,
ADD COLUMN mtds_DeletedTXID INTEGER;
```

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- **Homepage**: https://github.com/canons-dev/tenant_replication.git
- **Repository**: https://github.com/canons-dev/tenant_replication.git
- **Issues**: https://github.com/canons-dev/tenant_replication/issues

## 📊 MTDS Compliance

This SDK is **fully compliant** with the Multi-Tenant Data Synchronization (MTDS) protocol:

✅ All 13 requirements implemented  
✅ Complete client-side implementation  
✅ Server integration documented  
✅ Production ready  

See [MTDS_COMPLIANCE.md](MTDS_COMPLIANCE.md) for detailed compliance status.

## 🎯 Version

**Current Version**: 0.0.5

**MTDS Compliant Since**: 0.0.5

---

Made with ❤️ by the Canons Dev Team
