import 'dart:convert';

/// Configuration for Google Apps Script Web App upload endpoint.
/// The Web App URL and Deployment ID are obfuscated via XOR cipher
/// to prevent plaintext string extraction from the application binary.
class AppUploadConfig {
  static const String _kSalt = 'NG_SA_SECURE_GAS_KEY_2026';

  // Obfuscated bytes for Deployment ID:
  // AKfycbx9aKErseNDNuKc4Z-NiBCVPHlx1dkAMiFtCsvnlqErIB3w87UcyNbI33lls1yZgS0
  static const List<int> _obfuscatedDeploymentId = [
    15, 12, 57, 42, 34, 61, 43, 124, 34, 30, 23, 55, 44, 34, 15, 23, 17, 62, 14, 58, 107, 104, 29, 124, 95, 12, 4, 9, 3, 9, 51, 43, 116, 39, 62, 19, 8, 54, 1, 53, 16, 44, 61, 43, 53, 46, 119, 66, 123, 116, 125, 48, 103, 100, 20, 60, 42, 11, 33, 28, 97, 118, 51, 43, 50, 98, 38, 17, 34, 10, 111
  ];

  // Obfuscated bytes for Web App URL:
  // https://script.google.com/macros/s/AKfycbx9aKErseNDNuKc4Z-NiBCVPHlx1dkAMiFtCsvnlqErIB3w87UcyNbI33lls1yZgS0/exec
  static const List<int> _obfuscatedUrl = [
    38, 51, 43, 35, 50, 101, 124, 106, 48, 54, 32, 44, 47, 51, 111, 52, 48, 36, 34, 53, 58, 28, 83, 93, 91, 97, 42, 62, 48, 51, 48, 32, 106, 48, 122, 19, 14, 57, 62, 34, 49, 39, 114, 36, 18, 26, 64, 67, 87, 120, 10, 9, 42, 24, 34, 107, 9, 104, 13, 60, 16, 6, 9, 23, 9, 63, 39, 122, 33, 50, 30, 127, 89, 116, 66, 13, 52, 41, 61, 45, 46, 22, 55, 10, 23, 97, 50, 103, 112, 20, 48, 38, 5, 39, 16, 108, 1, 92, 94, 69, 127, 62, 5, 52, 18, 111, 124, 32, 59, 48, 49
  ];

  static String _xorDecode(List<int> bytes) {
    final kBytes = utf8.encode(_kSalt);
    final res = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ kBytes[i % kBytes.length],
    );
    return utf8.decode(res);
  }

  /// Decoded Web App URL for Google Apps Script endpoint
  static String get webAppUrl => _xorDecode(_obfuscatedUrl);

  /// Decoded Deployment ID
  static String get deploymentId => _xorDecode(_obfuscatedDeploymentId);
}
