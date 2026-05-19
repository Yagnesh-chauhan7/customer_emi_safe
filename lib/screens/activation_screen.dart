import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../services/activation_service.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch customer details based on IMEI as soon as screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activationProvider.notifier).fetchCustomerDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activationState = ref.watch(activationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Device Activation',
          style: TextStyle(
            color: AppColors.mainText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shield Icon / Branding
            const Center(
              child: Icon(
                Icons.verified_user_rounded,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Activate Your Device',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Your device is currently locked. Please activate to continue using all features.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            const SizedBox(height: 32),

            if (activationState.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          activationState.isNetworkError
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activationState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    if (activationState.isNetworkError) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: activationState.isLoading
                              ? null
                              : () => ref
                                    .read(activationProvider.notifier)
                                    .fetchCustomerDetails(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Activation Code Section (Read-only)
            _buildSectionLabel('ACTIVATION CODE'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child:
                    activationState.isLoading &&
                        activationState.activationCode == null
                    ? const CircularProgressIndicator()
                    : Text(
                        activationState.activationCode ?? "Not Found",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Customer Details Section (Read-only)
            _buildSectionLabel('CUSTOMER DETAILS'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  activationState.isLoading &&
                      activationState.customerName == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.person_rounded,
                          label: 'Name',
                          value: activationState.customerName ?? 'N/A',
                        ),
                        _buildDivider(),
                        _buildDetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Phone',
                          value: activationState.customerPhone ?? 'N/A',
                        ),
                        _buildDivider(),
                        _buildDetailRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: activationState.customerEmail ?? 'N/A',
                        ),
                        _buildDivider(),
                        _buildDetailRow(
                          icon: Icons.sim_card_rounded,
                          label: 'IMEI 1',
                          value: activationState.customerImei1 ?? 'N/A',
                          monospace: true,
                        ),
                        _buildDivider(),
                        _buildDetailRow(
                          icon: Icons.sim_card_outlined,
                          label: 'IMEI 2',
                          value: activationState.customerImei2 ?? 'N/A',
                          monospace: true,
                        ),
                        _buildDivider(),
                        _buildDetailRow(
                          icon: Icons.perm_device_info_rounded,
                          label: 'Serial',
                          value: activationState.customerSerial ?? 'N/A',
                          monospace: true,
                        ),
                        _buildDivider(),
                        _buildStatusRow(
                          isActivated: activationState.isActivated,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),

            // Buttons
            ElevatedButton(
              onPressed:
                  (activationState.isLoading ||
                      activationState.isActivated ||
                      activationState.customerId == null)
                  ? null
                  : () async {
                      await ref
                          .read(activationProvider.notifier)
                          .activateDevice();
                      if (mounted &&
                          ref.read(activationProvider).error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device Activated Successfully!'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.5,
                ),
              ),
              child: activationState.isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      activationState.isActivated
                          ? 'ACTIVATED'
                          : 'ACTIVATE NOW',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Hide App Logic
              },
              icon: const Icon(Icons.visibility_off_rounded, size: 20),
              label: const Text('HIDE APP'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Remove Device Admin ────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _confirmRemoveDeviceOwner(context),
              icon: const Icon(Icons.shield_outlined, size: 20),
              label: const Text('REMOVE DEVICE ADMIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Remove Device Owner logic ──────────────────────────────────────────

  static const _adminChannel = MethodChannel(
    'com.example.customer_emi_app/admin',
  );

  Future<void> _confirmRemoveDeviceOwner(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Remove Device Admin?'),
          ],
        ),
        content: const Text(
          'This will remove Device Owner / Device Admin status from this app.\n\n'
          'All kiosk restrictions and security policies will be cleared. '
          'The app can then be uninstalled normally.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _removeDeviceOwner(context);
    }
  }

  Future<void> _removeDeviceOwner(BuildContext context) async {
    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text('Removing device admin…'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final result = await _adminChannel.invokeMethod<bool>(
        'removeDeviceOwner',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Device admin removed successfully.'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App was not a Device Admin — nothing to remove.'),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.mainText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
                letterSpacing: monospace ? 0.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: AppColors.border);
  }

  Widget _buildStatusRow({required bool isActivated}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(
            isActivated ? Icons.verified_rounded : Icons.lock_clock_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActivated
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActivated
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.amber.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              isActivated ? 'Activated' : 'Pending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActivated
                    ? Colors.green.shade700
                    : Colors.amber.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.secondaryText,
        letterSpacing: 1.5,
      ),
    );
  }
}
