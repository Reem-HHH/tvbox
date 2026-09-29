/// Morning (06:00) and night (18:00) local playlist-sync windows.
class PlaylistSyncSchedule {
  PlaylistSyncSchedule._();

  static const morningHour = 6;
  static const nightHour = 18;

  /// `yyyyMMdd-morning` or `yyyyMMdd-night` for [now]'s current window.
  static String windowId(DateTime now) {
    var date = DateTime(now.year, now.month, now.day);
    final String slot;
    if (now.hour < morningHour) {
      date = date.subtract(const Duration(days: 1));
      slot = 'night';
    } else if (now.hour < nightHour) {
      slot = 'morning';
    } else {
      slot = 'night';
    }
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d-$slot';
  }

  static bool needsSync({
    required String? lastWindowId,
    required DateTime now,
  }) {
    final last = lastWindowId?.trim();
    if (last == null || last.isEmpty) return true;
    return last != windowId(now);
  }

  static String alreadySyncedMessage(DateTime now) {
    return now.hour < nightHour && now.hour >= morningHour
        ? 'Already synced this morning.'
        : 'Already synced tonight.';
  }

  static DateTime nextWindowStart(DateTime now) {
    final todayMorning = DateTime(now.year, now.month, now.day, morningHour);
    final todayNight = DateTime(now.year, now.month, now.day, nightHour);
    if (now.isBefore(todayMorning)) return todayMorning;
    if (now.isBefore(todayNight)) return todayNight;
    return DateTime(now.year, now.month, now.day + 1, morningHour);
  }

  static Duration untilNextWindow(DateTime now) {
    final wait = nextWindowStart(now).difference(now);
    if (wait.inSeconds < 1) return const Duration(seconds: 1);
    return wait;
  }
}
