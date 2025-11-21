## Purpose

Provides a state management table (`mtds_state`) for storing SDK configuration, device ID, timestamps, and per-table sync state.

## Requirements

### Requirement: Drift ORM Usage

The SDK SHALL use Drift ORM as the primary method for all database queries to ensure type safety and consistency.

Database operations SHALL:

- Use Drift ORM methods and queries as the default approach
- Define `mtds_state` table using Drift table definitions
- Use Drift's type-safe query builders for SELECT, INSERT, UPDATE operations
- Use raw SQL queries only when Drift ORM cannot be used effectively (e.g., limitations, performance drawbacks, or unsupported operations)
- Examples where raw SQL may be necessary: SQL triggers, RETURNING clauses, complex aggregations, or operations not well-supported by Drift
- Ensure all queries are type-safe where possible and benefit from compile-time checking

### Requirement: State Table Schema

The SDK SHALL create and manage a `mtds_state` table with the following schema:

```sql
CREATE TABLE mtds_state (
    Attribute   TEXT PRIMARY KEY,
    numValue    INTEGER NOT NULL DEFAULT 0,
    textValue   TEXT
);
```

The table SHALL:

- Use `Attribute` as PRIMARY KEY (TEXT)
- Store numeric values in `numValue` (INTEGER, NOT NULL, default 0)
- Store text values in `textValue` (TEXT, nullable)

#### Scenario: State table creation

- **WHEN** SDK is initialized
- **THEN** `mtds_state` table SHALL be created if it doesn't exist
- **AND** the table SHALL have the correct schema with Attribute as PRIMARY KEY

### Requirement: State Table Initialization

The SDK SHALL initialize required state entries during setup.

Initialization SHALL:

- Insert `'mtds:client_ts'` attribute for client timestamp tracking
- Insert `'mtds:lastSyncTS'` attribute for last sync timestamp
- Insert `'mtds:DeviceID'` attribute for device ID storage
- For each user table, insert `'table:' + tableName` attribute for storing MAX(mtds_server_ts) per table

#### Scenario: Core state attributes initialization

- **WHEN** SDK is initialized
- **THEN** the following attributes SHALL be inserted if they don't exist:
  - `'mtds:client_ts'` (for client timestamp generation)
  - `'mtds:lastSyncTS'` (for tracking last sync time)
  - `'mtds:DeviceID'` (for device ID storage)

#### Scenario: Per-table state attributes initialization

- **WHEN** a user table is registered with MTDS
- **THEN** an attribute `'table:' + tableName` SHALL be inserted if it doesn't exist
- **AND** this attribute SHALL store the MAX(mtds_server_ts) value for that table
- **AND** the value SHALL be updated when sync completes

### Requirement: Public State Table Methods

The SDK SHALL provide public methods to upsert values in the state table.

Public methods SHALL:

- Provide `upsertNumValue(Attribute, numValue)` to set numeric value for an attribute
- Provide `upsertTextValue(Attribute, textValue)` to set text value for an attribute
- Support both INSERT and UPDATE operations (upsert semantics)

#### Scenario: Upsert numeric value

- **WHEN** `upsertNumValue(Attribute, numValue)` is called
- **THEN** if attribute exists, numValue SHALL be updated
- **AND** if attribute doesn't exist, a new row SHALL be inserted with the provided numValue
- **AND** textValue SHALL remain unchanged or NULL

#### Scenario: Upsert text value

- **WHEN** `upsertTextValue(Attribute, textValue)` is called
- **THEN** if attribute exists, textValue SHALL be updated
- **AND** if attribute doesn't exist, a new row SHALL be inserted with the provided textValue
- **AND** numValue SHALL remain 0 or unchanged

#### Scenario: Retrieve numeric value

- **WHEN** numeric value is needed for an attribute
- **THEN** the SDK SHALL use Drift ORM to query the `mtds_state` table
- **AND** the query SHALL filter by Attribute and return numValue
- **AND** the value SHALL be returned as INTEGER (type-safe)

#### Scenario: Retrieve text value

- **WHEN** text value is needed for an attribute
- **THEN** the SDK SHALL use Drift ORM to query the `mtds_state` table
- **AND** the query SHALL filter by Attribute and return textValue
- **AND** the value SHALL be returned as TEXT or NULL (type-safe)

### Requirement: Client Timestamp Generation via State Table

The SDK SHALL generate client timestamps using the state table.

Client timestamp generation SHALL:

- Update `'mtds:client_ts'` attribute using Drift ORM when possible
- If Drift ORM cannot effectively handle the RETURNING clause or MAX() calculation, raw SQL may be used
- The update SHALL set numValue to MAX(numValue + 1, unixepoch('subsec') - 1735689600000) WHERE Attribute = 'mtds:client_ts'
- Use the returned numValue as `mtds_client_ts`
- Ensure monotonic increment (always increases)
- **NOTE**: If raw SQL is used, it should be wrapped in Drift's `customStatement()` or `customSelect()` for consistency

#### Scenario: Client timestamp update

- **WHEN** a client timestamp is needed
- **THEN** the SDK SHALL use Drift ORM to update the `'mtds:client_ts'` attribute (using custom SQL if RETURNING clause is needed)
- **AND** numValue SHALL be set to MAX of (current numValue + 1) or (current unix epoch - 1735689600000)
- **AND** the returned numValue SHALL be used as `mtds_client_ts`
- **AND** subsequent calls SHALL return strictly increasing values

### Requirement: Device ID Retrieval from State Table

The SDK SHALL retrieve device ID from the state table.

Device ID retrieval SHALL:

- Use Drift ORM to query the `mtds_state` table WHERE Attribute = 'mtds:DeviceID'
- Return the 64-bit device ID stored in numValue (type-safe)
- Handle case where device ID doesn't exist (initialization required)

#### Scenario: Device ID retrieval

- **WHEN** device ID is needed
- **THEN** the SDK SHALL use Drift ORM to query the `mtds_state` table WHERE Attribute = 'mtds:DeviceID'
- **AND** the returned numValue SHALL be used as the 64-bit device ID (type-safe)
- **AND** if no row exists, device ID initialization SHALL be triggered

### Requirement: Per-Table MAX Timestamp Storage

The SDK SHALL store MAX(mtds_server_ts) per table in the state table.

Per-table timestamp storage SHALL:

- Store MAX timestamp as `'table:' + tableName` attribute
- Update the value after successful sync operations
- Use numValue to store the BIGINT timestamp value

#### Scenario: Store MAX timestamp per table

- **WHEN** sync completes for a table
- **THEN** the MAX(mtds_server_ts) value SHALL be stored in `mtds_state` with Attribute `'table:' + tableName`
- **AND** the value SHALL be stored in numValue column
- **AND** this value SHALL be used for subsequent sync requests

#### Scenario: Retrieve MAX timestamp per table

- **WHEN** initial sync is performed
- **THEN** the SDK SHALL use Drift ORM to query the `mtds_state` table WHERE Attribute = 'table:' + tableName
- **AND** if value exists, it SHALL be used as the last known MAX(mtds_server_ts) (type-safe)
- **AND** if value doesn't exist, 0 SHALL be used as default
