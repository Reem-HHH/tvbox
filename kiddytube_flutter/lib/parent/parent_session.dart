/// In-memory parent unlock session (~5 minutes), mirrors Kotlin [ParentSession].
class ParentSession {
  ParentSession._();

  static const unlockTtlMs = 5 * 60 * 1000;
  static int _unlockedUntilMs = 0;

  static void grant([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _unlockedUntilMs = now + unlockTtlMs;
  }

  static void clear() {
    _unlockedUntilMs = 0;
  }

  static bool isActive([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now < _unlockedUntilMs;
  }
}
