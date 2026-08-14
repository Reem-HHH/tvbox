import 'parent_pin.dart';

/// Rules for the factory development PIN (`2580`) and release gating.
/// Parity with Kotlin [ReleasePinPolicy].
class ReleasePinPolicy {
  ReleasePinPolicy._();

  /// When true, an entered PIN equal to the factory PIN must be rejected
  /// even if it still matches the stored hash.
  static bool rejectDefaultDevPin({
    required bool isDebugBuild,
    required bool releaseReady,
    required bool pinChangedFromDefault,
  }) {
    if (releaseReady) return true;
    if (!isDebugBuild && pinChangedFromDefault) return true;
    return false;
  }

  /// Release builds block channel/player launch until the factory PIN is replaced.
  static bool requirePinChangeForKidPlayback({
    required bool isDebugBuild,
    required bool pinChangedFromDefault,
  }) =>
      !isDebugBuild && !pinChangedFromDefault;

  static Future<bool> matchesDefaultDevPinAsync(String? salt, String? hash) async {
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) {
      return false;
    }
    return ParentPinManager().verifyPinAsync(
      ParentPinManager.defaultDevPin,
      salt,
      hash,
    );
  }

  /// Sync helper for unit tests; prefer [sanitizePinFlagsAsync] on the UI path.
  static bool matchesDefaultDevPin(String? salt, String? hash) {
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) {
      return false;
    }
    return ParentPinManager().verifyPin(
      ParentPinManager.defaultDevPin,
      salt,
      hash,
    );
  }

  static Future<({bool pinChangedFromDefault, bool releaseReady})>
      sanitizePinFlagsAsync({
    required String? pinSalt,
    required String? pinHash,
    required bool pinChangedFromDefault,
    required bool releaseReady,
  }) async {
    // Flags already say "still default" — skip PBKDF2 (cold-start / tests).
    if (!pinChangedFromDefault) {
      return (pinChangedFromDefault: false, releaseReady: false);
    }
    final stillDefault = await matchesDefaultDevPinAsync(pinSalt, pinHash);
    final changed = !stillDefault;
    final ready = releaseReady && changed;
    return (pinChangedFromDefault: changed, releaseReady: ready);
  }

  static ({bool pinChangedFromDefault, bool releaseReady}) sanitizePinFlags({
    required String? pinSalt,
    required String? pinHash,
    required bool pinChangedFromDefault,
    required bool releaseReady,
  }) {
    if (!pinChangedFromDefault) {
      return (pinChangedFromDefault: false, releaseReady: false);
    }
    final stillDefault = matchesDefaultDevPin(pinSalt, pinHash);
    final changed = !stillDefault;
    final ready = releaseReady && changed;
    return (pinChangedFromDefault: changed, releaseReady: ready);
  }
}
