import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SmsLockScreen extends StatelessWidget {
  const SmsLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offline Control'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Offline Security Active',
              style: TextStyle(
                color: AppColors.mainText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This device is protected by advanced offline security protocols.\n\n'
              'If the device loses internet connection, your administrator can still manage and secure the device using encrypted offline commands.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AES-256 Encryption Enabled\nReplay-Attack Protection Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
