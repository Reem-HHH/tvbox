import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/playlist_sync_schedule.dart';

void main() {
  test('windowId is morning after 6am and night after 6pm', () {
    expect(
      PlaylistSyncSchedule.windowId(DateTime(2026, 9, 8, 7, 0)),
      '20260908-morning',
    );
    expect(
      PlaylistSyncSchedule.windowId(DateTime(2026, 9, 8, 19, 0)),
      '20260908-night',
    );
    expect(
      PlaylistSyncSchedule.windowId(DateTime(2026, 9, 8, 2, 0)),
      '20260907-night',
    );
  });

  test('needsSync once per morning and once per night', () {
    final morning = DateTime(2026, 9, 8, 8, 0);
    final laterMorning = DateTime(2026, 9, 8, 11, 0);
    final night = DateTime(2026, 9, 8, 19, 0);
    expect(
      PlaylistSyncSchedule.needsSync(lastWindowId: null, now: morning),
      isTrue,
    );
    expect(
      PlaylistSyncSchedule.needsSync(
        lastWindowId: '20260908-morning',
        now: laterMorning,
      ),
      isFalse,
    );
    expect(
      PlaylistSyncSchedule.needsSync(
        lastWindowId: '20260908-morning',
        now: night,
      ),
      isTrue,
    );
    expect(
      PlaylistSyncSchedule.needsSync(
        lastWindowId: '20260908-night',
        now: night,
      ),
      isFalse,
    );
    expect(
      PlaylistSyncSchedule.needsSync(
        lastWindowId: '20260908-night',
        now: DateTime(2026, 9, 9, 7, 0),
      ),
      isTrue,
    );
  });

  test('untilNextWindow points at 6am or 6pm', () {
    expect(
      PlaylistSyncSchedule.nextWindowStart(DateTime(2026, 9, 8, 10, 0)),
      DateTime(2026, 9, 8, 18, 0),
    );
    expect(
      PlaylistSyncSchedule.nextWindowStart(DateTime(2026, 9, 8, 20, 0)),
      DateTime(2026, 9, 9, 6, 0),
    );
    expect(
      PlaylistSyncSchedule.nextWindowStart(DateTime(2026, 9, 8, 3, 0)),
      DateTime(2026, 9, 8, 6, 0),
    );
  });
}
