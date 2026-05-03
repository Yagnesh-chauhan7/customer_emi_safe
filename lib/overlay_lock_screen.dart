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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock, size: 120, color: Colors.white),
              SizedBox(height: 30),
              Text(
                "DEVICE LOCKED",
                style: TextStyle(
                  fontSize: 36,
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
                  fontSize: 20,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 40),
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
    );
  }
}
