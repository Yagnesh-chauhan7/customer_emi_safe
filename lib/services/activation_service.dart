import 'package:customer_emi_app/services/device_info_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:device_information/device_information.dart';
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
  final String? customerId;
  final String? customerName;
  final String? activationCode;
  final bool isActivated;

  ActivationState({
    this.isLoading = false,
    this.error,
    this.customerId,
    this.customerName,
    this.activationCode,
    this.isActivated = false,
  });

  ActivationState copyWith({
    bool? isLoading,
    String? error,
    String? customerId,
    String? customerName,
    String? activationCode,
    bool? isActivated,
  }) {
    return ActivationState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Clear error if null passed intentionally, or just replace
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
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

  /// Fetches the device's IMEI and looks up the customer in Supabase.
  Future<void> fetchCustomerDetails() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (!Platform.isAndroid) {
        state = state.copyWith(isLoading: false, error: "Only Android is supported.");
        return;
      }

      // Request phone state permission required to read IMEI
      final permissionStatus = await Permission.phone.request();
      if (!permissionStatus.isGranted) {
        state = state.copyWith(isLoading: false, error: "Phone permission denied.");
        return;
      }
      final all = await DeviceInfoService.getAllInfo();

      // Read IMEI using device_information package
      final imei = List<String>.from(all['imeiList'] ?? []);
      if (imei == null || imei.isEmpty) {
        state = state.copyWith(isLoading: false, error: "Could not read IMEI.");
        return;
      }

      // Query Supabase for customer matching this IMEI
      final response = await _supabase
          .from('customer_table')
          .select('customer_id, customer_name, activaction_code, is_device_active')
          .or('customer_imei1.eq.$imei,customer_imei2.eq.$imei')
          .maybeSingle();

      if (response == null) {
        state = state.copyWith(isLoading: false, error: "No customer found for this device's IMEI ($imei).");
        return;
      }

      state = state.copyWith(
        isLoading: false,
        customerId: response['customer_id'] as String?,
        customerName: response['customer_name'] as String?,
        activationCode: response['activaction_code'] as String?,
        isActivated: response['is_device_active'] == true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Error fetching details: $e");
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
