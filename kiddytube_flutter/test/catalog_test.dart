import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/home_library.dart';
import 'package:kiddytube/catalog/models.dart';
import 'package:kiddytube/catalog/seed.dart';

void main() {
  test('HomeLibraryMode defaults unknown storage to channels', () {
    expect(HomeLibraryMode.fromStored(null), HomeLibraryMode.channels);
    expect(HomeLibraryMode.fromStored('nope'), HomeLibraryMode.channels);
    expect(HomeLibraryMode.fromStored('mixVideos'), HomeLibraryMode.mixVideos);
  });

  test('flattenEnabledVideos only includes enabled channels and is seed-stable', () {
    final channels = [
      ContentChannel(
        id: 'a',
        title: 'A',
        sourceType: SourceType.youtubeVideoList,
        enabled: true,
        videos: const [
          VideoItem(id: '1', title: 'One', youtubeVideoId: '1'),
          VideoItem(id: '2', title: 'Two', youtubeVideoId: '2'),
        ],
      ),
      ContentChannel(
        id: 'b',
        title: 'B',
        sourceType: SourceType.youtubeVideoList,
        enabled: false,
        videos: const [
          VideoItem(id: '3', title: 'Three', youtubeVideoId: '3'),
        ],
      ),
    ];

    final first = flattenEnabledVideos(channels, 42);
    final second = flattenEnabledVideos(channels, 42);
    expect(first.map((e) => e.video.id).toSet(), {'1', '2'});
    expect(first.every((e) => e.channelId == 'a'), isTrue);
    expect(
      first.map((e) => e.video.id).toList(),
      second.map((e) => e.video.id).toList(),
    );
  });

  test('seed has starter videos on scaffold channels', () {
    final seed = DefaultChannels.seed();
    expect(seed, isNotEmpty);
    for (final ch in seed) {
      expect(ch.videos, isNotEmpty, reason: ch.id);
      expect(ch.videos.every((v) => v.youtubeVideoId == v.id), isTrue);
    }
  });
}
