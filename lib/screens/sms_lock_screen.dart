import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/sms_lock_service.dart';
import '../theme/app_colors.dart';

/// Shows on the CUSTOMER DEVICE — displays the secret code so admin can note it.
/// Also lets customer generate/change their code.
class SmsLockScreen extends StatefulWidget {
  const SmsLockScreen({super.key});

  @override
  State<SmsLockScreen> createState() => _SmsLockScreenState();
}

class _SmsLockScreenState extends State<SmsLockScreen> {
  String? _secretCode;
  bool _loading = true;
  bool _saving = false;
  bool _smsPermissionGranted = false;
  bool _smsPermissionDeniedForever = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSmsPermission();
    _loadCode();
  }

  Future<void> _checkSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) {
      setState(() => _smsPermissionGranted = true);
      return;
    }
    if (status.isPermanentlyDenied) {
      setState(() => _smsPermissionDeniedForever = true);
      return;
    }
    final result = await Permission.sms.request();
    setState(() {
      _smsPermissionGranted = result.isGranted;
      _smsPermissionDeniedForever = result.isPermanentlyDenied;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    setState(() => _loading = true);
    String? code = await SmsLockService.getSecretCode();
    // Auto-generate on first launch
    if (code == null || code.isEmpty) {
      code = await SmsLockService.generateSecretCode();
    }
    setState(() {
      _secretCode = code;
      _loading = false;
    });
  }

  Future<void> _generateNew() async {
    setState(() => _saving = true);
    final code = await SmsLockService.generateSecretCode();
    setState(() {
      _secretCode = code;
      _saving = false;
    });
    _showSnack('New secret code generated!', Colors.green);
  }

  Future<void> _saveCustomCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      _showSnack('Code must be at least 4 characters.', Colors.red);
      return;
    }
    setState(() => _saving = true);
    final ok = await SmsLockService.setSecretCode(code);
    setState(() {
      if (ok) _secretCode = code;
      _saving = false;
    });
    _codeController.clear();
    if (ok) _showSnack('Secret code updated!', Colors.green);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard!', AppColors.primary);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lockSms   = _secretCode != null ? SmsLockService.buildLockSms(_secretCode!) : '---';
    final unlockSms = _secretCode != null ? SmsLockService.buildUnlockSms(_secretCode!) : '---';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        title: const Text('SMS Lock Setup',
            style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.mainText),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── SMS Permission Banner ──
                  if (!_smsPermissionGranted) _buildSmsBanner(),
                  if (!_smsPermissionGranted) const SizedBox(height: 16),

                  // ── How it works ──
                  _buildInfoCard(),
                  const SizedBox(height: 20),

                  // ── Current Secret Code ──
                  _buildSecretCard(lockSms, unlockSms),
                  const SizedBox(height: 20),

                  // ── Generate new code ──
                  _buildActionButton(
                    icon: Icons.casino,
                    label: 'Generate New Random Code',
                    color: AppColors.primary,
                    loading: _saving,
                    onPressed: _generateNew,
                  ),
                  const SizedBox(height: 12),

                  // ── Custom code ──
                  _buildCustomCodeSection(),
                  const SizedBox(height: 20),

                  // ── Admin instruction ──
                  _buildAdminInstructionCard(lockSms, unlockSms),
                ],
              ),
            ),
    );
  }

  Widget _buildSmsBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.sms_failed, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text('SMS Permission Required',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Without RECEIVE_SMS permission, the device cannot be locked/unlocked via SMS.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _smsPermissionDeniedForever
                  ? openAppSettings
                  : _checkSmsPermission,
              icon: Icon(_smsPermissionDeniedForever ? Icons.settings : Icons.security),
              label: Text(_smsPermissionDeniedForever
                  ? 'Open App Settings'
                  : 'Grant SMS Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sms, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('How SMS Lock Works',
                style: TextStyle(
                    color: AppColors.mainText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          SizedBox(height: 10),
          Text(
            '1. Share this device\'s secret code with the admin.\n'
            '2. Admin sends a specific SMS to this device\'s phone number.\n'
            '3. Device locks/unlocks instantly — even without internet!',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretCard(String lockSms, String unlockSms) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Secret Code',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            Text(
              _secretCode ?? 'Not Set',
              style: const TextStyle(
                  color: AppColors.mainText,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  fontFamily: 'monospace'),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, color: AppColors.primary),
              tooltip: 'Copy code',
              onPressed: () => _copyToClipboard(_secretCode ?? ''),
            ),
          ]),
            const Divider(color: AppColors.border),
          const SizedBox(height: 4),
          _buildSmsRow('Lock SMS', lockSms, Colors.redAccent),
          const SizedBox(height: 8),
          _buildSmsRow('Unlock SMS', unlockSms, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildSmsRow(String label, String smsText, Color color) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
        const SizedBox(height: 2),
        Text(smsText,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'monospace')),
      ]),
      const Spacer(),
      IconButton(
        icon: Icon(Icons.copy, color: color, size: 18),
        tooltip: 'Copy',
        onPressed: () => _copyToClipboard(smsText),
      ),
    ]);
  }

  Widget _buildCustomCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set Custom Code',
            style: TextStyle(
                color: AppColors.mainText,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              style: const TextStyle(color: AppColors.mainText),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'Enter custom code (min 4 chars)',
                hintStyle: const TextStyle(color: AppColors.secondaryText),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _saving ? null : _saveCustomCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save'),
          ),
        ]),
      ],
    );
  }

  Widget _buildAdminInstructionCard(String lockSms, String unlockSms) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber, size: 18),
            SizedBox(width: 6),
            Text('Instructions for Admin',
                style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Share the following with your admin panel / admin app:\n',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
          _infoRow('Device Phone Number', 'Your SIM number'),
          const SizedBox(height: 6),
          _infoRow('To LOCK device, send SMS', lockSms),
          const SizedBox(height: 6),
          _infoRow('To UNLOCK device, send SMS', unlockSms),
          const SizedBox(height: 10),
          const Text(
            '⚡ Works without internet — only needs cellular signal.',
            style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
      Text(value,
          style: const TextStyle(
              color: AppColors.mainText,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
