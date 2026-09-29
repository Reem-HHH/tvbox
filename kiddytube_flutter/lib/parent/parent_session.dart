/// In-memory parent unlock session (~5 minutes), mirrors Kotlin [ParentSession].
/// Activity calls [touch] to slide the TTL while the parent settings screen is open.
class ParentSession {
  ParentSession._();

  static const unlockTtlMs = 5 * 60 * 1000;
  static int _unlockedUntilMs = 0;

  static void grant([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _unlockedUntilMs = now + unlockTtlMs;
  }

  /// Extends the session when still active (sliding expiration).
  static void touch([int? nowMs]) {
    if (!isActive(nowMs)) return;
    grant(nowMs);
  }

  static void clear() {
    _unlockedUntilMs = 0;
  }

  static bool isActive([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now < _unlockedUntilMs;
  }

  /// Milliseconds remaining, or 0 if expired.
  static int remainingMs([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final left = _unlockedUntilMs - now;
    return left > 0 ? left : 0;
  }
}
