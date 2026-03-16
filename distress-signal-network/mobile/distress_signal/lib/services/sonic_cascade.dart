import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

class SonicCascade {
  static final Set<int> _seenIds = <int>{};
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  /// Build a 14-byte SOS payload:
  /// [0-1] id (uint16), [2] hop (uint8), [3-6] lat (float32),
  /// [7-10] lng (float32), [10-13] timestamp (uint32)
  static Uint8List _buildPayload(int id, int hop, double lat, double lng) {
    final ByteData d = ByteData(14);
    d.setUint16(0, id, Endian.big);
    d.setUint8(2, hop);
    d.setFloat32(3, lat, Endian.big);
    d.setFloat32(7, lng, Endian.big);
    d.setUint32(10, DateTime.now().millisecondsSinceEpoch ~/ 1000, Endian.big);
    return d.buffer.asUint8List();
  }

  // ══════════════════════════════════════════════════════════════
  // PHONE A (OFFLINE VICTIM): True BLE Peripheral Advertising
  // Broadcasts SOS coordinates as Manufacturer Data (0xFFFF)
  // so any nearby phone scanning can pick it up without pairing.
  // ══════════════════════════════════════════════════════════════
  static Future<void> advertiseBleSos(double lat, double lng) async {
    // Request all BLE permissions
    await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    final id = Random().nextInt(65535);
    final payload = _buildPayload(id, 0, lat, lng);
    final hexPayload = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    debugPrint('[BLE TX] Starting TRUE BLE Advertisement id=$id lat=$lat lng=$lng');
    debugPrint('[BLE TX] Payload (${ payload.length } bytes): $hexPayload');

    try {
      // Check if this device supports peripheral mode
      final isSupported = await _peripheral.isSupported;
      if (!isSupported) {
        debugPrint('[BLE TX] ERROR: This device does not support BLE peripheral mode');
        return;
      }

      // Build manufacturer data: 0xFF 0xFF (company ID) + payload bytes
      // This matches what startBleRelay() looks for in manufacturerData[0xFFFF]
      final List<int> mfrData = [0xFF, 0xFF, ...payload];

      final AdvertiseData advertiseData = AdvertiseData(
        includeDeviceName: false,
        manufacturerId: 0xFFFF,
        manufacturerData: Uint8List.fromList(payload),
      );

      final AdvertiseSettings advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        connectable: false,
        timeout: 30000,  // 30 seconds
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      );

      // Start broadcasting!
      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      debugPrint('[BLE TX] ✓ BROADCASTING ACTIVE (id=$id) for 30 seconds');
      debugPrint('[BLE TX] Any phone scanning will pick up mfr data 0xFFFF');

      // Keep advertising for 30 seconds then stop
      await Future.delayed(const Duration(seconds: 30));

      final isAdvertising = await _peripheral.isAdvertising;
      if (isAdvertising) {
        await _peripheral.stop();
      }
      debugPrint('[BLE TX] Broadcast STOPPED after 30s.');
    } catch (e) {
      debugPrint('[BLE TX] CRITICAL ERROR: $e');
      // Try to stop advertising if it was started
      try {
        await _peripheral.stop();
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PHONE B/C (ONLINE NODE): Passive BLE Scanner / Relay Receiver
  // Listens for manufacturer data 0xFFFF in BLE advertisements,
  // extracts the SOS payload, and relays it to the backend.
  // ══════════════════════════════════════════════════════════════
  static void startBleRelay(Function(double lat, double lng, int hop, int id) onRelayRequest) {
    Permission.bluetoothScan.request();
    Permission.location.request();

    // Listen to scan results
    FlutterBluePlus.onScanResults.listen((results) async {
      for (ScanResult r in results) {
        // Look for our manufacturer ID (0xFFFF = 65535)
        final mfr = r.advertisementData.manufacturerData[0xFFFF];
        if (mfr == null || mfr.length < 11) continue;

        final bd = ByteData.sublistView(Uint8List.fromList(mfr));
        final id = bd.getUint16(0, Endian.big);

        // Dedup: skip if we've already relayed this SOS
        if (_seenIds.contains(id)) continue;
        _seenIds.add(id);

        final hop = bd.getUint8(2);
        final lat = bd.getFloat32(3, Endian.big);
        final lng = bd.getFloat32(7, Endian.big);

        debugPrint('[BLE RX] ✓ SIGNAL DETECTED! ID=$id Hop=$hop lat=$lat lng=$lng');

        // Execute the relay callback (Backend POST)
        onRelayRequest(lat, lng, hop, id);
      }
    });

    // Start continuous scanning (1 hour timeout)
    FlutterBluePlus.startScan(timeout: const Duration(hours: 1));
    debugPrint('[BLE] Mesh Scanner Active — listening for 0xFFFF manufacturer data');
  }
}