import 'dart:async';
import '../features/eeg/muse_ble_service.dart';
import 'ble_constants.dart';

class EegWindow {
  // Each channel has exactly 512 samples
  final List<double> tp9;
  final List<double> af7;
  final List<double> af8;
  final List<double> tp10;
  final DateTime timestamp;

  EegWindow({
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
    required this.timestamp,
  });

  // Returns as 2D list in training channel order:
  // [T7-P7/TP9, FP1-F7/AF7, FP2-F8/AF8, T8-P8/TP10]
  List<List<double>> toTrainingOrder() => [tp9, af7, af8, tp10];
}

class EegBuffer {
  // Internal sample lists per channel
  final List<double> _tp9  = [];
  final List<double> _af7  = [];
  final List<double> _af8  = [];
  final List<double> _tp10 = [];

  // Fires every time a full 512-sample window is ready
  final StreamController<EegWindow> _windowController =
      StreamController.broadcast();

  Stream<EegWindow> get windowStream => _windowController.stream;

  // Stats — useful for UI/debugging
  int _totalWindowsEmitted = 0;
  int _droppedSamples = 0;
  int get totalWindowsEmitted => _totalWindowsEmitted;
  int get droppedSamples => _droppedSamples;

  // ─── ADD SAMPLE ────────────────────────────────────────────
  // Called every time MuseBleService emits a new EegSample
  void addSample(MuseEegSample sample) {
    // Artefact rejection — skip samples with extreme amplitude
    if (_isArtefact(sample)) {
      _droppedSamples++;
      return;
    }

    _tp9.add(sample.tp9);
    _af7.add(sample.af7);
    _af8.add(sample.af8);
    _tp10.add(sample.tp10);

    // Once all channels have 512 samples, emit window and reset
    if (_tp9.length >= BleConstants.windowSamples) {
      _emitWindow();
    }
  }

  // ─── EMIT WINDOW ───────────────────────────────────────────
  void _emitWindow() {
    final window = EegWindow(
      tp9:  List.from(_tp9.take(BleConstants.windowSamples)),
      af7:  List.from(_af7.take(BleConstants.windowSamples)),
      af8:  List.from(_af8.take(BleConstants.windowSamples)),
      tp10: List.from(_tp10.take(BleConstants.windowSamples)),
      timestamp: DateTime.now(),
    );

    _windowController.add(window);
    _totalWindowsEmitted++;

    // Reset all buffers
    _tp9.clear();
    _af7.clear();
    _af8.clear();
    _tp10.clear();
  }

  // ─── ARTEFACT REJECTION ────────────────────────────────────
  // If any channel exceeds ±200 µV it's likely movement noise
  bool _isArtefact(MuseEegSample sample) {
    const double threshold = 200.0;
    return sample.tp9.abs()  > threshold ||
           sample.af7.abs()  > threshold ||
           sample.af8.abs()  > threshold ||
           sample.tp10.abs() > threshold;
  }

  // ─── RESET ─────────────────────────────────────────────────
  // Call this when Muse disconnects to avoid stale partial windows
  void reset() {
    _tp9.clear();
    _af7.clear();
    _af8.clear();
    _tp10.clear();
  }

  void dispose() {
    _windowController.close();
  }
}