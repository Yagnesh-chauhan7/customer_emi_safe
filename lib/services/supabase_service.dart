import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SupabaseService {
  static const supabaseUrl = 'https://wxulcmnhsdxgrnvxkmkv.supabase.co';
  static const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4dWxjbW5oc2R4Z3JudnhrbWt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NDIwMjEsImV4cCI6MjA5MzIxODAyMX0.rzkK6wkWfJuXX6cpWV2GWvd4saUo6TNw-oYxky-QGLw';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<String> getOrCreateDeviceId({String? fcmToken}) async {
    final androidIdPlugin = const AndroidId();
    String? rawHardwareId = await androidIdPlugin.getId();
    
    // Postgres 'uuid' columns strictly require the standard UUID format.
    // The Android ID is 16 hex characters. We pad it with 0s and insert hyphens.
    String? hardwareId;
    if (rawHardwareId != null && rawHardwareId.length >= 16) {
      final hex = rawHardwareId.padRight(32, '0');
      hardwareId = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = hardwareId ?? prefs.getString('device_id');

    if (deviceId == null) {
      // Fallback: Generate a random UUID-like string based on current time
      final timeHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padRight(32, '0');
      deviceId = '${timeHex.substring(0, 8)}-${timeHex.substring(8, 12)}-${timeHex.substring(12, 16)}-${timeHex.substring(16, 20)}-${timeHex.substring(20, 32)}';
    }
    await prefs.setString('device_id', deviceId);

    // Get device name
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final deviceName = "${androidInfo.brand} ${androidInfo.model}";

    // Check if device exists
    try {
      final existing = await client.from('devices').select().eq('id', deviceId).maybeSingle();

      if (existing == null) {
        // Register new device
        await client.from('devices').insert({
          'id': deviceId,
          'device_name': deviceName,
          'is_locked': false,
          'fcm_token': fcmToken,
          'last_seen': DateTime.now().toIso8601String(),
        });
      } else {
        // Update last seen and FCM token if changed
        final updateData = {
          'last_seen': DateTime.now().toIso8601String(),
        };
        if (fcmToken != null) {
          updateData['fcm_token'] = fcmToken;
        }
        await client.from('devices').update(updateData).eq('id', deviceId);
      }
    } catch (e) {
      print("Failed to sync device with Supabase: $e");
    }

    return deviceId;
  }
}
