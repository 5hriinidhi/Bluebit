import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sonic_cascade.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = false;
  bool _locationEnabled = false;
  bool _isSending = false;
  bool _powerSaveMode = false; // New state variable
  
  // Tracks which specific button is currently hitting the API
  String? _activeStatusLoading; 
  int? _lastSosId; 
  
  String _statusMessage = "Ready";
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
    _initSystem();
    // Heartbeat to monitor connection status to Railway
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkHealth());
  }

  // Task 5C Persistence: Ensures buttons stay visible even if app restarts
  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastSosId = prefs.getInt('last_sos_id');
        if (_lastSosId != null) _statusMessage = "Last SOS: #$_lastSosId";
      });
    }
  }

  Future<void> _persistSosId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sos_id', id);
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSystem() async {
    await _checkLocationPermission();
    await _checkHealth();
    
    // Task 3b: Mesh Relay Listener
    SonicCascade.startBleRelay((lat, lng, hop, id) => ApiService.submitSos(
      lat: lat, 
      lng: lng, 
      message: "Mesh Relay (Hop $hop)", 
      source: "sonic_cascade", 
      metadata: {'relay_id': id}
    ));
  }

  Future<void> _checkHealth() async {
    final h = await ApiService.checkBackendHealth();
    if (mounted) {
      setState(() {
        _isOnline = h;
        _statusMessage = h ? "Grid Online" : "Grid Offline - Check Data";
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (mounted) {
      setState(() => _locationEnabled = enabled && p != LocationPermission.deniedForever);
    }
  }

  Future<void> _handleManualSos() async {
    setState(() {
      _isSending = true;
      _statusMessage = "Broadcasting Emergency...";
    });
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: _powerSaveMode ? LocationAccuracy.low : LocationAccuracy.high
      );
      final res = await ApiService.submitSos(
        lat: pos.latitude, 
        lng: pos.longitude, 
        message: "Citizen SOS Triggered", 
        source: "manual"
      );
      
      if (res != null && res['id'] != null) {
        final id = res['id'];
        await _persistSosId(id);
        setState(() {
          _lastSosId = id;
          _statusMessage = "SOS Sent (ID: #$id)";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Network Fail: SOS not sent");
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Two-Way Comms Button with Individual Loading
  Widget _statusBtn(String label, Color color, String val) {
    bool loading = _activeStatusLoading == val;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color, 
            foregroundColor: Colors.white, 
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 2,
          ),
          onPressed: (_lastSosId == null || _activeStatusLoading != null) ? null : () async {
            setState(() => _activeStatusLoading = val);
            
            // "Shotgun" payload to ensure backend field matching
            final ok = await ApiService.post('/api/status', {
              'sos_id': _lastSosId,
              'status': val,          // Requirement: 'safe', 'need rescue', 'medical'
              'citizen_status': val   // Playbook variant
            });
            
            if (mounted) {
              setState(() => _activeStatusLoading = null);
              if (ok != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Status Reported: $label"), backgroundColor: color)
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to report status"), backgroundColor: Colors.black)
                );
              }
            }
          },
          child: loading 
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DIST.RESS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        actions: [
          Icon(Icons.circle, size: 12, color: _isOnline ? Colors.green : Colors.grey),
          const SizedBox(width: 20)
        ],
      ),
      // LayoutBuilder + SingleChildScrollView + IntrinsicHeight prevents the overflow error
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100], 
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[300]!)
                        ),
                        child: Column(
                          children: [
                            Row(children: [
                              Icon(Icons.gps_fixed, color: _locationEnabled ? Colors.green : Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Text(_locationEnabled ? "GPS Locked" : "Location Error", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            const Divider(height: 24),
                            Row(children: [
                              Icon(
                                _isOnline ? Icons.cloud_done : Icons.bluetooth_searching, 
                                color: _isOnline ? Colors.blue : Colors.orange, 
                                size: 20
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isOnline ? "Mode: CLOUD (Railway)" : "Mode: MESH (BLE Active)",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: _isOnline ? Colors.blue : Colors.orange
                                ),
                              ),
                            ]),
                            const Divider(height: 24),
                            Row(children: [
                              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_statusMessage, style: TextStyle(color: Colors.grey[800]))),
                            ]),
                          ],
                        ),
                      ),
                      const Spacer(),
                      
                      // Two-Way Communication Section (Task 5C)
                      if (_lastSosId != null) ...[
                        const Text("ARE YOU SAFE?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 12),
                        Row(children: [
                          _statusBtn("SAFE", Colors.green, "safe"),
                          _statusBtn("RESCUE", Colors.orange, "need rescue"),
                          _statusBtn("MEDICAL", Colors.red, "medical"),
                        ]),
                        const SizedBox(height: 40),
                      ],

                      // Main Emergency Trigger
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), 
                            elevation: 8
                          ),
                          onPressed: _isSending ? null : _handleManualSos,
                          child: _isSending 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text("SOS", style: TextStyle(fontSize: 45, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // BLE Mesh Broadcast (Offline Channel)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bluetooth_searching), 
                        label: const Text("BLE SOS BROADCAST"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60), 
                          side: const BorderSide(color: Colors.red, width: 2), 
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          Position p = await Geolocator.getCurrentPosition(
                            desiredAccuracy: _powerSaveMode ? LocationAccuracy.low : LocationAccuracy.high
                          );
                          SonicCascade.advertiseBleSos(p.latitude, p.longitude);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Battery Optimization Toggle
                      SwitchListTile(
                        title: const Text("Battery Optimization", style: TextStyle(fontSize: 14)),
                        subtitle: Text(_powerSaveMode ? "GPS: Power Save (Low Freq)" : "GPS: High Accuracy"),
                        value: _powerSaveMode,
                        onChanged: (val) => setState(() => _powerSaveMode = val),
                        secondary: Icon(Icons.battery_saver, color: _powerSaveMode ? Colors.green : Colors.grey),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}