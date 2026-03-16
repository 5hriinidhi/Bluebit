import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/shake_detector.dart';
import '../services/sonic_cascade.dart';
import '../constants/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _connected = false;
  String _locationText = 'Fetching location...';
  double? _lat;
  double? _lng;
  bool _sosSubmitting = false;
  String _lastStatus = 'Idle';
  Timer? _healthTimer;
  late ShakeDetector _shakeDetector;

  @override
  void initState() {
    super.initState();
    // 1. Initialize and Start Background Service
    _initForegroundTask().then((_) => _startService());
    
    // 2. Core App Logic
    _fetchLocation();
    _checkConnection();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
    
    // 3. Initialize Shake Detector for Zero-Touch
    _shakeDetector = ShakeDetector(
      onShake: () {
        print('Physical Impact Detected!');
        _triggerSos(Config.sourceZeroTouch);
      }
    );
    _shakeDetector.startListening();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _shakeDetector.stopListening();
    super.dispose();
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'distress_service',
        channelName: 'DIST.RESS Protection',
        channelDescription: 'Monitoring for physical impacts...',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        // This is the missing required parameter for v9.2.1
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }

  Future<void> _startService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'DIST.RESS Active',
      notificationText: 'Zero-Touch monitoring is running in background',
    );
  }

  Future<void> _checkConnection() async {
    try {
      print('[HEALTH] Checking ${Config.backendUrl}/health ...');
      final health = await ApiService.checkHealth();
      print('[HEALTH] Response: $health');
      setState(() => _connected = health['status'] == 'ok');
    } catch (e) {
      print('[HEALTH] Connection FAILED: $e');
      setState(() => _connected = false);
    }
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationText = 'Location disabled — opening settings...');
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        setState(() => _locationText = 'Location disabled');
        return;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationText = 'Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationText = 'Location permission denied — opening settings...');
      await Geolocator.openAppSettings();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationText = '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() => _locationText = 'Location unavailable');
    }
  }

  Future<void> _triggerSos(String source, {Map<String, dynamic>? metadata}) async {
    if (_sosSubmitting) return;
    setState(() {
      _sosSubmitting = true;
      _lastStatus = 'Sending $source SOS...';
    });

    try {
      String msg = (source == Config.sourceZeroTouch) 
          ? Config.zeroTouchMessage 
          : 'Emergency SOS triggered manually';

      await ApiService.submitSos(
        lat: _lat ?? 0.0,
        lng: _lng ?? 0.0,
        message: msg,
        source: source,
        metadata: metadata,
      );
      
      setState(() => _lastStatus = 'Success: $source sent');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$source SOS Sent Successfully!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      setState(() => _lastStatus = 'Failed to connect');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network Error: Could not reach backend'), backgroundColor: Colors.red)
        );
      }
    } finally {
      setState(() => _sosSubmitting = false);
    }
  }

  void _onDevButtonPress() {
    _triggerSos(Config.sourceZeroTouch, metadata: {'dev_triggered': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onLongPress: _onDevButtonPress,
              child: const Text('DIST.RESS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24)),
            ),
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(_connected ? 'Live' : 'Offline', style: const TextStyle(fontSize: 14)),
              ],
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(_locationText, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Status: $_lastStatus', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _triggerSos(Config.sourceManual), 
              child: _sosSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SOS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: (_sosSubmitting || _lat == null) ? null : () async {
                setState(() => _sosSubmitting = true);
                try {
                  await SonicCascade.advertiseBleSos(_lat!, _lng!);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('BLE SOS Broadcast Sent!'), backgroundColor: Colors.purple)
                    );
                  }
                } catch (e) {
                  print('BLE broadcast failed: $e');
                } finally {
                  setState(() => _sosSubmitting = false);
                }
              },
              child: const Text('BLE SOS Broadcast', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}