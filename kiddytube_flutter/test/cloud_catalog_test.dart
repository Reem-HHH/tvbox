import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/cloud/cloud_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CloudClient.normalizeBaseUrl strips slash and adds scheme', () {
    expect(
      CloudClient.normalizeBaseUrl('192.168.1.5:8787'),
      'http://192.168.1.5:8787',
    );
    expect(
      CloudClient.normalizeBaseUrl('http://127.0.0.1:8787/'),
      'http://127.0.0.1:8787',
    );
  });

  test('applyCatalogPayload replaces channels from cloud JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = CatalogRepository(
      prefs: prefs,
      secrets: MemorySecretsStore(),
    );
    await repo.load();

    final summary = await repo.applyCatalogPayload({
      'seedVersion': 18,
      'homeLibraryMode': 'mixVideos',
      'revision': 3,
      'channels': [
        {
          'id': 'cloud_show',
          'title': 'Cloud Show',
          'sourceType': 'youtubeVideoList',
          'enabled': true,
          'videos': [
            {
              'id': 'dQw4w9WgXcQ',
              'title': 'Episode',
              'youtubeVideoId': 'dQw4w9WgXcQ',
              'manual': true,
              'allowSeek': true,
            },
          ],
        },
      ],
    });

    expect(summary, contains('1 channels'));
    expect(summary, contains('rev 3'));
    final settings = repo.current();
    expect(settings.channels.length, 1);
    expect(settings.channels.first.id, 'cloud_show');
    expect(settings.homeLibraryMode.name, 'mixVideos');

    final status = await repo.cloudStatus();
    expect(status.lastRevision, 3);
    expect(status.lastCloudSyncMs, greaterThan(0));
  });
}
