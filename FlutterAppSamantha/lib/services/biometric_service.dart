import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric authentication is available on this device.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      dev.log('Biometric availability check failed: $e');
      return false;
    }
  }

  /// Prompt the user for biometric authentication (Face ID / fingerprint).
  /// Returns true if authenticated successfully.
  static Future<bool> authenticate() async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: 'Verify your identity to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      dev.log('Biometric authentication failed: $e');
      return false;
    }
  }
}
