import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content_title_filter.dart';
import 'models.dart';

/// YouTube Data API playlist sync (requires a parent-stored API key).
///
/// Keeps full on-demand videos only: drops Shorts (by duration / title) and
/// live / upcoming broadcasts that often break in the kid player.
class YoutubeCatalogSource {
  YoutubeCatalogSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Shorts are typically under a minute; allow a small buffer.
  static const minFullVideoDuration = Duration(seconds: 60);

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
      final response = await _client.get(uri);
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

    final filtered = await _keepFullOnDemandVideos(
      apiKey: apiKey,
      candidates: items,
    );
    return _newestFirst(filtered);
  }

  /// Batch-check duration + liveBroadcastContent; drop Shorts and live/upcoming.
  Future<List<VideoItem>> _keepFullOnDemandVideos({
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
          'part': 'contentDetails,snippet',
          'id': chunk.join(','),
          'key': apiKey,
        },
      );
      final response = await _client.get(uri);
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
        final title = snippet['title'] as String? ?? byId[id]?.title ?? '';
        final live = (snippet['liveBroadcastContent'] as String?)?.trim() ??
            'none';
        final duration = parseIso8601Duration(
          content['duration'] as String?,
        );
        if (!isFullOnDemandVideo(
          title: title,
          liveBroadcastContent: live,
          duration: duration,
        )) {
          continue;
        }
        final base = byId[id];
        if (base == null) continue;
        kept.add(base.copyWith(title: title));
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

  /// True when the item is a normal VOD suitable for kids (not Short / live).
  static bool isFullOnDemandVideo({
    required String title,
    required String liveBroadcastContent,
    Duration? duration,
  }) {
    final live = liveBroadcastContent.trim().toLowerCase();
    if (live == 'live' || live == 'upcoming') return false;
    if (looksLikeShortOrLiveTitle(title)) return false;
    if (duration != null && duration < minFullVideoDuration) return false;
    return true;
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
        RegExp(r'(^|[^a-z])live\s*[:\-|]').hasMatch(t) ||
        RegExp(r'(^|[^a-z])livestream([^a-z]|$)').hasMatch(t)) {
      return true;
    }
    return false;
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

  static List<VideoItem> _newestFirst(List<VideoItem> items) {
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
}
