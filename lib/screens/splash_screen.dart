import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show isLockScreenActive;
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Ensure first frame is built before showing dialogs
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Check for updates first
    final updateInfo = await UpdateService.checkForUpdate();
    if (!mounted) return;

    if (updateInfo != null) {
      if (updateInfo.isForceUpdate) {
        // Block navigation, show un-dismissable dialog
        UpdateDialog.show(context, updateInfo);
        return; // Halt here
      } else {
        // Show optional dialog and wait for it to be dismissed
        await UpdateDialog.show(context, updateInfo);
      }
    }

    if (!mounted) return;

    // Minimum delay for splash visual if update check was too fast
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    if (isLockScreenActive) return;
    
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_locked') == true) return;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
    );
  }
}
