import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Optional Face ID / fingerprint unlock for parents (not device PIN/pattern).
class ParentBiometrics {
  ParentBiometrics({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True when the platform can offer biometrics (fingerprint / Face ID).
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Face ID / Touch ID / fingerprint only (no device PIN fallback).
  /// Returns true on success; false on cancel or failure (caller should fall back to app PIN).
  Future<bool> authenticate({
    String reason = 'Unlock parent settings',
  }) async {
    try {
      if (!await canAuthenticate()) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
