/// Abstract interface for authentication services
/// Allows pluggable auth providers (UIDS, Firebase, Custom, etc.)
abstract class AuthService {
  /// Get the tenant ID (tid) from the authentication provider
  /// This is typically extracted from JWT token claims
  Future<String?> getTenantId();

  /// Get the subject ID (sub) from the authentication provider
  /// This represents the authenticated user/subject
  Future<String?> getSubjectId();

  /// Get the application name from the authentication provider
  Future<String?> getAppName();

  /// Get the device ID (must fit in 48 bits for MTDS compliance)
  Future<int?> getDeviceId();

  /// Get the authentication token (JWT or similar)
  /// Returns null if not authenticated
  Future<String?> getAuthToken();

  /// Parse JWT token and extract claims
  /// Returns a map of claims or null if invalid/not JWT
  Map<String, dynamic>? parseToken(String token);

  /// Check if user is currently authenticated
  Future<bool> isAuthenticated();

  /// Optional: Refresh authentication if needed
  Future<void> refreshAuth();
}
