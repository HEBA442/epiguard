/// Centralized API configuration for the EpiGuard backend.
/// baseUrl is set dynamically at startup via mDNS discovery (see main.dart).
/// Falls back to the hardcoded IP if discovery fails.
class ApiEndpoints {
  // ── Base URL ─────────────────────────────────────────────
  // Set dynamically in main.dart via ServerDiscovery.findServer()
  // Fallback: update this if mDNS is unavailable on your network
  static String baseUrl = 'http://192.168.1.1:5000';

  // ── Health ───────────────────────────────────────────────
  static String get health => '$baseUrl/api/health';

  // ── Auth Endpoints ───────────────────────────────────────
  static String get requestSignupOtp   => '$baseUrl/api/auth/request-signup-otp';
  static String get completeSignup     => '$baseUrl/api/auth/complete-signup';
  static String get login              => '$baseUrl/api/auth/login';
  static String get verifyToken        => '$baseUrl/api/auth/verify-token';
  static String get registerFcmToken   => '$baseUrl/api/auth/register-fcm-token';

  // ── Password Reset ───────────────────────────────────────
  static String get requestPasswordReset => '$baseUrl/api/auth/request-password-reset';
  static String get resetPassword        => '$baseUrl/api/auth/reset-password';

  // ── User ─────────────────────────────────────────────────
  static String get userProfile => '$baseUrl/api/users/profile';

  // ── Seizure Detection ────────────────────────────────────
  static String get predict        => '$baseUrl/api/seizure/predict';
  static String get seizureHistory => '$baseUrl/api/seizure/history';
}
