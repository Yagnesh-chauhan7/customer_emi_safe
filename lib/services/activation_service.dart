import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// ──────────────────────────────────────────────
// State Class for Activation
// ──────────────────────────────────────────────
class ActivationState {
  final bool isLoading;
  final String? error;
  final bool isNetworkError; // true when error is due to no internet
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerImei1;
  final String? customerImei2;
  final String? customerSerial;
  final String? activationCode;
  final bool isActivated;

  ActivationState({
    this.isLoading = false,
    this.error,
    this.isNetworkError = false,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerImei1,
    this.customerImei2,
    this.customerSerial,
    this.activationCode,
    this.isActivated = false,
  });

  ActivationState copyWith({
    bool? isLoading,
    String? error,
    bool? isNetworkError,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerImei1,
    String? customerImei2,
    String? customerSerial,
    String? activationCode,
    bool? isActivated,
  }) {
    return ActivationState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Clear error if null passed intentionally, or just replace
      isNetworkError: isNetworkError ?? false,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerImei1: customerImei1 ?? this.customerImei1,
      customerImei2: customerImei2 ?? this.customerImei2,
      customerSerial: customerSerial ?? this.customerSerial,
      activationCode: activationCode ?? this.activationCode,
      isActivated: isActivated ?? this.isActivated,
    );
  }
}

// ──────────────────────────────────────────────
// Activation Notifier (Riverpod StateManagement)
// ──────────────────────────────────────────────
class ActivationNotifier extends Notifier<ActivationState> {
  @override
  ActivationState build() {
    return ActivationState();
  }

  final _supabase = Supabase.instance.client;
  final _channel = const MethodChannel('device_info_channel');

  /// Checks if the device has an active internet connection.
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the device's Serial Number and looks up the customer in Supabase.
  Future<void> fetchCustomerDetails() async {
    state = state.copyWith(isLoading: true, error: null, isNetworkError: false);

    try {
      if (!Platform.isAndroid) {
        state = state.copyWith(isLoading: false, error: "Only Android is supported.");
        return;
      }

      // ── Step 1: Check internet connectivity first ──────────────────────────
      final hasInternet = await _hasInternetConnection();
      if (!hasInternet) {
        state = state.copyWith(
          isLoading: false,
          error: "No internet connection. Please connect to Wi-Fi or mobile data and try again.",
          isNetworkError: true,
        );
        return;
      }

      // ── Step 2: Request phone permission & read Serial Number ──────────────
      final permissionStatus = await Permission.phone.request();
      if (!permissionStatus.isGranted) {
        state = state.copyWith(isLoading: false, error: "Phone permission denied.");
        return;
      }

      // Read Serial Number using native method channel
      String? serial;
      try {
        serial = await _channel.invokeMethod<String>('getSerial');
      } on PlatformException catch (e) {
        state = state.copyWith(isLoading: false, error: "Native error reading serial: ${e.message}");
        return;
      }

      if (serial == null || serial.isEmpty || serial.contains("Permission required") || serial.contains("Unavailable")) {
        state = state.copyWith(isLoading: false, error: "Could not read Serial Number ($serial).");
        return;
      }

      // ── Step 3: Query Supabase ─────────────────────────────────────────────
      try {
        final response = await _supabase
            .from('customer_table')
            .select(
              'customer_id, customer_name, customer_phone, customer_email, '
              'customer_imei1, customer_imei2, customer_serial, '
              'activaction_code, is_device_active',
            )
            .eq('customer_serial', serial)
            .maybeSingle();

        if (response == null) {
          state = state.copyWith(
            isLoading: false,
            error: "No customer found for this device's Serial Number ($serial).",
          );
          return;
        }

        state = state.copyWith(
          isLoading: false,
          customerId: response['customer_id'] as String?,
          customerName: response['customer_name'] as String?,
          customerPhone: response['customer_phone'] as String?,
          customerEmail: response['customer_email'] as String?,
          customerImei1: response['customer_imei1'] as String?,
          customerImei2: response['customer_imei2'] as String?,
          customerSerial: response['customer_serial'] as String?,
          activationCode: response['activaction_code'] as String?,
          isActivated: response['is_device_active'] == true,
        );
      } on SocketException {
        // Network dropped mid-request
        state = state.copyWith(
          isLoading: false,
          error: "Network lost during request. Please check your connection and retry.",
          isNetworkError: true,
        );
      }
    } catch (e) {
      final isSocket = e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated');
      state = state.copyWith(
        isLoading: false,
        error: isSocket
            ? "No internet connection. Please connect to Wi-Fi or mobile data and try again."
            : "Error fetching details: $e",
        isNetworkError: isSocket,
      );
    }
  }

  /// Activates the device by updating the database.
  Future<void> activateDevice() async {
    if (state.customerId == null || state.isActivated) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Gather device information
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      final deviceName = androidInfo.brand;
      final deviceModel = androidInfo.model;
      final androidVersion = androidInfo.version.release;
      final deviceFingerprint = androidInfo.fingerprint;

      // 2. Insert into device_detail_table
      await _supabase.from('device_detail_table').insert({
        'customer_id': state.customerId,
        'activaction_code': state.activationCode,
        'device_name': deviceName,
        'device_model': deviceModel,
        'android_version': androidVersion,
        'device_fingerprint': deviceFingerprint,
      });

      // 3. Update customer_table
      await _supabase
          .from('customer_table')
          .update({'is_device_active': true})
          .eq('customer_id', state.customerId!);

      // 4. Update local state
      state = state.copyWith(isLoading: false, isActivated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Activation failed: $e");
    }
  }
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────
final activationProvider = NotifierProvider<ActivationNotifier, ActivationState>(() {
  return ActivationNotifier();
});
