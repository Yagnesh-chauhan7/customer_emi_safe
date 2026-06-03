import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() async {
  final apkPath = r'C:\Users\Hello\koffeekodes\customer_emi_safe\build\app\outputs\flutter-apk\app-release.apk';
  final file = File(apkPath);
  if (!await file.exists()) {
    print('Error: APK file not found at $apkPath');
    return;
  }

  // Calculate file hash (PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM)
  final bytes = await file.readAsBytes();
  final fileHash = sha256.convert(bytes);
  final fileHashBase64Url = base64Url.encode(fileHash.bytes).replaceAll('=', '');
  print('APK File SHA-256 (Hex): $fileHash');
  print('PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM (Base64URL, no padding): $fileHashBase64Url');

  // Let's also parse the debug certificate SHA-256 that we know:
  // "d6b4d3b09a2685a7ffa7f4f1c61f88db2980939dd6d031a95cd4bf8e4c116b05"
  final debugCertHex = 'd6b4d3b09a2685a7ffa7f4f1c61f88db2980939dd6d031a95cd4bf8e4c116b05';
  final debugCertBytes = hexToBytes(debugCertHex);
  final debugCertBase64Url = base64Url.encode(debugCertBytes);
  print('Debug Cert SIGNATURE_CHECKSUM (with padding): $debugCertBase64Url');
  print('Debug Cert SIGNATURE_CHECKSUM (no padding):   ${debugCertBase64Url.replaceAll('=', '')}');

  // Release certificate SHA-256:
  // "8893239f6e30205fcb4f34b465205bece470bf80c6cad6257fc40fdee594c2a6"
  final releaseCertHex = '8893239f6e30205fcb4f34b465205bece470bf80c6cad6257fc40fdee594c2a6';
  final releaseCertBytes = hexToBytes(releaseCertHex);
  final releaseCertBase64Url = base64Url.encode(releaseCertBytes);
  print('Release Cert SIGNATURE_CHECKSUM (with padding): $releaseCertBase64Url');
  print('Release Cert SIGNATURE_CHECKSUM (no padding):   ${releaseCertBase64Url.replaceAll('=', '')}');
}

List<int> hexToBytes(String hex) {
  List<int> bytes = [];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
