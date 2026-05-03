import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide NotificationVisibility;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'supabase_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'emi_service', // id
    'EMI Security Service', // title
    description: 'This channel is used for monitoring device lock status.', // description
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'emi_service',
      initialNotificationTitle: 'EMI Security Active',
      initialNotificationContent: 'Monitoring device status',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase in the isolate
  await SupabaseService.initialize();
  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString('device_id');

  if (deviceId == null) return;

  const platform = MethodChannel('com.example.customer_emi_app/admin');

  SupabaseService.client
      .from('devices')
      .stream(primaryKey: ['id'])
      .eq('id', deviceId)
      .listen((List<Map<String, dynamic>> data) async {
    if (data.isNotEmpty) {
      final isLocked = data.first['is_locked'] == true;
      
      if (isLocked) {
        // Show Overlay
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
        
        // Trigger Kiosk Mode
        try {
          await platform.invokeMethod('startKioskMode');
        } catch (e) {
          print("Failed to start kiosk from bg: $e");
        }
      } else {
        // Hide Overlay
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
        
        // Stop Kiosk Mode
        try {
          await platform.invokeMethod('stopKioskMode');
        } catch (e) {
          print("Failed to stop kiosk from bg: $e");
        }
      }
    }
  });

  // Keep the service alive and update last seen occasionally
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    try {
      await SupabaseService.client.from('devices').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', deviceId);
    } catch (e) {}
  });
}
