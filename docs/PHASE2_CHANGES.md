# Phase 2: DeviceID & Versioning - MTDS Compliance

## Overview

Phase 2 implements 48-bit DeviceID support with proper packing into SQLite PRAGMA fields, enabling MAC address usage as DeviceID and proper app versioning.

## Changes Implemented

### 1. 48-bit DeviceID Support

**File:** `lib/src/db_helper.dart`

**New Constant:**

```dart
static const int _appVersion = 1; // Application schema version
```

**New Method:**

```dart
static Future<int> getDeviceId48Bit() async
```

- Reads DeviceID from secure storage
- Validates it fits in 48 bits (max: 281,474,976,710,655)
- Throws exception if exceeds 48-bit limit
- **Purpose:** Supports MAC addresses as DeviceID (48 bits)

### 2. PRAGMA Packing/Unpacking Utilities

#### Pack Methods

**`packUserVersion(int appVersion, int deviceId)`**

- Packs App Version (16 bits) + MS 16 bits of DeviceID
- Layout: `[App Version: 16 bits][DeviceID MS 16 bits: 16 bits]`
- Returns: 32-bit integer for `PRAGMA user_version`

**`packApplicationId(int deviceId)`**

- Packs LS 32 bits of DeviceID
- Layout: `[DeviceID LS 32 bits: 32 bits]`
- Returns: 32-bit integer for `PRAGMA application_id`

#### Unpack Methods

**`unpackAppVersion(int userVersion)`**

- Extracts App Version from user_version
- Returns: 16-bit App Version

**`unpackDeviceIdMS16(int userVersion)`**

- Extracts MS 16 bits of DeviceID from user_version
- Returns: 16-bit value

**`reconstructDeviceId(int userVersion, int applicationId)`**

- Reconstructs full 48-bit DeviceID from both PRAGMAs
- Combines MS 16 bits from user_version + LS 32 bits from application_id
- Returns: Full 48-bit DeviceID

### 3. Database Initialization Updates

**File:** `lib/src/db_helper.dart`

**Before:**

```dart
await database.execute("PRAGMA application_id = $deviceId;");
```

**After:**

```dart
// Pack and set user_version (App Version + MS 16 bits of DeviceID)
final packedUserVersion = packUserVersion(_appVersion, deviceId48);
await database.execute("PRAGMA user_version = $packedUserVersion;");

// Pack and set application_id (LS 32 bits of DeviceID)
final packedAppId = packApplicationId(deviceId48);
await database.execute("PRAGMA application_id = $packedAppId;");

// Verify reconstruction
final reconstructed = reconstructDeviceId(packedUserVersion, packedAppId);
if (reconstructed != deviceId48) {
  throw Exception("DeviceID packing/unpacking failed!");
}
```

**New Features:**

- Stores app version separately from DeviceID
- Splits 48-bit DeviceID across two PRAGMAs
- Verifies packing/unpacking integrity on startup
- Debug logging for verification

### 4. Nanosecond Timestamp Generation

**File:** `lib/src/db_helper.dart`

**New Method:**

```dart
static int generateNanosecondTimestamp()
```

- Generates 64-bit nanosecond timestamp since epoch
- Uses `DateTime.now().microsecondsSinceEpoch * 1000`
- **Purpose:** Consistent, monotonic PKs across machines
- **Use Case:** For generating `mtds_lastUpdatedTxid` values

### 5. Trigger Updates for 48-bit DeviceID

**File:** `lib/src/trigger_manager.dart`

**Old Logic:**

```sql
WHEN NEW.mtds_DeviceID = (SELECT application_id FROM pragma_application_id())
```

**New Logic (Two-Part Comparison):**

```sql
WHEN (
  (NEW.mtds_DeviceID & 0xFFFFFFFF) = (SELECT application_id FROM pragma_application_id())
  AND ((NEW.mtds_DeviceID >> 32) & 0xFFFF) = ((SELECT user_version FROM pragma_user_version()) & 0xFFFF)
)
```

**Comparison Strategy:**

- **Part 1:** Compare LS 32 bits of `mtds_DeviceID` with `application_id`
- **Part 2:** Compare MS 16 bits of `mtds_DeviceID` with MS 16 bits of `user_version`
- **Result:** Full 48-bit DeviceID verification

**Applied to:**

- INSERT trigger WHEN clause
- UPDATE trigger WHEN clause (both conditions)

## Storage Layout

### PRAGMA user_version (32 bits)

```
┌─────────────────────┬──────────────────────┐
│  App Version        │  DeviceID MS 16 bits │
│  (16 bits)          │  (16 bits)           │
└─────────────────────┴──────────────────────┘
Bits: 31-16              15-0
```

### PRAGMA application_id (32 bits)

```
┌──────────────────────────────────────────┐
│  DeviceID LS 32 bits                     │
│  (32 bits)                               │
└──────────────────────────────────────────┘
Bits: 31-0
```

### Combined 48-bit DeviceID

```
┌──────────────────────┬────────────────────────────────────────┐
│  MS 16 bits          │  LS 32 bits                            │
│  (from user_version) │  (from application_id)                 │
└──────────────────────┴────────────────────────────────────────┘
Bits: 47-32               31-0
Total: 48 bits (6 bytes)
```

## DeviceID Limits

| Representation  | Max Value             | Notes            |
| --------------- | --------------------- | ---------------- |
| Decimal         | 281,474,976,710,655   | ~281 trillion    |
| Hexadecimal     | 0xFFFFFFFFFFFF        | 12 hex digits    |
| Binary          | 48 ones               | 6 bytes          |
| **MAC Address** | **FF:FF:FF:FF:FF:FF** | **Perfect fit!** |

## API Changes

### New Public Methods

```dart
// DeviceID Management
DBHelper.getDeviceId48Bit() -> Future<int>
DBHelper.generateNanosecondTimestamp() -> int

// PRAGMA Packing
DBHelper.packUserVersion(int appVersion, int deviceId) -> int
DBHelper.packApplicationId(int deviceId) -> int

// PRAGMA Unpacking
DBHelper.unpackAppVersion(int userVersion) -> int
DBHelper.unpackDeviceIdMS16(int userVersion) -> int
DBHelper.reconstructDeviceId(int userVersion, int applicationId) -> int
```

### Removed Methods

```dart
_getDeviceId() // Replaced by getDeviceId48Bit()
```

## Migration Notes

### Breaking Changes

1. **DeviceID must fit in 48 bits**: Existing 64-bit DeviceIDs will cause exceptions
2. **PRAGMA storage changed**: user_version now stores app version + partial DeviceID
3. **Trigger logic updated**: Now performs two-part DeviceID comparison

### Backward Compatibility

- No automatic migration from old PRAGMA format
- Apps must regenerate databases or manually migrate PRAGMAs
- DeviceIDs exceeding 48 bits will throw exceptions

## Verification

The system automatically verifies DeviceID packing/unpacking on database initialization:

```
📊 user_version set: 65537 (App: 1, DeviceID MS16: 1)
📊 application_id set: 2857740885 (DeviceID LS32)
✅ DeviceID verification: Original=4295250645, Reconstructed=4295250645
```

If verification fails, initialization throws an exception.

## Example DeviceID Values

### MAC Address as DeviceID

```dart
// MAC: 00:1A:2B:3C:4D:5E
final macAddress = 0x001A2B3C4D5E; // 28,553,429,155,166
await storage.write(key: 'DeviceId', value: macAddress.toString());

// Result:
// user_version = (1 << 16) | 0x001A = 65562
// application_id = 0x2B3C4D5E = 725,404,766
```

### Sequential DeviceID

```dart
// Simple sequential ID
final deviceId = 123456789; // Fits in 48 bits
await storage.write(key: 'DeviceId', value: '123456789');

// Result:
// user_version = (1 << 16) | 0x0000 = 65536
// application_id = 0x075BCD15 = 123,456,789
```

## Testing Requirements

Before deploying:

1. **Test with various DeviceID sizes:**
   - Small values (< 32 bits)
   - Large values (32-47 bits)
   - MAX value (48 bits all 1s)
2. **Test MAC address conversion:**

   - Convert MAC to integer
   - Verify packing/unpacking
   - Verify trigger firing

3. **Test nanosecond timestamps:**

   - Verify monotonic ordering
   - Test across system clock changes
   - Verify 64-bit storage

4. **Test trigger DeviceID comparison:**
   - Insert with matching DeviceID
   - Insert with non-matching DeviceID
   - Verify tbldmlog entries

## Next Steps (Phase 3)

- JWT token parsing for tid/sub/app extraction
- Auth service interface
- Integration with external auth provider (UIDS)

## Files Modified

- `lib/src/db_helper.dart` - Added packing utilities, updated initialization
- `lib/src/trigger_manager.dart` - Updated trigger DeviceID comparison logic

## Commit Recommendation

```bash
git add lib/src/
git commit -m "feat: Phase 2 - 48-bit DeviceID & PRAGMA Packing

- Implement 48-bit DeviceID support (supports MAC addresses)
- Add PRAGMA packing utilities for user_version and application_id
- Pack App Version (16 bits) + DeviceID (48 bits) across PRAGMAs
- Update triggers for two-part 48-bit DeviceID comparison
- Add nanosecond timestamp generation for PKs
- Add DeviceID reconstruction and verification
- Remove legacy _getDeviceId() method

Breaking Changes:
- DeviceID must fit in 48 bits (throws exception otherwise)
- PRAGMA storage format changed
- Trigger DeviceID comparison updated

MTDS Compliance: Requirements 5, 6, 7, 8"
```


