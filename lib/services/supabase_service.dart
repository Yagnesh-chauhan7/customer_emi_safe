import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
      
      // Get device name
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceName = "${androidInfo.brand} ${androidInfo.model}";

      // Register device in Supabase
      try {
        await client.from('devices').insert({
          'id': deviceId,
          'device_name': deviceName,
          'is_locked': false,
          'last_seen': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print("Failed to register device: $e");
      }
    } else {
      // Update last seen
      try {
        await client.from('devices').update({
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', deviceId);
      } catch (e) {
        print("Failed to update last seen: $e");
      }
    }

    return deviceId;
  }
}
