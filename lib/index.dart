library mtds;

// Export main SDK class
export 'src/mtds_sdk.dart';

// Export database utilities
export 'src/database/trigger_manager.dart';
export 'src/database/schema_manager.dart';
export 'src/database/mtds_columns.dart';

// Export helpers
export 'src/helpers/pragma_helper.dart';

// Export utilities
export 'src/utils/mtds_utils.dart';

// Export models
export 'src/models/sync_result.dart';
export 'src/models/server_events.dart';

// Export services (advanced users may need these)
export 'src/sync/sync_service.dart';
export 'src/sync/sse_service.dart';
export 'src/sync/delete_service.dart';

// Users must import drift and dio themselves
// This gives them version control and flexibility
//
// Required peer dependencies:
// - drift: ^2.13.0
// - dio: ^5.9.0
// - sqlite3_flutter_libs: ^0.5.19
//
// Note: Configure Dio with auth interceptors before passing to SDK
