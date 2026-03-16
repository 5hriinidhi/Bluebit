import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/sonic_cascade.dart';
import 'services/api_service.dart';
import 'constants/config.dart';

// Global Navigator Key for context-less navigation and snackbars
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // STEP B: Manual Initialization using Aryan's project IDs
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAT48YvBz00OXsSwHKdOTRlZHoqCTEqZYE", // From client info JSON
      appId: "1:555845540549:android:0661885c8c3ee7feffeeac", // From mobilesdk_app_id
      messagingSenderId: "555845540549", // From project_number
      projectId: "bluebithack", // From project_id
    ),
  );

  final msg = FirebaseMessaging.instance;

  // Request permissions for iOS/Android
  await msg.requestPermission(alert: true, sound: true, badge: true);

  // Subscribe to the mandatory emergency topic
  await msg.subscribeToTopic('emergency-alerts');

  // Foreground (Red Snackbar)
  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;

    // Requirement 4c: Show red snackbar with alert details
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text('${n.title}\n${n.body}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  });

  // Background (Tray & Navigation)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    // Navigate to home and clear history
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (_) => false);
  });

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
      navigatorKey: navigatorKey,
      title: 'DIST.RESS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}