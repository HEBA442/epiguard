import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/ble_constants.dart';

enum WatchConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  unsupported,
}

class WatchReading {
  final int heartRate;
  final int? systolic; // BP — null if watch doesn't support it
  final int? diastolic;
  final DateTime timestamp;

  WatchReading({
    required this.heartRate,
    this.systolic,
    this.diastolic,
    required this.timestamp,
  });

  @override
  String toString() {
    final bp = systolic != null ? ' | BP: $systolic/$diastolic' : '';
    return 'HR: $heartRate bpm$bp';
  }
}

class WatchBleService {
  BluetoothDevice? _device;
  final StreamController<WatchReading> _readingController =
      StreamController.broadcast();
  final StreamController<WatchConnectionState> _stateController =
      StreamController.broadcast();

  int _heartRate = 0;
  int? _systolic, _diastolic;

  Stream<WatchReading> get readingStream => _readingController.stream;
  Stream<WatchConnectionState> get stateStream => _stateController.stream;

  // ─── SCAN & CONNECT ──────────────────────────────────────────
  Future<void> connect() async {
    _stateController.add(WatchConnectionState.scanning);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await for (final results in FlutterBluePlus.scanResults) {
      for (final result in results) {
        if (result.device.platformName.toLowerCase().contains(
          BleConstants.watchDeviceName.toLowerCase(),
        )) {
          await FlutterBluePlus.stopScan();
          _device = result.device;
          await _connectToDevice();
          return;
        }
      }
    }

    _stateController.add(WatchConnectionState.disconnected);
  }

  Future<void> _connectToDevice() async {
    if (_device == null) return;
    _stateController.add(WatchConnectionState.connecting);

    try {
      await _device!.connect(timeout: const Duration(seconds: 15));
      _stateController.add(WatchConnectionState.connected);

      _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _stateController.add(WatchConnectionState.disconnected);
        }
      });

      await _discoverAndSubscribe();
    } catch (e) {
      _stateController.add(WatchConnectionState.disconnected);
    }
  }

  // ─── DISCOVER SERVICES & SUBSCRIBE ──────────────────────────
  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;
    bool hrFound = false;

    final services = await _device!.discoverServices();

    for (final service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();

      // Heart rate service
      if (serviceUuid == BleConstants.watchHrServiceUuid) {
        hrFound = true;
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              BleConstants.watchHrCharUuid) {
            await _subscribeHr(char);
          }
        }
      }

      // Blood pressure service
      if (serviceUuid == BleConstants.watchBpServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              BleConstants.watchBpCharUuid) {
            await _subscribeBp(char);
          }
        }
      }
    }

    if (!hrFound) {
      // Standard GATT HR not found — watch may use proprietary protocol
      _stateController.add(WatchConnectionState.unsupported);
    }
  }

  Future<void> _subscribeHr(BluetoothCharacteristic char) async {
    if (!char.properties.notify && !char.properties.indicate) return;
    await char.setNotifyValue(true);

    char.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      _heartRate = _parseHeartRate(data);
      _emitReading();
    });
  }

  Future<void> _subscribeBp(BluetoothCharacteristic char) async {
    if (!char.properties.indicate) return;
    await char.setNotifyValue(true);

    char.lastValueStream.listen((data) {
      if (data.length < 3) return;
      final bp = _parseBloodPressure(data);
      _systolic = bp[0];
      _diastolic = bp[1];
      _emitReading();
    });
  }

  // ─── PARSING ─────────────────────────────────────────────────
  // Standard GATT HR measurement format (0x2A37)
  // Byte 0: flags, Byte 1: HR value (if flag bit0 = 0, else bytes 1-2)
  int _parseHeartRate(List<int> data) {
    final flags = data[0];
    if ((flags & 0x01) == 0) {
      return data[1]; // 8-bit HR value
    } else {
      return data[1] | (data[2] << 8); // 16-bit HR value
    }
  }

  // Standard GATT BP measurement format (0x2A35)
  List<int> _parseBloodPressure(List<int> data) {
    // Bytes 1-2: systolic, Bytes 3-4: diastolic (SFLOAT format, simplified)
    final systolic = data[1] | (data[2] << 8);
    final diastolic = data[3] | (data[4] << 8);
    return [systolic, diastolic];
  }

  void _emitReading() {
    _readingController.add(
      WatchReading(
        heartRate: _heartRate,
        systolic: _systolic,
        diastolic: _diastolic,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ─── DISCONNECT ──────────────────────────────────────────────
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _stateController.add(WatchConnectionState.disconnected);
  }

  void dispose() {
    _readingController.close();
    _stateController.close();
  }
}
