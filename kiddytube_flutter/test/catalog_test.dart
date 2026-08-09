import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/home_library.dart';
import 'package:kiddytube/catalog/models.dart';
import 'package:kiddytube/catalog/recent_watch.dart';
import 'package:kiddytube/catalog/seed.dart';
import 'package:kiddytube/parent/parent_pin.dart';
import 'package:kiddytube/parent/release_pin_policy.dart';

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


  test('seed keeps Twirlywoos expanded starters', () {
    expect(DefaultChannels.seedVersion, 24);
    final twirly = DefaultChannels.seed().firstWhere((c) => c.id == 'twirlywoos');
    expect(twirly.videos.any((v) => v.id == 'wAFiVXz1NNw'), isTrue);
    expect(twirly.videos.any((v) => v.id == 'Wg0JkKmQY6A'), isTrue);
    expect(twirly.videos.length, greaterThanOrEqualTo(9));
  });

  test('seed v19 adds Maruko Chan Arabic starters', () {
    expect(DefaultChannels.seedVersion, 24);
    final maruko = DefaultChannels.seed().firstWhere((c) => c.id == 'maruko');
    expect(maruko.title, 'ماروكو الصغيرة');
    expect(maruko.followUploads, isFalse);
    expect(maruko.youtubePlaylistId, isNull);
    expect(maruko.videos.any((v) => v.id == 'OMbPlfL2VMY'), isTrue);
    expect(maruko.videos.any((v) => v.id == '7Xf9nKYyAM4'), isTrue);
    expect(maruko.videos.length, greaterThanOrEqualTo(16));
    expect(maruko.videos.any((v) => v.id == 'efoYDgyUdbU'), isTrue);
  });

  test('seed includes live Makkah Quran Masha Blippi Disney channels', () {
    expect(DefaultChannels.seedVersion, 24);
    final seed = DefaultChannels.seed();
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.containsAll([
      'live_makkah',
      'live_quran',
      'masha_ar',
      'blippi_ar',
      'disney_songs',
    ]), isTrue);
    expect(ids.contains('disney_songs_ar'), isFalse);
    expect(DefaultChannels.retiredChannelIds.contains('disney_songs_ar'), isTrue);
    final makkah = seed.firstWhere((c) => c.id == 'live_makkah');
    expect(makkah.videos.any((v) => v.id == 'wawzF8i5yAo'), isTrue);
    expect(makkah.followUploads, isFalse);
    final disney = seed.firstWhere((c) => c.id == 'disney_songs');
    expect(disney.videos.any((v) => v.id == 'L0MK7qz13bU'), isTrue);
    expect(disney.videos.any((v) => v.id == 'bseyU2PvBQo'), isTrue);
    expect(disney.videos.length, greaterThanOrEqualTo(16));
    expect(disney.followUploads, isFalse);
  });

  test('seed v18 enables daily follow and Numberblocks Season 1', () {
    expect(DefaultChannels.seedVersion, 24);
    final seed = DefaultChannels.seed();
    expect(seed.length, greaterThanOrEqualTo(30));
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.contains('omar_hana'), isTrue);
    expect(ids.contains('dawood'), isTrue);
    expect(ids.contains('cocomelon'), isTrue);
    expect(ids.contains('mansour'), isTrue);
    expect(ids.contains('numberblocks'), isTrue);
    for (final ch in seed) {
      if (ch.youtubePlaylistId != null && ch.youtubePlaylistId!.isNotEmpty) {
        expect(ch.followUploads, isTrue, reason: ch.id);
      }
      if (ch.id == 'dawood') {
        expect(ch.youtubePlaylistId, isNotNull);
        continue;
      }
      expect(ch.videos, isNotEmpty, reason: ch.id);
      expect(ch.videos.every((v) => v.youtubeVideoId == v.id), isTrue);
    }
    final numberblocks = seed.firstWhere((c) => c.id == 'numberblocks');
    expect(
      numberblocks.youtubePlaylistId,
      'PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm',
    );
    expect(numberblocks.videos.any((v) => v.id == 'Ap5kgJ-bpEQ'), isTrue);
    final kidsMusic = seed.firstWhere((c) => c.id == 'kids_music');
    expect(kidsMusic.followUploads, isFalse);
    expect(kidsMusic.videos.any((v) => v.id == 'qn3ITODjLiw'), isTrue);
    expect(kidsMusic.videos.any((v) => v.id == 'ISSlEZyIRFw'), isFalse);
    expect(kidsMusic.videos.any((v) => v.id == '03X3iys-Rcs'), isTrue);
    expect(kidsMusic.videos.any((v) => v.id == 'XE4qklLOokQ'), isTrue);
    expect(ids.contains('toyor_jana'), isFalse);
    expect(DefaultChannels.retiredChannelIds.contains('toyor_jana'), isTrue);
  });

  test('seed v22 adds Babar and Hadikat al-Marah channels', () {
    expect(DefaultChannels.seedVersion, 24);
    final seed = DefaultChannels.seed();
    final babar = seed.firstWhere((c) => c.id == 'babar');
    expect(babar.title, 'بابار');
    expect(babar.followUploads, isFalse);
    expect(babar.videos.length, greaterThanOrEqualTo(16));
    expect(babar.videos.any((v) => v.id == 'fbRBhg1tegQ'), isTrue);
    expect(babar.videos.any((v) => v.id == 'CKG8KXSiehs'), isTrue);
    final garden = seed.firstWhere((c) => c.id == 'hadikat_almarah');
    expect(garden.title, 'حديقة المرح');
    expect(garden.followUploads, isFalse);
    expect(garden.videos.any((v) => v.id == 'knTqvBZtgDc'), isTrue);
    expect(garden.videos.length, greaterThanOrEqualTo(8));
  });

  test('mergeSeedUpdates retires Arabic Disney and expands English Disney Songs', () {
    final existing = [
      ContentChannel(
        id: 'disney_songs_ar',
        title: 'أغاني ديزني',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'pBTtPEVdf3k',
            title: 'أطلقي سركِ',
            youtubeVideoId: 'pBTtPEVdf3k',
          ),
        ],
      ),
      ContentChannel(
        id: 'disney_songs',
        title: 'Disney Songs',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'L0MK7qz13bU',
            title: 'Let It Go',
            youtubeVideoId: 'L0MK7qz13bU',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    expect(merged.any((c) => c.id == 'disney_songs_ar'), isFalse);
    final disney = merged.firstWhere((c) => c.id == 'disney_songs');
    expect(disney.videos.any((v) => v.id == 'bseyU2PvBQo'), isTrue);
    expect(disney.videos.any((v) => v.id == 'TeQ_TTyLGMs'), isTrue);
  });

  test('mergeSeedUpdates retires طيور الجنة and expands Maruko Babar', () {
    final existing = [
      ContentChannel(
        id: 'toyor_jana',
        title: 'طيور الجنة',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: '7GgZjoF0D2I',
            title: 'قلبي ينادي',
            youtubeVideoId: '7GgZjoF0D2I',
          ),
        ],
      ),
      ContentChannel(
        id: 'maruko',
        title: 'ماروكو الصغيرة',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'OMbPlfL2VMY',
            title: 'الحلقات الثلاث الأولى',
            youtubeVideoId: 'OMbPlfL2VMY',
          ),
        ],
      ),
      ContentChannel(
        id: 'babar',
        title: 'بابار',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'CKG8KXSiehs',
            title: 'Elephant Express',
            youtubeVideoId: 'CKG8KXSiehs',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    expect(merged.any((c) => c.id == 'toyor_jana'), isFalse);
    final maruko = merged.firstWhere((c) => c.id == 'maruko');
    expect(maruko.videos.any((v) => v.id == 'efoYDgyUdbU'), isTrue);
    final babar = merged.firstWhere((c) => c.id == 'babar');
    expect(babar.videos.any((v) => v.id == 'fbRBhg1tegQ'), isTrue);
  });

  test('mergeSeedUpdates replaces wrong Kids Music sleep song', () {
    final existing = [
      ContentChannel(
        id: 'kids_music',
        title: 'Kids Music',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'wyOJfLSeZIE',
            title: 'بابا فين',
            youtubeVideoId: 'wyOJfLSeZIE',
          ),
          VideoItem(
            id: 'ISSlEZyIRFw',
            title: 'مابي أنام — wrong',
            youtubeVideoId: 'ISSlEZyIRFw',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final kidsMusic = merged.firstWhere((c) => c.id == 'kids_music');
    expect(kidsMusic.videos.any((v) => v.id == 'ISSlEZyIRFw'), isFalse);
    expect(kidsMusic.videos.any((v) => v.id == 'qn3ITODjLiw'), isTrue);
    expect(kidsMusic.videos.any((v) => v.id == 'wyOJfLSeZIE'), isTrue);
  });

  test('mergeSeedUpdates enables follow and Numberblocks Season 1 playlist', () {
    final existing = [
      ContentChannel(
        id: 'numberblocks',
        title: 'Numberblocks',
        sourceType: SourceType.youtubePlaylist,
        youtubePlaylistId: 'UUPlwvN0w4qFSP1FllALB92w',
        followUploads: false,
        videos: const [
          VideoItem(
            id: 'jVeYnCehEFE',
            title: 'One',
            youtubeVideoId: 'jVeYnCehEFE',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final numberblocks = merged.firstWhere((c) => c.id == 'numberblocks');
    expect(
      numberblocks.youtubePlaylistId,
      'PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm',
    );
    expect(numberblocks.followUploads, isTrue);
    expect(numberblocks.videos.any((v) => v.id == 'Ap5kgJ-bpEQ'), isTrue);
  });



  test('seed v16 has expected channels and starter videos where applicable', () {
    expect(DefaultChannels.seedVersion, 24);
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
          VideoItem(
            id: 'T6ggVnk1JZg',
            title: 'Song',
            youtubeVideoId: 'T6ggVnk1JZg',
          ),
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

  test('clampedResumePosition clears near start and near end', () {
    expect(clampedResumePosition(1000, 60_000), 0);
    expect(clampedResumePosition(10_000, 60_000), 10_000);
    expect(clampedResumePosition(56_000, 60_000), 0);
  });

  test('ReleasePinPolicy blocks kid playback on release until PIN changed', () {
    expect(
      ReleasePinPolicy.requirePinChangeForKidPlayback(
        isDebugBuild: true,
        pinChangedFromDefault: false,
      ),
      isFalse,
    );
    expect(
      ReleasePinPolicy.requirePinChangeForKidPlayback(
        isDebugBuild: false,
        pinChangedFromDefault: false,
      ),
      isTrue,
    );
    expect(
      ReleasePinPolicy.requirePinChangeForKidPlayback(
        isDebugBuild: false,
        pinChangedFromDefault: true,
      ),
      isFalse,
    );
  });

  test('ReleasePinPolicy sanitize clears flags when hash still default', () {
    final salt = ParentPinManager.newSaltHex();
    final hash =
        ParentPinManager.hashPin(ParentPinManager.defaultDevPin, salt)!;
    final sanitized = ReleasePinPolicy.sanitizePinFlags(
      pinSalt: salt,
      pinHash: hash,
      pinChangedFromDefault: true,
      releaseReady: true,
    );
    expect(sanitized.pinChangedFromDefault, isFalse);
    expect(sanitized.releaseReady, isFalse);
  });
}
