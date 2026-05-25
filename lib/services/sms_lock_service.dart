import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SmsLockService {
  static const _channel = MethodChannel('sms_lock_channel');

  /// Get the currently stored AES secret key
  static Future<String?> getSmsKey() async {
    try {
      return await _channel.invokeMethod<String>('getSmsKey');
    } catch (_) {
      return null;
    }
  }

  /// Save the 32-character AES secret key to native SharedPreferences
  static Future<bool> saveSmsKey(String key) async {
    try {
      await _channel.invokeMethod('saveSmsKey', {'key': key});
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      return false;
    }
  }
}
