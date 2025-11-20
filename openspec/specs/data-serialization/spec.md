## Purpose

Handles data serialization for server communication, ensuring binary data and numeric values are properly encoded for GraphQL transport.

## Requirements

### Requirement: Binary Data Encoding

The SDK SHALL encode binary data fields (BLOB columns) as Base64 strings when serializing to JSON for server communication.

#### Scenario: Binary field serialization

- **WHEN** a table contains BLOB columns
- **AND** data is serialized to JSON for sync operations
- **THEN** BLOB values SHALL be encoded as Base64 strings
- **AND** the encoded strings SHALL be included in JSON payload

#### Scenario: Number field serialization

- **WHEN** table columns contain numeric types (INTEGER, REAL)
- **AND** data is serialized to JSON for sync operations
- **THEN** numeric values SHALL be serialized as JSON numbers (without quotes)
- **AND** the server SHALL receive proper number types for json-bigint processing

### Requirement: Data Serialization for Sync

The SDK SHALL serialize table data to JSON format compatible with server requirements.

Serialization SHALL:

- Encode binary fields (BLOB) as Base64 strings
- Serialize numeric fields as JSON numbers (unquoted)
- Handle all data types correctly for GraphQL transport

#### Scenario: Complete row serialization

- **WHEN** a row is serialized for sync
- **THEN** all columns SHALL be included in JSON
- **AND** BLOB columns SHALL be Base64 encoded
- **AND** numeric columns SHALL be unquoted numbers
- **AND** text columns SHALL be quoted strings

