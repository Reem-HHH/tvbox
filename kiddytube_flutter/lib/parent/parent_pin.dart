import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Parent unlock: salted PIN verification + temporary rate limiting.
///
/// New hashes use PBKDF2-HMAC-SHA256 (`pbkdf2-sha256$iters$hex`).
/// Legacy single-round SHA-256 hashes still verify and are upgraded on unlock.
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

  /// KDF id + iteration count embedded in stored hash strings.
  static const kdfId = 'pbkdf2-sha256';
  static const kdfIterations = 100000;

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
    final expected = expectedHashHex.trim();
    if (isLegacyHash(expected)) {
      final legacy = legacyHashPin(pin, saltHex);
      if (legacy == null) return false;
      return _constantTimeEquals(legacy, expected);
    }
    final actual = hashPin(pin, saltHex);
    if (actual == null) return false;
    return _constantTimeEquals(actual, expected);
  }

  /// PBKDF2 verify off the UI isolate (Android TV SoCs hitch on 100k iters).
  Future<bool> verifyPinAsync(
    String pin,
    String? saltHex,
    String? expectedHashHex,
  ) {
    if (!isValidPinFormat(pin) ||
        saltHex == null ||
        saltHex.isEmpty ||
        expectedHashHex == null ||
        expectedHashHex.isEmpty) {
      return Future<bool>.value(false);
    }
    return compute(
      _verifyPinWorker,
      <String, String>{
        'pin': pin,
        'salt': saltHex,
        'hash': expectedHashHex,
      },
    );
  }

  /// Hash off the UI isolate for PIN change / first-run seed.
  static Future<String?> hashPinAsync(String pin, String saltHex) {
    return compute(
      _hashPinWorker,
      <String, String>{'pin': pin, 'salt': saltHex},
    );
  }

  /// True when [hash] is the old single-round SHA-256 format (no KDF prefix).
  static bool isLegacyHash(String? hash) {
    if (hash == null || hash.isEmpty) return false;
    return !hash.startsWith('$kdfId\$');
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

  /// Hash for newly stored PINs (PBKDF2-HMAC-SHA256).
  static String? hashPin(String pin, String saltHex) {
    try {
      final salt = _fromHex(saltHex);
      final dk = _pbkdf2HmacSha256(
        utf8.encode(pin),
        salt,
        kdfIterations,
        32,
      );
      final hex = dk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '$kdfId\$$kdfIterations\$$hex';
    } catch (_) {
      return null;
    }
  }

  /// Legacy single-round SHA-256 (salt || pin). Used only for verify/migrate.
  static String? legacyHashPin(String pin, String saltHex) {
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

  static bool _constantTimeEquals(String a, String b) {
    final left = a.toLowerCase();
    final right = b.toLowerCase();
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }

  static List<int> _pbkdf2HmacSha256(
    List<int> password,
    List<int> salt,
    int iterations,
    int dkLen,
  ) {
    const hLen = 32;
    final blockCount = (dkLen + hLen - 1) ~/ hLen;
    final out = <int>[];
    for (var block = 1; block <= blockCount; block++) {
      out.addAll(_pbkdf2Block(password, salt, iterations, block));
    }
    return out.sublist(0, dkLen);
  }

  static List<int> _pbkdf2Block(
    List<int> password,
    List<int> salt,
    int iterations,
    int blockIndex,
  ) {
    final hmac = Hmac(sha256, password);
    final first = <int>[
      ...salt,
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];
    var u = hmac.convert(first).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
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

bool _verifyPinWorker(Map<String, String> args) {
  return ParentPinManager().verifyPin(
    args['pin']!,
    args['salt']!,
    args['hash']!,
  );
}

String? _hashPinWorker(Map<String, String> args) {
  return ParentPinManager.hashPin(args['pin']!, args['salt']!);
}
