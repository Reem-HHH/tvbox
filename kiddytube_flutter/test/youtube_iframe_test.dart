import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/media_ids.dart';
import 'package:kiddytube/player/youtube_iframe.dart';

void main() {
  test('youtubeIframeHtml rejects invalid ids', () {
    expect(
      () => youtubeIframeHtml(videoId: "';alert(1)//"),
      throwsArgumentError,
    );
    expect(
      () => youtubeIframeHtml(videoId: 'short'),
      throwsArgumentError,
    );
  });

  test('youtubeIframeHtml embeds allowlisted id only', () {
    const id = 'dQw4w9WgXcQ';
    expect(MediaIds.isValidVideoId(id), isTrue);
    final html = youtubeIframeHtml(videoId: id, startSec: 12);
    expect(html.contains("videoId:'$id'"), isTrue);
    expect(html.contains('<script>'), isTrue);
    expect(html.contains('function loadVideoById'), isTrue);
  });
}
