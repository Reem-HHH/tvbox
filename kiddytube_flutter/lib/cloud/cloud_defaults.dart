/// Baked-in cloud connection for household installs.
///
/// Prefer **pairing codes** from the web admin (no secret in the APK).
/// Auto-enroll is opt-in: set `CLOUD_AUTO_ENROLL=true` plus URL + secret.
///
/// ```bash
/// cp local_defines.json.example local_defines.json
/// # Pairing-first: only CLOUD_BASE_URL (enter code in Parent settings)
/// # Or auto-enroll: CLOUD_BASE_URL + CLOUD_ENROLL_SECRET + CLOUD_AUTO_ENROLL=true
/// flutter run --dart-define-from-file=local_defines.json -d <device>
/// ```
class CloudDefaults {
  CloudDefaults._();

  static const bundledBaseUrl = String.fromEnvironment(
    'CLOUD_BASE_URL',
    defaultValue: '',
  );

  static const bundledEnrollSecret = String.fromEnvironment(
    'CLOUD_ENROLL_SECRET',
    defaultValue: '',
  );

  /// Must be explicitly enabled — baking the enroll secret alone is not enough.
  static const allowAutoEnroll = bool.fromEnvironment(
    'CLOUD_AUTO_ENROLL',
    defaultValue: false,
  );

  static String? get baseUrl {
    final v = bundledBaseUrl.trim();
    return v.isEmpty ? null : v;
  }

  static String? get enrollSecret {
    final v = bundledEnrollSecret.trim();
    return v.isEmpty ? null : v;
  }

  /// True when this binary may auto-register (pairing is still preferred).
  static bool get canAutoEnroll =>
      allowAutoEnroll &&
      baseUrl != null &&
      enrollSecret != null &&
      enrollSecret!.length >= 8;
}
