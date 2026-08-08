import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/home_library.dart';
import 'package:kiddytube/catalog/models.dart';
import 'package:kiddytube/catalog/seed.dart';
import 'package:kiddytube/parent/parent_pin.dart';

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

  test('seed v16 has expected channels and starter videos where applicable', () {
    expect(DefaultChannels.seedVersion, 16);
    final seed = DefaultChannels.seed();
    expect(seed.length, greaterThanOrEqualTo(30));
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.contains('omar_hana'), isTrue);
    expect(ids.contains('dawood'), isTrue);
    expect(ids.contains('cocomelon'), isTrue);
    expect(ids.contains('mansour'), isTrue);
    for (final ch in seed) {
      if (ch.id == 'dawood') {
        expect(ch.youtubePlaylistId, isNotNull);
        continue;
      }
      expect(ch.videos, isNotEmpty, reason: ch.id);
      expect(ch.videos.every((v) => v.youtubeVideoId == v.id), isTrue);
    }
  });

  test('mergeSeedUpdates adds missing seed channels', () {
    final existing = [
      ContentChannel(
        id: 'omar_hana',
        title: 'Omar & Hana',
        sourceType: SourceType.youtubePlaylist,
        videos: const [
          VideoItem(id: 'T6ggVnk1JZg', title: 'Song', youtubeVideoId: 'T6ggVnk1JZg'),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    expect(merged.any((c) => c.id == 'peppa'), isTrue);
    expect(merged.any((c) => c.id == 'omar_hana'), isTrue);
  });

  test('ParentPinManager hashes and verifies default PIN', () {
    final salt = ParentPinManager.newSaltHex();
    final hash = ParentPinManager.hashPin(ParentPinManager.defaultDevPin, salt);
    expect(hash, isNotNull);
    final manager = ParentPinManager();
    expect(manager.verifyPin('2580', salt, hash), isTrue);
    expect(manager.verifyPin('0000', salt, hash), isFalse);
  });

  test('ParentPinManager lockout after failures', () {
    final manager = ParentPinManager();
    final now = 1_000_000;
    for (var i = 0; i < ParentPinManager.maxFailuresBeforeLockout - 1; i++) {
      expect(manager.registerFailure(now), isFalse);
    }
    expect(manager.registerFailure(now), isTrue);
    expect(manager.isLockedOut(now), isTrue);
  });
}
