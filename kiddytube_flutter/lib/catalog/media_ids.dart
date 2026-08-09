/// YouTube ID / URL parsing and direct HTTPS media validation.
/// Mirrors native [YoutubeUrlParser] + [MediaUrlValidator].
class MediaIds {
  MediaIds._();

  static final _validVideoId = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static final _videoFromUrl = RegExp(
    r'(?:youtube\.com/watch\?.*v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})',
  );
  static const _allowedExtensions = ['.mp4', '.m3u8', '.mpd'];

  static bool isValidVideoId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return _validVideoId.hasMatch(id.trim());
  }

  static String? extractVideoId(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final trimmed = input.trim();
    final fromUrl = _videoFromUrl.firstMatch(trimmed);
    if (fromUrl != null) {
      final id = fromUrl.group(1);
      return isValidVideoId(id) ? id : null;
    }
    if (isValidVideoId(trimmed)) return trimmed;
    return null;
  }

  /// Split on commas, semicolons, newlines, or spaces and extract video ids.
  static List<String> parseVideoIdsCsv(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    final parts = csv.split(RegExp(r'[,;\s]+'));
    final ids = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      final id = extractVideoId(part.trim());
      if (id != null && seen.add(id)) ids.add(id);
    }
    return ids;
  }

  static String defaultThumbnail(String videoId) =>
      'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  /// Direct media must be HTTPS file/stream URLs (.mp4 / .m3u8 / .mpd).
  static bool isDirectMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (_isBlockedViewerPage(url)) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.isEmpty) return false;
    return _hasAllowedMediaExtension(uri);
  }

  static bool _hasAllowedMediaExtension(Uri uri) {
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    return _allowedExtensions.any(path.endsWith);
  }

  static bool _isBlockedViewerPage(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('drive.google.com') && lower.contains('/view')) {
      return true;
    }
    if (lower.contains('docs.google.com')) return true;
    if (lower.contains('youtube.com/watch')) return true;
    if (lower.contains('youtube.com/shorts')) return true;
    if (lower.contains('youtu.be/') && !lower.contains('embed')) return true;
    if (lower.contains('dropbox.com/s/') && !lower.contains('dl=1')) {
      return true;
    }
    return false;
  }
}
