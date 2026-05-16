import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:barcode_widget/barcode_widget.dart';
import 'activation_screen.dart';
import '../services/device_info_service.dart';
import '../theme/app_colors.dart';

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  bool _loading = true;
  bool _permissionGranted = false;
  bool _permissionDeniedForever = false;

  List<String> _imeiList = [];
  String _serial = '';
  List<Map<String, dynamic>> _simList = [];
  Map<String, dynamic> _deviceInfo = {};

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  // ─── Permission Flow ────────────────────────────────────────────
  Future<void> _checkAndRequestPermissions() async {
    setState(() => _loading = true);

    final phoneState  = await Permission.phone.status;
    final phoneNumber = await Permission.phone.status; // READ_PHONE_NUMBERS maps to phone group

    if (phoneState.isGranted) {
      setState(() => _permissionGranted = true);
      await _loadAll();
      return;
    }

    if (phoneState.isPermanentlyDenied) {
      setState(() {
        _permissionDeniedForever = true;
        _loading = false;
      });
      return;
    }

    // Request permissions
    final results = await [
      Permission.phone,
    ].request();

    final granted = results[Permission.phone] == PermissionStatus.granted;

    if (granted) {
      setState(() => _permissionGranted = true);
      await _loadAll();
    } else if (results[Permission.phone] == PermissionStatus.permanentlyDenied) {
      setState(() {
        _permissionDeniedForever = true;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final all = await DeviceInfoService.getAllInfo();
    setState(() {
      _imeiList   = List<String>.from(all['imeiList'] ?? []);
      _serial     = all['serialNumber']?.toString() ?? 'Unavailable';
      _simList    = (all['simDetails'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _deviceInfo = Map<String, dynamic>.from(all['deviceInfo'] ?? {});
      _loading    = false;
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Copied to clipboard'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 1),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        title: const Text('Device Information',
            style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.mainText),
        actions: [
          if (_permissionGranted)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
              onPressed: _loadAll,
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBottomBar() {
    if (!_permissionGranted) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivationScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Next: Activation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    // Permanently denied → show open-settings card
    if (_permissionDeniedForever) {
      return _buildPermissionCard(
        title: 'Permission Permanently Denied',
        subtitle:
            'READ_PHONE_STATE was denied permanently. Open App Settings to grant it manually.',
        buttonLabel: 'Open App Settings',
        buttonIcon: Icons.settings,
        onPressed: openAppSettings,
        color: Colors.redAccent,
      );
    }

    // Not yet granted (denied once)
    if (!_permissionGranted) {
      return _buildPermissionCard(
        title: 'Phone Permission Required',
        subtitle:
            'To show IMEI, SIM details, and Serial Number, the app needs READ_PHONE_STATE permission.',
        buttonLabel: 'Grant Permission',
        buttonIcon: Icons.security,
        onPressed: _checkAndRequestPermissions,
        color: AppColors.primary,
      );
    }

    // Permissions granted — show data
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceHeader(),
          const SizedBox(height: 16),

          _sectionTitle(Icons.smartphone, 'IMEI Number(s)', AppColors.primary),
          const SizedBox(height: 8),
          if (_imeiList.isEmpty)
            _buildWarningCard('IMEI not available on this device.')
          else
            ..._imeiList.asMap().entries.map((e) => _buildImeiCard(e.key + 1, e.value)),

          const SizedBox(height: 16),
          _sectionTitle(Icons.memory, 'Serial Number', AppColors.success),
          const SizedBox(height: 8),
          _buildCopyCard(icon: Icons.numbers, value: _serial, color: AppColors.success),

          const SizedBox(height: 16),
          _sectionTitle(Icons.sim_card, 'SIM Card Details', AppColors.danger),
          const SizedBox(height: 8),
          if (_simList.isEmpty)
            _buildWarningCard('No active SIM cards found.')
          else
            ..._simList.map((sim) => _buildSimCard(sim)),

          const SizedBox(height: 16),
          _sectionTitle(Icons.info_outline, 'Device Build Info', AppColors.secondaryText),
          const SizedBox(height: 8),
          _buildDeviceBuildCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Permission UI ────────────────────────────────────────────────
  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sim_card_alert, color: color, size: 40),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.mainText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.6)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(buttonIcon),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Data Cards ───────────────────────────────────────────────────
  Widget _buildDeviceHeader() {
    final brand   = _deviceInfo['brand']?.toString() ?? '';
    final model   = _deviceInfo['model']?.toString() ?? '';
    final android = _deviceInfo['androidVersion']?.toString() ?? '';
    final sdk     = _deviceInfo['sdkInt']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3D5BF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(children: [
        const Icon(Icons.phone_android, color: Colors.white, size: 48),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$brand $model',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Android $android  •  API $sdk',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _buildImeiCard(int slot, String imei) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00C9FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('SIM\n$slot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
            title: const Text('IMEI', style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
            subtitle: Text(imei,
                style: const TextStyle(
                    color: AppColors.mainText, fontSize: 15, fontFamily: 'monospace',
                    fontWeight: FontWeight.w600, letterSpacing: 1)),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
              onPressed: () => _copy(imei),
            ),
          ),
          if (imei.isNotEmpty && imei != 'Unavailable')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: imei,
                height: 50,
                width: double.infinity,
                drawText: false,
                color: AppColors.mainText.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCopyCard({required IconData icon, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.mainText, fontSize: 14,
                      fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: Icon(Icons.copy, color: color, size: 18),
              onPressed: () => _copy(value),
            ),
          ]),
          if (value.isNotEmpty && value != 'Unavailable') ...[
            const SizedBox(height: 12),
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: value,
              height: 50,
              width: double.infinity,
              drawText: false,
              color: AppColors.mainText.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimCard(Map<String, dynamic> sim) {
    if (sim.containsKey('error')) return _buildWarningCard(sim['error'].toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.sim_card, color: Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 8),
            Text('${sim['slot']} — ${sim['carrierName']}',
                style: const TextStyle(
                    color: AppColors.mainText, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _simRow('📱 Phone Number', sim['phoneNumber'] ?? 'N/A', copyable: true),
            _simRow('🌍 Country', sim['countryIso'] ?? 'N/A'),
            _simRow('📡 Network', sim['networkType'] ?? 'N/A'),
            _simRow('📶 SIM State', sim['simState'] ?? 'N/A'),
            _simRow('✈️ Roaming', sim['roaming'] ?? 'No'),
            _simRow('🔢 SIM Serial', sim['simSerial'] ?? 'N/A'),
          ]),
        ),
      ]),
    );
  }

  Widget _simRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.mainText, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        if (copyable) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _copy(value),
            child: const Icon(Icons.copy, color: AppColors.secondaryText, size: 14),
          ),
        ]
      ]),
    );
  }

  Widget _buildDeviceBuildCard() {
    final fields = {
      'Manufacturer': _deviceInfo['manufacturer'],
      'Device':       _deviceInfo['device'],
      'Product':      _deviceInfo['product'],
      'Build ID':     _deviceInfo['buildId'],
      'Fingerprint':  _deviceInfo['fingerprint'],
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: fields.entries
            .map((e) => _buildInfoRow(e.key, e.value?.toString() ?? 'N/A'))
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.mainText, fontSize: 12, fontFamily: 'monospace')),
        ),
        GestureDetector(
          onTap: () => _copy(value),
          child: const Icon(Icons.copy, color: AppColors.secondaryText, size: 14),
        ),
      ]),
    );
  }

  Widget _buildWarningCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.amber, fontSize: 12))),
      ]),
    );
  }
}
