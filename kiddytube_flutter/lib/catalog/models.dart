enum SourceType {
  youtubePlaylist,
  youtubeVideoList,
  directUrl;

  static SourceType fromName(String? raw) {
    for (final value in SourceType.values) {
      if (value.name == raw) return value;
    }
    return SourceType.youtubeVideoList;
  }
}

/// Kids home: channel tiles vs a flat newest-first video mix.
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

  /// YouTube thumbnail for this video. Always derived from the video id so
  /// kids see the correct episode art when catalog content changes.
  /// Uses mqdefault (320×180) for faster decode/scroll than sd/hq.
  String? get youtubeThumbnail {
    final id = youtubeVideoId;
    if (id != null && id.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
    }
    return thumbnailUrl;
  }

  VideoItem copyWith({
    String? title,
    String? thumbnailUrl,
    String? youtubeVideoId,
    String? directUrl,
    int? publishedAtMs,
    bool? manual,
    bool? allowSeek,
  }) {
    return VideoItem(
      id: id,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      directUrl: directUrl ?? this.directUrl,
      publishedAtMs: publishedAtMs ?? this.publishedAtMs,
      manual: manual ?? this.manual,
      allowSeek: allowSeek ?? this.allowSeek,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
        if (directUrl != null) 'directUrl': directUrl,
        if (publishedAtMs != null) 'publishedAtMs': publishedAtMs,
        'manual': manual,
        'allowSeek': allowSeek,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Video',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        youtubeVideoId: json['youtubeVideoId'] as String?,
        directUrl: json['directUrl'] as String?,
        publishedAtMs: (json['publishedAtMs'] as num?)?.toInt(),
        manual: json['manual'] as bool? ?? false,
        allowSeek: json['allowSeek'] as bool? ?? true,
      );
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
    this.playlistManagedByParent = false,
    this.defaultAllowSeek = true,
    this.youtubeChannelId,
    this.artworkUrl,
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
  final bool playlistManagedByParent;
  final bool defaultAllowSeek;
  /// YouTube `UC…` id used to fetch the channel's cartoon avatar.
  final String? youtubeChannelId;
  /// HTTPS URL of the YouTube channel profile image (not an episode thumb).
  final String? artworkUrl;

  /// Show-folder image: channel avatar when fetched, else first episode thumb.
  String? get tileArtwork {
    final art = artworkUrl?.trim();
    if (art != null && art.isNotEmpty) return art;
    return previewThumbnail;
  }

  /// Preview thumb from the first YouTube video when available.
  String? get previewThumbnail {
    for (final v in videos) {
      final t = v.youtubeThumbnail;
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  /// Stable id of the video used for the channel tile image (for cache keys).
  String? get previewVideoId {
    for (final v in videos) {
      if (v.youtubeVideoId != null && v.youtubeVideoId!.isNotEmpty) {
        return v.youtubeVideoId;
      }
      if (v.thumbnailUrl != null && v.thumbnailUrl!.isNotEmpty) return v.id;
    }
    return null;
  }

  ContentChannel copyWith({
    String? title,
    SourceType? sourceType,
    bool? enabled,
    String? youtubePlaylistId,
    bool clearPlaylist = false,
    List<VideoItem>? videos,
    int? sortOrder,
    bool? followUploads,
    int? color,
    bool? playlistManagedByParent,
    bool? defaultAllowSeek,
    String? youtubeChannelId,
    String? artworkUrl,
  }) {
    return ContentChannel(
      id: id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      enabled: enabled ?? this.enabled,
      youtubePlaylistId:
          clearPlaylist ? null : (youtubePlaylistId ?? this.youtubePlaylistId),
      videos: videos ?? this.videos,
      sortOrder: sortOrder ?? this.sortOrder,
      followUploads: followUploads ?? this.followUploads,
      color: color ?? this.color,
      playlistManagedByParent:
          playlistManagedByParent ?? this.playlistManagedByParent,
      defaultAllowSeek: defaultAllowSeek ?? this.defaultAllowSeek,
      youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceType': sourceType.name,
        'enabled': enabled,
        if (youtubePlaylistId != null) 'youtubePlaylistId': youtubePlaylistId,
        'videos': videos.map((v) => v.toJson()).toList(),
        'sortOrder': sortOrder,
        'followUploads': followUploads,
        'color': color,
        'playlistManagedByParent': playlistManagedByParent,
        'defaultAllowSeek': defaultAllowSeek,
        if (youtubeChannelId != null) 'youtubeChannelId': youtubeChannelId,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
      };

  factory ContentChannel.fromJson(Map<String, dynamic> json) => ContentChannel(
        id: json['id'] as String,
        title: json['title'] as String? ?? json['id'] as String,
        sourceType: SourceType.fromName(json['sourceType'] as String?),
        enabled: json['enabled'] as bool? ?? true,
        youtubePlaylistId: json['youtubePlaylistId'] as String?,
        videos: (json['videos'] as List<dynamic>? ?? const [])
            .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        followUploads: json['followUploads'] as bool? ?? false,
        color: (json['color'] as num?)?.toInt() ?? 0xFF42A5F5,
        playlistManagedByParent:
            json['playlistManagedByParent'] as bool? ?? false,
        defaultAllowSeek: json['defaultAllowSeek'] as bool? ?? true,
        youtubeChannelId: json['youtubeChannelId'] as String?,
        artworkUrl: json['artworkUrl'] as String?,
      );
}

/// Newest [publishedAtMs] first; stable for equal/missing dates.
List<VideoItem> newestVideosFirst(List<VideoItem> items) {
  final indexed = items.asMap().entries.toList();
  indexed.sort((a, b) {
    final aMs = a.value.publishedAtMs ?? -1;
    final bMs = b.value.publishedAtMs ?? -1;
    final byDate = bMs.compareTo(aMs);
    if (byDate != 0) return byDate;
    return a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

/// Video tile bound to its owning channel.
class PlayableVideo {
  const PlayableVideo({required this.channelId, required this.video});

  final String channelId;
  final VideoItem video;
}
