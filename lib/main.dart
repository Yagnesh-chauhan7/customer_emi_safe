import 'dart:async';
import 'dart:io';
import 'package:customer_emi_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'services/supabase_service.dart';
import 'screens/frp_demo_screen.dart';
import 'screens/connectivity_screen.dart';
import 'screens/sms_lock_screen.dart';
import 'screens/device_info_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/activation_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/emergency_call_screen.dart';
import 'services/wallpaper_service.dart';
import 'screens/splash_screen.dart';


// ──────────────────────────────────────────────
// FCM Background handler (terminated/background isolate)
// IMPORTANT: ONLY SharedPreferences + AndroidIntent work here.
// ──────────────────────────────────────────────
// ──────────────────────────────────────────────
// Wallpaper service import — used in both background and foreground handlers
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
        arguments: {'start_kiosk': true, 'wakeup': true},
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
      // 268435456 = FLAG_ACTIVITY_NEW_TASK, 67108864 = FLAG_ACTIVITY_SINGLE_TOP
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'apply_policies': true},
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'FETCH_SIM') {
      await prefs.setBool('action_fetch_sim', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'power_off': true},
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'HIDE_APP') {
      await prefs.setBool('action_hide_app', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'power_off': true},
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'UNHIDE_APP') {
      await prefs.setBool('action_unhide_app', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'SETTLE_EMI') {
      await prefs.setBool('action_settle_emi', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'FETCH_LOCATION') {
      await prefs.setBool('action_fetch_location', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'power_off': true},
        flags: <int>[268435456, 67108864],
      ).launch();
    } else if (action == 'SET_WALLPAPER') {
      final url = message.data['wallpaper_url'];
      if (url != null) {
        try {
          await WallpaperService.setWallpaper(url);
        } catch (e) {
          debugPrint('Background setWallpaper error: $e');
        }
      }
    } else if (action == 'RESET_WALLPAPER') {
      try {
        await WallpaperService.resetWallpaper();
      } catch (e) {
        debugPrint('Background resetWallpaper error: $e');
      }
    } else if (action == 'APP_UPDATE') {
      await prefs.setBool('action_app_update', true);
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.example.customer_emi_app',
        componentName: 'com.example.customer_emi_app.MainActivity',
        arguments: {'power_off': true},
        flags: <int>[268435456, 67108864],
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

// Global navigator key — lets us push routes from outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isLockScreenActive = false;

// App-level Realtime subscription (lives for full app lifetime)
StreamSubscription<List<Map<String, dynamic>>>? _policyRealtimeSubscription;

// ──────────────────────────────────────────────
// Navigate to LockScreen (replaces overlay approach)
// ──────────────────────────────────────────────
void navigateToLockScreen() {
  if (isLockScreenActive) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  isLockScreenActive = true;
  // Push LockScreen on top of everything — user cannot pop it
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const LockScreen(),
      settings: const RouteSettings(name: '/lock'),
    ),
    (route) => false, // remove every route below
  );
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
    // Navigate to our custom LockScreen
    navigateToLockScreen();
  } else if (action == 'UNLOCK') {
    await prefs.setBool('is_locked', false);
    try {
      // stopKioskMode calls stopLockTask() + finishAndRemoveTask() in Kotlin
      await _adminChannel.invokeMethod('stopKioskMode');
    } catch (e) {
      debugPrint('stopKioskMode error: $e');
    }
    // Also trigger SystemNavigator.pop() to guarantee close on DartVM side
    await SystemNavigator.pop();
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
          if (deviceId == null) return;
          final data = await SupabaseService.client
              .from('customer_service_table')
              .select('allow_factory_reset, allow_admin_removal')
              .eq('customer_id', deviceId)
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
// Handle background triggers
// ──────────────────────────────────────────────
Future<void> _handleFetchSim() async {
  try {
    const deviceInfoChannel = MethodChannel('device_info_channel');
    final simDetails = await deviceInfoChannel.invokeMethod<List<dynamic>>('getSimDetails');
    
    if (simDetails != null && simDetails.isNotEmpty) {
      final sim1 = Map<dynamic, dynamic>.from(simDetails[0] as Map);
      final String? number1 = sim1['phoneNumber'] as String?;
      final String? provider1 = sim1['carrierName'] as String?;
      
      String? number2;
      String? provider2;
      if (simDetails.length > 1) {
        final sim2 = Map<dynamic, dynamic>.from(simDetails[1] as Map);
        number2 = sim2['phoneNumber'] as String?;
        provider2 = sim2['carrierName'] as String?;
      }

      final deviceId = await SupabaseService.getOrCreateDeviceId();
      if (deviceId == null) return;
      await SupabaseService.client.from('customer_service_table').update({
        'sim_number1': number1,
        'sim_provider1': provider1,
        'sim_number2': number2,
        'sim_provider2': provider2,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('customer_id', deviceId);
    }
  } catch (e) {
    debugPrint('Fetch SIM error: $e');
  } finally {
    try {
      await _adminChannel.invokeMethod('finishAndRemoveTask');
    } catch (_) {}
  }
}

Future<void> _handleFetchLocation() async {
  const connectivityChannel = MethodChannel('connectivity_channel');
  try {
    // Automatically turn on location service using Device Owner method channel
    debugPrint('Automatically starting customer location services...');
    await connectivityChannel.invokeMethod('setLocationEnabled', {'enabled': true});
    
    // Wait for GPS hardware/provider to start up
    await Future.delayed(const Duration(milliseconds: 1500));

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are still disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

    final deviceId = await SupabaseService.getOrCreateDeviceId();
    if (deviceId == null) return;
    await SupabaseService.client.from('customer_service_table').update({
      'location_lat': position.latitude.toString(),
      'location_long': position.longitude.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('customer_id', deviceId);
    debugPrint('Location synced: ${position.latitude}, ${position.longitude}');
  } catch (e) {
    debugPrint('Fetch location error: $e');
  } finally {
    // Automatically turn off location service after sync or on error to save battery/privacy
    try {
      debugPrint('Automatically turning customer location services off...');
      await connectivityChannel.invokeMethod('setLocationEnabled', {'enabled': false});
    } catch (e) {
      debugPrint('Failed to turn location off: $e');
    }
    
    // Close app and remove from recents
    try {
      await _adminChannel.invokeMethod('finishAndRemoveTask');
    } catch (_) {}
  }
}

// ──────────────────────────────────────────────
// Unified foreground FCM action router
// ──────────────────────────────────────────────
Future<void> _handleFcmAction(Map<String, dynamic> data) async {
  final action = data['action'] as String?;
  if (action == null) return;

  switch (action) {
    case 'LOCK':
    case 'UNLOCK':
      await handleLockAction(action);
      break;
    case 'APPLY_POLICIES':
      final allowFR = data['allow_factory_reset'];
      final allowAR = data['allow_admin_removal'];
      await applySecurityPolicies(
        allowFactoryReset: allowFR == null ? null : allowFR == 'true',
        allowAdminRemoval: allowAR == null ? null : allowAR == 'true',
      );
      break;
    case 'FETCH_SIM':
      await _handleFetchSim();
      break;
    case 'FETCH_LOCATION':
      await _handleFetchLocation();
      break;
    case 'HIDE_APP':
      try {
        await _adminChannel.invokeMethod('hideAppIcon');
        // Small delay so Android processes the icon state change
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('hideAppIcon error: $e');
      } finally {
        // Always close app + remove from recents after icon is hidden
        try {
          await _adminChannel.invokeMethod('finishAndRemoveTask');
        } catch (_) {}
      }
      break;
    case 'UNHIDE_APP':
      try {
        await _adminChannel.invokeMethod('unhideApp');
        // Small delay so Android processes the icon state change
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('unhideApp error: $e');
      } finally {
        // Always close app + remove from recents after icon is restored
        try {
          await _adminChannel.invokeMethod('finishAndRemoveTask');
        } catch (_) {}
      }
      break;
    case 'SETTLE_EMI':
      try {
        await _adminChannel.invokeMethod('removeDeviceOwner');
        await _adminChannel.invokeMethod('uninstallApp');
      } catch (e) {
        debugPrint('settleEmi error: $e');
      }
      break;
    case 'SET_WALLPAPER':
      final wallpaperUrl = data['wallpaper_url'] as String?;
      if (wallpaperUrl != null) {
        try {
          await WallpaperService.setWallpaper(wallpaperUrl);
        } catch (e) {
          debugPrint('setWallpaper error: $e');
        } finally {
          // Close app silently after applying
          try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
        }
      }
      break;
    case 'RESET_WALLPAPER':
      try {
        await WallpaperService.resetWallpaper();
      } catch (e) {
        debugPrint('resetWallpaper error: $e');
      } finally {
        try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
      }
      break;
    case 'APP_UPDATE':
      try {
        final response = await SupabaseService.client
            .from('customer_app_versions')
            .select('app_url, version')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
            
        if (response != null && response['app_url'] != null) {
          final version = response['version'] ?? 'Unknown';
          await _adminChannel.invokeMethod('silentUpdate', {'url': response['app_url'], 'version': version});
        } else {
          debugPrint('APP_UPDATE error: No APK URL found in DB');
        }
      } catch (e) {
        debugPrint('silentUpdate error: $e');
      }
      break;
    default:
      debugPrint('Unknown FCM action: $action');
  }
}


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

  // Restore lock screen if device was locked in a previous session
  final prefs = await SharedPreferences.getInstance();
  final wasLocked = prefs.getBool('is_locked') ?? false;
  if (wasLocked && Platform.isAndroid) {
    try {
      await _adminChannel.invokeMethod('startKioskMode');
    } catch (_) {}
    // Small extra delay so the navigator is ready before we push
    await Future.delayed(const Duration(milliseconds: 300));
    navigateToLockScreen();
  }

  if (!Platform.isAndroid && !Platform.isIOS) return;

  // FIX 4: Supabase init runs here (network call — not blocking UI)
  await SupabaseService.initialize();

  // Background action execution
  if (prefs.getBool('action_fetch_sim') == true) {
    await prefs.remove('action_fetch_sim');
    await _handleFetchSim();
  }
  if (prefs.getBool('action_fetch_location') == true) {
    await prefs.remove('action_fetch_location');
    await _handleFetchLocation();
  }
  if (prefs.getBool('action_hide_app') == true) {
    await prefs.remove('action_hide_app');
    try {
      await _adminChannel.invokeMethod('hideAppIcon');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
    // Close app and remove from recents after hiding icon
    try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
  }
  if (prefs.getBool('action_unhide_app') == true) {
    await prefs.remove('action_unhide_app');
    try {
      await _adminChannel.invokeMethod('unhideApp');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
    // Close app and remove from recents after restoring icon
    try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
  }
  if (prefs.getBool('action_settle_emi') == true) {
    await prefs.remove('action_settle_emi');
    await _adminChannel.invokeMethod('removeDeviceOwner');
    await _adminChannel.invokeMethod('uninstallApp');
  }
  if (prefs.getBool('action_set_wallpaper') == true) {
    final url = prefs.getString('action_wallpaper_url');
    await prefs.remove('action_set_wallpaper');
    await prefs.remove('action_wallpaper_url');
    if (url != null) {
      try {
        await WallpaperService.setWallpaper(url);
      } catch (e) {
        debugPrint('Background setWallpaper error: $e');
      } finally {
        try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
      }
    }
  }
  if (prefs.getBool('action_reset_wallpaper') == true) {
    await prefs.remove('action_reset_wallpaper');
    try {
      await WallpaperService.resetWallpaper();
    } catch (e) {
      debugPrint('Background resetWallpaper error: $e');
    } finally {
      try { await _adminChannel.invokeMethod('finishAndRemoveTask'); } catch (_) {}
    }
  }
  if (prefs.getBool('action_app_update') == true) {
    await prefs.remove('action_app_update');
    try {
      final response = await SupabaseService.client
          .from('customer_app_versions')
          .select('app_url, version')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
          
      if (response != null && response['app_url'] != null) {
        final version = response['version'] ?? 'Unknown';
        await _adminChannel.invokeMethod('silentUpdate', {'url': response['app_url'], 'version': version});
      } else {
        debugPrint('Background silentUpdate error: No APK URL found in DB');
      }
    } catch (e) {
      debugPrint('Background silentUpdate error: $e');
    }
  }

  try {
    _adminChannel.setMethodCallHandler((call) async {
      if (call.method == 'logUpdateProgress') {
        final progress = call.arguments['progress'];
        final status = call.arguments['status'];
        final version = call.arguments['version'];
        debugPrint('🟢 SILENT UPDATE LOG | Version: $version | Status: $status | Progress: $progress%');
      }
    });
  } catch (e) {
    debugPrint('Error setting method call handler: $e');
  }

  // ── Native → Flutter event channel (SMS offline commands) ──────────────
  // Kotlin calls smsUnlock / smsLock on this channel when an SMS command
  // arrives. This makes offline SMS unlock follow the SAME flow as online
  // FCM unlock (handleLockAction), ensuring identical behaviour.
  try {
    const MethodChannel('emi_native_events').setMethodCallHandler((call) async {
      debugPrint('📲 emi_native_events received: ${call.method}');
      if (call.method == 'smsUnlock') {
        await handleLockAction('UNLOCK');
      } else if (call.method == 'smsLock') {
        await handleLockAction('LOCK');
      }
    });
  } catch (e) {
    debugPrint('Error setting emi_native_events handler: $e');
  }

  // FCM setup
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: false);

    if (Platform.isAndroid) {
      await _adminChannel.invokeMethod('createNotificationChannel');
    }

    // Register foreground handler AFTER Supabase is ready
    FirebaseMessaging.onMessage.listen((msg) => _handleFcmAction(msg.data));
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleFcmAction(msg.data));

    final fcmToken = await messaging.getToken();
    messaging.onTokenRefresh.listen((newToken) {
      SupabaseService.getOrCreateDeviceId(fcmToken: newToken);
    });

    // Sync device + FCM token to Supabase
    final deviceId = await SupabaseService.getOrCreateDeviceId(fcmToken: fcmToken);

    // Start app-level Realtime listener for policy changes on customer_service_table
    // Cancels old subscription first to avoid duplicates
    await _policyRealtimeSubscription?.cancel();
    if (deviceId == null) return;
    _policyRealtimeSubscription = SupabaseService.client
        .from('customer_service_table')
        .stream(primaryKey: ['customer_id'])
        .eq('customer_id', deviceId)
        .listen((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return;
          final row = rows.first;
          final allowFactoryReset = row['allow_factory_reset'] as bool? ?? false;
          final allowAdminRemoval = row['allow_admin_removal'] as bool? ?? false;
          final serviceAppHide = row['service_app_hide'] as bool? ?? false;

          // Apply Device Owner policies immediately when admin changes them
          applySecurityPolicies(
            allowFactoryReset: allowFactoryReset,
            allowAdminRemoval: allowAdminRemoval,
          );

          // Apply app icon hiding/unhiding immediately
          if (serviceAppHide) {
            _adminChannel.invokeMethod('hideAppIcon').catchError((e) => debugPrint('hideAppIcon error: $e'));
          } else {
            _adminChannel.invokeMethod('unhideApp').catchError((e) => debugPrint('unhideApp error: $e'));
          }
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
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('is_locked') ?? false;
    if (isLocked) {
      try {
        await _adminChannel.invokeMethod('startKioskMode');
      } catch (_) {}
      navigateToLockScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMI Device',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const SplashScreen(nextScreen: PermissionsScreen()),
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
      if (mounted) setState(() => _deviceId = id ?? 'Not Activated');
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
        overlayResult = true; // Overlay window no longer required — lock uses navigation
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
    // Overlay permission no longer required — lock screen uses Flutter navigation
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
