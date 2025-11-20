## Purpose

Manages device identification for multi-device synchronization, ensuring each device has a unique, persistent identifier.

## Requirements

### Requirement: Device ID Management

The SDK SHALL manage device identification using the `mtds_metadata` table exclusively.

Device ID management SHALL:

- Store device ID in `mtds_metadata` table via `SchemaManager.upsertMetadata()`
- Never change device ID after first initialization
- Support optional device ID parameter in SDK constructor
- Generate random device ID if not provided
- Be retrievable from metadata table for trigger operations

#### Scenario: Device ID initialization with provided value

- **WHEN** SDK is initialized with deviceID parameter
- **AND** no device ID exists in metadata table
- **THEN** the provided device ID SHALL be stored in `mtds_metadata` table
- **AND** the device ID SHALL be used for all operations

#### Scenario: Device ID initialization without provided value

- **WHEN** SDK is initialized without deviceID parameter
- **AND** no device ID exists in metadata table
- **THEN** a random device ID SHALL be generated
- **AND** the generated device ID SHALL be stored in `mtds_metadata` table

#### Scenario: Device ID persistence

- **WHEN** device ID exists in metadata table
- **THEN** the existing device ID SHALL be used
- **AND** it SHALL never be changed during database lifetime
- **AND** provided device ID parameter SHALL be ignored if metadata exists

#### Scenario: Device ID retrieval for triggers

- **WHEN** triggers need device ID for change tracking
- **THEN** device ID SHALL be read from `mtds_metadata` table
- **AND** triggers SHALL use this value to populate `mtds_device_id` column

#### Scenario: Device ID validation

- **WHEN** a device ID is provided or generated
- **THEN** the device ID SHALL be a valid 48-bit integer (0 to 281,474,976,710,655)
- **AND** invalid device IDs SHALL be rejected with an error

