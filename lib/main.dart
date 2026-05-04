import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'services/supabase_service.dart';
import 'overlay_lock_screen.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayLockScreen(),
  ));
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await handleLockAction(message.data['action']);
}

Future<void> handleLockAction(String? action) async {
  if (Platform.isAndroid) {
    if (action == 'LOCK') {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.example.customer_emi_app',
          componentName: 'com.example.customer_emi_app.MainActivity',
          arguments: {'start_kiosk': true},
          flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
      } catch (e) {
        debugPrint("Background Kiosk mode error: $e");
      }
      
      if (!(await FlutterOverlayWindow.isActive())) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false,
          overlayTitle: "Device Locked",
          overlayContent: "Please contact support",
          flag: OverlayFlag.focusPointer,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
        );
      }
    } else if (action == 'UNLOCK') {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.example.customer_emi_app',
          componentName: 'com.example.customer_emi_app.MainActivity',
          arguments: {'stop_kiosk': true},
          flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
      } catch (e) {
        debugPrint("Background Kiosk unlock error: $e");
      }
      
      await FlutterOverlayWindow.closeOverlay();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Set foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      handleLockAction(message.data['action']);
    });
  }

  await SupabaseService.initialize();
  
  String? fcmToken;
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      
      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        SupabaseService.getOrCreateDeviceId(fcmToken: newToken);
      });
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
    }
  }

  try {
    await SupabaseService.getOrCreateDeviceId(fcmToken: fcmToken);
  } catch (e) {
    debugPrint("Failed to sync device ID: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AdminControlScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  static const platform = MethodChannel('com.example.customer_emi_app/admin');
  bool _isAdminActive = false;
  bool _isDeviceOwner = false;
  bool _hasOverlayPermission = false;
  String _deviceId = "Loading...";

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await SupabaseService.getOrCreateDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = id;
      });
    }
  }

  Future<void> _checkStatus() async {
    try {
      final bool adminResult = await platform.invokeMethod('isAdminActive');
      final bool ownerResult = await platform.invokeMethod('isDeviceOwner');
      bool overlayResult = false;
      if (Platform.isAndroid) {
        overlayResult = await FlutterOverlayWindow.isPermissionGranted() ?? false;
      }
      
      setState(() {
        _isAdminActive = adminResult;
        _isDeviceOwner = ownerResult;
        _hasOverlayPermission = overlayResult;
      });
      
      if (_isDeviceOwner) {
        await platform.invokeMethod('setKioskPolicies');
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get status: '\${e.message}'.");
    }
  }

  Future<void> _requestAdmin() async {
    try {
      await platform.invokeMethod('requestAdmin');
      await Future.delayed(const Duration(seconds: 3)); 
      _checkStatus();
    } on PlatformException catch (e) {
      debugPrint("Failed to request admin: '\${e.message}'.");
    }
  }

  Future<void> _requestOverlayPermission() async {
    if (Platform.isAndroid) {
      final bool? res = await FlutterOverlayWindow.requestPermission();
    }
    _checkStatus();
  }

  Future<void> _lockDeviceWithKiosk() async {
    // This is for local testing. The actual lock is handled via Supabase background service.
    // If the overlay permission is granted, we can test it directly:
    if (_hasOverlayPermission) {
      if (Platform.isAndroid) {
        if (!await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            overlayTitle: "Device Locked",
            overlayContent: "Please contact support",
            flag: OverlayFlag.focusPointer,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: WindowSize.matchParent,
            width: WindowSize.matchParent,
          );
        }
      }
      try {
        await platform.invokeMethod('startKioskMode');
      } catch (e) {
        debugPrint("Kiosk mode error: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Overlay permission required first!')),
      );
    }
  }

  Future<void> _hideAppIcon() async {
    try {
      await platform.invokeMethod('hideAppIcon');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App hidden!')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to hide icon: '\${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Setup (Hybrid)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Device ID Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple),
                ),
                child: Column(
                  children: [
                    const Text(
                      "DEVICE ID (SUPABASE)",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _deviceId,
                      style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Icon(
                _isDeviceOwner ? Icons.verified_user : (_isAdminActive ? Icons.security : Icons.warning_amber_rounded),
                size: 80,
                color: _isDeviceOwner ? Colors.blue : (_isAdminActive ? Colors.green : Colors.orange),
              ),
              const SizedBox(height: 20),
              Text(
                'Device Admin: ${_isAdminActive ? "Yes" : "No"}\nDevice Owner: ${_isDeviceOwner ? "Yes" : "No (ADB required)"}\nOverlay Permission: ${_hasOverlayPermission ? "Yes" : "No"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              
              if (!_hasOverlayPermission)
                ElevatedButton.icon(
                  onPressed: _requestOverlayPermission,
                  icon: const Icon(Icons.layers),
                  label: const Text('Grant Overlay Permission'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                ),
              const SizedBox(height: 10),
              
              ElevatedButton.icon(
                onPressed: _requestAdmin,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('1. Request Basic Admin'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _lockDeviceWithKiosk,
                icon: const Icon(Icons.screen_lock_portrait),
                label: const Text('2. Test Lock (Overlay + Kiosk)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  if (Platform.isAndroid) {
                    await FlutterOverlayWindow.closeOverlay();
                  }
                  await platform.invokeMethod('stopKioskMode');
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock (Local Test)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100]),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _hideAppIcon,
                icon: const Icon(Icons.visibility_off),
                label: const Text('3. Hide App Icon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkStatus,
        tooltip: 'Refresh Status',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
