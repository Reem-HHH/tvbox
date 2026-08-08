import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Optional Face ID / fingerprint / device credential unlock for parents.
class ParentBiometrics {
  ParentBiometrics({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True when the platform can offer biometrics or device credentials.
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Face ID / Touch ID / fingerprint / device PIN.
  /// Returns true on success; false on cancel or failure (caller should fall back to app PIN).
  Future<bool> authenticate({
    String reason = 'Unlock parent settings',
  }) async {
    try {
      if (!await canAuthenticate()) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
