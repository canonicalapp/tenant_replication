# Schema Alignment Guide

This document describes the expected schema alignment between the client (Flutter/SQLite) and server (PostgreSQL) sides.

## Overview

The client and server schemas are **intentionally different**:
- **Client schema**: Contains only business columns + MTDS columns
- **Server schema**: Contains business columns + MTDS columns + server-only columns

Server-only columns are automatically filtered out during data synchronization.

## Expected Schema Differences

### Server-Only Columns

The server may include additional columns that don't exist in the client schema:

- `tenant_id` - Multi-tenant isolation (server-managed)
- `created_at` - Server-side timestamp (server-managed)
- `updated_at` - Server-side timestamp (server-managed)

These columns are:
- ✅ **Automatically filtered** during `loadFromServer()`
- ✅ **Ignored** during SSE updates
- ✅ **Not sent** during `syncToServer()` (client doesn't have them)

### Required MTDS Columns

Both client and server **must** have these columns:

- `mtds_last_updated_txid` - Transaction ID (BIGINT/INTEGER)
- `mtds_device_id` - Device identifier (INTEGER)
- `mtds_deleted_txid` - Soft delete timestamp (BIGINT/INTEGER, nullable)

## Example: Users Table

### Client Schema (SQLite/Drift)

```dart
class Users extends Table with MtdsColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  IntColumn get age => integer().nullable()();
  // MtdsColumns provides:
  // - mtds_last_updated_txid
  // - mtds_device_id
  // - mtds_deleted_txid
}
```

**Resulting SQLite columns:**
- `id`, `name`, `email`, `age`
- `mtds_last_updated_txid`, `mtds_device_id`, `mtds_deleted_txid`

### Server Schema (PostgreSQL)

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    age INTEGER,
    tenant_id TEXT NOT NULL,              -- Server-only
    mtds_last_updated_txid BIGINT NOT NULL DEFAULT 0,
    mtds_device_id INTEGER NOT NULL DEFAULT 0,
    mtds_deleted_txid BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Server-only
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- Server-only
);
```

**Resulting PostgreSQL columns:**
- `id`, `name`, `email`, `age`
- `mtds_last_updated_txid`, `mtds_device_id`, `mtds_deleted_txid`
- `tenant_id`, `created_at`, `updated_at` (server-only)

## Example: Products Table

### Client Schema (SQLite/Drift)

```dart
class Products extends Table with MtdsColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get description => text().nullable()();
  // MtdsColumns provides:
  // - mtds_last_updated_txid
  // - mtds_device_id
  // - mtds_deleted_txid
}
```

### Server Schema (PostgreSQL)

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    tenant_id TEXT NOT NULL,              -- Server-only
    mtds_last_updated_txid BIGINT NOT NULL DEFAULT 0,
    mtds_device_id INTEGER NOT NULL DEFAULT 0,
    mtds_deleted_txid BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Server-only
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- Server-only
);
```

## Schema Verification

The SDK automatically verifies schema alignment during `loadFromServer()`:

1. **Server-only columns** are logged and filtered:
   ```
   ⚠️ Server-only columns (will be ignored): tenant_id, created_at, updated_at
   ```

2. **Missing server columns** are logged (will use defaults):
   ```
   ⚠️ Missing server columns (will use defaults): column_name
   ```

## Best Practices

### ✅ DO:

1. **Use `MtdsColumns` mixin** on all client tables:
   ```dart
   class Users extends Table with MtdsColumns {
     // Your columns here
   }
   ```

2. **Match business column names** between client and server:
   - Client: `name`, `email`, `age`
   - Server: `name`, `email`, `age` ✅

3. **Let the SDK handle filtering** - don't manually filter server-only columns

4. **Document server-only columns** in your server schema comments

### ❌ DON'T:

1. **Don't add server-only columns to client schema** - they'll cause errors
2. **Don't manually filter columns** - the SDK handles this automatically
3. **Don't rename MTDS columns** - they must match exactly:
   - `mtds_last_updated_txid` (not `last_updated_txid`)
   - `mtds_device_id` (not `device_id`)
   - `mtds_deleted_txid` (not `deleted_txid`)

## Troubleshooting

### Error: "table has no column named X"

**Cause**: Server is returning a column that doesn't exist in client schema.

**Solution**: 
- If it's a server-only column (like `tenant_id`), this is expected - the SDK filters it automatically
- If it's a business column, ensure both schemas match

### Error: "Missing column X in server response"

**Cause**: Client expects a column that server doesn't provide.

**Solution**: 
- Check server schema includes the column
- Check server stored procedure returns the column
- Column will use default value (NULL or 0)

## Verification Checklist

When setting up a new table:

- [ ] Client table uses `MtdsColumns` mixin
- [ ] Business column names match between client and server
- [ ] Server includes `tenant_id` (if using multi-tenancy)
- [ ] Server includes `created_at`/`updated_at` (if using timestamps)
- [ ] Both sides have all MTDS columns with correct names
- [ ] Test `loadFromServer()` and verify schema warnings in logs

