import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles secure persistence of JWT token and user metadata.
/// Uses encrypted storage so tokens are safe even on rooted devices.
class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // ── Keys ────────────────────────────────────────────────
  static const _tokenKey   = 'auth_token';
  static const _userIdKey  = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userTypeKey = 'user_type';

  // ── Token ───────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // ── User Info ───────────────────────────────────────────

  static Future<void> saveUserInfo({
    required int userId,
    required String userName,
    required String userType,
  }) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _userNameKey, value: userName);
    await _storage.write(key: _userTypeKey, value: userType);
  }

  static Future<String?> getUserType() async {
    return await _storage.read(key: _userTypeKey);
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  static Future<int?> getUserId() async {
    final id = await _storage.read(key: _userIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  // ── Logout (clear everything) ──────────────────────────

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
