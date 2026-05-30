import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_emi_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:customer_emi_app/services/connectivity_service.dart';
import 'qr_scanner_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _unlockCodeController = TextEditingController();
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isQrBlurred = true;
  String? _wallpaperUrl;
  
  String _shopName = "EMI Shield";
  String _ownerName = "Support Agent";
  String _contactNumber = "";
  String _activationCode = "";
  String? _paymentUpiId;
  int _emiAmount = 0;
  @override
  void initState() {
    super.initState();
    isLockScreenActive = true;
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadLockScreenData();
  }

  Future<void> _loadLockScreenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _wallpaperUrl = prefs.getString('lock_screen_wallpaper_url');
          _activationCode = prefs.getString('activation_code') ?? '';
        });
      }

      String? ownerId = prefs.getString('owner_id');
      final customerId = prefs.getString('customer_id');
      final supabase = Supabase.instance.client;

      // Fallback to fetch ownerId if it's missing but we have customerId
      if (ownerId == null && customerId != null) {
        try {
          final cData = await supabase
              .from('customer_table')
              .select('owner_id')
              .eq('customer_id', customerId)
              .maybeSingle();
          if (cData != null && cData['owner_id'] != null) {
            ownerId = cData['owner_id'];
            await prefs.setString('owner_id', ownerId!);
          }
        } catch (e) {
          debugPrint('Error fetching fallback ownerId: $e');
        }
      }

      if (ownerId != null) {
        // Fetch kyc Data
        final kycData = await supabase
            .from('shop_owner_kyc_table')
            .select('kyc_shop_name')
            .eq('owner_id', ownerId)
            .maybeSingle();
            
        // Fetch owner Data
        final ownerData = await supabase
            .from('shop_owner_table')
            .select('owner_name, owner_phone')
            .eq('owner_id', ownerId)
            .maybeSingle();

        // Fetch UPI ID
        final paymentData = await supabase
            .from('shop_owner_payment_table')
            .select('payment_upi_id')
            .eq('owner_id', ownerId)
            .maybeSingle();

        // Fetch EMI Amount & Activation Code
        Map<String, dynamic>? customerData;
        if (customerId != null) {
          customerData = await supabase
              .from('customer_table')
              .select('emi_amount, activaction_code')
              .eq('customer_id', customerId)
              .maybeSingle();
        }

        if (mounted) {
          setState(() {
            if (kycData != null && kycData['kyc_shop_name'] != null) {
              _shopName = kycData['kyc_shop_name'];
            }
            if (ownerData != null) {
              _ownerName = ownerData['owner_name'] ?? _ownerName;
              _contactNumber = ownerData['owner_phone'] ?? _contactNumber;
            }
            if (paymentData != null) {
              _paymentUpiId = paymentData['payment_upi_id'];
            }
            if (customerData != null) {
              if (customerData['emi_amount'] != null) {
                _emiAmount = int.tryParse(customerData['emi_amount'].toString()) ?? 0;
              }
              if (_activationCode.isEmpty && customerData['activaction_code'] != null) {
                _activationCode = customerData['activaction_code'].toString().trim();
                prefs.setString('activation_code', _activationCode);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading lock screen data: $e');
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result != null && result is String) {
      _unlockCodeController.text = result;
      _unlockDevice();
    }
  }

  @override
  void dispose() {
    isLockScreenActive = false;
    _unlockCodeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _unlockDevice() async {
    HapticFeedback.heavyImpact();
    final enteredCode = _unlockCodeController.text.trim();
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter authorization code'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    var storedCode = _activationCode.trim();
    debugPrint('Unlock attempt. Entered: $enteredCode, Stored: $storedCode');

    if (enteredCode == storedCode) {
      // 1. Reset state
      isLockScreenActive = false;

      // 2. Set SharedPreferences is_locked to false
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_locked', false);

      // 3. Stop kiosk mode & close app
      const adminChannel = MethodChannel('com.example.customer_emi_app/admin');
      try {
        await adminChannel.invokeMethod('stopKioskMode');
      } catch (e) {
        debugPrint('stopKioskMode error: $e');
      }

      // 4. Force pop Dart app to make sure Dart VM stops
      await SystemNavigator.pop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid Authorization Code'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primaryColor: const Color(0xFFEF4444),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Deep Layered Background
            if (_wallpaperUrl != null && _wallpaperUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  _wallpaperUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFFEF2F2),
                          Color(0xFFFEE2E2),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF2F2),
                      Color(0xFFFEE2E2),
                    ],
                  ),
                ),
              ),
            
            // Abstract Glowing Accents
            Positioned(
              top: -50,
              right: -50,
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1 * _glowAnimation.value),
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildSecurityHeader(),
                    const SizedBox(height: 32),
                    _buildShopIdentity(),
                    if (_paymentUpiId != null && _paymentUpiId!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildPaymentPortal(),
                    ],
                    const SizedBox(height: 32),
                    _buildUnlockInterface(),
                    const SizedBox(height: 48),
                    _buildEmergencySupport(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.security_rounded, color: Color(0xFFEF4444), size: 42),
        ),
        const SizedBox(height: 20),
        const Text(
          'DEVICE RESTRICTED',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildShopIdentity() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            _shopName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF991B1B),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Text(
                _ownerName,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (_emiAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'EMI Amount: ₹$_emiAmount',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentPortal() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'PAYMENT GATEWAY',
            style: TextStyle(
              color: Color(0xFF991B1B),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          // Premium QR Frame
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isQrBlurred = !_isQrBlurred;
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _isQrBlurred ? 8.0 : 0.0,
                    sigmaY: _isQrBlurred ? 8.0 : 0.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'upi://pay?pa=$_paymentUpiId&am=$_emiAmount&cu=INR',
                      version: QrVersions.auto,
                      size: 140.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_isQrBlurred)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF991B1B).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TAP TO VIEW QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // UPI Action
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _paymentUpiId ?? ''));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('UPI ID Secured to Clipboard'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _paymentUpiId ?? '',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy_all_rounded, size: 18, color: Color(0xFFEF4444)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockInterface() {
    return Column(
      children: [
        const Text(
          'ENTER AUTHORIZATION CODE',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
        _buildGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _unlockCodeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    hintStyle: TextStyle(color: const Color(0xFFEF4444).withValues(alpha: 0.3), letterSpacing: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEF4444), size: 30),
                onPressed: _scanQR,
                padding: const EdgeInsets.only(left: 16, right: 8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Premium Action Button
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _unlockDevice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'UNLOCK DEVICE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _makeDirectCall() async {
    if (_contactNumber.isEmpty) return;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$_contactNumber',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('Call failed: $e');
    }
  }

  Future<void> _openWifiSettings() async {
    HapticFeedback.lightImpact();
    final success = await ConnectivityService.openWifiSettings();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open WiFi settings'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildEmergencySupport() {
    return Column(
      children: [
        const Text(
          'DIRECT ASSISTANCE & UTILITIES',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            GestureDetector(
              onTap: _makeDirectCall,
              child: _buildGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.support_agent_rounded, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTACT SUPPORT',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        if (_contactNumber.isNotEmpty)
                          Text(
                            _contactNumber,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _openWifiSettings,
              child: _buildGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_rounded, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONNECT WIFI',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          'Configure settings',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, required EdgeInsetsGeometry padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                blurRadius: 10,
              )
            ]
          ),
          child: child,
        ),
      ),
    );
  }
}
