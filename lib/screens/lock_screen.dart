import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'emergency_call_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _unlockCodeController = TextEditingController();
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  // Static data for demonstration
  final String _upiId = "yagnesh13122003@okaxis";
  final String _shopName = "Yagnesh Tech & EMI Solutions";
  final String _ownerName = "Yagnesh Chauhan";
  final String _contactNumber = "+91 9725250740";

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _unlockCodeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        primaryColor: const Color(0xFFEF4444),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Deep Layered Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF1E1B4B),
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
                      color: const Color(0xFFEF4444).withValues(alpha: 0.05 * _glowAnimation.value),
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
                    const SizedBox(height: 24),
                    _buildPaymentPortal(),
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
            color: const Color(0xFFEF4444).withValues(alpha: 0.03),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                _ownerName,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          // Premium QR Frame
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 140,
              color: Color(0xFF020617),
            ),
          ),
          const SizedBox(height: 24),
          // UPI Action
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _upiId));
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
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _upiId,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
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
            color: Colors.white24,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
        _buildGlassContainer(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _unlockCodeController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w200,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.05)),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: InputBorder.none,
            ),
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
            onPressed: () => HapticFeedback.heavyImpact(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'UNLOCK DEVICE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencySupport() {
    return Column(
      children: [
        const Text(
          'DIRECT ASSISTANCE',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyCallScreen()),
            );
          },
          child: _buildGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded, color: Color(0xFFEF4444), size: 22),
                const SizedBox(width: 12),
                Text(
                  'CONTACT SUPPORT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
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
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
