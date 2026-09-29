import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content_title_filter.dart';
import 'models.dart';

/// YouTube Data API playlist sync (requires a parent-stored API key).
///
/// Keeps on-demand videos: drops YouTube Shorts (classic length, #shorts
/// labels/tags, or vertical 60–180s clips), live / upcoming broadcasts, and
/// videos YouTube marks non-embeddable (common for some Milo compilations —
/// they play on youtube.com but not in the kid iframe player).
class YoutubeCatalogSource {
  YoutubeCatalogSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sub-minute clips are treated as Shorts even without a #shorts label.
  static const classicShortMax = Duration(seconds: 60);

  /// YouTube allows Shorts up to 3 minutes. In this band, drop only if the
  /// clip is labeled a Short or has a vertical Shorts thumbnail.
  static const maxShortDuration = Duration(seconds: 180);

  /// Upper bound of the "maybe a Short" band (same as [maxShortDuration]).
  static const minFullVideoDuration = maxShortDuration;

  /// Match [CloudClient] so hung networks cannot leave parent sync busy forever.
  static const _requestTimeout = Duration(seconds: 20);

  Future<List<VideoItem>> fetchPlaylistVideos({
    required String apiKey,
    required String playlistId,
    int maxResults = 50,
  }) async {
    final items = <VideoItem>[];
    String? pageToken;
    var pagesFetched = 0;

    while (items.length < maxResults) {
      final params = <String, String>{
        'part': 'snippet,contentDetails',
        'playlistId': playlistId,
        'maxResults': '${maxResults - items.length > 50 ? 50 : maxResults - items.length}',
        'key': apiKey,
      };
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/playlistItems',
        params,
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          'YouTube API ${response.statusCode}: ${response.body}',
        );
      }
      pagesFetched++;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      if (root['error'] != null) {
        final message = (root['error'] as Map<String, dynamic>)['message'] ??
            'YouTube API error';
        throw Exception(message);
      }
      final arr = root['items'] as List<dynamic>? ?? const [];
      for (final raw in arr) {
        final item = Map<String, dynamic>.from(raw as Map);
        final snippet =
            Map<String, dynamic>.from(item['snippet'] as Map? ?? const {});
        final content = Map<String, dynamic>.from(
          item['contentDetails'] as Map? ?? const {},
        );
        final videoId = (content['videoId'] as String?)?.trim().isNotEmpty == true
            ? content['videoId'] as String
            : ((snippet['resourceId'] as Map?)?['videoId'] as String?);
        if (videoId == null || videoId.isEmpty) continue;
        final title = snippet['title'] as String? ?? 'Video';
        if (title.toLowerCase() == 'private video' ||
            title.toLowerCase() == 'deleted video') {
          continue;
        }
        if (ContentTitleFilter.isBlocked(title)) {
          continue;
        }
        if (looksLikeShortOrLiveTitle(title)) {
          continue;
        }
        final thumbs =
            Map<String, dynamic>.from(snippet['thumbnails'] as Map? ?? const {});
        final thumb = (thumbs['medium'] as Map?)?['url'] as String? ??
            (thumbs['default'] as Map?)?['url'] as String?;
        final published = (content['videoPublishedAt'] as String?)?.trim().isNotEmpty ==
                true
            ? content['videoPublishedAt'] as String
            : snippet['publishedAt'] as String?;
        items.add(
          VideoItem(
            id: videoId,
            title: title,
            thumbnailUrl: thumb,
            youtubeVideoId: videoId,
            publishedAtMs: _parseIso8601(published),
          ),
        );
      }
      pageToken = (root['nextPageToken'] as String?)?.isNotEmpty == true
          ? root['nextPageToken'] as String
          : null;
      if (pageToken == null) break;
    }

    if (pagesFetched == 0) {
      throw Exception('No playlist response');
    }

    final filtered = await keepFullOnDemandVideos(
      apiKey: apiKey,
      candidates: items,
    );
    return newestVideosFirst(filtered);
  }

  /// Batch-check duration, live status, embeddable, and family title/tags;
  /// drop Shorts / live / non-embeddable / off-brief rows that break the
  /// kid iframe player or fail the content gate.
  ///
  /// Used by playlist sync and by one-shot local catalog purge for leftover
  /// Shorts that arrived before duration filtering existed.
  Future<List<VideoItem>> keepFullOnDemandVideos({
    required String apiKey,
    required List<VideoItem> candidates,
  }) async {
    if (candidates.isEmpty) return candidates;
    final byId = {for (final v in candidates) v.id: v};
    final kept = <VideoItem>[];

    for (var i = 0; i < candidates.length; i += 50) {
      final chunk = candidates.skip(i).take(50).map((v) => v.id).toList();
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/videos',
        {
          'part': 'contentDetails,snippet,status',
          'id': chunk.join(','),
          'key': apiKey,
        },
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          'YouTube videos API ${response.statusCode}: ${response.body}',
        );
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      if (root['error'] != null) {
        final message = (root['error'] as Map<String, dynamic>)['message'] ??
            'YouTube API error';
        throw Exception(message);
      }
      final arr = root['items'] as List<dynamic>? ?? const [];
      final seen = <String>{};
      for (final raw in arr) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id'] as String?;
        if (id == null || id.isEmpty) continue;
        seen.add(id);
        final snippet =
            Map<String, dynamic>.from(item['snippet'] as Map? ?? const {});
        final content = Map<String, dynamic>.from(
          item['contentDetails'] as Map? ?? const {},
        );
        final status =
            Map<String, dynamic>.from(item['status'] as Map? ?? const {});
        final title = snippet['title'] as String? ?? byId[id]?.title ?? '';
        final tags = _stringList(snippet['tags']);
        final live = (snippet['liveBroadcastContent'] as String?)?.trim() ??
            'none';
        final duration = parseIso8601Duration(
          content['duration'] as String?,
        );
        final embeddable = status['embeddable'] as bool?;
        final labeledShort =
            looksLikeShortOrLiveTitle(title) || looksLikeShortsTags(tags);
        var isVerticalShort = false;
        if (!labeledShort &&
            id.isNotEmpty &&
            duration != null &&
            duration >= classicShortMax &&
            duration <= maxShortDuration) {
          isVerticalShort = await looksLikeVerticalShort(id);
        }
        if (!isFullOnDemandVideo(
          title: title,
          liveBroadcastContent: live,
          duration: duration,
          embeddable: embeddable,
          tags: tags,
          isVerticalShort: isVerticalShort,
        )) {
          continue;
        }
        if (ContentTitleFilter.isBlocked(title, tags: tags)) {
          continue;
        }
        final base = byId[id];
        if (base == null) continue;
        kept.add(
          base.copyWith(
            title: title,
            publishedAtMs: _parseIso8601(snippet['publishedAt'] as String?),
          ),
        );
      }
      // Drop IDs the videos.list call did not return (unavailable / region).
      for (final id in chunk) {
        if (!seen.contains(id)) {
          byId.remove(id);
        }
      }
    }

    // Preserve playlist order (newest-first applied by caller).
    return [
      for (final v in candidates)
        if (kept.any((k) => k.id == v.id))
          kept.firstWhere((k) => k.id == v.id),
    ];
  }

  /// True when the item is a normal VOD suitable for kids (not Short / live /
  /// embed-blocked).
  ///
  /// Duration bands: under 60s is always a Short; 60–180s is a Short only when
  /// labeled (`#shorts` / Shorts tags) or [isVerticalShort]; over 180s is kept.
  static bool isFullOnDemandVideo({
    required String title,
    required String liveBroadcastContent,
    Duration? duration,
    bool? embeddable,
    Iterable<String>? tags,
    bool isVerticalShort = false,
  }) {
    if (embeddable == false) return false;
    final live = liveBroadcastContent.trim().toLowerCase();
    if (live == 'live' || live == 'upcoming') return false;
    if (looksLikeShortOrLiveTitle(title) || looksLikeShortsTags(tags)) {
      return false;
    }
    if (duration != null) {
      if (duration < classicShortMax) return false;
      if (duration <= maxShortDuration && isVerticalShort) return false;
    }
    return true;
  }

  /// True when YouTube tags mark the upload as a Short (not the word "short").
  static bool looksLikeShortsTags(Iterable<String>? tags) {
    if (tags == null) return false;
    for (final raw in tags) {
      final t = raw.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (t == 'shorts' ||
          t == '#shorts' ||
          t == '#short' ||
          t == 'youtubeshorts' ||
          t == 'youtube shorts' ||
          t == 'ytshorts') {
        return true;
      }
      if (t.contains('#shorts') || t.contains('youtubeshorts')) {
        return true;
      }
    }
    return false;
  }

  /// Title heuristics for Shorts and live streams (Arabic + English).
  static bool looksLikeShortOrLiveTitle(String? title) {
    if (title == null || title.trim().isEmpty) return false;
    final t = title.toLowerCase();
    if (t.contains('#shorts') ||
        t.contains('#short') ||
        t.contains('youtube shorts') ||
        RegExp(r'(^|[^a-z])shorts([^a-z]|$)').hasMatch(t)) {
      return true;
    }
    if (t.contains('بث مباشر') ||
        t.contains('livestream') ||
        t.contains('live stream') ||
        t.contains('live broadcast') ||
        (t.contains('🔴') && t.contains('live')) ||
        RegExp(r'(^|[^a-z])live\s*[:\-|!]').hasMatch(t) ||
        RegExp(r'^live\b').hasMatch(t) ||
        RegExp(r'(^|[^a-z])livestream([^a-z]|$)').hasMatch(t)) {
      return true;
    }
    return false;
  }

  /// YouTube serves `oardefault.jpg` for vertical Shorts. Landscape VODs 404.
  /// Fail open (treat as not a Short) on network errors.
  Future<bool> looksLikeVerticalShort(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return false;
    final uri = Uri.https('i.ytimg.com', '/vi/$id/oardefault.jpg');
    try {
      final response = await _client.head(uri).timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Parses YouTube `contentDetails.duration` (ISO-8601), e.g. `PT1M30S`.
  static Duration? parseIso8601Duration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(raw);
    if (match == null) return null;
    final days = int.tryParse(match.group(1) ?? '') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '') ?? 0;
    return Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  static int? _parseIso8601(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  /// `snippet.publishedAt` for each video id (does not filter Shorts).
  Future<Map<String, int>> fetchPublishedAtById({
    required String apiKey,
    required List<String> videoIds,
  }) async {
    final out = <String, int>{};
    final unique = {
      for (final raw in videoIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    }.toList();
    for (var i = 0; i < unique.length; i += 50) {
      final chunk = unique.skip(i).take(50).toList();
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/videos',
        {
          'part': 'snippet',
          'id': chunk.join(','),
          'key': apiKey,
        },
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) continue;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in root['items'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id'] as String?;
        final snippet =
            Map<String, dynamic>.from(item['snippet'] as Map? ?? const {});
        final ms = _parseIso8601(snippet['publishedAt'] as String?);
        if (id == null || ms == null) continue;
        out[id] = ms;
      }
    }
    return out;
  }
}
