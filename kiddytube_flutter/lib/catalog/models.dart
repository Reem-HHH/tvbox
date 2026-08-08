enum SourceType {
  youtubePlaylist,
  youtubeVideoList,
  directUrl,
}

/// Kids home: channel tiles vs a flat shuffled video mix.
enum HomeLibraryMode {
  channels,
  mixVideos;

  static HomeLibraryMode fromStored(String? raw) {
    for (final value in HomeLibraryMode.values) {
      if (value.name == raw) return value;
    }
    return HomeLibraryMode.channels;
  }

  String get storageName => name;
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.youtubeVideoId,
    this.directUrl,
    this.publishedAtMs,
    this.manual = false,
    this.allowSeek = true,
  });

  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? youtubeVideoId;
  final String? directUrl;
  final int? publishedAtMs;
  final bool manual;
  final bool allowSeek;

  bool get isYoutube => youtubeVideoId != null && youtubeVideoId!.isNotEmpty;
  bool get isDirect => directUrl != null && directUrl!.isNotEmpty;

  /// YouTube hqdefault thumbnail when an id is present.
  String? get youtubeThumbnail {
    final id = youtubeVideoId;
    if (id == null || id.isEmpty) return null;
    return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  }
}

class ContentChannel {
  const ContentChannel({
    required this.id,
    required this.title,
    required this.sourceType,
    this.enabled = true,
    this.youtubePlaylistId,
    this.videos = const [],
    this.sortOrder = 0,
    this.followUploads = false,
    this.color = 0xFF42A5F5,
  });

  final String id;
  final String title;
  final SourceType sourceType;
  final bool enabled;
  final String? youtubePlaylistId;
  final List<VideoItem> videos;
  final int sortOrder;
  final bool followUploads;
  /// ARGB seed tile color until artwork assets are ported.
  final int color;

  ContentChannel copyWith({
    bool? enabled,
    List<VideoItem>? videos,
    bool? followUploads,
  }) {
    return ContentChannel(
      id: id,
      title: title,
      sourceType: sourceType,
      enabled: enabled ?? this.enabled,
      youtubePlaylistId: youtubePlaylistId,
      videos: videos ?? this.videos,
      sortOrder: sortOrder,
      followUploads: followUploads ?? this.followUploads,
      color: color,
    );
  }
}

/// Video tile bound to its owning channel.
class PlayableVideo {
  const PlayableVideo({required this.channelId, required this.video});

  final String channelId;
  final VideoItem video;
}
