import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/ble_constants.dart';

enum MuseConnectionState { disconnected, scanning, connecting, connected }

class MuseEegSample {
  final double tp9, af7, af8, tp10;
  final DateTime timestamp;

  MuseEegSample({
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
    required this.timestamp,
  });

  @override
  String toString() =>
      'TP9: ${tp9.toStringAsFixed(2)} | AF7: ${af7.toStringAsFixed(2)} | '
      'AF8: ${af8.toStringAsFixed(2)} | TP10: ${tp10.toStringAsFixed(2)}';
}

class MuseBleService {
  BluetoothDevice? _device;
  final StreamController<MuseEegSample> _eegController =
      StreamController.broadcast();
  final StreamController<MuseConnectionState> _stateController =
      StreamController.broadcast();

  // Latest raw values per channel
  double _tp9 = 0, _af7 = 0, _af8 = 0, _tp10 = 0;

  Stream<MuseEegSample> get eegStream => _eegController.stream;
  Stream<MuseConnectionState> get stateStream => _stateController.stream;

  // ─── SCAN & CONNECT ──────────────────────────────────────────
  Future<void> connect() async {
    _stateController.add(MuseConnectionState.scanning);

    // Start scan
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await for (final results in FlutterBluePlus.scanResults) {
      for (final result in results) {
        if (result.device.platformName.contains(BleConstants.museDeviceName)) {
          await FlutterBluePlus.stopScan();
          _device = result.device;
          await _connectToDevice();
          return;
        }
      }
    }

    // If we reach here, scan finished without finding Muse
    _stateController.add(MuseConnectionState.disconnected);
  }

  Future<void> _connectToDevice() async {
    if (_device == null) return;
    _stateController.add(MuseConnectionState.connecting);

    try {
      await _device!.connect(timeout: const Duration(seconds: 15));
      _stateController.add(MuseConnectionState.connected);

      // Listen for disconnection
      _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _stateController.add(MuseConnectionState.disconnected);
        }
      });

      await _discoverAndSubscribe();
    } catch (e) {
      _stateController.add(MuseConnectionState.disconnected);
    }
  }

  // ─── DISCOVER SERVICES & SUBSCRIBE ──────────────────────────
  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.museServiceUuid) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          await _subscribeToChar(char, uuid);
        }

        // Send start streaming command to control characteristic
        await _sendStartCommand(service);
        break;
      }
    }
  }

  Future<void> _subscribeToChar(
    BluetoothCharacteristic char,
    String uuid,
  ) async {
    if (!char.properties.notify) return;

    await char.setNotifyValue(true);

    char.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      final value = _parseMuseEeg(Uint8List.fromList(data));

      // Update the correct channel
      if (uuid == BleConstants.museEegCharUuid) {
        _tp9 = value;
      } else if (uuid == BleConstants.museEegAf7CharUuid) {
        _af7 = value;
      } else if (uuid == BleConstants.museEegAf8CharUuid) {
        _af8 = value;
      } else if (uuid == BleConstants.museEegTp10CharUuid) {
        _tp10 = value;
      } else {
        return; // ignore AUX
      }

      // Emit a combined sample every time any channel updates
      _eegController.add(
        MuseEegSample(
          tp9: _tp9,
          af7: _af7,
          af8: _af8,
          tp10: _tp10,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _sendStartCommand(BluetoothService service) async {
    for (final char in service.characteristics) {
      if (char.uuid.toString().toLowerCase() ==
          BleConstants.museControlCharUuid) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          // Muse expects the command as encoded bytes
          final cmd = _encodeMuseCommand(BleConstants.museStartCommand);
          await char.write(
            cmd,
            withoutResponse: char.properties.writeWithoutResponse,
          );
        }
        break;
      }
    }
  }

  // ─── MUSE PACKET PARSING ─────────────────────────────────────
  // Muse sends 12-byte packets: 2 bytes header + 5x 10-bit EEG samples
  // We extract the first sample and convert to microvolts
  double _parseMuseEeg(Uint8List data) {
    if (data.length < 4) return 0.0;

    // Unpack first 10-bit sample from bytes 2-3
    final int raw = ((data[2] & 0x3F) << 4) | ((data[3] >> 4) & 0x0F);

    // Convert to microvolts: Muse uses 0.48828125 µV per bit, offset at 2048
    const double scale = 0.48828125;
    const int offset = 2048;
    return (raw - offset) * scale;
  }

  // Muse command encoding: wraps command char in SLIP-style framing
  List<int> _encodeMuseCommand(String cmd) {
    return [0x02, ...cmd.codeUnits, 0x0A, 0x03];
  }

  // ─── DISCONNECT ──────────────────────────────────────────────
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _stateController.add(MuseConnectionState.disconnected);
  }

  void dispose() {
    _eegController.close();
    _stateController.close();
  }
}
