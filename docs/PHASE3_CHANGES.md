# Phase 3: Sync & Replication Improvements - MTDS Compliance

## Overview
Phase 3 implements critical sync and replication improvements including soft-delete vs hard-delete handling, transactional data loading, and helper methods for timestamp generation.

## Changes Implemented

### 1. Delete Operation Types
**File:** `lib/src/db_helper.dart`

#### Soft Delete
Marks records for deletion and replicates to server. Record is deleted locally only after server confirmation.

**New Method:**
```dart
static Future<void> softDelete({
  required String tableName,
  required String primaryKeyColumn,
  required dynamic primaryKeyValue,
})
```

**Behavior:**
- Sets `mtds_DeletedTXID` to current nanosecond timestamp
- Sets `mtds_DeviceID` to current device
- Triggers UPDATE trigger which logs to `tbldmlog`
- Record syncs to server
- After server confirms, record is permanently deleted locally

**Use Case:** Normal user deletions that should sync across all devices

**Example:**
```dart
await DBHelper.softDelete(
  tableName: 'users',
  primaryKeyColumn: 'id',
  primaryKeyValue: 123,
);
```

#### Hard Delete
Directly deletes record without replication. No sync to server.

**New Method:**
```dart
static Future<void> hardDelete({
  required String tableName,
  required String primaryKeyColumn,
  required dynamic primaryKeyValue,
})
```

**Behavior:**
- Executes direct `DELETE` statement
- No trigger fires (normal DELETE doesn't fire UPDATE triggers)
- No `tbldmlog` entry created
- No replication to server

**Use Case:** Local-only deletions (temporary data, cache cleanup, etc.)

**Example:**
```dart
await DBHelper.hardDelete(
  tableName: 'temp_cache',
  primaryKeyColumn: 'id',
  primaryKeyValue: 456,
);
```

### 2. Timestamp Generation Helper
**File:** `lib/src/db_helper.dart`

**New Method:**
```dart
static int generateTxid()
```

**Purpose:**
- Generate `mtds_lastUpdatedTxid` values for INSERT/UPDATE operations
- Returns 64-bit nanosecond timestamp since epoch
- Ensures monotonic ordering across all devices

**Usage:**
```dart
final txid = DBHelper.generateTxid();
await db.insert('users', {
  'id': 1,
  'name': 'John',
  'mtds_lastUpdatedTxid': txid,
  'mtds_DeviceID': deviceId,
});
```

### 3. PRAGMA Helper Methods
**File:** `lib/src/db_helper.dart`

**New Methods:**

**`getCurrentDeviceId()`**
```dart
static Future<int> getCurrentDeviceId()
```
- Reads `user_version` and `application_id` from database
- Reconstructs full 48-bit DeviceID
- Useful for verification and debugging

**`getCurrentAppVersion()`**
```dart
static Future<int> getCurrentAppVersion()
```
- Reads `user_version` from database
- Extracts app version (MS 16 bits)
- Useful for migration logic

### 4. Transactional Data Loading
**File:** `lib/src/sse/sse.dart`

#### Updated `loadData()` Method

**Before:**
```dart
for (final row in response.data) {
  await db.insert(tableName, filteredRow, ...);
}
// Each insert is a separate transaction
```

**After:**
```dart
await db.transaction((txn) async {
  for (final row in response.data) {
    await txn.insert(tableName, filteredRow, ...);
  }
});
// All inserts in a single atomic transaction
```

**Benefits:**
- **Atomicity**: All records loaded or none
- **Performance**: Significantly faster for bulk inserts
- **Consistency**: No partial data states
- **Rollback**: Automatic rollback on error

### 5. Sequential Table Loading
**File:** `lib/src/sse/sse.dart`

**New Method:**
```dart
Future<Map<String, int>> loadAllTables({
  required String url,
  required String token,
  required List<String> tableNames,
  Map<String, dynamic>? extraParams,
})
```

**Purpose:**
- Load multiple tables sequentially on app startup
- Each table loads in its own transaction
- Returns summary of loaded records

**Behavior:**
- Processes tables one at a time (sequential)
- Each table gets its own transaction
- Continues even if one table fails
- Returns results map: `{tableName: recordCount}`
- Failed tables marked with `-1`

**Example:**
```dart
final sseManager = SSEManager();
final results = await sseManager.loadAllTables(
  url: 'https://api.example.com/data',
  token: authToken,
  tableNames: ['users', 'products', 'orders'],
);

// results = {'users': 150, 'products': 500, 'orders': 1200}
print("Total records loaded: ${results.values.fold(0, (a, b) => a + b)}");
```

**Output:**
```
🔄 Starting initial data load for 3 tables...
📋 Loading table: users
📥 Loading 150 records into users (single transaction)
✅ Data loaded into users successfully
✅ users: 150 records loaded
📋 Loading table: products
📥 Loading 500 records into products (single transaction)
✅ Data loaded into products successfully
✅ products: 500 records loaded
...
✅ Initial data load complete: 1850 records across 3 tables
```

### 6. Soft-Delete Confirmation Processing
**File:** `lib/src/sync_manager.dart`

**New Method:**
```dart
static Future<void> _processConfirmedDeletes(
  Database db,
  List<Map<String, dynamic>> updates,
)
```

**Purpose:**
- Process soft-deletes after server confirms sync
- Actually delete records marked with `mtds_DeletedTXID`

**Workflow:**
1. User calls `DBHelper.softDelete()` → sets `mtds_DeletedTXID`
2. Trigger logs to `tbldmlog` with `Action = null`
3. `SyncManager.syncWithServer()` sends to server
4. Server responds with 200 OK
5. `_processConfirmedDeletes()` finds entries with `Action == null`
6. Executes actual `DELETE` from local database
7. Records permanently removed

**Updated `syncWithServer()` Flow:**
```dart
if (response.statusCode == 200) {
  // NEW: Process confirmed soft-deletes
  await _processConfirmedDeletes(db, normalizedUpdates);
  
  // Clear tbldmlog after successful sync
  await db.delete('tbldmlog');
}
```

## Delete Operation Comparison

| Feature | Soft Delete | Hard Delete |
|---------|------------|-------------|
| **Replication** | ✅ Yes | ❌ No |
| **Trigger Fires** | ✅ Yes (UPDATE) | ❌ No |
| **tbldmlog Entry** | ✅ Yes (Action=null) | ❌ No |
| **Server Sync** | ✅ Yes | ❌ No |
| **Immediate Deletion** | ❌ No (marks only) | ✅ Yes |
| **Final Deletion** | After server confirm | Immediate |
| **Use Case** | User data | Temp/cache data |

## Soft-Delete Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  1. User Action                                             │
│     DBHelper.softDelete(table, pk, value)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Database Update                                         │
│     UPDATE table SET mtds_DeletedTXID = <timestamp>        │
│     WHERE pk = value                                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Trigger Fires                                           │
│     INSERT INTO tbldmlog (Action = NULL, ...)               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Sync to Server                                          │
│     SyncManager.syncWithServer()                            │
│     POST /update with tbldmlog entries                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Server Confirms (200 OK)                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Process Confirmed Deletes                               │
│     _processConfirmedDeletes()                              │
│     DELETE FROM table WHERE pk = value                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Record Permanently Removed                              │
│     ✅ Deleted from local database                          │
│     ✅ Replicated to all other devices                      │
└─────────────────────────────────────────────────────────────┘
```

## API Changes

### New Public Methods

**DBHelper:**
```dart
// Delete operations
DBHelper.softDelete({required String tableName, required String primaryKeyColumn, required dynamic primaryKeyValue})
DBHelper.hardDelete({required String tableName, required String primaryKeyColumn, required dynamic primaryKeyValue})

// Timestamp generation
DBHelper.generateTxid() -> int

// PRAGMA helpers
DBHelper.getCurrentDeviceId() -> Future<int>
DBHelper.getCurrentAppVersion() -> Future<int>
```

**SSEManager:**
```dart
// Bulk loading
sseManager.loadAllTables({required String url, required String token, required List<String> tableNames, Map<String, dynamic>? extraParams}) -> Future<Map<String, int>>
```

### Modified Methods

**SSEManager.loadData():**
- Now uses transactions for atomic inserts
- Added logging for operation tracking

**SyncManager._applyServerUpdates():**
- Calls `_processConfirmedDeletes()` after successful sync
- Handles soft-delete confirmations automatically

## Usage Examples

### Example 1: Initial App Startup
```dart
// On app startup, load all tables
final sseManager = SSEManager();
final results = await sseManager.loadAllTables(
  url: 'https://api.example.com/sync',
  token: userToken,
  tableNames: ['users', 'products', 'orders', 'settings'],
);

print("Loaded ${results.values.fold(0, (a, b) => a + b)} total records");
```

### Example 2: User Deletes a Record
```dart
// User deletes an order - should sync to all devices
await DBHelper.softDelete(
  tableName: 'orders',
  primaryKeyColumn: 'id',
  primaryKeyValue: orderId,
);

// Later, sync to server
await SyncManager.syncWithServer(serverUrl);
// After server confirms, record is permanently deleted
```

### Example 3: Clear Temporary Cache
```dart
// Clear cache - local only, no sync
final cacheIds = await db.query('cache', columns: ['id']);
for (final row in cacheIds) {
  await DBHelper.hardDelete(
    tableName: 'cache',
    primaryKeyColumn: 'id',
    primaryKeyValue: row['id'],
  );
}
```

### Example 4: Insert with Proper Timestamp
```dart
final deviceId = await DBHelper.getDeviceId48Bit();
final txid = DBHelper.generateTxid();

await db.insert('users', {
  'id': newUserId,
  'name': 'John Doe',
  'email': 'john@example.com',
  'mtds_lastUpdatedTxid': txid,
  'mtds_DeviceID': deviceId,
  'mtds_DeletedTXID': null,
});
```

## Testing Requirements

Before deploying:

1. **Test soft-delete workflow:**
   - Create record
   - Soft delete
   - Verify `mtds_DeletedTXID` set
   - Sync to server
   - Verify record deleted after sync

2. **Test hard-delete workflow:**
   - Create record
   - Hard delete
   - Verify no `tbldmlog` entry
   - Verify immediate deletion

3. **Test transactional loading:**
   - Load large dataset
   - Verify all-or-nothing behavior
   - Test with network failure mid-load

4. **Test sequential table loading:**
   - Load multiple tables
   - Verify each table in own transaction
   - Test with one table failing

5. **Test timestamp generation:**
   - Generate multiple TXIDs
   - Verify monotonic ordering
   - Verify uniqueness

## Migration Notes

### Breaking Changes
None - All new features are additive

### Backward Compatibility
✅ Fully backward compatible with Phases 1 & 2

### Recommendations
1. Update existing delete operations to use `softDelete()`
2. Use `loadAllTables()` on app startup
3. Use `generateTxid()` for all new records

## Next Steps (Phase 4)

- JWT token parsing for tid/sub/app extraction
- Auth service interface
- Server-side field naming documentation
- Unique index requirements documentation

## Files Modified
- `lib/src/db_helper.dart` - Added delete helpers, timestamp helpers, PRAGMA helpers
- `lib/src/sse/sse.dart` - Added transactional loading, bulk table loading
- `lib/src/sync_manager.dart` - Added soft-delete confirmation processing

## Commit Recommendation
```bash
git add lib/src/
git commit -m "feat: Phase 3 - Sync & Replication Improvements

- Implement soft-delete vs hard-delete operations
- Add transactional data loading for atomicity
- Add sequential table loading for app startup
- Add soft-delete confirmation processing
- Add timestamp generation helper (generateTxid)
- Add PRAGMA helper methods (getCurrentDeviceId, getCurrentAppVersion)
- Improve logging and error handling

Features:
- Soft-delete: marks records, syncs, then deletes on confirmation
- Hard-delete: immediate local deletion, no replication
- Bulk loading: all tables loaded sequentially in transactions
- Atomic inserts: all records or none per table

MTDS Compliance: Requirements 10, 12"
```

