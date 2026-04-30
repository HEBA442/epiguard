import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../core/api_endpoints.dart';
import '../../core/secure_storage.dart';
import 'alarm_service.dart';

/// Handles Firebase Cloud Messaging for caregiver push alerts.
/// - Registers the device token with the Flask backend after login.
/// - Listens for incoming seizure alerts (foreground + background).
/// - Triggers AlarmService on the CAREGIVER's phone when a seizure fires.
class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ─── INIT (call once after Firebase.initializeApp) ───────────
  static Future<void> init({required String userType}) async {
    // Request permission (iOS + Android 13+)
    await _fcm.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );

    // Register the token with Flask
    await registerToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((_) => registerToken());

    // Only caregivers receive and trigger the alarm
    if (userType == 'caregiver') {
      _setupForegroundListener();
    }
  }

  // ─── TOKEN REGISTRATION ───────────────────────────────────────
  static Future<void> registerToken() async {
    try {
      final token = await SecureStorage.getToken(); // JWT
      if (token == null) return;

      final fcmToken = await _fcm.getToken();
      if (fcmToken == null) return;

      await http.post(
        Uri.parse(ApiEndpoints.registerFcmToken),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {
      // Silent — token registration failing should not crash the app
    }
  }

  // ─── FOREGROUND LISTENER (app is open) ───────────────────────
  static void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleSeizureMessage(message.data);
    });
  }

  // ─── BACKGROUND / TERMINATED HANDLER ─────────────────────────
  /// Must be a top-level function (registered in main.dart).
  /// Triggers the AlarmService when a seizure alert arrives in background.
  static Future<void> backgroundHandler(RemoteMessage message) async {
    _handleSeizureMessage(message.data);
  }

  // ─── CORE HANDLER ─────────────────────────────────────────────
  static void _handleSeizureMessage(Map<String, dynamic> data) {
    if (data['type'] == 'seizure_alert') {
      // Trigger the "Air Strike" alarm on the caregiver's phone
      AlarmService.startAlarm();
    }
  }

  // ─── STOP ALARM (called from dismiss button) ──────────────────
  static Future<void> stopAlarm() async {
    await AlarmService.stopAlarm();
  }
}
