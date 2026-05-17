import 'dart:async';
import 'dart:io';
import 'package:customer_emi_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'overlay_lock_screen.dart';
import 'screens/frp_demo_screen.dart';
import 'screens/connectivity_screen.dart';
import 'screens/sms_lock_screen.dart';
import 'screens/device_info_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/activation_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/emergency_call_screen.dart';


// ──────────────────────────────────────────────
// Overlay entry point (separate isolate)
// ──────────────────────────────────────────────
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayLockScreen(),
  ));
}

// ──────────────────────────────────────────────
// FCM Background handler (terminated/background isolate)
// IMPORTANT: ONLY SharedPreferences + AndroidIntent work here.
// ──────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final action = message.data['action'] as String?;
  if (action == null || !Platform.isAndroid) return;

  try {
    final prefs = await SharedPreferences.getInstance();

    if (action == 'LOCK') {
      await prefs.setBool('is_locked', true);
      // Launch app to apply kiosk — background isolate can't call MethodChannel
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'start_kiosk': true},
        flags: <int>[268435456],
      ).launch();
    } else if (action == 'UNLOCK') {
      await prefs.setBool('is_locked', false);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'stop_kiosk': true},
        flags: <int>[268435456],
      ).launch();
    } else if (action == 'APPLY_POLICIES') {
      // ── Silent background apply ──────────────────────────────────────
      // Store the new values from FCM data payload in SharedPrefs.
      // The MethodChannel call runs via AndroidIntent silently (no UI open).
      final allowFR = message.data['allow_factory_reset'];
      final allowAR = message.data['allow_admin_removal'];
      if (allowFR != null) {
        await prefs.setBool('allow_factory_reset', allowFR == 'true');
      }
      if (allowAR != null) {
        await prefs.setBool('allow_admin_removal', allowAR == 'true');
      }
      // Silently bring the app to foreground so MethodChannel can execute.
      // FLAG_ACTIVITY_SINGLE_TOP (67108864) | NEW_TASK (268435456) = 335544320
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'apply_policies': true},
        flags: <int>[335544320], // SINGLE_TOP | NEW_TASK — no new task if already running
      ).launch();
    }
  } catch (e) {
    debugPrint('Background FCM error: $e');
  }
}

// ──────────────────────────────────────────────
// Shared MethodChannel
// ──────────────────────────────────────────────
const _adminChannel = MethodChannel('com.example.customer_emi_app/admin');

// ──────────────────────────────────────────────
// FIX 3: App-level Realtime subscription (lives for full app lifetime)
// ──────────────────────────────────────────────
StreamSubscription<List<Map<String, dynamic>>>? _policyRealtimeSubscription;

// ──────────────────────────────────────────────
// Show overlay lock screen
// ──────────────────────────────────────────────
Future<void> showLockOverlay() async {
  try {
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
  } catch (e) {
    debugPrint('showLockOverlay error: $e');
  }
}

// ──────────────────────────────────────────────
// Handle LOCK / UNLOCK (foreground main isolate only)
// ──────────────────────────────────────────────
Future<void> handleLockAction(String? action) async {
  if (!Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();

  if (action == 'LOCK') {
    await prefs.setBool('is_locked', true);
    try {
      await _adminChannel.invokeMethod('startKioskMode');
    } catch (e) {
      debugPrint('startKioskMode error: $e');
    }
    await showLockOverlay();
  } else if (action == 'UNLOCK') {
    await prefs.setBool('is_locked', false);
    try {
      await _adminChannel.invokeMethod('stopKioskMode');
    } catch (e) {
      debugPrint('stopKioskMode error: $e');
    }
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}

// ──────────────────────────────────────────────
// Apply Device Owner security policies
// ──────────────────────────────────────────────
Future<void> applySecurityPolicies({
  bool? allowFactoryReset,
  bool? allowAdminRemoval,
}) async {
  try {
    final bool isDeviceOwner =
        await _adminChannel.invokeMethod('isDeviceOwner');
    if (!isDeviceOwner) return;

    bool frAllow = allowFactoryReset ?? false;
    bool arAllow = allowAdminRemoval ?? false;

    if (allowFactoryReset == null || allowAdminRemoval == null) {
      // 1st: try SharedPrefs cache (works offline & in background)
      final prefs = await SharedPreferences.getInstance();
      final cachedFR = prefs.getBool('allow_factory_reset');
      final cachedAR = prefs.getBool('allow_admin_removal');

      if (cachedFR != null && cachedAR != null) {
        frAllow = cachedFR;
        arAllow = cachedAR;
      } else {
        // 2nd: fetch from Supabase (online only)
        try {
          final deviceId = await SupabaseService.getOrCreateDeviceId();
          final data = await SupabaseService.client
              .from('devices')
              .select('allow_factory_reset, allow_admin_removal')
              .eq('id', deviceId)
              .maybeSingle();
          if (data == null) return;
          frAllow = data['allow_factory_reset'] as bool? ?? false;
          arAllow = data['allow_admin_removal'] as bool? ?? false;
          // Cache the fetched values
          await prefs.setBool('allow_factory_reset', frAllow);
          await prefs.setBool('allow_admin_removal', arAllow);
        } catch (_) {
          return; // offline and no cache
        }
      }
    } else {
      // Save provided values to cache too
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('allow_factory_reset', frAllow);
      await prefs.setBool('allow_admin_removal', arAllow);
    }

    await _adminChannel.invokeMethod('setFactoryResetAllowed', {'allowed': frAllow});
    await _adminChannel.invokeMethod('setUninstallBlocked', {'blocked': !arAllow});
    debugPrint('Policies applied: factoryReset=$frAllow, adminRemoval=$arAllow');
  } catch (e) {
    debugPrint('applySecurityPolicies error: $e');
  }
}

// ──────────────────────────────────────────────
// FIX 4: main() — only Firebase before runApp (fast local read)
//        Supabase + everything else is deferred to background
// ──────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() reads local google-services.json — very fast
  await Firebase.initializeApp();

  // Register FCM background handler BEFORE runApp (Firebase requirement)
  if (Platform.isAndroid || Platform.isIOS) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Show UI immediately — don't wait for network calls
  runApp(const ProviderScope(child: MyApp()));

  // All network-dependent tasks run after first frame
  _initializeInBackground();
}

/// All heavy/network tasks run AFTER the UI is visible.
Future<void> _initializeInBackground() async {
  // Wait for first frame to render
  await Future.delayed(const Duration(milliseconds: 200));

  // FIX 1: Re-apply lock if device was locked before this session
  final prefs = await SharedPreferences.getInstance();
  final wasLocked = prefs.getBool('is_locked') ?? false;
  if (wasLocked && Platform.isAndroid) {
    try {
      await _adminChannel.invokeMethod('startKioskMode');
    } catch (_) {}
    await showLockOverlay();
  }

  if (!Platform.isAndroid && !Platform.isIOS) return;

  // FIX 4: Supabase init runs here (network call — not blocking UI)
  await SupabaseService.initialize();

  // FCM setup
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: false);

    if (Platform.isAndroid) {
      await _adminChannel.invokeMethod('createNotificationChannel');
    }

    // Register foreground handler AFTER Supabase is ready
    FirebaseMessaging.onMessage.listen((msg) {
      final action = msg.data['action'] as String?;
      if (action == 'APPLY_POLICIES') {
        applySecurityPolicies();
      } else {
        handleLockAction(action);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final action = msg.data['action'] as String?;
      if (action == 'APPLY_POLICIES') {
        applySecurityPolicies();
      } else {
        handleLockAction(action);
      }
    });

    final fcmToken = await messaging.getToken();
    messaging.onTokenRefresh.listen((newToken) {
      SupabaseService.getOrCreateDeviceId(fcmToken: newToken);
    });

    // Sync device + FCM token to Supabase
    final deviceId = await SupabaseService.getOrCreateDeviceId(fcmToken: fcmToken);

    // FIX 3: Start app-level Realtime listener for policy changes
    // Cancels old subscription first to avoid duplicates
    await _policyRealtimeSubscription?.cancel();
    _policyRealtimeSubscription = SupabaseService.client
        .from('devices')
        .stream(primaryKey: ['id'])
        .eq('id', deviceId)
        .listen((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return;
          final row = rows.first;
          final allowFactoryReset = row['allow_factory_reset'] as bool? ?? false;
          final allowAdminRemoval = row['allow_admin_removal'] as bool? ?? false;
          // Apply Device Owner policies immediately when admin changes them
          applySecurityPolicies(
            allowFactoryReset: allowFactoryReset,
            allowAdminRemoval: allowAdminRemoval,
          );
        });

    // Apply security policies on startup
    await applySecurityPolicies();

    // Show battery optimization dialog (delayed so it doesn't feel intrusive)
    if (Platform.isAndroid) {
      await Future.delayed(const Duration(seconds: 3));
      await _adminChannel.invokeMethod('requestBatteryOptimization');
    }
  } catch (e) {
    debugPrint('Background init error: $e');
  }
}

// ──────────────────────────────────────────────
// App root
// ──────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMI Device',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const PermissionsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ──────────────────────────────────────────────
// Device Setup / Status Screen
// ──────────────────────────────────────────────
class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
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
    // Wait for Supabase to be ready (initialized in background)
    await Future.delayed(const Duration(seconds: 1));
    try {
      final id = await SupabaseService.getOrCreateDeviceId();
      if (mounted) setState(() => _deviceId = id);
    } catch (e) {
      if (mounted) setState(() => _deviceId = 'Initializing...');
    }
  }

  Future<void> _checkStatus() async {
    try {
      final bool adminResult =
          await _adminChannel.invokeMethod('isAdminActive');
      final bool ownerResult =
          await _adminChannel.invokeMethod('isDeviceOwner');
      bool overlayResult = false;
      if (Platform.isAndroid) {
        overlayResult = (await FlutterOverlayWindow.isPermissionGranted()) == true;
      }
      if (!mounted) return;
      setState(() {
        _isAdminActive = adminResult;
        _isDeviceOwner = ownerResult;
        _hasOverlayPermission = overlayResult;
      });
      if (_isDeviceOwner) {
        await _adminChannel.invokeMethod('setKioskPolicies');
      }
    } on PlatformException catch (e) {
      debugPrint("Status check failed: '${e.message}'.");
    }
  }

  Future<void> _requestAdmin() async {
    try {
      await _adminChannel.invokeMethod('requestAdmin');
      await Future.delayed(const Duration(seconds: 3));
      _checkStatus();
    } on PlatformException catch (e) {
      debugPrint("Request admin failed: '${e.message}'.");
    }
  }

  Future<void> _requestOverlayPermission() async {
    if (Platform.isAndroid) {
      await FlutterOverlayWindow.requestPermission();
    }
    _checkStatus();
  }

  Future<void> _lockDeviceWithKiosk() async {
    if (_hasOverlayPermission) {
      await handleLockAction('LOCK');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overlay permission required first!')),
        );
      }
    }
  }

  Future<void> _hideAppIcon() async {
    try {
      await _adminChannel.invokeMethod('hideAppIcon');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App icon hidden!')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Hide icon failed: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple),
                ),
                child: Column(
                  children: [
                    const Text("DEVICE ID",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    const SizedBox(height: 8),
                    SelectableText(_deviceId,
                        style: const TextStyle(
                            fontSize: 14, fontFamily: 'monospace'),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                _isDeviceOwner
                    ? Icons.verified_user
                    : (_isAdminActive
                        ? Icons.security
                        : Icons.warning_amber_rounded),
                size: 80,
                color: _isDeviceOwner
                    ? Colors.blue
                    : (_isAdminActive ? Colors.green : Colors.orange),
              ),
              const SizedBox(height: 16),
              Text(
                'Device Admin: ${_isAdminActive ? "✅ Yes" : "❌ No"}\n'
                'Device Owner: ${_isDeviceOwner ? "✅ Yes" : "❌ No (ADB required)"}\n'
                'Overlay Permission: ${_hasOverlayPermission ? "✅ Yes" : "❌ No"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (!_hasOverlayPermission)
                ElevatedButton.icon(
                  onPressed: _requestOverlayPermission,
                  icon: const Icon(Icons.layers),
                  label: const Text('Grant Overlay Permission'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100]),
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
                label: const Text('2. Test Lock'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100]),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => handleLockAction('UNLOCK'),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock (Local Test)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100]),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _hideAppIcon,
                icon: const Icon(Icons.visibility_off),
                label: const Text('3. Hide App Icon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FRPDemoScreen()),
                  );
                },
                icon: const Icon(Icons.security_update_good),
                label: const Text('Manage FRP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConnectivityScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Connectivity Control'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmsLockScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.sms_failed),
                label: const Text('SMS Lock Setup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeviceInfoScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.sim_card_outlined),
                label: const Text('SIM & Device Info'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PermissionsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('App Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActivationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Activation Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LockScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock Screen (Demo)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyCallScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.emergency_outlined),
                label: const Text('Emergency Dial (Demo)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[200],
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
