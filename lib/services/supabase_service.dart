import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<String?> getOrCreateDeviceId({String? fcmToken}) async {
    final prefs = await SharedPreferences.getInstance();
    String? customerId = prefs.getString('customer_id');

    if (customerId == null) {
      // Try to recover customer_id using device serial
      try {
        const channel = MethodChannel('device_info_channel');
        final serial = await channel.invokeMethod<String>('getSerial');
        if (serial != null && serial.isNotEmpty && !serial.contains("Permission") && !serial.contains("Unavailable")) {
          final response = await client
              .from('customer_table')
              .select('customer_id')
              .eq('customer_serial', serial)
              .maybeSingle();
          if (response != null) {
            customerId = response['customer_id'] as String?;
            if (customerId != null) {
              await prefs.setString('customer_id', customerId);
            }
          }
        }
      } catch (e) {
        print("Error recovering customer_id: $e");
      }
    }

    // Update FCM token if provided
    if (customerId != null && fcmToken != null) {
      try {
        await client
            .from('customer_table')
            .update({'fcm_token': fcmToken})
            .eq('customer_id', customerId);
      } catch (e) {
        print("Failed to sync FCM token: $e");
      }
    }

    return customerId;
  }
}
