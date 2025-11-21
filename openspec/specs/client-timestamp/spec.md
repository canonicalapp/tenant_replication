## Purpose

Provides client-side timestamp generation using the state table for monotonic timestamp tracking, ensuring unique timestamps for conflict resolution and change tracking.

## Requirements

### Requirement: Drift ORM Usage

The SDK SHALL use Drift ORM as the primary method for client timestamp operations.

Client timestamp operations SHALL:

- Use Drift ORM as the default for querying and updating `mtds_state` table
- Use raw SQL queries only when Drift ORM cannot be used effectively (e.g., RETURNING clause limitations, SQL triggers, or performance drawbacks)
- Ensure type-safe handling of BIGINT timestamp values where possible

### Requirement: Client Timestamp Generation via State Table

The SDK SHALL generate client timestamps using the `mtds_state` table with monotonic guarantees.

Client timestamp generation SHALL:

- Use `'mtds:client_ts'` attribute in `mtds_state` table
- Update timestamp using Drift ORM when possible
- If Drift ORM cannot effectively handle the RETURNING clause or MAX() calculation, raw SQL may be used
- The update SHALL set numValue to MAX(numValue + 1, unixepoch('subsec') - 1735689600000) WHERE Attribute = 'mtds:client_ts'
- **NOTE**: If raw SQL is used, it should be wrapped in Drift's `customStatement()` or `customSelect()` for consistency
- Ensure monotonic increment (always increases)
- Return timestamp in milliseconds since client epoch (January 1, 2025: 1735689600000)
- Store timestamp as BIGINT

#### Scenario: Client timestamp update and retrieval

- **WHEN** a client timestamp is needed
- **THEN** the SDK SHALL use Drift ORM to update the `mtds_state` table (using custom SQL if RETURNING clause is needed)
- **AND** Attribute SHALL be `'mtds:client_ts'`
- **AND** numValue SHALL be set to MAX of:
  - `numValue + 1` (monotonic increment)
  - `unixepoch('subsec') - 1735689600000` (current time since epoch)
- **AND** the returned numValue SHALL be used as `mtds_client_ts`
- **AND** subsequent calls SHALL return strictly increasing values

#### Scenario: Client timestamp initialization

- **WHEN** SDK is initialized
- **AND** `'mtds:client_ts'` attribute doesn't exist
- **THEN** the attribute SHALL be inserted with numValue = 0
- **AND** first timestamp generation SHALL set numValue to current time or 1

#### Scenario: Monotonic timestamp guarantee

- **WHEN** `mtds_client_ts` is generated multiple times
- **THEN** each timestamp SHALL be greater than the previous
- **AND** if system clock goes backwards, numValue + 1 SHALL ensure monotonicity
- **AND** timestamps SHALL never decrease

### Requirement: Client Timestamp Usage in Triggers

The SDK SHALL use state table-generated timestamps in BEFORE INSERT and BEFORE UPDATE triggers.

Trigger usage SHALL:

- Retrieve `mtds_client_ts` from state table before insert/update
- Set `NEW.mtds_client_ts` in triggers
- Ensure timestamps are set before change logging

#### Scenario: Client timestamp in BEFORE INSERT trigger

- **WHEN** a row is inserted
- **THEN** BEFORE INSERT trigger SHALL update `'mtds:client_ts'` in state table
- **AND** the returned numValue SHALL be set as `NEW.mtds_client_ts`
- **AND** the timestamp SHALL be stored as BIGINT

#### Scenario: Client timestamp in BEFORE UPDATE trigger

- **WHEN** a row is updated
- **THEN** BEFORE UPDATE trigger SHALL update `'mtds:client_ts'` in state table
- **AND** the returned numValue SHALL be set as `NEW.mtds_client_ts`
- **AND** the new timestamp SHALL be greater than the old timestamp

### Requirement: Client Timestamp for Soft Delete

The SDK SHALL use client timestamp for soft delete operations.

Soft delete timestamp SHALL:

- Set `mtds_delete_ts` to the same value as `mtds_client_ts` when soft deleting
- Use state table to generate timestamp before setting delete marker
- Store delete timestamp as BIGINT

#### Scenario: Soft delete timestamp

- **WHEN** a record is soft deleted
- **THEN** `mtds_client_ts` SHALL be updated via state table
- **AND** `mtds_delete_ts` SHALL be set to the same value as `mtds_client_ts`
- **AND** both timestamps SHALL be in milliseconds since client epoch

### Requirement: Primary Key Generation with Client Timestamp

The SDK SHALL use client timestamp in primary key generation formula.

Primary key generation SHALL:

- Use `mtds_client_ts` from state table in PK formula
- Generate PK as: `pk = ((((DeviceID << 16) + mtds_client_ts) & 0xFFFFFFFFFF) << 24) | (DeviceID & 0xFFFFFF)`
- Ensure primary keys are unique and encode both device ID and timestamp

#### Scenario: Primary key includes client timestamp

- **WHEN** a primary key is generated
- **THEN** `mtds_client_ts` SHALL be retrieved from state table first
- **AND** the PK formula SHALL use this timestamp
- **AND** the generated PK SHALL encode both device ID and client timestamp
