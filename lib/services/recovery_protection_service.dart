import 'package:flutter/services.dart';

class RecoveryProtectionService {
  static const platform = MethodChannel('com.example.customer_emi_app/admin');

  // Solution 1: OEM Unlock Disable
  static Future<bool> disableOemUnlock() async {
    try {
      final result = await platform.invokeMethod<bool>('disableOemUnlock') ?? false;
      print('✓ OEM Unlock disabled: $result');
      return result;
    } catch (e) {
      print('❌ Error in disableOemUnlock: $e');
      return false;
    }
  }

  // Solution 1: Recovery Mode Detection
  static Future<bool> isRecoveryModeDetected() async {
    try {
      final result = await platform.invokeMethod<bool>('isRecoveryModeDetected') ?? false;
      if (result) print('⚠️ Recovery mode detected!');
      return result;
    } catch (e) {
      print('❌ Error in isRecoveryModeDetected: $e');
      return false;
    }
  }

  // Solution 1: Start Monitoring
  static Future<void> startSecurityMonitoring() async {
    try {
      await platform.invokeMethod('startSecurityMonitoring');
      print('✓ Security monitoring started');
    } catch (e) {
      print('❌ Error in startSecurityMonitoring: $e');
    }
  }

  // Solution 2: Bootloader Lock
  static Future<bool> initBootloaderLock() async {
    try {
      final result = await platform.invokeMethod<bool>('initBootloaderLock') ?? false;
      print('✓ Bootloader lock initiated: $result');
      return result;
    } catch (e) {
      print('❌ Error in initBootloaderLock: $e');
      return false;
    }
  }

  // Solution 2: Bootloader Status
  static Future<bool> getBootloaderStatus() async {
    try {
      final result = await platform.invokeMethod<bool>('getBootloaderStatus') ?? false;
      print('Bootloader: ${result ? "LOCKED ✓" : "UNLOCKED ⚠️"}');
      return result;
    } catch (e) {
      print('❌ Error in getBootloaderStatus: $e');
      return false;
    }
  }
}
