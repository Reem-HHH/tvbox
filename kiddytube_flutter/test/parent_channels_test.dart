import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/catalog/media_ids.dart';
import 'package:kiddytube/catalog/seed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MediaIds', () {
    test('extracts bare and URL video ids', () {
      expect(MediaIds.extractVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        MediaIds.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        MediaIds.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(MediaIds.extractVideoId('nope'), isNull);
      expect(MediaIds.extractVideoId(''), isNull);
    });

    test('parseVideoIdsCsv dedupes and splits', () {
      expect(
        MediaIds.parseVideoIdsCsv(
          'dQw4w9WgXcQ, https://youtu.be/abcdefghijk\ndQw4w9WgXcQ',
        ),
        ['dQw4w9WgXcQ', 'abcdefghijk'],
      );
      expect(MediaIds.parseVideoIdsCsv(''), isEmpty);
    });

    test('isDirectMediaUrl allows https media files only', () {
      expect(
        MediaIds.isDirectMediaUrl('https://cdn.example.com/a.mp4'),
        isTrue,
      );
      expect(
        MediaIds.isDirectMediaUrl('https://cdn.example.com/a.m3u8'),
        isTrue,
      );
      expect(
        MediaIds.isDirectMediaUrl('https://cdn.example.com/stream.mpd'),
        isTrue,
      );
      expect(
        MediaIds.isDirectMediaUrl('http://cdn.example.com/a.mp4'),
        isFalse,
      );
      expect(
        MediaIds.isDirectMediaUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isFalse,
      );
      expect(MediaIds.isDirectMediaUrl('https://cdn.example.com/video'), isFalse);
    });
  });

  group('CatalogRepository channel mutators', () {
    late CatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = CatalogRepository(secrets: MemorySecretsStore());
      await repo.load();
    });

    test('setFollowUploads marks parent-managed', () async {
      final id = DefaultChannels.seed().first.id;
      await repo.setFollowUploads(id, false);
      var ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(ch.followUploads, isFalse);
      expect(ch.playlistManagedByParent, isTrue);

      await repo.setFollowUploads(id, true);
      ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(ch.followUploads, isTrue);
    });

    test('addManualVideoIds and removeVideo', () async {
      final id = DefaultChannels.seed().first.id;
      final before =
          repo.current().channels.firstWhere((c) => c.id == id).videos.length;
      final added = await repo.addManualVideoIds(
        id,
        'xxxxxxxxxxx,yyyyyyyyyyy',
      );
      expect(added, 2);
      var ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(ch.videos.length, before + 2);
      expect(ch.videos.any((v) => v.id == 'xxxxxxxxxxx' && v.manual), isTrue);

      await repo.removeVideo(id, 'xxxxxxxxxxx');
      ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(ch.videos.any((v) => v.id == 'xxxxxxxxxxx'), isFalse);
    });

    test('clearSyncedVideos keeps manual entries', () async {
      final id = DefaultChannels.seed().first.id;
      await repo.addManualVideoIds(id, 'zzzzzzzzzzz');
      await repo.clearSyncedVideos(id);
      final ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(ch.videos.every((v) => v.manual || v.isDirect), isTrue);
      expect(ch.videos.any((v) => v.id == 'zzzzzzzzzzz'), isTrue);
    });

    test('addDirectVideo rejects non-https media', () async {
      final id = DefaultChannels.seed().first.id;
      await expectLater(
        repo.addDirectVideo(id, 'Bad', 'http://x.com/a.mp4'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addDirectVideo accepts https mp4', () async {
      final id = DefaultChannels.seed().first.id;
      await repo.addDirectVideo(
        id,
        'Clip',
        'https://cdn.example.com/kids.mp4',
      );
      final ch = repo.current().channels.firstWhere((c) => c.id == id);
      expect(
        ch.videos.any(
          (v) =>
              v.manual &&
              v.isDirect &&
              v.directUrl == 'https://cdn.example.com/kids.mp4',
        ),
        isTrue,
      );
    });
  });
}
