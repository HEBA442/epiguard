import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_endpoints.dart';
import '../../core/secure_storage.dart';

/// Raw HTTP layer — every method maps 1:1 to a Flask endpoint.
/// Returns parsed JSON maps; the provider layer handles UI state.
class AuthService {
  // ════════════════════════════════════════════════════════
  //  SIGNUP FLOW
  // ════════════════════════════════════════════════════════

  /// Step 1 — POST /api/auth/request-signup-otp
  /// Sends OTP to the patient's email for verification.
  static Future<Map<String, dynamic>> requestSignupOtp({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.requestSignupOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Step 2 — POST /api/auth/complete-signup
  /// Verifies OTP then creates patient + caregiver accounts.
  static Future<Map<String, dynamic>> completeSignup({
    required String patientName,
    required String patientEmail,
    required String patientPassword,
    required int patientAge,
    required String patientEpilepsyDuration,
    required String caregiverName,
    required String caregiverEmail,
    required String caregiverRelation,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.completeSignup),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_name': patientName,
          'patient_email': patientEmail,
          'patient_password': patientPassword,
          'patient_age': patientAge,
          'patient_epilepsy_duration': patientEpilepsyDuration,
          'caregiver_name': caregiverName,
          'caregiver_email': caregiverEmail,
          'caregiver_relation': caregiverRelation,
          'otp_code': otpCode,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ════════════════════════════════════════════════════════
  //  LOGIN
  // ════════════════════════════════════════════════════════

  /// POST /api/auth/login
  /// Authenticates patient or caregiver, returns JWT.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ════════════════════════════════════════════════════════
  //  TOKEN VERIFICATION
  // ════════════════════════════════════════════════════════

  /// GET /api/auth/verify-token
  /// Checks whether the stored JWT is still valid.
  static Future<Map<String, dynamic>> verifyToken() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token stored'};
      }

      final response = await http.get(
        Uri.parse(ApiEndpoints.verifyToken),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ════════════════════════════════════════════════════════
  //  PASSWORD RESET
  // ════════════════════════════════════════════════════════

  /// POST /api/auth/request-password-reset
  /// Sends a password-reset OTP to the user's email.
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.requestPasswordReset),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// POST /api/auth/reset-password
  /// Verifies the OTP and sets a new password.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.resetPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp_code': otpCode,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
