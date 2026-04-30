class BleConstants {
  // ─── MUSE GEN 2 ───────────────────────────────────────────────
  // Muse uses a proprietary BLE service
  static const String museServiceUuid = '0000fe8d-0000-1000-8000-00805f9b34fb';
  static const String museControlCharUuid =
      '273e0001-4c4d-454d-96be-f03bac821358'; // send commands
  static const String museEegCharUuid =
      '273e0003-4c4d-454d-96be-f03bac821358'; // TP9
  static const String museEegAf7CharUuid =
      '273e0004-4c4d-454d-96be-f03bac821358'; // AF7
  static const String museEegAf8CharUuid =
      '273e0005-4c4d-454d-96be-f03bac821358'; // AF8
  static const String museEegTp10CharUuid =
      '273e0006-4c4d-454d-96be-f03bac821358'; // TP10
  static const String museEegRightAuxCharUuid =
      '273e0007-4c4d-454d-96be-f03bac821358'; // AUX (ignore)

  // Muse channel order → maps to training order
  // Muse:     TP9,    AF7,    AF8,    TP10
  // Training: T7-P7, FP1-F7, FP2-F8, T8-P8
  static const List<String> museChannelOrder = ['TP9', 'AF7', 'AF8', 'TP10'];
  static const List<String> trainingChannelOrder = [
    'T7-P7',
    'FP1-F7',
    'FP2-F8',
    'T8-P8',
  ];

  // Muse sampling rate
  static const int museSamplingRate = 256; // Hz
  static const int windowSamples = 512; // 2 seconds worth
  static const String museDeviceName = 'Muse';

  // Muse start/stop streaming commands
  static const String museStartCommand = 'd';
  static const String museStopCommand = 'h';

  // ─── SMARTWATCH (Standard GATT — fallback to proprietary) ──────
  static const String watchHrServiceUuid =
      '0000180d-0000-1000-8000-00805f9b34fb';
  static const String watchHrCharUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  // BP — standard GATT (not all watches support this)
  static const String watchBpServiceUuid =
      '00001810-0000-1000-8000-00805f9b34fb';
  static const String watchBpCharUuid = '00002a35-0000-1000-8000-00805f9b34fb';
  static const String watchDeviceName =
      'Watch'; // update once you know the model
}
