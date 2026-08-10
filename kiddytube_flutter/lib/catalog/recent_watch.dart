import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class RecentWatchItem {
  const RecentWatchItem({
    required this.channelId,
    required this.videoId,
    required this.title,
    this.youtubeVideoId,
    this.directUrl,
    this.positionMs = 0,
    required this.updatedAtMs,
  });

  final String channelId;
  final String videoId;
  final String title;
  final String? youtubeVideoId;
  final String? directUrl;
  final int positionMs;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'videoId': videoId,
        'title': title,
        if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
        if (directUrl != null) 'directUrl': directUrl,
        'positionMs': positionMs,
        'updatedAtMs': updatedAtMs,
      };

  factory RecentWatchItem.fromJson(Map<String, dynamic> json) =>
      RecentWatchItem(
        channelId: json['channelId'] as String? ?? '',
        videoId: json['videoId'] as String? ?? '',
        title: json['title'] as String? ?? 'Video',
        youtubeVideoId: json['youtubeVideoId'] as String?,
        directUrl: json['directUrl'] as String?,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );

  PlayableVideo toPlayable() => PlayableVideo(
        channelId: channelId,
        video: VideoItem(
          id: videoId,
          title: title,
          youtubeVideoId: youtubeVideoId,
          directUrl: directUrl,
        ),
      );
}

class RecentWatchStore {
  RecentWatchStore([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _key = 'recent_watch_v1';
  static const maxItems = 12;

  Future<void> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<RecentWatchItem>> load() async {
    await _ensure();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentWatchItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> record({
    required String channelId,
    required VideoItem video,
    int positionMs = 0,
  }) async {
    await _ensure();
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await load();
    final next = [
      RecentWatchItem(
        channelId: channelId,
        videoId: video.id,
        title: video.title,
        youtubeVideoId: video.youtubeVideoId,
        directUrl: video.directUrl,
        positionMs: positionMs,
        updatedAtMs: now,
      ),
      ...current.where((e) => !(e.channelId == channelId && e.videoId == video.id)),
    ].take(maxItems).toList();
    await _prefs!.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _ensure();
    await _prefs!.remove(_key);
  }

  /// Merge cloud rows with local; keep newest per channel+video, cap [maxItems].
  Future<List<RecentWatchItem>> mergeFromCloud(
    List<RecentWatchItem> remote,
  ) async {
    await _ensure();
    final local = await load();
    final byKey = <String, RecentWatchItem>{};
    for (final item in [...local, ...remote]) {
      final key = '${item.channelId}::${item.videoId}';
      final existing = byKey[key];
      if (existing == null || item.updatedAtMs >= existing.updatedAtMs) {
        byKey[key] = item;
      }
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    final next = merged.take(maxItems).toList();
    await _prefs!.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    return next;
  }
}

/// Clamp resume position like Kotlin [PlayerActivity.clampedResumePosition].
int clampedResumePosition(int positionMs, int durationMs) {
  if (positionMs < 5000) return 0;
  if (durationMs > 0 && positionMs >= (durationMs * 0.92).floor()) {
    return 0;
  }
  return positionMs;
}
