import 'package:flutter/material.dart';
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
                style: TextStyle(
                  color: AppColors.secondaryText,
                ),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activationState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
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
                child: activationState.isLoading && activationState.activationCode == null
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
              child: activationState.isLoading && activationState.customerName == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _buildDetailRow("Name", activationState.customerName ?? "N/A"),
                        _buildDetailRow("Status", activationState.isActivated ? "Activated" : "Pending Activation"),
                      ],
                    ),
            ),
            const SizedBox(height: 40),

            // Buttons
            ElevatedButton(
              onPressed: (activationState.isLoading || 
                          activationState.isActivated || 
                          activationState.customerId == null)
                  ? null
                  : () async {
                      await ref.read(activationProvider.notifier).activateDevice();
                      if (mounted && ref.read(activationProvider).error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device Activated Successfully!')),
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
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
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
                      activationState.isActivated ? 'ACTIVATED' : 'ACTIVATE NOW',
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.mainText,
              fontWeight: FontWeight.bold,
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
