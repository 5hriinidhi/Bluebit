import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/sonic_cascade.dart';
import 'services/api_service.dart';
import 'constants/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Foreground task communication
  FlutterForegroundTask.initCommunicationPort();

  // Start BLE relay listener
  SonicCascade.startBleRelay((lat, lng, hop, id) async {
    try {
      await ApiService.submitSos(
        lat: lat,
        lng: lng,
        message: 'Relayed via BLE Mesh (hop $hop)',
        source: Config.sourceSonicCascade,
        metadata: {'relay': 'ble_mesh', 'hop': hop, 'relay_id': id},
      );
      debugPrint('[BLE] Relay to backend OK');
    } catch (e) {
      debugPrint('[BLE] Backend relay failed: $e');
    }
  });

  runApp(const DistressApp());
}

class DistressApp extends StatelessWidget {
  const DistressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIST.RESS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}