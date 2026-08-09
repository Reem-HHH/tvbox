import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content_title_filter.dart';
import 'models.dart';

/// YouTube Data API playlist sync (requires a parent-stored API key).
class YoutubeCatalogSource {
  YoutubeCatalogSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    return _newestFirst(items);
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
