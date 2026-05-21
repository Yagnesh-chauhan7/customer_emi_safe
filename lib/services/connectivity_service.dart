import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static const MethodChannel _channel = MethodChannel('connectivity_channel');

  // ─────────────── WIFI ───────────────

  /// Returns {'success': bool, 'enabled': bool}
  static Future<Map<String, dynamic>> getWifiStatus() async {
    try {
      final result = await _channel.invokeMethod('getWifiStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString(), 'enabled': false};
    }
  }

  /// [enabled] = true to turn WiFi ON, false to turn OFF
  static Future<Map<String, dynamic>> setWifiEnabled(bool enabled) async {
    try {
      final result =
          await _channel.invokeMethod('setWifiEnabled', {'enabled': enabled});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────── MOBILE DATA ───────────────

  /// Returns {'success': bool, 'enabled': bool}
  static Future<Map<String, dynamic>> getMobileDataStatus() async {
    try {
      final result = await _channel.invokeMethod('getMobileDataStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString(), 'enabled': false};
    }
  }

  /// [enabled] = true to turn Mobile Data ON, false to turn OFF
  static Future<Map<String, dynamic>> setMobileDataEnabled(
      bool enabled) async {
    try {
      final result = await _channel
          .invokeMethod('setMobileDataEnabled', {'enabled': enabled});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────── BLUETOOTH ───────────────

  /// Returns {'success': bool, 'enabled': bool, 'supported': bool}
  static Future<Map<String, dynamic>> getBluetoothStatus() async {
    try {
      final result = await _channel.invokeMethod('getBluetoothStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'enabled': false,
        'supported': false
      };
    }
  }

  /// [enabled] = true to turn Bluetooth ON, false to turn OFF
  static Future<Map<String, dynamic>> setBluetoothEnabled(bool enabled) async {
    try {
      final result = await _channel
          .invokeMethod('setBluetoothEnabled', {'enabled': enabled});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────── LOCATION ───────────────

  /// Returns {'success': bool, 'enabled': bool}
  static Future<Map<String, dynamic>> getLocationStatus() async {
    try {
      final result = await _channel.invokeMethod('getLocationStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString(), 'enabled': false};
    }
  }

  /// [enabled] = true to turn Location ON, false to turn OFF
  static Future<Map<String, dynamic>> setLocationEnabled(bool enabled) async {
    try {
      final result = await _channel
          .invokeMethod('setLocationEnabled', {'enabled': enabled});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
