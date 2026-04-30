import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../core/secure_storage.dart';
import '../alert/fcm_service.dart';

/// Manages all authentication state for the UI.
/// Screens listen to this via Provider; they never call AuthService directly.
class AuthProvider extends ChangeNotifier {
  // ── State flags ─────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _authChecked = false;
  bool get authChecked => _authChecked;

  String? _userType; // 'patient' or 'caregiver'
  String? get userType => _userType;

  String? _userName;
  String? get userName => _userName;

  // ── Data passed between signup screens ──────────────────
  String? signupEmail; // Set in signup_page, used in otp_page

  // ── Helpers ─────────────────────────────────────────────

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  CHECK AUTH ON APP START
  // ════════════════════════════════════════════════════════

  /// Called once in main.dart to decide the initial route.
  Future<void> checkAuthStatus() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _isAuthenticated = false;
      notifyListeners();
      return;
    }

    // Verify with backend
    final result = await AuthService.verifyToken();

    if (result['success'] == true) {
      _isAuthenticated = true;
      _userType = result['user_type'];
      _userName = result['user_name'];
    } else {
      // Token expired / invalid — force re-login
      _isAuthenticated = false;
      await SecureStorage.clearAll();
    }
    notifyListeners();
    _authChecked = true;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  SIGNUP — Step 1: Request OTP
  // ════════════════════════════════════════════════════════

  Future<bool> requestSignupOtp(String email) async {
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    final result = await AuthService.requestSignupOtp(email: email);

    _setLoading(false);

    if (result['success'] == true) {
      signupEmail = email;
      _successMessage = result['message'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to send OTP';
      notifyListeners();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  //  SIGNUP — Step 2: Complete Signup
  // ════════════════════════════════════════════════════════

  Future<bool> completeSignup({
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
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    final result = await AuthService.completeSignup(
      patientName: patientName,
      patientEmail: patientEmail,
      patientPassword: patientPassword,
      patientAge: patientAge,
      patientEpilepsyDuration: patientEpilepsyDuration,
      caregiverName: caregiverName,
      caregiverEmail: caregiverEmail,
      caregiverRelation: caregiverRelation,
      otpCode: otpCode,
    );

    _setLoading(false);

    if (result['success'] == true) {
      _successMessage = result['message'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Signup failed';
      notifyListeners();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  //  LOGIN
  // ════════════════════════════════════════════════════════

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await AuthService.login(
      email: email,
      password: password,
    );

    _setLoading(false);

    if (result['success'] == true) {
      // Persist token & user info
      await SecureStorage.saveToken(result['token']);
      await SecureStorage.saveUserInfo(
        userId: result['user_id'],
        userName: result['user_name'],
        userType: result['user_type'],
      );

      _isAuthenticated = true;
      _userType = result['user_type'];
      _userName = result['user_name'];

      // Register FCM token + start caregiver alarm listener if applicable
      FcmService.init(userType: result['user_type']);

      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  //  PASSWORD RESET
  // ════════════════════════════════════════════════════════

  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    final result = await AuthService.requestPasswordReset(email: email);

    _setLoading(false);

    if (result['success'] == true) {
      _successMessage = result['message'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to send reset OTP';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    final result = await AuthService.resetPassword(
      email: email,
      otpCode: otpCode,
      newPassword: newPassword,
    );

    _setLoading(false);

    if (result['success'] == true) {
      _successMessage = result['message'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Password reset failed';
      notifyListeners();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  //  LOGOUT
  // ════════════════════════════════════════════════════════

  Future<void> logout() async {
    await SecureStorage.clearAll();
    _isAuthenticated = false;
    _userType = null;
    _userName = null;
    _errorMessage = null;
    _successMessage = null;
    signupEmail = null;
    notifyListeners();
  }
}
