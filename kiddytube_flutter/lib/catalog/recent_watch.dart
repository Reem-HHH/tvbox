import 'dart:async';
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
    this.durationMs = 0,
    required this.updatedAtMs,
  });

  final String channelId;
  final String videoId;
  final String title;
  final String? youtubeVideoId;
  final String? directUrl;
  final int positionMs;
  final int durationMs;
  final int updatedAtMs;

  RecentWatchItem copyWith({
    String? channelId,
    String? videoId,
    String? title,
    String? youtubeVideoId,
    String? directUrl,
    int? positionMs,
    int? durationMs,
    int? updatedAtMs,
  }) {
    return RecentWatchItem(
      channelId: channelId ?? this.channelId,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      directUrl: directUrl ?? this.directUrl,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'videoId': videoId,
        'title': title,
        if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
        if (directUrl != null) 'directUrl': directUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
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
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
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
  Future<void>? _writeChain;
  static const _key = 'recent_watch_v1';
  static const maxItems = 12;

  Future<void> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _writeChain;
    final done = Completer<void>();
    _writeChain = done.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_writeChain, done.future)) {
        _writeChain = null;
      }
    }
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
    int durationMs = 0,
  }) async {
    await _serialized(() async {
      await _ensure();
      final now = DateTime.now().millisecondsSinceEpoch;
      final current = await load();
      RecentWatchItem? previous;
      for (final item in current) {
        if (item.channelId == channelId && item.videoId == video.id) {
          previous = item;
          break;
        }
      }
      final keptDuration =
          durationMs > 0 ? durationMs : (previous?.durationMs ?? 0);
      final next = [
        RecentWatchItem(
          channelId: channelId,
          videoId: video.id,
          title: video.title,
          youtubeVideoId: video.youtubeVideoId,
          directUrl: video.directUrl,
          positionMs: positionMs,
          durationMs: keptDuration,
          updatedAtMs: now,
        ),
        ...current.where(
          (e) => !(e.channelId == channelId && e.videoId == video.id),
        ),
      ].take(maxItems).toList();
      await _prefs!.setString(
        _key,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
    });
  }

  Future<void> clear() async {
    await _serialized(() async {
      await _ensure();
      await _prefs!.remove(_key);
    });
  }

  /// Merge cloud rows with local; keep newest per channel+video, cap [maxItems].
  /// If the winning row has no duration, keep a known duration from the other copy.
  Future<List<RecentWatchItem>> mergeFromCloud(
    List<RecentWatchItem> remote,
  ) async {
    return _serialized(() async {
      await _ensure();
      final local = await load();
      final byKey = <String, RecentWatchItem>{};
      for (final item in [...local, ...remote]) {
        final key = '${item.channelId}::${item.videoId}';
        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = item;
          continue;
        }
        final newer = item.updatedAtMs >= existing.updatedAtMs ? item : existing;
        final older = identical(newer, item) ? existing : item;
        byKey[key] = keepKnownDuration(newer, older);
      }
      final merged = byKey.values.toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      final next = merged.take(maxItems).toList();
      await _prefs!.setString(
        _key,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
      return next;
    });
  }
}

/// Prefer [winner]; if it has no duration, copy duration from [other].
RecentWatchItem keepKnownDuration(RecentWatchItem winner, RecentWatchItem other) {
  if (winner.durationMs > 0 || other.durationMs <= 0) return winner;
  return winner.copyWith(durationMs: other.durationMs);
}

/// Clamp resume position like Kotlin [PlayerActivity.clampedResumePosition].
int clampedResumePosition(int positionMs, int durationMs) {
  if (positionMs < 5000) return 0;
  if (durationMs > 0 && positionMs >= (durationMs * 0.92).floor()) {
    return 0;
  }
  return positionMs;
}

/// Real watched fraction for a progress bar. Zero when duration is unknown
/// (never a fake placeholder).
double watchProgressFraction(int positionMs, int durationMs) {
  if (durationMs <= 0 || positionMs <= 0) return 0;
  return (positionMs / durationMs).clamp(0.0, 1.0);
}

/// Resume offset to pass into the player (near-start / near-end → 0).
int resumeStartMs(int positionMs, int durationMs) =>
    clampedResumePosition(positionMs, durationMs);
