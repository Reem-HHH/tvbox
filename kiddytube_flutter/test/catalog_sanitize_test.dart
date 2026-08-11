import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_sanitize.dart';
import 'package:kiddytube/catalog/media_ids.dart';
import 'package:kiddytube/catalog/models.dart';

void main() {
  test('CatalogSanitize drops Shorts/live titles', () {
    final channel = ContentChannel(
      id: 'demo',
      title: 'Demo',
      sourceType: SourceType.youtubeVideoList,
      videos: const [
        VideoItem(
          id: 'abcdefghijk',
          title: 'Funny #Shorts',
          youtubeVideoId: 'abcdefghijk',
        ),
        VideoItem(
          id: 'lmnopqrstuv',
          title: 'Full episode',
          youtubeVideoId: 'lmnopqrstuv',
        ),
        VideoItem(
          id: 'wxyzaaaaaaa',
          title: 'LIVE: stream',
          youtubeVideoId: 'wxyzaaaaaaa',
        ),
      ],
    );

    final cleaned = CatalogSanitize.channel(channel)!;
    expect(cleaned.videos.map((v) => v.id), ['lmnopqrstuv']);
  });

  test('parseVideoIdsCsv rejects shorts URLs but accepts watch URLs', () {
    expect(MediaIds.isShortsUrl('https://www.youtube.com/shorts/abcdefghijk'), isTrue);
    expect(
      MediaIds.parseVideoIdsCsv(
        'https://www.youtube.com/shorts/abcdefghijk, https://youtu.be/lmnopqrstuv',
      ),
      ['lmnopqrstuv'],
    );
    expect(
      MediaIds.extractVideoId('https://www.youtube.com/shorts/abcdefghijk'),
      'abcdefghijk',
    );
  });
}
