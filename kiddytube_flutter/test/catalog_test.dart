import 'dart:convert';

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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('HomeLibraryMode defaults unknown storage to channels', () {
    expect(HomeLibraryMode.fromStored(null), HomeLibraryMode.channels);
    expect(HomeLibraryMode.fromStored('nope'), HomeLibraryMode.channels);
    expect(HomeLibraryMode.fromStored('mixVideos'), HomeLibraryMode.mixVideos);
  });

  test('flattenEnabledVideos only includes enabled channels, newest first', () {
    final channels = [
      ContentChannel(
        id: 'a',
        title: 'A',
        sourceType: SourceType.youtubeVideoList,
        enabled: true,
        sortOrder: 1,
        videos: const [
          VideoItem(
            id: '1',
            title: 'One',
            youtubeVideoId: '1',
            publishedAtMs: 100,
          ),
          VideoItem(
            id: '2',
            title: 'Two',
            youtubeVideoId: '2',
            publishedAtMs: 300,
          ),
        ],
      ),
      ContentChannel(
        id: 'b',
        title: 'B',
        sourceType: SourceType.youtubeVideoList,
        enabled: false,
        videos: const [
          VideoItem(
            id: '3',
            title: 'Three',
            youtubeVideoId: '3',
            publishedAtMs: 999,
          ),
        ],
      ),
    ];

    final first = flattenEnabledVideos(channels);
    expect(first.map((e) => e.video.id).toList(), ['2', '1']);
    expect(first.every((e) => e.channelId == 'a'), isTrue);
    expect(
      flattenEnabledVideos(channels).map((e) => e.video.id).toList(),
      first.map((e) => e.video.id).toList(),
    );
  });

  test('enabledChannelsInCatalogOrder follows sortOrder not shuffle', () {
    final channels = [
      ContentChannel(
        id: 'z',
        title: 'Z',
        sourceType: SourceType.youtubeVideoList,
        enabled: true,
        sortOrder: 2,
      ),
      ContentChannel(
        id: 'a',
        title: 'A',
        sourceType: SourceType.youtubeVideoList,
        enabled: true,
        sortOrder: 0,
      ),
      ContentChannel(
        id: 'off',
        title: 'Off',
        sourceType: SourceType.youtubeVideoList,
        enabled: false,
        sortOrder: 1,
      ),
    ];
    expect(
      enabledChannelsInCatalogOrder(channels).map((c) => c.id).toList(),
      ['a', 'z'],
    );
  });

  test('newestVideosFirst puts dated items before undated', () {
    const items = [
      VideoItem(id: 'old', title: 'Old', publishedAtMs: 10),
      VideoItem(id: 'none', title: 'None'),
      VideoItem(id: 'new', title: 'New', publishedAtMs: 50),
    ];
    expect(newestVideosFirst(items).map((v) => v.id).toList(), [
      'new',
      'old',
      'none',
    ]);
  });

  test('previewVideoForChannel picks from latest videos and is seed-stable', () {
    final channel = ContentChannel(
      id: 'show',
      title: 'Show',
      sourceType: SourceType.youtubeVideoList,
      videos: const [
        VideoItem(
          id: 'old',
          title: 'Old',
          youtubeVideoId: 'AAAAAAAAAAA',
          publishedAtMs: 1,
        ),
        VideoItem(
          id: 'mid',
          title: 'Mid',
          youtubeVideoId: 'BBBBBBBBBBB',
          publishedAtMs: 2,
        ),
        VideoItem(
          id: 'new',
          title: 'New',
          youtubeVideoId: 'CCCCCCCCCCC',
          publishedAtMs: 3,
        ),
      ],
    );
    expect(previewVideoForChannel(channel, 1)?.id, previewVideoForChannel(channel, 1)?.id);
    expect(
      {'old', 'mid', 'new'}.contains(previewVideoForChannel(channel, 7, latestPool: 8)?.id),
      isTrue,
    );
    expect(
      previewVideoForChannel(channel, 3, latestPool: 1)?.id,
      'new',
    );
  });


  test('seed keeps Twirlywoos expanded starters', () {
    expect(DefaultChannels.seedVersion, 48);
    final twirly = DefaultChannels.seed().firstWhere((c) => c.id == 'twirlywoos');
    expect(twirly.videos.any((v) => v.id == 'wAFiVXz1NNw'), isTrue);
    expect(twirly.videos.any((v) => v.id == 'Wg0JkKmQY6A'), isTrue);
    expect(twirly.videos.length, greaterThanOrEqualTo(9));
    expect(twirly.followUploads, isFalse);
  });

  test('seed v19 adds Maruko Chan Arabic starters', () {
    expect(DefaultChannels.seedVersion, 48);
    final maruko = DefaultChannels.seed().firstWhere((c) => c.id == 'maruko');
    expect(maruko.title, 'ماروكو الصغيرة');
    expect(maruko.followUploads, isFalse);
    expect(maruko.youtubePlaylistId, isNull);
    expect(maruko.videos.any((v) => v.id == 'OMbPlfL2VMY'), isTrue);
    expect(maruko.videos.any((v) => v.id == 'ZIuKvaoPd9s'), isTrue);
    expect(maruko.videos.length, greaterThanOrEqualTo(16));
    expect(maruko.videos.any((v) => v.id == '7y_MQlpWhTI'), isTrue);
  });

  test('seed includes Makkah Quran Masha Blippi Disney channels without live', () {
    expect(DefaultChannels.seedVersion, 48);
    final seed = DefaultChannels.seed();
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.containsAll([
      'live_makkah',
      'masha_ar',
      'blippi_ar',
      'disney_songs',
    ]), isTrue);
    expect(ids.contains('live_quran'), isFalse);
    expect(ids.contains('disney_songs_ar'), isFalse);
    expect(DefaultChannels.retiredChannelIds.contains('disney_songs_ar'), isTrue);
    expect(DefaultChannels.retiredChannelIds.contains('live_quran'), isTrue);
    final makkah = seed.firstWhere((c) => c.id == 'live_makkah');
    expect(makkah.title, 'قرآن للنوم ورقية');
    expect(makkah.videos.any((v) => v.id == 'wawzF8i5yAo'), isFalse);
    expect(makkah.videos.any((v) => DefaultChannels.retiredLiveVideoIds.contains(v.id)), isFalse);
    expect(makkah.videos.any((v) => v.id == 'UMT2RvaOKrg'), isTrue);
    expect(makkah.videos.any((v) => v.id == 'WFnpX2yMRK8'), isTrue);
    expect(makkah.videos.any((v) => v.id == '6hDV4sQiQNc'), isTrue);
    expect(makkah.videos.any((v) => v.id == 'TQ9R8-TIdV4'), isTrue);
    expect(makkah.videos.length, greaterThanOrEqualTo(30));
    expect(makkah.followUploads, isFalse);
    final disney = seed.firstWhere((c) => c.id == 'disney_songs');
    expect(disney.videos.any((v) => v.id == 'L0MK7qz13bU'), isTrue);
    expect(disney.videos.any((v) => v.id == 'bseyU2PvBQo'), isTrue);
    expect(disney.videos.length, greaterThanOrEqualTo(16));
    expect(disney.followUploads, isFalse);
    final blippi = seed.firstWhere((c) => c.id == 'blippi_ar');
    expect(blippi.title, 'بليبي وميكا');
    expect(blippi.videos.length, greaterThanOrEqualTo(35));
    expect(blippi.videos.any((v) => v.id == 'jCH68ZT2z1U' || v.title.contains('ميكا')), isTrue);
    expect(blippi.followUploads, isFalse);
  });

  test('seed v26 follow only curated playlists; Numberblocks Season 1', () {
    expect(DefaultChannels.seedVersion, 48);
    final seed = DefaultChannels.seed();
    expect(seed.length, greaterThanOrEqualTo(30));
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.contains('omar_hana'), isTrue);
    expect(ids.contains('dawood'), isTrue);
    expect(ids.contains('cocomelon'), isTrue);
    expect(ids.contains('mansour'), isTrue);
    expect(ids.contains('numberblocks'), isTrue);
    const followOn = {
      'dawood',
      'numberblocks',
      'zaky',
      'colourblocks',
      'alphablocks',
      'bing',
      'bakkar',
    };
    for (final ch in seed) {
      if (followOn.contains(ch.id)) {
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
    expect(kidsMusic.videos.any((v) => v.id == 'Pf1Y0JtfMPU'), isTrue);
    expect(kidsMusic.videos.any((v) => v.id == 'ZUCS_cR9cY8'), isTrue);
    expect(ids.contains('toyor_jana'), isFalse);
    expect(DefaultChannels.retiredChannelIds.contains('toyor_jana'), isTrue);
  });

  test('seed v22 adds Babar and Hadikat al-Marah channels', () {
    expect(DefaultChannels.seedVersion, 48);
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

  test('seed v35 adds Muka Muka, Milo, and Peppa Toys channels', () {
    expect(DefaultChannels.seedVersion, 48);
    final seed = DefaultChannels.seed();
    final ids = seed.map((c) => c.id).toSet();
    expect(ids.containsAll(['ana_wa_akhi', 'muka_muka', 'milo', 'peppa_toys']), isTrue);

    final muka = seed.firstWhere((c) => c.id == 'muka_muka');
    expect(muka.title, 'موكا موكا');
    expect(muka.followUploads, isFalse);
    expect(muka.youtubePlaylistId, isNull);
    expect(muka.videos.any((v) => v.id == 'DOmcbxGqMds'), isTrue);
    expect(muka.videos.any((v) => v.id == 'wjI1Jf0W7vE'), isTrue);
    expect(muka.videos.length, greaterThanOrEqualTo(7));

    final milo = seed.firstWhere((c) => c.id == 'milo');
    expect(milo.title, 'Milo');
    expect(milo.followUploads, isFalse);
    expect(milo.youtubePlaylistId, 'UUYYRc7w6PgFgSh3dnZyZchw');
    expect(milo.videos.any((v) => v.id == 'mNOhUdl3yfQ'), isTrue);
    expect(milo.videos.any((v) => v.id == '4SODfWe8c20'), isTrue);
    expect(milo.videos.any((v) => v.id == '8Uj_MSzZECs'), isTrue);
    expect(
      milo.videos.any(
        (v) => DefaultChannels.retiredUnplayableVideoIds.contains(v.id),
      ),
      isFalse,
    );
    expect(milo.videos.length, greaterThanOrEqualTo(20));

    final toys = seed.firstWhere((c) => c.id == 'peppa_toys');
    expect(toys.title, 'Peppa Pig Toys');
    expect(toys.followUploads, isFalse);
    expect(toys.youtubePlaylistId, isNull);
    expect(toys.videos.any((v) => v.id == 'IV8Iu-hoI-I'), isTrue);
    expect(toys.videos.any((v) => v.id == 'iJmGYabu5kc'), isTrue);
    expect(
      toys.videos.every(
        (v) =>
            !v.title.toLowerCase().contains('halloween') &&
            !v.title.toLowerCase().contains('christmas') &&
            !v.title.toLowerCase().contains('scary'),
      ),
      isTrue,
    );
    expect(toys.videos.length, greaterThanOrEqualTo(20));
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
    expect(maruko.videos.any((v) => v.id == 'ZIuKvaoPd9s'), isTrue);
    final babar = merged.firstWhere((c) => c.id == 'babar');
    expect(babar.videos.any((v) => v.id == 'fbRBhg1tegQ'), isTrue);
  });

  test('seed v40 adds Zaky Colourblocks Alphablocks Bing Bakkar with Follow', () {
    expect(DefaultChannels.seedVersion, 48);
    final seed = DefaultChannels.seed();
    final byId = {for (final c in seed) c.id: c};

    final zaky = byId['zaky']!;
    expect(zaky.title, 'Zaky');
    expect(zaky.followUploads, isTrue);
    expect(zaky.youtubePlaylistId, 'PLVhRNB9aLU4iijlj1hieweb16ao3P5C-o');
    expect(zaky.videos.length, greaterThanOrEqualTo(50));
    expect(zaky.videos.any((v) => ContentTitleFilter.isBlocked(v.title)), isFalse);

    final colour = byId['colourblocks']!;
    expect(colour.followUploads, isTrue);
    expect(colour.youtubePlaylistId, 'PLNlJG0d7KqJvg1Lxjm33FsYBpZHRS5o2H');
    expect(colour.videos.length, greaterThanOrEqualTo(25));

    final alpha = byId['alphablocks']!;
    expect(alpha.followUploads, isTrue);
    expect(alpha.youtubePlaylistId, 'PLSW2D61TnopQh0UN4Xqi1wNFfF1wHliQg');
    expect(alpha.videos.length, greaterThanOrEqualTo(50));

    final bing = byId['bing']!;
    expect(bing.followUploads, isTrue);
    expect(bing.youtubePlaylistId, 'PLiHTGV3bXdR8yYzEepbhfb23SxoTSTtF7');
    expect(bing.videos.any((v) => v.title.toLowerCase().contains('halloween')), isFalse);
    expect(bing.videos.any((v) => v.id == 'eYuUe-o1T8w'), isFalse);

    final bakkar = byId['bakkar']!;
    expect(bakkar.title, 'بكار');
    expect(bakkar.followUploads, isTrue);
    expect(bakkar.youtubePlaylistId, 'PL678DQfcGwUyHPVWW7u4SO1jPkfuQiDdx');
    expect(bakkar.videos.length, greaterThanOrEqualTo(20));
  });

  test('seed v44 adds Ana wa Akhi curated Arabic episodes', () {
    expect(DefaultChannels.seedVersion, 48);
    final ana = DefaultChannels.seed().firstWhere((c) => c.id == 'ana_wa_akhi');
    expect(ana.title, 'أنا وأخي');
    expect(ana.followUploads, isFalse);
    expect(ana.youtubePlaylistId, isNull);
    expect(ana.videos.length, greaterThanOrEqualTo(30));
    expect(ana.videos.any((v) => v.id == '_M-sZNslWM8'), isTrue);
    expect(ana.videos.any((v) => v.id == '1yxODADlgXA'), isTrue);
    expect(ana.videos.any((v) => v.id == 'BdWkREGkK38'), isTrue);
    expect(
      ana.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('seed v45 adds True\'s Magical Adventure official episodes', () {
    expect(DefaultChannels.seedVersion, 48);
    final trueShow =
        DefaultChannels.seed().firstWhere((c) => c.id == 'true_magical');
    expect(trueShow.title, 'True\'s Magical Adventure');
    expect(trueShow.followUploads, isFalse);
    expect(trueShow.youtubePlaylistId, 'PL3cjmspE05RhaybbOA6cIJGbc9QlwYOAP');
    expect(trueShow.videos.length, greaterThanOrEqualTo(25));
    expect(trueShow.videos.any((v) => v.id == 'pnM1TEWRPm0'), isTrue);
    expect(trueShow.videos.any((v) => v.id == 'ZtRMyNLqJHc'), isTrue);
    expect(trueShow.videos.any((v) => v.id == '6otsqlZQUNU'), isTrue);
    expect(
      trueShow.videos.any(
        (v) =>
            v.title.toLowerCase().contains('halloween') ||
            v.title.toLowerCase().contains('easter') ||
            v.title.toLowerCase().contains('valentine') ||
            v.title.toLowerCase().contains('spooky'),
      ),
      isFalse,
    );
    expect(
      trueShow.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('seed v46 adds Sesame Street English and Iftah Ya Simsim', () {
    expect(DefaultChannels.seedVersion, 48);
    final en =
        DefaultChannels.seed().firstWhere((c) => c.id == 'sesame');
    expect(en.title, 'Sesame Street');
    expect(en.followUploads, isFalse);
    expect(en.youtubePlaylistId, 'PL8TioFHubWFsnPhBmrDQ8dtoXxghDMKxr');
    expect(en.videos.length, greaterThanOrEqualTo(25));
    expect(en.videos.any((v) => v.id == 'cO1x0WYdGjI'), isTrue);
    expect(en.videos.any((v) => v.id == '1Wqv-kUX8ao'), isTrue);
    expect(
      en.videos.any(
        (v) =>
            v.title.toLowerCase().contains('halloween') ||
            v.title.toLowerCase().contains('christmas') ||
            v.title.toLowerCase().contains('easter') ||
            v.title.toLowerCase().contains('valentine') ||
            v.title.toLowerCase().contains('pride'),
      ),
      isFalse,
    );
    expect(
      en.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );

    final ar =
        DefaultChannels.seed().firstWhere((c) => c.id == 'sesame_ar');
    expect(ar.title, 'افتح يا سمسم');
    expect(ar.followUploads, isFalse);
    expect(ar.youtubePlaylistId, 'PLc4t1-K0nthvSUhYtc43BiG-Z9LK2mw5D');
    expect(ar.videos.length, greaterThanOrEqualTo(25));
    expect(ar.videos.any((v) => v.id == '8EdkVl27Ix0'), isTrue);
    expect(ar.videos.any((v) => v.id == 'tvsL5xABpW4'), isTrue);
    expect(
      ar.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('seed v47 adds Rob the Robot official singles', () {
    expect(DefaultChannels.seedVersion, 48);
    final rob =
        DefaultChannels.seed().firstWhere((c) => c.id == 'rob_the_robot');
    expect(rob.title, 'Rob the Robot');
    expect(rob.followUploads, isFalse);
    expect(rob.youtubePlaylistId, 'PLCgmiKORinbJSqB2B_KK5kHx1bmeK6TmX');
    expect(rob.videos.length, greaterThanOrEqualTo(30));
    expect(rob.videos.any((v) => v.id == 'P7PQof3mLlI'), isTrue);
    expect(rob.videos.any((v) => v.id == 'l9WpweX0eto'), isTrue);
    expect(
      rob.videos.any(
        (v) =>
            v.title.toLowerCase().contains('halloween') ||
            v.title.toLowerCase().contains('christmas') ||
            v.title.toLowerCase().contains('spooky') ||
            v.title.toLowerCase().contains('holiday'),
      ),
      isFalse,
    );
    expect(
      rob.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('seed v48 adds Sofia the First official episodes', () {
    expect(DefaultChannels.seedVersion, 48);
    final sofia =
        DefaultChannels.seed().firstWhere((c) => c.id == 'sofia');
    expect(sofia.title, 'Sofia the First');
    expect(sofia.followUploads, isFalse);
    expect(sofia.youtubePlaylistId, 'PL2m1vjiMH_hMCxxjKvsORK-mybMW4OB33');
    expect(sofia.videos.length, greaterThanOrEqualTo(20));
    expect(sofia.videos.any((v) => v.id == 'WEurGXf0grY'), isTrue);
    expect(sofia.videos.any((v) => v.id == 'Xze_F5Fbyog'), isTrue);
    expect(sofia.videos.any((v) => v.id == 'Cfe15ehP4g4'), isTrue);
    expect(
      sofia.videos.any(
        (v) =>
            v.title.toLowerCase().contains('halloween') ||
            v.title.toLowerCase().contains('christmas') ||
            v.title.toLowerCase().contains('holiday') ||
            v.title.toLowerCase().contains('witch') ||
            v.title.toLowerCase().contains('spooky'),
      ),
      isFalse,
    );
    expect(
      sofia.videos.every((v) => ContentTitleFilter.isAllowed(v.title)),
      isTrue,
    );
  });

  test('seed v43 expands full episodes and drops live title leftovers', () {
    expect(DefaultChannels.seedVersion, 48);
    final seed = DefaultChannels.seed();
    expect(seed.length, greaterThanOrEqualTo(45));
    var total = 0;
    for (final ch in seed) {
      total += ch.videos.length;
      expect(
        ch.videos.any((v) => DefaultChannels.retiredLiveVideoIds.contains(v.id)),
        isFalse,
        reason: ch.id,
      );
      expect(
        ch.videos.any((v) => v.title.toLowerCase().contains('live 🔴') || v.title.startsWith('LIVE 🔴')),
        isFalse,
        reason: ch.id,
      );
    }
    expect(total, greaterThanOrEqualTo(1900));
    final omar = seed.firstWhere((c) => c.id == 'omar_hana');
    expect(omar.videos.length, greaterThanOrEqualTo(40));
    expect(omar.youtubeChannelId, 'UC178EmfQAV3OT-UpuO6WUMg');
    final maruko = seed.firstWhere((c) => c.id == 'maruko');
    expect(maruko.videos.length, greaterThanOrEqualTo(30));
    final toys = seed.firstWhere((c) => c.id == 'peppa_toys');
    expect(toys.videos.any((v) => v.title.toLowerCase().contains('full episodes')), isFalse);
  });

  test('seed v42 uses @legocooking stop-motion kitchen videos', () {
    expect(DefaultChannels.seedVersion, 48);
    final cooking = DefaultChannels.seed().firstWhere((c) => c.id == 'lego_cooking');
    expect(cooking.title, 'LEGO Cooking');
    expect(cooking.followUploads, isFalse);
    expect(cooking.youtubePlaylistId, isNull);
    expect(cooking.videos.length, greaterThanOrEqualTo(15));
    expect(cooking.videos.any((v) => v.id == 'yqx7nYQZ91I'), isTrue);
    expect(cooking.videos.any((v) => v.id == 'MO89_KK7m2E'), isTrue);
    expect(cooking.videos.any((v) => v.id == 'kTQ4vmhFfCc'), isTrue);
    expect(cooking.videos.any((v) => v.id == 'ANJilSbKmng'), isFalse);
    expect(cooking.videos.any((v) => ContentTitleFilter.isBlocked(v.title)), isFalse);
  });

  test('mergeSeedUpdates replaces old LEGO Cooking Friends list with @legocooking', () {
    final existing = [
      ContentChannel(
        id: 'lego_cooking',
        title: 'LEGO Cooking',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'ANJilSbKmng',
            title: 'Not Just Baking',
            youtubeVideoId: 'ANJilSbKmng',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final cooking = merged.firstWhere((c) => c.id == 'lego_cooking');
    expect(cooking.videos.any((v) => v.id == 'ANJilSbKmng'), isFalse);
    expect(cooking.videos.any((v) => v.id == 'yqx7nYQZ91I'), isTrue);
    expect(cooking.videos.length, greaterThanOrEqualTo(15));
  });

  test('seed v36 has no retired short ids and merge drops leftovers', () {
    expect(DefaultChannels.seedVersion, 48);
    expect(DefaultChannels.retiredShortVideoIds, isNotEmpty);
    for (final ch in DefaultChannels.seed()) {
      expect(
        ch.videos.any((v) => DefaultChannels.retiredShortVideoIds.contains(v.id)),
        isFalse,
        reason: ch.id,
      );
    }
    final existing = [
      ContentChannel(
        id: 'kids_music',
        title: 'Kids Music',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: '03X3iys-Rcs',
            title: 'أغنية آيس كريم',
            youtubeVideoId: '03X3iys-Rcs',
          ),
          VideoItem(
            id: 'qn3ITODjLiw',
            title: 'بنيتي الحبوبة',
            youtubeVideoId: 'qn3ITODjLiw',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final kidsMusic = merged.firstWhere((c) => c.id == 'kids_music');
    expect(kidsMusic.videos.any((v) => v.id == '03X3iys-Rcs'), isFalse);
    expect(kidsMusic.videos.any((v) => v.id == 'qn3ITODjLiw'), isTrue);
  });

  test('mergeSeedUpdates drops non-embeddable Milo compilations', () {
    final existing = [
      ContentChannel(
        id: 'milo',
        title: 'Milo',
        sourceType: SourceType.youtubePlaylist,
        youtubePlaylistId: 'UUYYRc7w6PgFgSh3dnZyZchw',
        videos: const [
          VideoItem(
            id: 'A-fxPLinzR8',
            title: 'MILO THE CRUISE SHIP CAPTAIN — Compilation',
            youtubeVideoId: 'A-fxPLinzR8',
          ),
          VideoItem(
            id: '4SODfWe8c20',
            title: 'MILO, MARINE BIOLOGIST — Full Episode',
            youtubeVideoId: '4SODfWe8c20',
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    final milo = merged.firstWhere((c) => c.id == 'milo');
    expect(milo.videos.any((v) => v.id == 'A-fxPLinzR8'), isFalse);
    expect(milo.videos.any((v) => v.id == '4SODfWe8c20'), isTrue);
    expect(milo.videos.any((v) => v.id == '8Uj_MSzZECs'), isTrue);
  });

  test('load drops persisted retired shorts from seed v35 catalog', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final leftover = DefaultChannels.retiredShortVideoIds.first;
    SharedPreferences.setMockInitialValues({
      'seed_version': 35,
      'catalog_channels_v1': jsonEncode([
        {
          'id': 'kids_music',
          'title': 'Kids Music',
          'sourceType': 'youtubeVideoList',
          'enabled': true,
          'videos': [
            {
              'id': leftover,
              'title': 'short leftover',
              'youtubeVideoId': leftover,
            },
            {
              'id': 'qn3ITODjLiw',
              'title': 'بنيتي الحبوبة',
              'youtubeVideoId': 'qn3ITODjLiw',
            },
          ],
        },
      ]),
    });
    final secrets = MemorySecretsStore();
    await secrets.writePin('ab' * 16, 'pre-seeded');
    final repo = CatalogRepository(secrets: secrets);
    final settings = await repo.load();
    final leftoverIds = [
      for (final ch in settings.channels)
        for (final v in ch.videos)
          if (DefaultChannels.retiredShortVideoIds.contains(v.id)) v.id,
    ];
    expect(leftoverIds, isEmpty);
    expect(settings.seedVersion, 48);
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
    expect(makkah.title, 'قرآن للنوم ورقية');
    expect(makkah.videos.any((v) => v.id == 'wawzF8i5yAo'), isFalse);
    expect(makkah.videos.any((v) => v.id == 'UMT2RvaOKrg'), isTrue);
    expect(makkah.videos.any((v) => v.id == '6hDV4sQiQNc'), isTrue);
    final coco = merged.firstWhere((c) => c.id == 'cocomelon');
    expect(coco.followUploads, isFalse);
  });

  test('mergeSeedUpdates folds live_quran into live_makkah', () {
    final existing = [
      ContentChannel(
        id: 'live_makkah',
        title: 'قرآن للنوم',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'UMT2RvaOKrg',
            title: 'قرآن للنوم',
            youtubeVideoId: 'UMT2RvaOKrg',
          ),
        ],
      ),
      ContentChannel(
        id: 'live_quran',
        title: 'رقية وقرآن',
        sourceType: SourceType.youtubeVideoList,
        videos: const [
          VideoItem(
            id: 'TQ9R8-TIdV4',
            title: 'قرآن هادئ',
            youtubeVideoId: 'TQ9R8-TIdV4',
          ),
          VideoItem(
            id: 'ParentRuqy1',
            title: 'Parent pick',
            youtubeVideoId: 'ParentRuqy1',
            manual: true,
          ),
        ],
      ),
    ];
    final merged = DefaultChannels.mergeSeedUpdates(existing);
    expect(merged.any((c) => c.id == 'live_quran'), isFalse);
    final hub = merged.firstWhere((c) => c.id == 'live_makkah');
    expect(hub.title, 'قرآن للنوم ورقية');
    expect(hub.videos.any((v) => v.id == 'UMT2RvaOKrg'), isTrue);
    expect(hub.videos.any((v) => v.id == 'TQ9R8-TIdV4'), isTrue);
    expect(hub.videos.any((v) => v.id == 'ParentRuqy1'), isTrue);
  });



  test('seed v16 has expected channels and starter videos where applicable', () {
    expect(DefaultChannels.seedVersion, 48);
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
    expect(merged.any((c) => c.id == 'lego_cooking'), isTrue);
    expect(merged.any((c) => c.id == 'ana_wa_akhi'), isTrue);
    expect(merged.any((c) => c.id == 'true_magical'), isTrue);
    expect(merged.any((c) => c.id == 'sesame'), isTrue);
    expect(merged.any((c) => c.id == 'sesame_ar'), isTrue);
    expect(merged.any((c) => c.id == 'rob_the_robot'), isTrue);
    expect(merged.any((c) => c.id == 'sofia'), isTrue);
    expect(merged.any((c) => c.id == 'omar_hana'), isTrue);
  });

  test('seed v28 adds Ben and Holly curated starters without Christmas', () {
    expect(DefaultChannels.seedVersion, 48);
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
    expect(DefaultChannels.seedVersion, 48);
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
