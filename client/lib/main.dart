import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/auth_provider.dart';
import 'features/seizure/seizure_provider.dart';
import 'features/alert/fcm_service.dart';
import 'core/server_discovery.dart';
import 'monitoring/monitoring_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FcmService.backgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Discover Flask server on local Wi-Fi via mDNS
  final found = await ServerDiscovery.findServer();
  if (!found) {
    debugPrint('[mDNS] Server not found — using fallback URL');
  }

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const EpiGuardApp());
}


class EpiGuardApp extends StatelessWidget {
  const EpiGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SeizureProvider()),
      ],
      child: MaterialApp(
        title: 'EpiGuard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const MonitoringPage(),
      ),
    );
  }
}
