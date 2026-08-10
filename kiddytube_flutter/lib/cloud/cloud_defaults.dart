/// Baked-in cloud connection for household installs.
///
/// Use `--dart-define` / `local_defines.json` so installs auto-enroll — no
/// typing URL or pairing code on the TV. Values are never committed to git.
///
/// ```bash
/// cp local_defines.json.example local_defines.json
/// # set CLOUD_BASE_URL + CLOUD_ENROLL_SECRET (match Render DEVICE_ENROLL_SECRET)
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

  static String? get baseUrl {
    final v = bundledBaseUrl.trim();
    return v.isEmpty ? null : v;
  }

  static String? get enrollSecret {
    final v = bundledEnrollSecret.trim();
    return v.isEmpty ? null : v;
  }

  /// True when this binary can auto-register with the family cloud.
  static bool get canAutoEnroll =>
      baseUrl != null && enrollSecret != null && enrollSecret!.length >= 8;
}
