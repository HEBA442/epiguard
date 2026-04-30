import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../core/eeg_buffer.dart';
import '../../core/api_endpoints.dart';
import '../../core/secure_storage.dart';
import '../alert/location_service.dart';

enum DetectionStatus { idle, processing, normal, seizure, error, skipped }

class DetectionResult {
  final DetectionStatus status;
  final double? probability;
  final int? eventId;
  final DateTime timestamp;
  final String? errorMessage;

  DetectionResult({
    required this.status,
    this.probability,
    this.eventId,
    required this.timestamp,
    this.errorMessage,
  });

  bool get isSeizure => status == DetectionStatus.seizure;

  @override
  String toString() {
    switch (status) {
      case DetectionStatus.seizure:
        return 'SEIZURE DETECTED (${(probability! * 100).toStringAsFixed(1)}%)';
      case DetectionStatus.normal:
        return 'Normal (${(probability! * 100).toStringAsFixed(1)}%)';
      case DetectionStatus.skipped:
        return 'Window skipped (artefact)';
      case DetectionStatus.error:
        return 'Error: $errorMessage';
      default:
        return status.name;
    }
  }
}

class SeizureDetectionService {
  final StreamController<DetectionResult> _resultController =
      StreamController.broadcast();

  Stream<DetectionResult> get resultStream => _resultController.stream;

  bool _isProcessing = false;

  // ─── MAIN ENTRY POINT ──────────────────────────────────────
  // Called every time EegBuffer emits a completed window
  Future<void> processWindow(EegWindow window) async {
    // Skip if previous window is still being processed
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Step 1: Extract features from the window
      final features = _extractFeatures(window);

      // Step 2: Send to Flask
      final result = await _sendToFlask(features, window.timestamp);

      // Step 3: Emit result
      _resultController.add(result);
    } catch (e) {
      _resultController.add(DetectionResult(
        status: DetectionStatus.error,
        timestamp: DateTime.now(),
        errorMessage: e.toString(),
      ));
    } finally {
      _isProcessing = false;
    }
  }

  // ─── FEATURE EXTRACTION ────────────────────────────────────
  // Mirrors exactly what was done in Colab training:
  // Delta, Theta, Alpha, Beta powers + Delta/Alpha, Delta/Beta ratios
  // For each of 4 channels = 24 features total
  Map<String, double> _extractFeatures(EegWindow window) {
    final Map<String, double> features = {};

    // Channel names must match training column order exactly
    final channels = {
      'T7-P7':  window.tp9,
      'FP1-F7': window.af7,
      'FP2-F8': window.af8,
      'T8-P8':  window.tp10,
    };

    for (final entry in channels.entries) {
      final chName = entry.key;
      final samples = entry.value;

      // Compute band powers via FFT
      final powers = _computeBandPowers(samples);

      features['${chName}_delta'] = powers['delta']!;
      features['${chName}_theta'] = powers['theta']!;
      features['${chName}_alpha'] = powers['alpha']!;
      features['${chName}_beta']  = powers['beta']!;

      // Ratio features — same epsilon as training (1e-10)
      features['${chName}_delta_alpha_ratio'] =
          powers['delta']! / (powers['alpha']! + 1e-10);
      features['${chName}_delta_beta_ratio'] =
          powers['delta']! / (powers['beta']!  + 1e-10);
    }

    return features;
  }

  // ─── FFT + BAND POWER ──────────────────────────────────────
  // Mirrors scipy.signal.welch with nperseg=512 from Colab
  Map<String, double> _computeBandPowers(List<double> samples) {
    const int fs = 256;
    final int n = samples.length; // 512

    // Apply Hanning window to reduce spectral leakage
    final windowed = List<double>.generate(
        n, (i) => samples[i] * 0.5 * (1 - _cos(2 * 3.141592653589793 * i / (n - 1))));

    // Compute FFT
    final fftResult = _computeFFT(windowed);

    // Compute power spectrum (one-sided)
    final int halfN = n ~/ 2 + 1;
    final List<double> psd = List.generate(halfN, (i) {
      final power = fftResult[i][0] * fftResult[i][0] +
                    fftResult[i][1] * fftResult[i][1];
      // Normalise: multiply by 2 for one-sided (except DC and Nyquist)
      return (i == 0 || i == halfN - 1)
          ? power / (fs * n)
          : 2.0 * power / (fs * n);
    });

    // Frequency resolution
    final double freqRes = fs / n; // 0.5 Hz per bin

    // Integrate each band using trapezoidal rule
    return {
      'delta': _bandPower(psd, freqRes, 0.5, 4.0),
      'theta': _bandPower(psd, freqRes, 4.0, 8.0),
      'alpha': _bandPower(psd, freqRes, 8.0, 13.0),
      'beta':  _bandPower(psd, freqRes, 13.0, 30.0),
    };
  }

  // Trapezoidal integration over a frequency band
  double _bandPower(List<double> psd, double freqRes, double fMin, double fMax) {
    final int iMin = (fMin / freqRes).floor();
    final int iMax = (fMax / freqRes).ceil().clamp(0, psd.length - 1);

    double power = 0.0;
    for (int i = iMin; i < iMax; i++) {
      power += (psd[i] + psd[i + 1]) * 0.5 * freqRes;
    }
    return power;
  }

  // ─── FFT (Cooley-Tukey, no external package needed) ────────
  // Returns list of [real, imaginary] pairs
  List<List<double>> _computeFFT(List<double> signal) {
    final int n = signal.length;
    final List<List<double>> result =
        List.generate(n, (i) => [signal[i], 0.0]);

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) {
        final tmp = result[i];
        result[i] = result[j];
        result[j] = tmp;
      }
    }

    // FFT butterfly operations
    for (int len = 2; len <= n; len <<= 1) {
      final double angle = -2 * 3.141592653589793 / len;
      final double wRe = _cos(angle);
      final double wIm = _sin(angle);

      for (int i = 0; i < n; i += len) {
        double curRe = 1.0, curIm = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final uRe = result[i + k][0];
          final uIm = result[i + k][1];
          final vRe = result[i + k + len ~/ 2][0] * curRe -
                      result[i + k + len ~/ 2][1] * curIm;
          final vIm = result[i + k + len ~/ 2][0] * curIm +
                      result[i + k + len ~/ 2][1] * curRe;

          result[i + k]           = [uRe + vRe, uIm + vIm];
          result[i + k + len ~/ 2] = [uRe - vRe, uIm - vIm];

          final newRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = newRe;
        }
      }
    }

    return result;
  }

  // ─── SEND TO FLASK ─────────────────────────────────────────
  Future<DetectionResult> _sendToFlask(
      Map<String, double> features, DateTime windowTime) async {
    try {
      // Read JWT token from secure storage
      final token = await SecureStorage.getToken();
      if (token == null) {
        return DetectionResult(
          status: DetectionStatus.error,
          timestamp: windowTime,
          errorMessage: 'Not authenticated — no token found',
        );
      }

      // Fetch GPS
      final position = await LocationService.getCurrentLocation();

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.predict),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'features': features,
              'latitude': position?.latitude,
              'longitude': position?.longitude,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle artefact flag from Flask
        if (data['skip'] == true) {
          return DetectionResult(
            status: DetectionStatus.skipped,
            timestamp: windowTime,
          );
        }

        final int prediction  = data['prediction'];
        final double probability = (data['probability'] as num).toDouble();
        final int? eventId = data['event_id'] as int?;

        return DetectionResult(
          status: prediction == 1
              ? DetectionStatus.seizure
              : DetectionStatus.normal,
          probability: probability,
          eventId: eventId,
          timestamp: windowTime,
        );
      } else {
        return DetectionResult(
          status: DetectionStatus.error,
          timestamp: windowTime,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
    } on TimeoutException {
      return DetectionResult(
        status: DetectionStatus.error,
        timestamp: windowTime,
        errorMessage: 'Flask timeout — is the server running?',
      );
    } catch (e) {
      return DetectionResult(
        status: DetectionStatus.error,
        timestamp: windowTime,
        errorMessage: e.toString(),
      );
    }
  }

  // ─── MATH HELPERS ──────────────────────────────────────────
  double _cos(double x) => _taylorCos(x);
  double _sin(double x) => _taylorCos(x - 3.141592653589793 / 2);

  double _taylorCos(double x) {
    // Normalize x to [-pi, pi]
    const double pi = 3.141592653589793;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    // Taylor series approximation — accurate enough for FFT
    final double x2 = x * x;
    return 1 - x2/2 + x2*x2/24 - x2*x2*x2/720 + x2*x2*x2*x2/40320;
  }

  void dispose() {
    _resultController.close();
  }
}