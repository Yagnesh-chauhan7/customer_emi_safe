import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() async {
  // Path to the built APK
  final apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
  final file = File(apkPath);

  if (!await file.exists()) {
    print('APK not found! Please run "flutter build apk --release" first.');
    return;
  }

  // Calculate SHA-256 of the APK file
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);

  // Convert to URL-safe Base64 (without padding)
  final base64Checksum = base64Url.encode(digest.bytes).replaceAll('=', '');

  print('\n=== YOUR APK CHECKSUM ===');
  print(base64Checksum);
  print('=========================\n');

  print('=== YOUR QR CODE JSON PAYLOAD ===');
  print('''
{
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": "com.example.customer_emi_app/com.example.customer_emi_app.MyDeviceAdminReceiver",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM": "$base64Checksum",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": "https://files.catbox.moe/tn4ls1.apk"
}
  ''');
  print('=================================');
  print('\nInstructions:');
  print('1. Replace the <YOUR-HOSTING-URL-HERE> with the actual direct download link to your APK.');
  print('2. Copy the JSON and paste it into any free QR Code Generator (like qr-code-generator.com).');
  print('3. On your factory reset device, connect to Wi-Fi manually FIRST (or the device will prompt you to connect after scanning).');
  print('4. Go back to the welcome screen, tap 6 times, and scan the QR code!');
}
