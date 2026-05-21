import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceInfoService {
  static const _ch = MethodChannel('device_info_channel');

  static Future<Map<String, dynamic>> getAllInfo() async {
    try {
      final result = await _ch.invokeMethod('getAllInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error: $e');
      return {'error': e.toString()};
    }
  }

  static Future<List<String>> getImeiList() async {
    try {
      final result = await _ch.invokeMethod<List>('getImeiList');
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getSimDetails() async {
    try {
      final result = await _ch.invokeMethod<List>('getSimDetails');
      return result
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }

  static Future<String> getSerialNumber() async {
    try {
      return await _ch.invokeMethod<String>('getSerial') ?? 'Unavailable';
    } catch (_) {
      return 'Unavailable';
    }
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _ch.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {};
    }
  }
}
