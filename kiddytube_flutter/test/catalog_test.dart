import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/catalog/content_title_filter.dart';
import 'package:kiddytube/catalog/home_library.dart';
import 'package:kiddytube/catalog/models.dart';
import 'package:kiddytube/catalog/recent_watch.dart';
import 'package:kiddytube/catalog/seed.dart';
import 'package:kiddytube/parent/parent_pin.dart';
import 'package:kiddytube/parent/parent_session.dart';
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
    expect(DefaultChannels.seedVersion, 30);
    final twirly = DefaultChannels.seed().firstWhere((c) => c.id == 'twirlywoos');
    expect(twirly.videos.any((v) => v.id == 'wAFiVXz1NNw'), isTrue);
    expect(twirly.videos.any((v) => v.id == 'Wg0JkKmQY6A'), isTrue);
    expect(twirly.videos.length, greaterThanOrEqualTo(9));
    expect(twirly.followUploads, isFalse);
  });

  test('seed v19 adds Maruko Chan Arabic starters', () {
    expect(DefaultChannels.seedVersion, 30);
    final maruko = DefaultChannels.seed().firstWhere((c) => c.id == 'maruko');
    expect(maruko.title, 'ماروكو الصغيرة');
    expect(maruko.followUploads, isFalse);
    expect(maruko.youtubePlaylistId, isNull);
    expect(maruko.videos.any((v) => v.id == 'OMbPlfL2VMY'), isTrue);
    expect(maruko.videos.any((v) => v.id == '7Xf9nKYyAM4'), isTrue);
    expect(maruko.videos.length, greaterThanOrEqualTo(16));
    expect(maruko.videos.any((v) => v.id == 'efoYDgyUdbU'), isTrue);
  });

  test('seed includes Makkah Quran Masha Blippi Disney channels without live', () {
    expect(DefaultChannels.seedVersion, 30);
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
    expect(makkah.title, 'قرآن للنوم');
    expect(makkah.videos.any((v) => v.id == 'wawzF8i5yAo'), isFalse);
    expect(makkah.videos.any((v) => DefaultChannels.retiredLiveVideoIds.contains(v.id)), isFalse);
    expect(makkah.videos.any((v) => v.id == 'UMT2RvaOKrg'), isTrue);
    expect(makkah.videos.any((v) => v.id == 'WFnpX2yMRK8'), isTrue);
    expect(makkah.videos.any((v) => v.id == '6hDV4sQiQNc'), isTrue);
    expect(makkah.videos.length, greaterThanOrEqualTo(14));
    expect(makkah.followUploads, isFalse);
    final quran = seed.firstWhere((c) => c.id == 'live_quran');
    expect(quran.title, 'رقية وقرآن');
    expect(quran.videos.any((v) => v.id == 'wawzF8i5yAo'), isFalse);
    expect(quran.videos.any((v) => v.id == 'TQ9R8-TIdV4'), isTrue);
    expect(quran.videos.length, greaterThanOrEqualTo(5));
    final disney = seed.firstWhere((c) => c.id == 'disney_songs');
    expect(disney.videos.any((v) => v.id == 'L0MK7qz13bU'), isTrue);
    expect(disney.videos.any((v) => v.id == 'bseyU2PvBQo'), isTrue);
    expect(disney.videos.length, greaterThanOrEqualTo(16));
    expect(disney.followUploads, isFalse);
  });

  test('seed v26 follow only curated playlists; Numberblocks Season 1', () {
    expect(DefaultChannels.seedVersion, 30);
    final seed = DefaultChannels.seed();
    expect(seed.length, greaterThanOrEqualTo(30));
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.contains('omar_hana'), isTrue);
    expect(ids.contains('dawood'), isTrue);
    expect(ids.contains('cocomelon'), isTrue);
    expect(ids.contains('mansour'), isTrue);
    expect(ids.contains('numberblocks'), isTrue);
    for (final ch in seed) {
      if (ch.id == 'dawood' || ch.id == 'numberblocks') {
        expect(ch.followUploads, isTrue, reason: ch.id);
        expect(ch.youtubePlaylistId, isNotNull);
      } else {
        expect(ch.followUploads, isFalse, reason: ch.id);
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
    expect(DefaultChannels.seedVersion, 30);
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

  test('mergePlaylistSync keeps old videos and adds new ones', () {
    const existing = [
      VideoItem(
        id: 'oldEp',
        title: 'Old episode',
        youtubeVideoId: 'oldEp',
        publishedAtMs: 1000,
      ),
      VideoItem(
        id: 'manual1',
        title: 'Parent pick',
        youtubeVideoId: 'manual1',
        manual: true,
        allowSeek: false,
        publishedAtMs: 2000,
      ),
      VideoItem(
        id: 'shared',
        title: 'Old title',
        youtubeVideoId: 'shared',
        allowSeek: false,
        publishedAtMs: 1500,
      ),
    ];
    const synced = [
      VideoItem(
        id: 'shared',
        title: 'Fresh title',
        youtubeVideoId: 'shared',
        thumbnailUrl: 'https://example.com/t.jpg',
        publishedAtMs: 3000,
      ),
      VideoItem(
        id: 'newEp',
        title: 'Brand new',
        youtubeVideoId: 'newEp',
        publishedAtMs: 4000,
      ),
    ];
    final merged = CatalogRepository.mergePlaylistSync(
      existing: existing,
      synced: synced,
      defaultAllowSeek: true,
    );
    final ids = merged.map((v) => v.id).toList();
    expect(ids, containsAll(['oldEp', 'manual1', 'shared', 'newEp']));
    expect(ids.first, 'newEp'); // newest-first
    final shared = merged.firstWhere((v) => v.id == 'shared');
    expect(shared.title, 'Fresh title');
    expect(shared.allowSeek, isFalse); // preserved
    expect(shared.thumbnailUrl, 'https://example.com/t.jpg');
    final manual = merged.firstWhere((v) => v.id == 'manual1');
    expect(manual.manual, isTrue);
    final added = merged.firstWhere((v) => v.id == 'newEp');
    expect(added.allowSeek, isTrue); // default for new
  });

  test('mergeSeedUpdates keeps prior sync videos when Follow is off', () {
    final seedSara = DefaultChannels.seed().firstWhere((c) => c.id == 'sara_duck');
    final existing = [
      seedSara.copyWith(
        followUploads: false,
        videos: [
          ...seedSara.videos,
          const VideoItem(
            id: 'SyncedExtr1',
            title: 'Earlier synced episode',
            youtubeVideoId: 'SyncedExtr1',
          ),
          const VideoItem(
            id: 'ManualKeep1',
            title: 'Parent pick',
            youtubeVideoId: 'ManualKeep1',
            manual: true,
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final sara = merged.firstWhere((c) => c.id == 'sara_duck');
    expect(sara.videos.any((v) => v.id == 'SyncedExtr1'), isTrue);
    expect(sara.videos.any((v) => v.id == 'ManualKeep1'), isTrue);
    expect(sara.videos.any((v) => v.id == 'EOj_7ZYmCOI'), isTrue);
  });

  test('mergeSeedUpdates drops retired live IDs and disables UU follow', () {
    final existing = [
      ContentChannel(
        id: 'live_makkah',
        title: 'مكة مباشر',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'wawzF8i5yAo',
            title: 'بث مباشر',
            youtubeVideoId: 'wawzF8i5yAo',
          ),
          VideoItem(
            id: 'UMT2RvaOKrg',
            title: 'قرآن للنوم',
            youtubeVideoId: 'UMT2RvaOKrg',
          ),
        ],
      ),
      ContentChannel(
        id: 'cocomelon',
        title: 'CoComelon',
        sourceType: SourceType.youtubePlaylist,
        youtubePlaylistId: 'UUbCmjCuTUZos6Inko4u57UQ',
        followUploads: true,
        videos: const [
          VideoItem(
            id: 'e_04ZrNroTo',
            title: 'Wheels on the Bus',
            youtubeVideoId: 'e_04ZrNroTo',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final makkah = merged.firstWhere((c) => c.id == 'live_makkah');
    expect(makkah.title, 'قرآن للنوم');
    expect(makkah.videos.any((v) => v.id == 'wawzF8i5yAo'), isFalse);
    expect(makkah.videos.any((v) => v.id == 'UMT2RvaOKrg'), isTrue);
    expect(makkah.videos.any((v) => v.id == '6hDV4sQiQNc'), isTrue);
    final coco = merged.firstWhere((c) => c.id == 'cocomelon');
    expect(coco.followUploads, isFalse);
  });



  test('seed v16 has expected channels and starter videos where applicable', () {
    expect(DefaultChannels.seedVersion, 30);
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
    expect(merged.any((c) => c.id == 'ben_and_holly'), isTrue);
    expect(merged.any((c) => c.id == 'minecraft'), isTrue);
    expect(merged.any((c) => c.id == 'omar_hana'), isTrue);
  });

  test('seed v28 adds Ben and Holly curated starters without Christmas', () {
    expect(DefaultChannels.seedVersion, 30);
    final ben = DefaultChannels.seed().firstWhere((c) => c.id == 'ben_and_holly');
    expect(ben.title, 'Ben & Holly');
    expect(ben.followUploads, isFalse);
    expect(ben.youtubePlaylistId, 'UU2UhuvjTIrR0Ck2KrkvRcuA');
    expect(ben.videos.length, greaterThanOrEqualTo(15));
    expect(ben.videos.any((v) => v.id == 'edAhVTPprT0'), isTrue);
    expect(ben.videos.any((v) => v.id == 'mLHPMMKTNRI'), isTrue);
    expect(
      ben.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
    expect(
      ben.videos.every(
        (v) =>
            !v.title.toLowerCase().contains('christmas') &&
            !v.title.toLowerCase().contains('xmas') &&
            !v.title.toLowerCase().contains('north pole'),
      ),
      isTrue,
    );
  });

  test('seed v29 adds Minecraft Dad & Olivia calm builds', () {
    expect(DefaultChannels.seedVersion, 30);
    final mc = DefaultChannels.seed().firstWhere((c) => c.id == 'minecraft');
    expect(mc.title, 'Minecraft');
    expect(mc.followUploads, isFalse);
    expect(mc.youtubePlaylistId, 'PLCGF5P4ZzZ6d2S5-RVKKkFp-wLZk-uKP9');
    expect(mc.videos.length, greaterThanOrEqualTo(12));
    expect(mc.videos.any((v) => v.id == '3prPLWKeDiw'), isTrue);
    expect(mc.videos.any((v) => v.id == 'FjTATyVGl-o'), isTrue);
    expect(mc.videos.any((v) => v.id == 'y1pigDzOku0'), isTrue);
    expect(mc.videos.any((v) => v.id == 'jeust7nhHdo'), isTrue);
    expect(
      mc.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('ParentPinManager hashes and verifies default PIN', () {
    final salt = ParentPinManager.newSaltHex();
    final hash = ParentPinManager.hashPin(ParentPinManager.defaultDevPin, salt);
    expect(hash, isNotNull);
    expect(hash, startsWith('pbkdf2-sha256\$'));
    final manager = ParentPinManager();
    expect(manager.verifyPin('2580', salt, hash), isTrue);
    expect(manager.verifyPin('0000', salt, hash), isFalse);
  });

  test('ParentPinManager verifies legacy SHA-256 hashes', () {
    final salt = ParentPinManager.newSaltHex();
    final legacy = ParentPinManager.legacyHashPin(
      ParentPinManager.defaultDevPin,
      salt,
    );
    expect(legacy, isNotNull);
    expect(ParentPinManager.isLegacyHash(legacy), isTrue);
    final manager = ParentPinManager();
    expect(manager.verifyPin('2580', salt, legacy), isTrue);
    expect(manager.verifyPin('0000', salt, legacy), isFalse);
  });

  test('ParentSession touch slides TTL while active', () {
    ParentSession.clear();
    ParentSession.grant(1_000_000);
    expect(ParentSession.isActive(1_000_000 + 1000), isTrue);
    ParentSession.touch(1_000_000 + 1000);
    expect(
      ParentSession.isActive(1_000_000 + 1000 + ParentSession.unlockTtlMs - 1),
      isTrue,
    );
    ParentSession.clear();
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
