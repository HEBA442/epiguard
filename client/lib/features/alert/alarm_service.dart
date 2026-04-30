import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the seizure alarm — plays a looping alert sound via a
/// foreground service so it continues even when the screen is locked.
class AlarmService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;

  // ─── FOREGROUND TASK SETUP ───────────────────────────────
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'epiguard_alarm',
        channelName: 'EpiGuard Seizure Alert',
        channelDescription: 'Keeps the seizure alarm running in the background',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        playSound: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  // ─── START ALARM ─────────────────────────────────────────
  /// Call this when a seizure is detected (0→1 transition only).
  static Future<void> startAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;

    // Start foreground service so OS won't kill the app
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🚨 SEIZURE DETECTED',
      notificationText: 'EpiGuard is alerting your caregiver. Tap to open.',
    );

    // Play looping alarm sound from assets
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/alarm.mp3'), volume: 1.0);
  }

  // ─── STOP ALARM ──────────────────────────────────────────
  /// Call this when the user dismisses the alert OR seizure ends naturally.
  static Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    _isPlaying = false;

    await _player.stop();
    await FlutterForegroundTask.stopService();
  }

  static bool get isPlaying => _isPlaying;
}
