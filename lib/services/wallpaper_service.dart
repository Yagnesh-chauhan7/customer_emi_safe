import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles saving and restoring wallpapers for the app's lock screen.
class WallpaperService {
  /// Saves the wallpaper at [url] to SharedPreferences.
  static Future<void> setWallpaper(String url) async {
    debugPrint('[WallpaperService] Setting lock screen wallpaper URL: $url');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lock_screen_wallpaper_url', url);
  }

  /// Removes the custom wallpaper from SharedPreferences.
  static Future<void> resetWallpaper() async {
    debugPrint('[WallpaperService] Resetting lock screen wallpaper to original');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lock_screen_wallpaper_url');
  }
}
