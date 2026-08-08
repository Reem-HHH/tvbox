import 'dart:math';

import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Parent unlock: salted SHA-256 PIN verification + temporary rate limiting.
/// Parity with Kotlin [ParentPinManager].
class ParentPinManager {
  ParentPinManager({
    int failureCount = 0,
    int lockedUntilMs = 0,
  })  : failureCount = failureCount < 0 ? 0 : failureCount,
        lockedUntilMs = lockedUntilMs < 0 ? 0 : lockedUntilMs;

  static const defaultDevPin = '2580';
  static const minPinLength = 4;
  static const maxPinLength = 8;
  static const maxFailuresBeforeLockout = 5;
  static const baseLockoutMs = 30000;

  int failureCount;
  int lockedUntilMs;

  void refreshLockout(int nowMs) {
    if (lockedUntilMs > 0 && nowMs >= lockedUntilMs) {
      lockedUntilMs = 0;
      failureCount = 0;
    }
  }

  bool isLockedOut(int nowMs) {
    refreshLockout(nowMs);
    return nowMs < lockedUntilMs;
  }

  int remainingLockoutMs(int nowMs) =>
      lockedUntilMs > nowMs ? lockedUntilMs - nowMs : 0;

  bool verifyPin(String pin, String? saltHex, String? expectedHashHex) {
    if (!isValidPinFormat(pin) ||
        saltHex == null ||
        saltHex.isEmpty ||
        expectedHashHex == null ||
        expectedHashHex.isEmpty) {
      return false;
    }
    final actual = hashPin(pin, saltHex);
    if (actual == null) return false;
    return actual.toLowerCase() == expectedHashHex.toLowerCase();
  }

  /// Returns true when this failure triggered a lockout.
  bool registerFailure(int nowMs) {
    failureCount++;
    if (failureCount >= maxFailuresBeforeLockout) {
      final rounds = failureCount - maxFailuresBeforeLockout + 1;
      final shift = rounds - 1 > 4 ? 4 : rounds - 1;
      final multiplier = 1 << shift;
      lockedUntilMs = nowMs + baseLockoutMs * multiplier;
      return true;
    }
    return false;
  }

  void registerSuccess() {
    failureCount = 0;
    lockedUntilMs = 0;
  }

  static bool isValidPinFormat(String? pin) {
    if (pin == null) return false;
    if (pin.length < minPinLength || pin.length > maxPinLength) return false;
    return pin.codeUnits.every((c) => c >= 48 && c <= 57);
  }

  static String newSaltHex() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String? hashPin(String pin, String saltHex) {
    try {
      final salt = _fromHex(saltHex);
      final digest = sha256.convert([...salt, ...utf8.encode(pin)]);
      return digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    } catch (_) {
      return null;
    }
  }

  static List<int> _fromHex(String hex) {
    final value = hex.trim();
    if (value.length.isOdd) {
      throw FormatException('Odd hex length');
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ];
  }
}
