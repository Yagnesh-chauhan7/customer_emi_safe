import 'package:flutter/material.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayLockScreen(),
  ));
}

class OverlayLockScreen extends StatelessWidget {
  const OverlayLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A fullscreen aggressive red lock screen
    return Scaffold(
      backgroundColor: Colors.red[900],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock, size: 100, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  "DEVICE LOCKED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "This device has been locked by your provider due to pending EMI payments. All functions have been disabled.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    height: 1.4,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  "Please contact support to unlock this device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
