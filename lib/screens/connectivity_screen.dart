import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  bool _wifiEnabled = false;
  bool _mobileDataEnabled = false;
  bool _bluetoothEnabled = false;
  bool _locationEnabled = false;

  bool _loadingWifi = false;
  bool _loadingMobileData = false;
  bool _loadingBluetooth = false;
  bool _loadingLocation = false;

  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _initialLoading = true);

    final results = await Future.wait([
      ConnectivityService.getWifiStatus(),
      ConnectivityService.getMobileDataStatus(),
      ConnectivityService.getBluetoothStatus(),
      ConnectivityService.getLocationStatus(),
    ]);

    if (mounted) {
      setState(() {
        _wifiEnabled = results[0]['enabled'] == true;
        _mobileDataEnabled = results[1]['enabled'] == true;
        _bluetoothEnabled = results[2]['enabled'] == true;
        _locationEnabled = results[3]['enabled'] == true;
        _initialLoading = false;
      });
    }
  }

  Future<void> _toggle(
    String label,
    bool currentValue,
    Future<Map<String, dynamic>> Function(bool) toggler,
    void Function(bool) onUpdate,
    void Function(bool) setLoading,
  ) async {
    setLoading(true);
    final result = await toggler(!currentValue);
    setLoading(false);

    if (result['success'] == true) {
      // Optimistic update — do NOT call _refreshAll() immediately.
      // Hardware state changes (BT, WiFi) are async and take 1-3 seconds.
      // Calling _refreshAll() now would overwrite the correct new state.
      onUpdate(!currentValue);
      _showSnackbar('$label ${!currentValue ? "enabled" : "disabled"} ✓',
          isError: false);
    } else if (result['openSettings'] == true) {
      // Settings panel was opened — refresh after short delay to pick up change
      _showSnackbar('$label: ${result["error"] ?? "Settings opened"}',
          isError: false);
      await Future.delayed(const Duration(seconds: 2));
      await _refreshAll();
    } else {
      _showSnackbar('$label: ${result["error"] ?? "Unknown error"}',
          isError: true);
      // Refresh to restore correct state on failure
      await _refreshAll();
    }
  }

  void _showSnackbar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Device Connectivity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh status',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: _initialLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildCard(
                    icon: Icons.wifi,
                    label: 'WiFi',
                    subtitle: 'Toggle wireless network access',
                    color: const Color(0xFF00C9FF),
                    enabled: _wifiEnabled,
                    loading: _loadingWifi,
                    onToggle: () => _toggle(
                      'WiFi',
                      _wifiEnabled,
                      ConnectivityService.setWifiEnabled,
                      (v) => setState(() => _wifiEnabled = v),
                      (l) => setState(() => _loadingWifi = l),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.signal_cellular_alt,
                    label: 'Mobile Data',
                    subtitle: 'Toggle cellular internet connection',
                    color: const Color(0xFF00E5A0),
                    enabled: _mobileDataEnabled,
                    loading: _loadingMobileData,
                    onToggle: () => _toggle(
                      'Mobile Data',
                      _mobileDataEnabled,
                      ConnectivityService.setMobileDataEnabled,
                      (v) => setState(() => _mobileDataEnabled = v),
                      (l) => setState(() => _loadingMobileData = l),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.bluetooth,
                    label: 'Bluetooth',
                    subtitle: 'Toggle Bluetooth radio',
                    color: const Color(0xFF5E8BFF),
                    enabled: _bluetoothEnabled,
                    loading: _loadingBluetooth,
                    onToggle: () => _toggle(
                      'Bluetooth',
                      _bluetoothEnabled,
                      ConnectivityService.setBluetoothEnabled,
                      (v) => setState(() => _bluetoothEnabled = v),
                      (l) => setState(() => _loadingBluetooth = l),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.location_on,
                    label: 'Location',
                    subtitle: 'Toggle GPS & location services',
                    color: const Color(0xFFFF6B6B),
                    enabled: _locationEnabled,
                    loading: _loadingLocation,
                    onToggle: () => _toggle(
                      'Location',
                      _locationEnabled,
                      ConnectivityService.setLocationEnabled,
                      (v) => setState(() => _locationEnabled = v),
                      (l) => setState(() => _loadingLocation = l),
                    ),
                  ),
                  const Spacer(),
                  _buildNote(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D5BF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_input_antenna, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connectivity Control',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Manage device radio & location settings',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool enabled,
    required bool loading,
    required VoidCallback onToggle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: enabled
            ? color.withValues(alpha: 0.12)
            : const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.5) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.25) : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: enabled ? color : Colors.white38,
            size: 26,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: loading
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            : Switch(
                value: enabled,
                onChanged: (_) => onToggle(),
                activeThumbColor: color,
                activeTrackColor: color.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
              ),
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'WiFi, Mobile Data & Location require Device Owner permission.\n'
              'Bluetooth toggle on Android 13+ requires manual Settings access.',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
