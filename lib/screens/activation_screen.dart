import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'lock_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  // Static data for demonstration (usually comes from server/local storage)
  final String _activationCode = "SAFE-8829-EMI";
  final Map<String, String> _customerDetails = {
    "Name": "Yagnesh Chauhan",
    "Phone": "+91 9725250740",
    "IMEI 1": "358291048271034",
    "Device": "Samsung Galaxy A54",
    "Status": "Pending Activation",
  };

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  _activationCode,
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
              child: Column(
                children: _customerDetails.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            color: AppColors.mainText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),

            // Buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LockScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'ACTIVATE NOW',
                style: TextStyle(
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
