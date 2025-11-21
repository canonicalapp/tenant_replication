import 'package:drift/drift.dart';

/// Drift table definition for `mtds_state` table.
///
/// This table stores SDK configuration, device ID, timestamps, and per-table sync state.
///
/// Schema:
/// - `Attribute` (TEXT PRIMARY KEY) - The attribute name/key
/// - `numValue` (INTEGER NOT NULL DEFAULT 0) - Numeric value for the attribute
/// - `textValue` (TEXT nullable) - Text value for the attribute
class MtdsState extends Table {
  /// Attribute name/key (PRIMARY KEY)
  TextColumn get attribute => text()();

  /// Numeric value for the attribute (default: 0)
  IntColumn get numValue => integer().withDefault(const Constant(0))();

  /// Text value for the attribute (nullable)
  TextColumn get textValue => text().nullable()();

  @override
  Set<Column> get primaryKey => {attribute};
}
