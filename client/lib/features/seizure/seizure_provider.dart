import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/eeg_buffer.dart';
import '../../features/eeg/muse_ble_service.dart';
import '../../features/eeg/watch_ble_service.dart';
import '../../features/alert/location_service.dart';
import 'seizure_detection_service.dart';

enum MonitoringStatus { idle, monitoring, paused }

class SeizureEvent {
  final DateTime timestamp;
  final double probability;

  SeizureEvent({required this.timestamp, required this.probability});

  String get timeString =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}

class SeizureProvider extends ChangeNotifier {
  // ─── SERVICES ────────────────────────────────────────────
  final MuseBleService _muse        = MuseBleService();
  final WatchBleService _watch      = WatchBleService();
  final EegBuffer _buffer           = EegBuffer();
  final SeizureDetectionService _detector = SeizureDetectionService();

  // ─── STATE ───────────────────────────────────────────────
  MuseConnectionState  _museState  = MuseConnectionState.disconnected;
  WatchConnectionState _watchState = WatchConnectionState.disconnected;
  MonitoringStatus     _monitoring = MonitoringStatus.idle;
  DetectionResult?     _lastResult;
  WatchReading?        _lastWatchReading;

  bool _seizureActive = false;    // true while alert is showing
  bool _wasSeizureLastWindow = false;
  int  _consecutiveNormalCount = 0;
  static const int _recoveryThreshold = 3;

  Position? _lastSeizureLocation;  // GPS position at time of seizure
  Position? get lastSeizureLocation => _lastSeizureLocation;

  final List<SeizureEvent> _seizureHistory = [];
  final List<StreamSubscription> _subs = [];

  // ─── GETTERS ─────────────────────────────────────────────
  MuseConnectionState  get museState       => _museState;
  WatchConnectionState get watchState      => _watchState;
  MonitoringStatus     get monitoringStatus => _monitoring;
  DetectionResult?     get lastResult      => _lastResult;
  WatchReading?        get lastWatchReading => _lastWatchReading;
  bool                 get seizureActive   => _seizureActive;
  List<SeizureEvent>   get seizureHistory  => List.unmodifiable(_seizureHistory);
  bool get museConnected => _museState == MuseConnectionState.connected;
  bool get watchConnected => _watchState == WatchConnectionState.connected;

  // Buffer stats
  int get windowsProcessed => _buffer.totalWindowsEmitted;
  int get droppedSamples   => _buffer.droppedSamples;

  // ─── INIT ────────────────────────────────────────────────
  SeizureProvider() {
    _wireStreams();
  }

  void _wireStreams() {
    // Muse connection state
    _subs.add(_muse.stateStream.listen((state) {
      _museState = state;
      if (state == MuseConnectionState.disconnected) {
        _buffer.reset();
        _monitoring = MonitoringStatus.idle;
      }
      notifyListeners();
    }));

    // EEG samples → buffer
    _subs.add(_muse.eegStream.listen((sample) {
      if (_monitoring == MonitoringStatus.monitoring) {
        _buffer.addSample(sample);
      }
    }));

    // Buffer windows → detection service
    _subs.add(_buffer.windowStream.listen((window) async {
      await _detector.processWindow(window);
    }));

    // Detection results
    _subs.add(_detector.resultStream.listen((result) {
      _lastResult = result;

      if (result.isSeizure) {
        _consecutiveNormalCount = 0; // reset recovery counter

        // Only fire alert on 0→1 transition (seizure START)
        if (!_wasSeizureLastWindow) {
          _seizureActive = true;
          _seizureHistory.insert(0, SeizureEvent(
            timestamp:   result.timestamp,
            probability: result.probability!,
          ));
          if (_seizureHistory.length > 50) _seizureHistory.removeLast();

          // Start GPS location fetch (sent to Flask on next predict window)
          LocationService.getCurrentLocation().then((pos) {
            _lastSeizureLocation = pos;
            notifyListeners();
          });
        }

        _wasSeizureLastWindow = true;

      } else if (result.status == DetectionStatus.normal) {
        _consecutiveNormalCount++;

        // Seizure considered ended after N consecutive normal windows
        if (_wasSeizureLastWindow && _consecutiveNormalCount >= _recoveryThreshold) {
          _wasSeizureLastWindow = false;
          _consecutiveNormalCount = 0;
          // Alarm is on caregiver's phone — nothing to stop here
        }
      }

      notifyListeners();
    }));

    // Watch connection state
    _subs.add(_watch.stateStream.listen((state) {
      _watchState = state;
      notifyListeners();
    }));

    // Watch readings
    _subs.add(_watch.readingStream.listen((reading) {
      _lastWatchReading = reading;
      notifyListeners();
    }));
  }

  // ─── MUSE ACTIONS ────────────────────────────────────────
  Future<void> connectMuse() async {
    await _muse.connect();
  }

  Future<void> disconnectMuse() async {
    stopMonitoring();
    await _muse.disconnect();
  }

  // ─── WATCH ACTIONS ───────────────────────────────────────
  Future<void> connectWatch() async {
    await _watch.connect();
  }

  Future<void> disconnectWatch() async {
    await _watch.disconnect();
  }

  // ─── MONITORING ACTIONS ──────────────────────────────────
  void startMonitoring() {
    if (!museConnected) return;
    _buffer.reset();
    _monitoring = MonitoringStatus.monitoring;
    notifyListeners();
  }

  void stopMonitoring() {
    _monitoring = MonitoringStatus.paused;
    _buffer.reset();
    notifyListeners();
  }

  void dismissSeizureAlert() {
    _seizureActive = false;
    notifyListeners();
  }

  void clearHistory() {
    _seizureHistory.clear();
    notifyListeners();
  }

  // ─── DISPOSE ─────────────────────────────────────────────
  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _muse.dispose();
    _watch.dispose();
    _buffer.dispose();
    _detector.dispose();
    super.dispose();
  }
}