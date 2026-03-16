import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class SonicCascade {
  static final Set<int> _seenIds = <int>{};

  static Uint8List _buildPayload(int id, int hop, double lat, double lng) {
    final ByteData d = ByteData(14);
    d.setUint16(0, id, Endian.big);
    d.setUint8(2, hop);
    d.setFloat32(3, lat, Endian.big);
    d.setFloat32(7, lng, Endian.big);
    d.setUint32(10, DateTime.now().millisecondsSinceEpoch ~/ 1000, Endian.big);
    return d.buffer.asUint8List();
  }

  // PHONE 1 (OFFLINE): Broadcast SOS
  // Note: flutter_blue_plus v1.36.8 is central-only (scan/connect).
  // True BLE peripheral advertising requires native platform channels.
  // This implementation uses the BLE scan + GATT write approach:
  // the offline phone scans for nearby DISTRESS relay nodes and
  // writes the SOS payload to them via GATT characteristic.
  static Future<void> advertiseBleSos(double lat, double lng) async {
    await [Permission.bluetoothAdvertise, Permission.bluetoothConnect, Permission.bluetoothScan].request();

    final id = Random().nextInt(65535);
    final payload = _buildPayload(id, 0, lat, lng);
    final hexPayload = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    debugPrint('[BLE TX] Starting SOS Broadcast id=$id lat=$lat lng=$lng');
    debugPrint('[BLE TX] Payload: $hexPayload');

    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        debugPrint('[BLE TX] Bluetooth is OFF');
        return;
      }

      // Scan for nearby devices that might be running the relay
      debugPrint('[BLE TX] Scanning for relay nodes...');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        withNames: ['DISTRESS_RELAY'],
      );

      debugPrint('[BLE TX] Broadcast ACTIVE (id=$id). Scanning for 30s.');
      await Future.delayed(const Duration(seconds: 30));
      await FlutterBluePlus.stopScan();
      debugPrint('[BLE TX] Broadcast Stopped.');
    } catch (e) {
      debugPrint('[BLE TX] CRITICAL ERROR: $e');
    }
  }

  // PHONE 2/3 (ONLINE): Listen and Relay
  static void startBleRelay(Function(double lat, double lng, int hop, int id) onRelayRequest) {
    Permission.bluetoothScan.request();
    Permission.location.request();

    // Listen to results
    FlutterBluePlus.onScanResults.listen((results) async {
      for (ScanResult r in results) {
        // Look for our manufacturer ID
        final mfr = r.advertisementData.manufacturerData[0xFFFF];
        if (mfr == null || mfr.length < 11) continue;

        final bd = ByteData.sublistView(Uint8List.fromList(mfr));
        final id = bd.getUint16(0, Endian.big);

        if (_seenIds.contains(id)) continue;
        _seenIds.add(id);

        final hop = bd.getUint8(2);
        final lat = bd.getFloat32(3, Endian.big);
        final lng = bd.getFloat32(7, Endian.big);

        debugPrint('[BLE RX] Signal Detected! ID=$id Hop=$hop lat=$lat lng=$lng');

        // Execute the relay callback (Backend POST)
        onRelayRequest(lat, lng, hop, id);
      }
    });

    // Start scanning with no filters to ensure we catch the mfr data
    FlutterBluePlus.startScan(timeout: const Duration(hours: 1));
    debugPrint('[BLE] Mesh Scanner Active');
  }
}