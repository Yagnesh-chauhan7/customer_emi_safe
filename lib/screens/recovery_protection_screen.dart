import 'package:flutter/material.dart';
import '../services/recovery_protection_service.dart';

class RecoveryProtectionScreen extends StatefulWidget {
  const RecoveryProtectionScreen({super.key});

  @override
  State<RecoveryProtectionScreen> createState() => _RecoveryProtectionScreenState();
}

class _RecoveryProtectionScreenState extends State<RecoveryProtectionScreen> {
  bool isOemUnlockDisabled = false;
  bool isBootloaderLocked = false;
  bool isMonitoringActive = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkSecurityStatus();
  }

  Future<void> checkSecurityStatus() async {
    try {
      final oemStatus = await RecoveryProtectionService.disableOemUnlock();
      final btStatus = await RecoveryProtectionService.getBootloaderStatus();

      if (mounted) {
        setState(() {
          isOemUnlockDisabled = oemStatus;
          isBootloaderLocked = btStatus;
          isMonitoringActive = true;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Security Status')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Protection'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(
                isOemUnlockDisabled ? Icons.lock : Icons.lock_open,
                color: isOemUnlockDisabled ? Colors.green : Colors.red,
                size: 32,
              ),
              title: const Text('OEM Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isOemUnlockDisabled ? 'Disabled ✓' : 'Enabled ⚠️'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(
                isMonitoringActive ? Icons.visibility : Icons.visibility_off,
                color: isMonitoringActive ? Colors.green : Colors.grey,
                size: 32,
              ),
              title: const Text('Security Monitoring', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isMonitoringActive ? 'Active ✓' : 'Inactive ⚠️'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(
                isBootloaderLocked ? Icons.verified : Icons.warning,
                color: isBootloaderLocked ? Colors.green : Colors.orange,
                size: 32,
              ),
              title: const Text('Bootloader Status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isBootloaderLocked ? 'Locked ✓' : 'Unlocked ⚠️'),
            ),
          ),
          const SizedBox(height: 32),
          if (!isBootloaderLocked)
            ElevatedButton.icon(
              onPressed: () async {
                final success = await RecoveryProtectionService.initBootloaderLock();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success 
                        ? 'Bootloader lock initialization started' 
                        : 'Failed to initialize bootloader lock'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.shield),
              label: const Text('Setup Bootloader Lock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: checkSecurityStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Status'),
          ),
        ],
      ),
    );
  }
}



