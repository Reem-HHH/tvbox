/// Default YouTube Data API key for household builds.
///
/// Parent settings key wins when set. Otherwise uses `--dart-define=YOUTUBE_API_KEY=...`
/// (or `--dart-define-from-file=local_defines.json`). No key is stored in git.
///
/// ```bash
/// cp local_defines.json.example local_defines.json   # fill in your key
/// flutter run --dart-define-from-file=local_defines.json -d <device>
/// ```
class YoutubeApiDefaults {
  YoutubeApiDefaults._();

  static const bundled = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: '',
  );

  static String? effective(String? storedOrParent) {
    final fromParent = storedOrParent?.trim();
    if (fromParent != null && fromParent.isNotEmpty) return fromParent;
    final fromBuild = bundled.trim();
    return fromBuild.isEmpty ? null : fromBuild;
  }
}
