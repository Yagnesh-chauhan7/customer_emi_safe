import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyCallScreen extends StatefulWidget {
  final String? supportNumber;
  const EmergencyCallScreen({super.key, this.supportNumber});

  @override
  State<EmergencyCallScreen> createState() => _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen> with SingleTickerProviderStateMixin {
  String _dialedNumber = "";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_dialedNumber.length < 15) {
      setState(() {
        _dialedNumber += digit;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _onDeletePressed() {
    if (_dialedNumber.isNotEmpty) {
      setState(() {
        _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _makeCall() async {
    if (_dialedNumber.isEmpty) return;

    // Standard national and international emergency numbers
    final allowedNumbers = ["100", "101", "102", "108", "112", "911", "1091"];
    if (widget.supportNumber != null && widget.supportNumber!.isNotEmpty) {
      final cleanSupport = widget.supportNumber!.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanSupport.isNotEmpty) {
        allowedNumbers.add(cleanSupport);
      }
    }

    final cleanDialed = _dialedNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!allowedNumbers.contains(cleanDialed)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Only Emergency Calls (112, 100, 101, 102, 108, or Support) are allowed.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // ── Step 1: Try native MethodChannel (ACTION_CALL — no dialer UI) ──────
    // Kiosk mode mein stopLockTask() Kotlin side pe handle hota hai automatically.
    bool callPlaced = false;
    const connectivityChannel = MethodChannel('connectivity_channel');
    try {
      final success = await connectivityChannel.invokeMethod<bool>(
        'makePhoneCall',
        {'number': cleanDialed},
      );
      if (success == true) {
        callPlaced = true;
        debugPrint('Emergency call placed via native channel: $cleanDialed');
      }
    } on PlatformException catch (e) {
      debugPrint('Native makePhoneCall failed (${e.code}): ${e.message}');
      // Don't show error yet — try url_launcher fallback below
    } catch (e) {
      debugPrint('Native makePhoneCall exception: $e');
    }

    // ── Step 2: Fallback — url_launcher (tel: URI) ──────────────────────────
    // Works even if MethodChannel is not responding or kiosk is blocking.
    if (!callPlaced) {
      try {
        final telUri = Uri(scheme: 'tel', path: cleanDialed);
        final launched = await launchUrl(
          telUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          callPlaced = true;
          debugPrint('Emergency call placed via url_launcher: $cleanDialed');
        }
      } catch (e) {
        debugPrint('url_launcher fallback failed: $e');
      }
    }

    if (!mounted) return;

    if (!callPlaced) {
      // Both methods failed — show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Could not place call. Please check CALL_PHONE permission.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // ── Step 3: After call returns, restore lock screen if device was locked ──
    // Wait for call activity to complete, then check lock state
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocked = prefs.getBool('is_locked') ?? false;
      if (isLocked && mounted) {
        // Re-apply kiosk mode and navigate back to lock screen
        const adminChannel = MethodChannel('com.example.customer_emi_app/admin');
        try {
          await adminChannel.invokeMethod('startKioskMode');
        } catch (_) {}
        // Pop back to lock screen (it's below in the stack)
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Lock restore after call error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Deep Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
            
            // Subtle Glowing Orbs
            Positioned(
              bottom: -20,
              left: -40,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Minimalist Header
                  _buildHeader(),

                  // Number Display
                  Expanded(
                    flex: 4,
                    child: _buildNumberDisplay(),
                  ),

                  // Glassmorphic Dial Pad
                  Expanded(
                    flex: 8,
                    child: _buildDialPad(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white24),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'EMERGENCY SERVICES',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _dialedNumber.isEmpty ? "•••" : _dialedNumber,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _dialedNumber.length > 10 ? 40 : 52,
              fontWeight: FontWeight.w100,
              color: _dialedNumber.isEmpty ? Colors.white.withValues(alpha: 0.1) : Colors.white,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          if (_dialedNumber.isNotEmpty)
            const Text(
              'TAP TO CALL',
              style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDialPad() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildDialRow(["1", "2", "3"]),
                _buildDialRow(["4", "5", "6"]),
                _buildDialRow(["7", "8", "9"]),
                _buildDialRow(["*", "0", "#"]),
                const Spacer(),
                _buildActionRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialRow(List<String> digits) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: digits.map((d) => _buildDialButton(d)).toList(),
      ),
    );
  }

  Widget _buildDialButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(width: 60),
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _makeCall,
            child: Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: _dialedNumber.isNotEmpty
              ? IconButton(
                  onPressed: _onDeletePressed,
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white24, size: 22),
                )
              : null,
        ),
      ],
    );
  }
}
