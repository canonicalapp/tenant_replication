# Phase 1: Core Infrastructure - MTDS Compliance

## Overview

Phase 1 implements core infrastructure changes for MTDS compliance, focusing on database naming, field naming conventions, and proper database initialization.

## Changes Implemented

### 1. Dependencies Added

- **path_provider** (^2.1.0): For platform-specific app directories
- **crypto** (^3.0.3): For SHA256 database name generation

### 2. Database Path Migration

**File:** `lib/src/db_helper.dart`

**Before:**

```dart
String dbPath = join(await getDatabasesPath(), dbName);
```

**After:**

```dart
final Directory appSupportDir = await getApplicationSupportDirectory();
String dbPath = join(appSupportDir.path, dbName);
```

**Impact:** Databases now stored in platform-specific application support directory instead of default SQLite path.

### 3. SHA256-Based Database Name Generation

**File:** `lib/src/db_helper.dart`

**Implementation:**

- Database name = `HEX(SHA256('sub:tid:app'))`
- Format: `XXXX-XXXX-XXXX-...-XXXX.db` (64 hex chars + 15 hyphens + .db = 82 chars total)
- Requires three values from secure storage:
  - `SubjectId` (sub)
  - `TenantId` (tid)
  - `AppName` (app)

**New Methods:**

```dart
Future<String?> _getTenantId()
Future<String?> _getSubjectId()
Future<String?> _getAppName()
Future<String> _getDatabaseName() // Updated with SHA256 logic
```

**Fallback:** If sub/tid/app are missing, falls back to legacy `DatabaseName` from secure storage.

### 4. Field Naming Convention: `mtds_` Prefix

All special-purpose fields now use `mtds_` prefix for proper namespacing:

| Old Field Name    | New Field Name              |
| ----------------- | --------------------------- |
| `lastUpdatedTxid` | `mtds_lastUpdatedTxid`      |
| `DeletedTXID`     | `mtds_DeletedTXID`          |
| N/A               | `mtds_DeviceID` (new field) |

### 5. tbldmlog Schema Update

**File:** `lib/src/db_helper.dart`

**Before:**

```sql
CREATE TABLE IF NOT EXISTS tbldmlog (
  TXID INTEGER PRIMARY KEY AUTOINCREMENT,
  TableName TEXT NOT NULL,
  PK INTEGER NOT NULL,
  Action INTEGER,
  PayLoad TEXT
);
```

**After:**

```sql
CREATE TABLE IF NOT EXISTS tbldmlog (
  TXID INTEGER PRIMARY KEY AUTOINCREMENT,
  TableName TEXT NOT NULL,
  PK INTEGER NOT NULL,
  mtds_DeviceID INTEGER NOT NULL,  -- NEW FIELD
  Action INTEGER,
  PayLoad TEXT
);
```

**Impact:** DeviceID now tracked separately in change log.

### 6. Trigger Updates

**File:** `lib/src/trigger_manager.dart`

**Changes:**

- Removed bitmask operations (`& 0xFFFFFF`)
- Updated to use `mtds_DeviceID` for device comparison
- Updated field references to use `mtds_` prefix

**INSERT Trigger:**

```sql
-- Old: WHEN (NEW.lastUpdatedTxid & 0xFFFFFF) = ...
-- New: WHEN NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())

INSERT INTO tbldmlog (TXID, TableName, PK, mtds_DeviceID, Action, PayLoad)
VALUES (
  NEW.mtds_lastUpdatedTxid,
  '$tableName',
  NEW.$pkColumn,
  NEW.mtds_DeviceID,  -- NEW
  0,
  json_object('New', json_object(...), 'old', NULL)
);
```

**UPDATE Trigger:**

```sql
WHEN (
  (
    OLD.mtds_lastUpdatedTxid <> NEW.mtds_lastUpdatedTxid
    AND NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
  )
  OR
  (
    OLD.mtds_DeletedTXID IS NULL
    AND NEW.mtds_DeletedTXID IS NOT NULL
    AND NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
  )
)
```

### 7. Foreign Keys Disabled

**File:** `lib/src/db_helper.dart`

Added `PRAGMA foreign_keys = OFF;` in database initialization to allow replication to work properly.

### 8. SSE Manager Update

**File:** `lib/src/sse/sse.dart`

Updated `getMaxLastUpdated()` to query the new field name:

```dart
// Old: SELECT MAX(lastupdated) as maxVal FROM $tableName
// New: SELECT MAX(mtds_lastUpdatedTxid) as maxVal FROM $tableName
```

## Required User Table Schema

For tables to work with MTDS replication, they must include these special fields:

```sql
CREATE TABLE your_table (
  id INTEGER PRIMARY KEY,
  -- your columns here
  mtds_lastUpdatedTxid INTEGER,
  mtds_DeletedTXID INTEGER,
  mtds_DeviceID INTEGER
);
```

## Required Secure Storage Keys

The following keys must be set in secure storage for proper operation:

### New Keys (for SHA256 naming):

- `SubjectId`: Subject identifier from auth token
- `TenantId`: Tenant identifier from auth token
- `AppName`: Unique application name

### Legacy Keys (still supported):

- `DeviceId`: Device identifier (used for application_id)
- `DatabaseName`: Fallback database name (if sub/tid/app not available)

## Migration Notes

### Breaking Changes

1. **Database name format changed**: Existing databases will NOT be automatically migrated. Apps will create new databases with SHA256 names.
2. **Field names changed**: Tables must be updated to use `mtds_` prefix.
3. **Trigger conditions changed**: Removed bitmask operations.

### Backward Compatibility

- Falls back to legacy `DatabaseName` if sub/tid/app are not provided
- All old field names removed (no compatibility layer)

## Testing Requirements

Before deploying to production:

1. Test SHA256 database name generation
2. Verify path_provider creates correct directory
3. Test trigger functionality with new field names
4. Verify foreign keys are disabled
5. Test with missing sub/tid/app (fallback scenario)

## Next Steps (Phase 2)

- Implement 48-bit DeviceID support
- Update user_version + application_id packing (App Version + DeviceID)
- PK format using nanoseconds since epoch

## Files Modified

- `pubspec.yaml`
- `pubspec.lock`
- `lib/src/db_helper.dart`
- `lib/src/trigger_manager.dart`
- `lib/src/sse/sse.dart`

## Commit Recommendation

```bash
git add pubspec.yaml pubspec.lock lib/src/
git commit -m "feat: Phase 1 - MTDS Core Infrastructure

- Add path_provider and crypto dependencies
- Implement SHA256-based database naming (HEX format)
- Migrate to mtds_ field name prefix
- Add mtds_DeviceID to tbldmlog schema
- Update triggers to use new field names
- Remove bitmask operations from triggers
- Disable foreign keys for replication
- Update SSE manager for new field names

Breaking Changes:
- Database name format changed to SHA256 hash
- All special fields now use mtds_ prefix
- Triggers updated with new field references

MTDS Compliance: Requirements 2, 3, 4, 13"
```


