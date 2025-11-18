# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-13

### 🎉 Major Release - Complete Rewrite

This is a major release with significant architectural improvements and breaking changes. The SDK has been completely modernized with Drift ORM, hybrid timestamps, and real-time sync capabilities.

### Added

- **MTDS_SDK**: New unified SDK class replacing DBHelper and SyncManager
- **Real-Time Sync**: Complete SSE (Server-Sent Events) implementation
  - `subscribeToSSE()` method for real-time updates
  - Auto-apply updates to local database
  - Automatic reconnection on disconnect
  - Loop prevention via DeviceID filtering
- **Hybrid Timestamps**: Client ordering + Server authority
  - `_updateLocalWithServerTxids()` method
  - Clock skew detection and logging
  - Resolves clock drift issues across devices
- **Delete Operations**:
  - `softDelete()` method (syncs to server)
  - `hardDelete()` method (local only)
- **Drift Support**: Type-safe ORM integration
  - `MtdsChangeLog` Drift table definition
  - Better type safety throughout
- **Connection Management**:
  - `isSSEConnected` status property
  - `dispose()` method for cleanup
- **Comprehensive Documentation**:
  - Migration guide
  - Server requirements
  - Phase completion docs
  - API documentation

### Changed

- **Table Rename**: `tbldmlog` → `mtds_change_log`
  - Consistent snake_case column naming
  - Clearer, more descriptive name
  - Migration script provided
- **Timestamps**: Forced UTC throughout
  - `MtdsUtils.generateTxid()` now uses `.toUtc()`
  - Added `getUtcTimestampString()` helper
- **Dependency Management**: Removed re-exports
  - Users must add drift and dio explicitly
  - Better version control
  - Cleaner API surface
- **Server Protocol**: Updated with hybrid timestamps
  - Request includes `clientTxid`
  - Response includes `serverTxid` mapping
  - Endpoint changed from `/update` to `/sync`
- **Version**: Bumped to 1.0.0 (production ready)

### Deprecated

- `DBHelper` class (removed in this version)
- `SyncManager` class (removed in this version)

### Removed

- `lib/src/db_helper.dart` - Functionality moved to MTDS_SDK
- `lib/src/sync_manager.dart` - Functionality moved to MTDS_SDK
- Re-exports of drift and dio from `lib/index.dart`

### Breaking Changes

#### 1. Table Name Change
**Before:**
```sql
CREATE TABLE tbldmlog (
  TXID INTEGER PRIMARY KEY,
  TableName TEXT,
  PK INTEGER,
  ...
);
```

**After:**
```sql
CREATE TABLE mtds_change_log (
  txid INTEGER PRIMARY KEY,
  table_name TEXT,
  record_pk INTEGER,
  ...
);
```

**Migration:** Run the migration script in MIGRATION_GUIDE.md

#### 2. API Changes
**Before:**
```dart
final db = await DBHelper.db;
await DBHelper.softDelete(...);
await SyncManager.syncWithServer(url);
```

**After:**
```dart
final sdk = MTDS_SDK(
  db: myDriftDatabase,
  httpClient: Dio(),
  serverUrl: url,
  authToken: token,
  deviceId: deviceId,
);
await sdk.softDelete(...);
await sdk.syncToServer();
```

#### 3. Dependency Management
**Before:** drift and dio were re-exported

**After:** Must add explicitly in pubspec.yaml
```yaml
dependencies:
  mtds: ^1.0.0
  drift: ^2.13.0
  dio: ^5.9.0
```

#### 4. Server Protocol
**Before:**
```json
POST /update
Body: [...]
Response: {"success": true}
```

**After:**
```json
POST /sync
Body: {"changes": [...]}
Response: {
  "success": true,
  "updates": [
    {"clientTxid": 123, "serverTxid": 456, ...}
  ]
}
```

### Fixed

- Clock skew issues across devices (hybrid timestamps)
- Infinite loop potential (DeviceID filtering)
- Timezone inconsistencies (forced UTC)
- Connection drops (auto-reconnect)
- Conflict resolution reliability (server timestamps)

### Security

- Enhanced authentication flow
- JWT token parsing improvements
- Device ID validation
- Tenant isolation enforcement

### Performance

- Optimized SSE message processing
- Reduced database queries with caching opportunities
- Efficient batch synchronization
- Minimal memory footprint for SSE connections

### Documentation

- Complete migration guide
- Server implementation guide
- Phase-by-phase completion docs
- API reference documentation
- Troubleshooting guide
- Testing scenarios

---

## [0.0.5] - 2024

### Added
- MTDS compliance (Phases 1-4)
- DeviceID packing in PRAGMAs
- Trigger system
- Auth service integration

### Changed
- Field naming with `mtds_` prefix
- Database path to app support directory

---

## [0.0.1] - 2024

### Added
- Initial release
- Basic sync functionality
- SQLite database support

---

## Migration Guides

### v0.0.5 → v1.0.0
See [MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md) for detailed migration instructions.

---

## Links

- [GitHub Repository](https://github.com/canons-dev/mtds)
- [Documentation](https://github.com/canons-dev/mtds/tree/main/docs)
- [Issue Tracker](https://github.com/canons-dev/mtds/issues)

---

## Contributors

Thanks to all contributors who made this release possible!

---

**Full Changelog**: v0.0.5...v1.0.0
