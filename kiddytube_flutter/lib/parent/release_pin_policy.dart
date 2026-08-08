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

  static bool matchesDefaultDevPin(String? salt, String? hash) {
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) {
      return false;
    }
    final expected =
        ParentPinManager.hashPin(ParentPinManager.defaultDevPin, salt);
    if (expected == null) return false;
    return expected.toLowerCase() == hash.toLowerCase();
  }

  static ({bool pinChangedFromDefault, bool releaseReady}) sanitizePinFlags({
    required String? pinSalt,
    required String? pinHash,
    required bool pinChangedFromDefault,
    required bool releaseReady,
  }) {
    final stillDefault = matchesDefaultDevPin(pinSalt, pinHash);
    final changed = pinChangedFromDefault && !stillDefault;
    final ready = releaseReady && changed;
    return (pinChangedFromDefault: changed, releaseReady: ready);
  }
}
