## Purpose

Defines the required MTDS columns that must be present in all replicated tables for synchronization to work correctly.

## Requirements

### Requirement: MTDS Required Columns

All replicated tables SHALL include the following MTDS columns via the `MtdsColumns` mixin.

Required columns SHALL include:

- `mtds_client_ts` (INTEGER, NOT NULL, default 0) - Client-generated timestamp using PK class
- `mtds_server_ts` (INTEGER, nullable) - Server-assigned authoritative timestamp
- `mtds_device_id` (INTEGER, NOT NULL, default 0) - Device identifier
- `mtds_deleted_ts` (INTEGER, nullable) - Soft delete marker (timestamp when deleted)

#### Scenario: Complete column set

- **WHEN** a table uses `MtdsColumns` mixin
- **THEN** all four MTDS columns SHALL be present
- **AND** columns SHALL have correct types and constraints
- **AND** columns SHALL be automatically added to the table schema

#### Scenario: Client timestamp column

- **WHEN** a table uses `MtdsColumns` mixin
- **THEN** the table SHALL include `mtds_client_ts` column
- **AND** the column SHALL be INTEGER type, NOT NULL, with default 0
- **AND** the column SHALL store client-generated timestamps using `PK.getPK()`

#### Scenario: Server timestamp column

- **WHEN** a table uses `MtdsColumns` mixin
- **THEN** the table SHALL include `mtds_server_ts` column
- **AND** the column SHALL be INTEGER type, nullable
- **AND** the column SHALL store server-assigned authoritative timestamps
- **AND** the column SHALL be NULL until the record is synced to server

#### Scenario: Device ID column

- **WHEN** a table uses `MtdsColumns` mixin
- **THEN** the table SHALL include `mtds_device_id` column
- **AND** the column SHALL be INTEGER type, NOT NULL, with default 0
- **AND** the column SHALL store the device identifier that created/modified the record

#### Scenario: Deleted timestamp column

- **WHEN** a table uses `MtdsColumns` mixin
- **THEN** the table SHALL include `mtds_deleted_ts` column
- **AND** the column SHALL be INTEGER type, nullable
- **AND** NULL value SHALL indicate the record is active
- **AND** non-NULL value SHALL indicate the record is soft-deleted at that timestamp

