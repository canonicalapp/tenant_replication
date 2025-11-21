## Purpose

Provides unique ID generation using the TX class with device ID encoding, monotonic guarantees, and UTC time extraction capabilities.

## Requirements

### Requirement: TX Class for ID Generation

The SDK SHALL provide a `TX` class in the utils module for generating unique IDs that encode device ID and can be decoded to extract UTC time.

The `TX` class SHALL:

- Be located in the utils module (e.g., `lib/src/utils/`)
- Use epoch starting at January 1, 2025 (timestamp: 1735689600000 milliseconds)
- Encode the last 24 bits of device ID in the generated ID
- Maintain monotonic ordering (strictly increasing)
- Support initialization with 64-bit device ID
- Provide `nextId()` method that returns a 64-bit integer
- Provide `getUTC(id64)` static method to extract UTC DateTime from an ID

#### Scenario: TX class initialization

- **WHEN** `TX.init(deviceId64)` is called with a 64-bit device ID
- **THEN** the last 24 bits of device ID SHALL be stored as `_dev24`
- **AND** the base milliseconds since 2025 epoch SHALL be calculated and stored
- **AND** a Stopwatch SHALL be started for elapsed time tracking
- **AND** `_initialized` flag SHALL be set to true
- **AND** subsequent calls to `init()` SHALL be ignored if already initialized

#### Scenario: ID generation with monotonic guarantee

- **WHEN** `TX.nextId()` is called
- **THEN** `_initialized` SHALL be true (assertion if false)
- **AND** physical milliseconds since 2025 SHALL be calculated: `_baseMsSince2025 + _sw.elapsedMilliseconds`
- **AND** logical milliseconds SHALL be MAX(physicalMs, \_lastLogicalMs + 1) to ensure monotonicity
- **AND** `_lastLogicalMs` SHALL be updated to logicalMs
- **AND** mix40 SHALL be calculated as: `(logicalMs + (_dev24 << 16)) & 0xFFFF_FFFFFF`
- **AND** the ID SHALL be returned as: `(mix40 << 24) | _dev24`
- **AND** subsequent calls SHALL return strictly increasing values

#### Scenario: Device ID encoding in ID

- **WHEN** an ID is generated via `TX.nextId()`
- **THEN** the lower 24 bits SHALL contain `_dev24` (last 24 bits of device ID)
- **AND** the device ID SHALL be extractable using `GlobalIdDecoder.extractDev24(id64)`

#### Scenario: UTC time extraction from ID

- **WHEN** `TX.getUTC(id64)` is called (or `GlobalIdDecoder.getUTC(id64)`)
- **THEN** the logical milliseconds SHALL be extracted from the ID
- **AND** UTC DateTime SHALL be calculated as: `DateTime.fromMillisecondsSinceEpoch(1735689600000 + logicalMs, isUtc: true)`
- **AND** the returned DateTime SHALL represent when the ID was generated

### Requirement: GlobalIdDecoder Class

The SDK SHALL provide a `GlobalIdDecoder` class for extracting information from generated IDs.

The `GlobalIdDecoder` class SHALL:

- Provide static methods for ID decoding
- Extract device ID (24 bits) from an ID
- Extract logical milliseconds from an ID
- Calculate UTC DateTime from an ID

#### Scenario: Extract device ID from ID

- **WHEN** `GlobalIdDecoder.extractDev24(id64)` is called
- **THEN** the lower 24 bits SHALL be extracted: `id64 & 0xFFF_FFF`
- **AND** the value SHALL be returned as integer

#### Scenario: Extract mix40 from ID

- **WHEN** `GlobalIdDecoder.extractMix40(id64)` is called
- **THEN** the upper 40 bits SHALL be extracted: `id64 >> 24`
- **AND** the value SHALL be returned as integer

#### Scenario: Extract logical milliseconds from ID

- **WHEN** `GlobalIdDecoder.extractLogicalMs(id64)` is called
- **THEN** dev24 SHALL be extracted first
- **AND** mix40 SHALL be extracted
- **AND** logical milliseconds SHALL be calculated as: `(mix40 - (dev24 << 16)) & 0xFFFF_FFFFFF`
- **AND** the value SHALL be returned

#### Scenario: Extract UTC DateTime from ID

- **WHEN** `GlobalIdDecoder.getUTC(id64)` is called
- **THEN** logical milliseconds SHALL be extracted
- **AND** UTC DateTime SHALL be calculated: `DateTime.fromMillisecondsSinceEpoch(1735689600000 + logicalMs, isUtc: true)`
- **AND** the DateTime SHALL be returned

### Requirement: TX Class Constants

The TX class SHALL define the following constants:

- `_epoch2025Ms = 1735689600000` - Milliseconds since Unix epoch for January 1, 2025
- `_MASK24 = 0xFFF_FFF` - Mask for 24 bits (device ID extraction)
- `_MASK40 = 0xFFFF_FFFFFF` - Mask for 40 bits (logical milliseconds)

#### Scenario: Constant values

- **WHEN** TX class is used
- **THEN** epoch constant SHALL be 1735689600000 milliseconds
- **AND** MASK24 SHALL be 0xFFF_FFF (24 bits)
- **AND** MASK40 SHALL be 0xFFFF_FFFFFF (40 bits)

### Requirement: Primary Key Generation

The SDK SHALL use TX class for generating primary keys in BEFORE INSERT triggers.

Primary key generation SHALL:

- Use TX class to generate IDs that encode device ID and timestamp
- Generate primary key using formula in trigger: `pk = ((((DeviceID << 16) + mtds_client_ts) & 0xFFFFFFFFFF) << 24) | (DeviceID & 0xFFFFFF)`
- Ensure primary keys are unique and monotonic
- Support UTC time extraction from primary keys

#### Scenario: Primary key generation in trigger

- **WHEN** a row is inserted
- **THEN** BEFORE INSERT trigger SHALL generate primary key using the formula
- **AND** DeviceID SHALL be retrieved from state table
- **AND** mtds_client_ts SHALL be retrieved/updated from state table
- **AND** the generated primary key SHALL be set in NEW.pk
- **AND** the primary key SHALL encode both device ID and client timestamp
