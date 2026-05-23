import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import 'device_info_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _PermType { runtime, system, manufacturer }

enum _PermState { granted, denied, permanentlyDenied, unknown, notApplicable }

class _PermItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final _PermType type;

  // For runtime + system permissions (permission_handler)
  final List<Permission>? permissions;

  // For intent-based (system / manufacturer)
  final Future<void> Function()? openAction;

  // Custom status check (e.g. for Device Admin)
  final Future<_PermState> Function()? customCheck;

  _PermState state = _PermState.unknown;

  _PermItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
    this.permissions,
    this.openAction,
    this.customCheck,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _grantingAll = false;

  late final List<_PermItem> _runtimePerms;
  late final List<_PermItem> _systemPerms;
  late final List<_PermItem> _devicePerms;

  bool get _allGranted {
    if (_loading) return false;
    final allItems = [..._runtimePerms, ..._systemPerms, ..._devicePerms];
    return allItems.every((item) => item.state == _PermState.granted || item.state == _PermState.notApplicable);
  }

  static const _adminChannel = MethodChannel('com.example.customer_emi_app/admin');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildPermItems();
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh when user returns from Settings
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  // ── Intent helpers ──────────────────────────────────────────────────────────

  Future<void> _openSettings(String action, {String? data, String? package, String? component}) async {
    if (!Platform.isAndroid) return;
    try {
      await AndroidIntent(
        action: action,
        data: data,
        package: package,
        componentName: component,
      ).launch();
    } catch (e) {
      debugPrint('Error: $e');
      _showSnack('Could not open settings: $e');
    }
  }

  Future<void> _openPackageSettings(String pkg) async {
    if (!Platform.isAndroid) return;
    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: pkg,
      ).launch();
    } catch (_) {
      _showSnack('App not found on this device');
    }
  }

  Future<void> _openAppDetails() async {
    await _openSettings(
      'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:com.example.customer_emi_app',
    );
  }

  // ── Build permission items ──────────────────────────────────────────────────

  void _buildPermItems() {
    // ── 1. RUNTIME PERMISSIONS ────────────────────────────────────────────────
    _runtimePerms = [
      _PermItem(
        id: 'location',
        title: 'Location',
        description: 'Required for WiFi scanning & network features on Android 9+',
        icon: Icons.location_on_rounded,
        color: const Color(0xFF00C897),
        type: _PermType.runtime,
        permissions: [Permission.locationWhenInUse, Permission.locationAlways],
      ),
      _PermItem(
        id: 'sms',
        title: 'SMS',
        description: 'Required to receive EMI lock/unlock commands via SMS',
        icon: Icons.sms_rounded,
        color: const Color(0xFF7C4DFF),
        type: _PermType.runtime,
        permissions: [Permission.sms],
      ),
      _PermItem(
        id: 'phone',
        title: 'Phone & Call',
        description: 'Required to read device IMEI, SIM info & phone number',
        icon: Icons.phone_rounded,
        color: const Color(0xFF2979FF),
        type: _PermType.runtime,
        permissions: [Permission.phone],
      ),
      _PermItem(
        id: 'camera',
        title: 'Camera',
        description: 'Required to take pictures and record videos',
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFFFF6D00),
        type: _PermType.runtime,
        permissions: [Permission.camera],
      ),
      _PermItem(
        id: 'microphone',
        title: 'Microphone',
        description: 'Required to record audio with video',
        icon: Icons.mic_rounded,
        color: const Color(0xFFE91E63),
        type: _PermType.runtime,
        permissions: [Permission.microphone],
      ),
      _PermItem(
        id: 'storage',
        title: 'File & Storage Access',
        description: 'Required to read and save files on device storage',
        icon: Icons.folder_rounded,
        color: const Color(0xFFFFAB00),
        type: _PermType.runtime,
        permissions: [Permission.storage, Permission.manageExternalStorage],
      ),
    ];

    // ── 2. SYSTEM PERMISSIONS ─────────────────────────────────────────────────
    _systemPerms = [
      _PermItem(
        id: 'notification',
        title: 'Notifications',
        description: 'Required to show lock alerts and FCM remote commands',
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFF00BCD4),
        type: _PermType.system,
        permissions: [Permission.notification],
      ),
      _PermItem(
        id: 'overlay',
        title: 'Display Over Other Apps',
        description: 'Required to show lock screen overlay on top of all apps',
        icon: Icons.layers_rounded,
        color: const Color(0xFF651FFF),
        type: _PermType.system,
        permissions: [Permission.systemAlertWindow],
      ),
      _PermItem(
        id: 'battery_opt',
        title: 'Battery Optimization',
        description: 'Disable battery optimization so FCM and background service run reliably',
        icon: Icons.battery_charging_full_rounded,
        color: const Color(0xFF76FF03),
        type: _PermType.system,
        permissions: [Permission.ignoreBatteryOptimizations],
      ),
      _PermItem(
        id: 'device_admin',
        title: 'Device Admin',
        description: 'Required for remote lock, wipe and policy enforcement',
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFFD32F2F),
        type: _PermType.system,
        customCheck: _checkAdminStatus,
        openAction: _requestAdmin,
      ),
    ];

    // ── 3. DEVICE / MANUFACTURER SETTINGS ────────────────────────────────────
    _devicePerms = [
      _PermItem(
        id: 'autostart',
        title: 'Auto Start',
        description: 'Allow app to start automatically on boot (Realme/OPPO specific)',
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFFFF4081),
        type: _PermType.manufacturer,
        openAction: _openAutoStart,
      ),
      _PermItem(
        id: 'power_saving',
        title: 'Power Saving Mode — Off',
        description: 'Disable Power Saving Mode so background services run reliably',
        icon: Icons.electric_bolt_rounded,
        color: const Color(0xFFFFD600),
        type: _PermType.manufacturer,
        openAction: () => _openSettings('android.settings.BATTERY_SAVER_SETTINGS'),
      ),
      _PermItem(
        id: 'play_protect',
        title: 'Play Protect',
        description: 'Open Play Protect settings to manage scan/threat alerts',
        icon: Icons.security_rounded,
        color: const Color(0xFF00E676),
        type: _PermType.manufacturer,
        openAction: _openPlayProtect,
      ),
      _PermItem(
        id: 'smart_sidebar',
        title: 'Disable Smart Sidebar',
        description: 'Disable Realme Smart Sidebar to prevent app interference in kiosk mode',
        icon: Icons.view_sidebar_rounded,
        color: const Color(0xFFFF6E40),
        type: _PermType.manufacturer,
        openAction: _openSmartSidebar,
      ),
      _PermItem(
        id: 'payment_restriction',
        title: 'Payment Restriction',
        description: 'Manage Realme payment restriction settings',
        icon: Icons.credit_card_off_rounded,
        color: const Color(0xFFAA00FF),
        type: _PermType.manufacturer,
        openAction: _openPaymentRestriction,
      ),
      _PermItem(
        id: 'phone_manager',
        title: 'Phone Manager / Security',
        description: 'Open Realme Phone Manager to configure security and permissions',
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF0091EA),
        type: _PermType.manufacturer,
        openAction: () => _openPackageSettings('com.coloros.phonemanager'),
      ),
    ];
  }

  // ── Manufacturer-specific intent actions ────────────────────────────────────

  Future<void> _openAutoStart() async {
    // Try Realme/OPPO auto-start manager first
    const candidates = [
      ('com.coloros.oppoguardelf',
          'com.coloros.oppoguardelf.view.safecontrol.AbsolutelyStartActivity'),
      ('com.coloros.safecenter',
          'com.coloros.safecenter.permission.startup.StartupAppListActivity'),
      ('com.iqoo.secure',
          'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'),
      ('com.miui.securitycenter',
          'com.miui.permcenter.autostart.AutoStartManagementActivity'),
    ];

    for (final (pkg, comp) in candidates) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: pkg,
          componentName: comp,
        ).launch();
        return;
      } catch (_) {}
    }

    // Fallback: open App Details
    await _openAppDetails();
  }

  Future<void> _openPlayProtect() async {
    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.android.vending',
        componentName: 'com.google.android.finsky.security.b.a',
      ).launch();
    } catch (_) {
      // Fallback: open Play Store directly
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.android.vending',
        ).launch();
      } catch (e) {
        debugPrint('Error: $e');
        _showSnack('Play Store not found: $e');
      }
    }
  }

  Future<void> _openSmartSidebar() async {
    // Try Realme Smart Sidebar settings
    const candidates = [
      ('com.oppo.sideappline', null),
      ('com.coloros.smartsidebar', null),
    ];

    for (final (pkg, comp) in candidates) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: pkg,
          componentName: comp,
        ).launch();
        return;
      } catch (_) {}
    }

    // Fallback: open Display settings
    await _openSettings('android.settings.DISPLAY_SETTINGS');
  }

  Future<void> _openPaymentRestriction() async {
    const candidates = [
      'com.coloros.phonemanager',
      'com.android.settings',
    ];
    for (final pkg in candidates) {
      try {
        await _openPackageSettings(pkg);
        return;
      } catch (_) {}
    }
    await _openAppDetails();
  }

  // ── Check all permission statuses ───────────────────────────────────────────

  Future<void> _checkAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    Future<_PermState> checkItem(_PermItem item) async {
      if (item.customCheck != null) return await item.customCheck!();
      if (item.permissions == null) return _PermState.notApplicable;
      // For items with multiple permissions, grant if ANY one is granted
      for (final perm in item.permissions!) {
        final s = await perm.status;
        if (s.isGranted) return _PermState.granted;
      }
      // Check if permanently denied
      for (final perm in item.permissions!) {
        final s = await perm.status;
        if (s.isPermanentlyDenied) return _PermState.permanentlyDenied;
      }
      return _PermState.denied;
    }

    for (final item in [..._runtimePerms, ..._systemPerms]) {
      item.state = await checkItem(item);
    }
    for (final item in _devicePerms) {
      item.state = _PermState.notApplicable;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Grant / open action ─────────────────────────────────────────────────────

  Future<void> _handleAction(_PermItem item) async {
    if (item.type == _PermType.manufacturer) {
      await item.openAction?.call();
      return;
    }

    if (item.openAction != null) {
      // System intent-based (accessibility)
      await item.openAction!();
      return;
    }

    if (item.state == _PermState.permanentlyDenied) {
      await openAppSettings();
      return;
    }

    if (item.permissions != null) {
      // Request all permissions in the group
      final List<Permission> perms = item.permissions!;
      final results = await perms.request();
      final anyGranted = results.values.any((s) => s.isGranted);

      // Special handling for battery optimization & overlay (open dialog)
      for (final perm in item.permissions!) {
        if (perm == Permission.ignoreBatteryOptimizations ||
            perm == Permission.systemAlertWindow) {
          final status = await perm.status;
          if (!status.isGranted) await perm.request();
        }
      }

      await _checkAll();

      if (mounted) {
        _showSnack(anyGranted ? '✅ Permission granted!' : '⚠️ Permission denied');
      }
    }
  }

  Future<_PermState> _checkAdminStatus() async {
    try {
      final bool isActive = await _adminChannel.invokeMethod('isAdminActive');
      return isActive ? _PermState.granted : _PermState.denied;
    } catch (_) {
      return _PermState.unknown;
    }
  }

  Future<void> _requestAdmin() async {
    try {
      await _adminChannel.invokeMethod('requestAdmin');
      // Wait for user action
      await Future.delayed(const Duration(seconds: 2));
      _checkAll();
    } catch (e) {
      debugPrint('Error: $e');
      _showSnack('Admin request failed: $e');
    }
  }

  Future<void> _grantAllRuntime() async {
    setState(() => _grantingAll = true);
    final List<Permission> allPerms = _runtimePerms
        .expand((i) => i.permissions ?? <Permission>[])
        .toSet()
        .toList();
    if (allPerms.isNotEmpty) {
      await allPerms.request();
    }
    await _checkAll();
    setState(() => _grantingAll = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.mainText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.mainText,
        elevation: 0,
        title: const Text(
          'App Permissions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh all',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _buildSummaryBanner(),
                const SizedBox(height: 20),
                _buildGrantAllButton(),
                const SizedBox(height: 16),
                _buildSection(
                  title: '📱 Runtime Permissions',
                  subtitle: 'Required system permissions for core features',
                  items: _runtimePerms,
                  headerColor: const Color(0xFF00C897),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: '⚙️ System Permissions',
                  subtitle: 'Special system-level access needed for background features',
                  items: _systemPerms,
                  headerColor: const Color(0xFF651FFF),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: '🏭 Device Settings',
                  subtitle: 'Manufacturer-specific settings (Realme / OPPO)',
                  items: _devicePerms,
                  headerColor: const Color(0xFFFF6D00),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBanner() {
    final allItems = [..._runtimePerms, ..._systemPerms];
    final granted = allItems.where((i) => i.state == _PermState.granted).length;
    final total = allItems.length;
    final pct = total == 0 ? 1.0 : granted / total;
    final allOk = granted == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allOk
              ? [const Color(0xFF00C897).withValues(alpha: 0.2), const Color(0xFF005C46).withValues(alpha: 0.3)]
              : [const Color(0xFF7C4DFF).withValues(alpha: 0.2), const Color(0xFF1A0A3C).withValues(alpha: 0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allOk
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allOk ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: allOk ? const Color(0xFF00C897) : const Color(0xFFFFAB00),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                allOk ? 'All permissions granted!' : '$granted / $total permissions granted',
                style: const TextStyle(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: allOk ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantAllButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _grantingAll ? null : _grantAllRuntime,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: _grantingAll
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.checklist_rounded),
        label: Text(
          _grantingAll ? 'Requesting...' : 'Grant All Runtime Permissions',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
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
          onPressed: _allGranted ? () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceInfoScreen()),
            );
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _allGranted ? AppColors.primary : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _allGranted ? 'Next: Device Information' : 'Grant All Permissions First',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (_allGranted) const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<_PermItem> items,
    required Color headerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
        // Permission cards
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return _buildPermCard(entry.value, isLast: isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPermCard(_PermItem item, {bool isLast = false}) {
    final state = item.state;
    final isManufacturer = item.type == _PermType.manufacturer;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isManufacturer) {
      statusColor = const Color(0xFFFFAB00);
      statusText = 'Configure';
      statusIcon = Icons.open_in_new_rounded;
    } else {
      switch (state) {
        case _PermState.granted:
          statusColor = AppColors.success;
          statusText = 'Granted';
          statusIcon = Icons.check_circle_rounded;
          break;
        case _PermState.permanentlyDenied:
          statusColor = AppColors.danger;
          statusText = 'Blocked';
          statusIcon = Icons.block_rounded;
          break;
        case _PermState.denied:
          statusColor = const Color(0xFFFFAB00);
          statusText = 'Denied';
          statusIcon = Icons.cancel_rounded;
          break;
        default:
          statusColor = AppColors.secondaryText;
          statusText = 'Unknown';
          statusIcon = Icons.help_outline_rounded;
      }
    }

    String btnLabel;
    if (isManufacturer) {
      btnLabel = 'Open';
    } else if (state == _PermState.granted) {
      btnLabel = 'Granted';
    } else if (state == _PermState.permanentlyDenied) {
      btnLabel = 'Settings';
    } else {
      btnLabel = 'Grant';
    }

    final canTap = isManufacturer || state != _PermState.granted;

    return Column(
      children: [
        InkWell(
          onTap: canTap ? () => _handleAction(item) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),

                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.mainText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Status + action button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Status badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Action button
                    SizedBox(
                      height: 30,
                      child: TextButton(
                        onPressed: canTap ? () => _handleAction(item) : null,
                        style: TextButton.styleFrom(
                          backgroundColor: canTap
                              ? item.color.withValues(alpha: 0.1)
                              : AppColors.divider,
                          foregroundColor: canTap ? item.color : AppColors.secondaryText,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          btnLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 74,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}
