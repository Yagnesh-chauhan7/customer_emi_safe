import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SmsLockService {
  static const _channel = MethodChannel('sms_lock_channel');

  /// Lock command format:   EMI_LOCK#<code>
  /// Unlock command format: EMI_UNLOCK#<code>
  static const lockPrefix   = 'EMI_LOCK#';
  static const unlockPrefix = 'EMI_UNLOCK#';

  /// Get the currently stored secret code (null if not set yet)
  static Future<String?> getSecretCode() async {
    try {
      return await _channel.invokeMethod<String>('getSecretCode');
    } catch (_) {
      return null;
    }
  }

  /// Save a custom secret code
  static Future<bool> setSecretCode(String code) async {
    try {
      await _channel.invokeMethod('setSecretCode', {'code': code});
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      return false;
    }
  }

  /// Auto-generate a random 6-digit code and save it
  static Future<String?> generateSecretCode() async {
    try {
      return await _channel.invokeMethod<String>('generateSecretCode');
    } catch (_) {
      return null;
    }
  }

  /// Returns the full SMS text to send to lock the device
  static String buildLockSms(String code) => '$lockPrefix$code';

  /// Returns the full SMS text to send to unlock the device
  static String buildUnlockSms(String code) => '$unlockPrefix$code';
}
