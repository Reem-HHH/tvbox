import 'content_title_filter.dart';
import 'media_ids.dart';
import 'models.dart';

/// Validates / sanitizes catalog rows from cloud, import, or untrusted JSON.
class CatalogSanitize {
  CatalogSanitize._();

  /// Drop blocked titles and invalid media; keep only playable videos.
  static ContentChannel? channel(ContentChannel channel) {
    final id = channel.id.trim();
    if (id.isEmpty) return null;
    final videos = <VideoItem>[];
    for (final raw in channel.videos) {
      final v = video(raw);
      if (v != null) videos.add(v);
    }
    return channel.copyWith(
      title: channel.title.trim().isEmpty ? id : channel.title.trim(),
      videos: videos,
      youtubePlaylistId: MediaIds.extractPlaylistId(channel.youtubePlaylistId),
    );
  }

  static VideoItem? video(VideoItem raw) {
    if (ContentTitleFilter.isBlocked(raw.title)) return null;
    final yt = MediaIds.isValidVideoId(raw.youtubeVideoId)
        ? raw.youtubeVideoId!.trim()
        : MediaIds.extractVideoId(raw.youtubeVideoId);
    final direct =
        MediaIds.isDirectMediaUrl(raw.directUrl) ? raw.directUrl!.trim() : null;
    if (yt == null && direct == null) return null;
    final id = (yt ?? raw.id).trim();
    if (id.isEmpty) return null;
    return VideoItem(
      id: id,
      title: raw.title.trim().isEmpty ? 'Video' : raw.title.trim(),
      thumbnailUrl: raw.thumbnailUrl,
      youtubeVideoId: yt,
      directUrl: direct,
      publishedAtMs: raw.publishedAtMs,
      manual: raw.manual,
      allowSeek: raw.allowSeek,
    );
  }

  static List<ContentChannel> channels(Iterable<ContentChannel> input) {
    final out = <ContentChannel>[];
    for (final ch in input) {
      final cleaned = channel(ch);
      if (cleaned != null) out.add(cleaned);
    }
    return out;
  }
}
