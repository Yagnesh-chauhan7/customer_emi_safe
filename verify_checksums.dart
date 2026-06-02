import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() async {
  // Path to the Release APK that was just built
  final apkPath = r'C:\Users\YAGNESH\AndroidStudioProjects\customer_emi_app\build\app\outputs\flutter-apk\app-release.apk';
  final file = File(apkPath);
  if (!await file.exists()) {
    print('Error: Release APK file not found at $apkPath');
    print('Make sure you have run: flutter build apk --release');
    return;
  }

  // 1. Calculate file hash (PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM)
  final bytes = await file.readAsBytes();
  final fileHash = sha256.convert(bytes);
  final fileHashBase64Url = base64Url.encode(fileHash.bytes).replaceAll('=', '');
  
  print('================================================================');
  print('1. PACKAGE CHECKSUM (Put this in your Admin App / Server)');
  print('================================================================');
  print('PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM: $fileHashBase64Url');
  print('');

  // 2. Release Certificate SHA-256 Checksum (PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM)
  // This is the SHA256 signature from your upload-keystore.jks!
  final releaseCertHex = '656bded6c884d7a4ed4eb057b11eba652a769584fa328378739081eb12c4ab33';
  final releaseCertBytes = hexToBytes(releaseCertHex);
  final releaseCertBase64Url = base64Url.encode(releaseCertBytes).replaceAll('=', '');

  print('================================================================');
  print('2. SIGNATURE CHECKSUM (Put this in your Admin App / Server)');
  print('================================================================');
  print('PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM: $releaseCertBase64Url');
  print('================================================================');
}

List<int> hexToBytes(String hex) {
  List<int> bytes = [];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
