import 'package:flutter/services.dart';

class FRPService {
  static const MethodChannel _channel = MethodChannel('frp_channel');

  /// Enables FRP with the given list of Google accounts.
  static Future<Map<String, dynamic>> enableFRP(List<String> accounts) async {
    try {
      final result = await _channel.invokeMethod('enableFRP', {'accounts': accounts});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Disables FRP.
  static Future<Map<String, dynamic>> disableFRP() async {
    try {
      final result = await _channel.invokeMethod('disableFRP');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Gets the current FRP status and accounts.
  static Future<Map<String, dynamic>> getFRPStatus() async {
    try {
      final result = await _channel.invokeMethod('getFRPStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'status': false};
    }
  }
}
