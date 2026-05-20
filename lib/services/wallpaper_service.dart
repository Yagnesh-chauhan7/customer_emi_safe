import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';

/// Handles downloading, applying, saving, and restoring wallpapers
/// on the customer device via the Kotlin WallpaperReceiver Broadcasts.
class WallpaperService {
  /// Downloads the wallpaper at [url], then sends a broadcast
  /// to set the new wallpaper on the device.
  static Future<void> setWallpaper(String url) async {
    debugPrint('[WallpaperService] Setting wallpaper from: $url');

    // Download image bytes from Supabase Storage public URL
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Failed to download wallpaper (HTTP ${response.statusCode})');
    }
    final Uint8List bytes = response.bodyBytes;

    // 3. Write to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/active_wallpaper.jpg');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[WallpaperService] Downloaded ${bytes.length} bytes → ${file.path}');

    // 4. Apply via Kotlin WallpaperReceiver Broadcast
    final intent = AndroidIntent(
      action: 'com.example.customer_emi_app.SET_WALLPAPER',
      package: 'com.example.customer_emi_app',
      arguments: {'filePath': file.path},
    );
    await intent.sendBroadcast();
    debugPrint('[WallpaperService] Broadcast SET_WALLPAPER sent');
  }

  /// Restores the wallpaper saved before the custom one was applied.
  /// Falls back to system default if no backup exists.
  static Future<void> resetWallpaper() async {
    debugPrint('[WallpaperService] Resetting wallpaper to original');
    final intent = const AndroidIntent(
      action: 'com.example.customer_emi_app.RESET_WALLPAPER',
      package: 'com.example.customer_emi_app',
    );
    await intent.sendBroadcast();
    debugPrint('[WallpaperService] Broadcast RESET_WALLPAPER sent');
    
    // Clean up downloaded file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/active_wallpaper.jpg');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
