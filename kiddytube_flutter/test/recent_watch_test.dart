import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/models.dart';
import 'package:kiddytube/catalog/recent_watch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('RecentWatchItem JSON keeps duration; old rows default to 0', () {
    const item = RecentWatchItem(
      channelId: 'peppa',
      videoId: 'vid1',
      title: 'Muddy Puddles',
      youtubeVideoId: 'aaaaaaaaaaa',
      positionMs: 12_000,
      durationMs: 60_000,
      updatedAtMs: 100,
    );
    final roundTrip = RecentWatchItem.fromJson(item.toJson());
    expect(roundTrip.durationMs, 60_000);
    expect(roundTrip.positionMs, 12_000);

    final legacy = RecentWatchItem.fromJson({
      'channelId': 'peppa',
      'videoId': 'vid1',
      'title': 'Old',
      'positionMs': 8000,
      'updatedAtMs': 1,
    });
    expect(legacy.durationMs, 0);
    expect(legacy.positionMs, 8000);
  });

  test('watchProgressFraction is zero without duration (no fake bar)', () {
    expect(watchProgressFraction(12_000, 0), 0);
    expect(watchProgressFraction(0, 60_000), 0);
    expect(watchProgressFraction(15_000, 60_000), 0.25);
    expect(watchProgressFraction(90_000, 60_000), 1.0);
  });

  test('resumeStartMs matches clampedResumePosition', () {
    expect(resumeStartMs(1000, 60_000), 0);
    expect(resumeStartMs(10_000, 60_000), 10_000);
    expect(resumeStartMs(56_000, 60_000), 0);
  });

  test('record keeps previous duration when new duration is unknown', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RecentWatchStore(prefs);
    const video = VideoItem(
      id: 'vid1',
      title: 'Ep',
      youtubeVideoId: 'aaaaaaaaaaa',
    );
    await store.record(
      channelId: 'peppa',
      video: video,
      positionMs: 10_000,
      durationMs: 60_000,
    );
    await store.record(
      channelId: 'peppa',
      video: video,
      positionMs: 12_000,
    );
    final loaded = await store.load();
    expect(loaded.single.positionMs, 12_000);
    expect(loaded.single.durationMs, 60_000);
  });

  test('mergeFromCloud keeps known duration when winner has none', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RecentWatchStore(prefs);
    await store.record(
      channelId: 'peppa',
      video: const VideoItem(
        id: 'vid1',
        title: 'Local',
        youtubeVideoId: 'aaaaaaaaaaa',
      ),
      positionMs: 8_000,
      durationMs: 45_000,
    );
    final local = await store.load();
    final merged = await store.mergeFromCloud([
      RecentWatchItem(
        channelId: 'peppa',
        videoId: 'vid1',
        title: 'Remote newer',
        youtubeVideoId: 'aaaaaaaaaaa',
        positionMs: 20_000,
        durationMs: 0,
        updatedAtMs: local.first.updatedAtMs + 5000,
      ),
    ]);
    expect(merged.single.positionMs, 20_000);
    expect(merged.single.durationMs, 45_000);
    expect(merged.single.title, 'Remote newer');
  });
}
