import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AdminControlScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  static const platform = MethodChannel('com.example.customer_emi_app/admin');
  bool _isAdminActive = false;
  bool _isDeviceOwner = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final bool adminResult = await platform.invokeMethod('isAdminActive');
      final bool ownerResult = await platform.invokeMethod('isDeviceOwner');
      setState(() {
        _isAdminActive = adminResult;
        _isDeviceOwner = ownerResult;
      });
      
      // If we are Device Owner, automatically initialize Kiosk Policies
      if (_isDeviceOwner) {
        await platform.invokeMethod('setKioskPolicies');
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get status: '\${e.message}'.");
    }
  }

  Future<void> _requestAdmin() async {
    try {
      await platform.invokeMethod('requestAdmin');
      await Future.delayed(const Duration(seconds: 3)); 
      _checkStatus();
    } on PlatformException catch (e) {
      debugPrint("Failed to request admin: '\${e.message}'.");
    }
  }

  Future<void> _lockDeviceWithKiosk() async {
    // Navigate to the fullscreen overlay screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const KioskLockScreen()),
    );
  }

  Future<void> _hideAppIcon() async {
    try {
      await platform.invokeMethod('hideAppIcon');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App hidden!')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to hide icon: '\${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Setup (Kiosk)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _isDeviceOwner ? Icons.verified_user : (_isAdminActive ? Icons.security : Icons.warning_amber_rounded),
                size: 80,
                color: _isDeviceOwner ? Colors.blue : (_isAdminActive ? Colors.green : Colors.orange),
              ),
              const SizedBox(height: 20),
              Text(
                'Device Admin: \${_isAdminActive ? "Yes" : "No"}\\nDevice Owner: \${_isDeviceOwner ? "Yes" : "No (ADB required)"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              if (!_isDeviceOwner)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.yellow[100],
                  child: const Text(
                    "Note: To prevent users from exiting the Lock Screen, you MUST run the ADB command to set this app as Device Owner.",
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _requestAdmin,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('1. Request Basic Admin'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _lockDeviceWithKiosk,
                icon: const Icon(Icons.screen_lock_portrait),
                label: const Text('2. Test Kiosk Lock Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                ),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _hideAppIcon,
                icon: const Icon(Icons.visibility_off),
                label: const Text('3. Hide App Icon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkStatus,
        tooltip: 'Refresh Status',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}


// --- THE FULLSCREEN LOCK SCREEN OVERLAY ---
class KioskLockScreen extends StatefulWidget {
  const KioskLockScreen({super.key});

  @override
  State<KioskLockScreen> createState() => _KioskLockScreenState();
}

class _KioskLockScreenState extends State<KioskLockScreen> {
  static const platform = MethodChannel('com.example.customer_emi_app/admin');

  @override
  void initState() {
    super.initState();
    // Engage Kiosk Mode immediately when this screen opens
    _startKiosk();
  }

  Future<void> _startKiosk() async {
    try {
      await platform.invokeMethod('startKioskMode');
    } on PlatformException catch (e) {
      debugPrint("Failed to start kiosk: '\${e.message}'.");
    }
  }

  Future<void> _stopKiosk() async {
    try {
      await platform.invokeMethod('stopKioskMode');
      if (mounted) {
        // Pop the screen to return to the dashboard
        Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to stop kiosk: '\${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope prevents the back button from working in Flutter 
    // (though in true Kiosk Mode, the physical back button is disabled anyway)
    return WillPopScope(
      onWillPop: () async => false, 
      child: Scaffold(
        backgroundColor: Colors.red[900], // Aggressive color for locked state
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 100, color: Colors.white),
                const SizedBox(height: 30),
                const Text(
                  "DEVICE LOCKED",
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "This device has been locked due to pending EMI payments. All functions have been disabled.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, 
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 60),
                // The unlock button to return to normal
                ElevatedButton.icon(
                  onPressed: _stopKiosk,
                  icon: const Icon(Icons.lock_open),
                  label: const Text(
                    "UNLOCK (DEV TESTING)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
