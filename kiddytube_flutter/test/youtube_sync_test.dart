import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/youtube_sync.dart';

void main() {
  group('YoutubeCatalogSource filters', () {
    test('parseIso8601Duration handles common YouTube forms', () {
      expect(
        YoutubeCatalogSource.parseIso8601Duration('PT45S'),
        const Duration(seconds: 45),
      );
      expect(
        YoutubeCatalogSource.parseIso8601Duration('PT1M30S'),
        const Duration(minutes: 1, seconds: 30),
      );
      expect(
        YoutubeCatalogSource.parseIso8601Duration('PT1H2M3S'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(YoutubeCatalogSource.parseIso8601Duration(null), isNull);
      expect(YoutubeCatalogSource.parseIso8601Duration('bogus'), isNull);
    });

    test('looksLikeShortOrLiveTitle catches shorts and live labels', () {
      expect(YoutubeCatalogSource.looksLikeShortOrLiveTitle('#Shorts clip'), isTrue);
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle('Funny Shorts'),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle('بث مباشر — مكة'),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle('LIVE: marathon'),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle(
          'LIVE 🔴 ماشا والدب رسوم متحركة',
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle('Full Episodes — Peppa'),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortOrLiveTitle('A Helping Pingu'),
        isFalse,
      );
    });

    test('looksLikeShortsTags matches Shorts labels not the word short', () {
      expect(YoutubeCatalogSource.looksLikeShortsTags(null), isFalse);
      expect(YoutubeCatalogSource.looksLikeShortsTags(const []), isFalse);
      expect(
        YoutubeCatalogSource.looksLikeShortsTags(const ['kids', 'peppa']),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.looksLikeShortsTags(const ['short film']),
        isFalse,
      );
      expect(YoutubeCatalogSource.looksLikeShortsTags(const ['shorts']), isTrue);
      expect(YoutubeCatalogSource.looksLikeShortsTags(const ['#Shorts']), isTrue);
      expect(
        YoutubeCatalogSource.looksLikeShortsTags(const ['YouTubeShorts']),
        isTrue,
      );
    });

    test('isFullOnDemandVideo drops live, classic Shorts, and labeled Shorts', () {
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Episode 1',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 5),
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Episode 1',
          liveBroadcastContent: 'live',
          duration: const Duration(hours: 2),
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Soon',
          liveBroadcastContent: 'upcoming',
          duration: const Duration(minutes: 10),
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Tiny',
          liveBroadcastContent: 'none',
          duration: const Duration(seconds: 45),
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Nursery song',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 2),
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Nursery song #Shorts',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 2),
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Nursery song',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 2),
          tags: const ['shorts'],
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Nursery song',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 2),
          isVerticalShort: true,
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Exactly three minutes',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 3),
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Just over three minutes',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 3, seconds: 1),
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'Funny #Shorts',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 5),
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'MILO THE VET Compilation',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 35),
          embeddable: false,
        ),
        isFalse,
      );
      expect(
        YoutubeCatalogSource.isFullOnDemandVideo(
          title: 'MILO, THE CHEF — Full Episode',
          liveBroadcastContent: 'none',
          duration: const Duration(minutes: 11),
          embeddable: true,
        ),
        isTrue,
      );
      expect(
        YoutubeCatalogSource.classicShortMax,
        const Duration(seconds: 60),
      );
      expect(
        YoutubeCatalogSource.minFullVideoDuration,
        const Duration(seconds: 180),
      );
    });
  });
}
