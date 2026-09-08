import 'dart:math';

import 'models.dart';

/// Caps Mix size so Android TV does not decode hundreds of thumbs at once.
const kMixVideoCap = 100;

/// Arabic / Islamic household tiles on Shows (everything else is English).
const kArabicHomeChannelIds = {
  'live_makkah',
  'dawood',
  'omar_hana',
  'mini_muslim',
  'zaky',
  'kids_music',
  'spacetoon',
  'moda_modi',
  'smarta',
  'sesame_ar',
  'ana_wa_akhi',
  'maruko',
  'muka_muka',
  'bakkar',
  'mansour',
  'masha_ar',
  'blippi_ar',
  'hadikat_almarah',
  'toyor_baby',
  'adam_mishmish',
  'zakaria',
  'kiki_nadoush',
  'rayan',
  'sweet_kalima',
  'abata',
};

bool isArabicHomeChannel(String id) => kArabicHomeChannelIds.contains(id);

/// Enabled channels in catalog [ContentChannel.sortOrder] (no shuffle).
List<ContentChannel> enabledChannelsInCatalogOrder(
  List<ContentChannel> channels,
) {
  final enabled = channels.where((c) => c.enabled).toList();
  enabled.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.id.compareTo(b.id);
  });
  return enabled;
}

/// Shows home: Arabic tiles, then English tiles (parent-added ids go English).
({List<ContentChannel> arabic, List<ContentChannel> english})
    splitEnabledChannelsByHomeSection(List<ContentChannel> channels) {
  final arabic = <ContentChannel>[];
  final english = <ContentChannel>[];
  for (final ch in enabledChannelsInCatalogOrder(channels)) {
    if (isArabicHomeChannel(ch.id)) {
      arabic.add(ch);
    } else {
      english.add(ch);
    }
  }
  return (arabic: arabic, english: english);
}

/// Flatten enabled libraries, newest publish date first.
/// Videos without [VideoItem.publishedAtMs] sort last, then by channel order.
List<PlayableVideo> flattenEnabledVideos(
  List<ContentChannel> channels, {
  int maxItems = kMixVideoCap,
}) {
  final items = <PlayableVideo>[
    for (final ch in enabledChannelsInCatalogOrder(channels))
      for (final video in ch.videos)
        PlayableVideo(channelId: ch.id, video: video),
  ];
  items.sort((a, b) {
    final aMs = a.video.publishedAtMs ?? -1;
    final bMs = b.video.publishedAtMs ?? -1;
    final byDate = bMs.compareTo(aMs);
    if (byDate != 0) return byDate;
    final byChannel = a.channelId.compareTo(b.channelId);
    if (byChannel != 0) return byChannel;
    return a.video.id.compareTo(b.video.id);
  });
  if (items.length <= maxItems) return items;
  return items.sublist(0, maxItems);
}

/// Newest episodes considered for a rotating show-tile thumb.
const kChannelThumbPool = 8;

/// Random thumb from the latest [latestPool] videos. Same [seed] + channel
/// always picks the same episode; [reshuffleHome] changes the seed.
VideoItem? previewVideoForChannel(
  ContentChannel channel,
  int seed, {
  int latestPool = kChannelThumbPool,
}) {
  final withThumbs = [
    for (final v in newestVideosFirst(channel.videos))
      if (v.youtubeThumbnail != null && v.youtubeThumbnail!.isNotEmpty) v,
  ];
  if (withThumbs.isEmpty) return null;
  final n = latestPool < 1 ? 1 : latestPool;
  final pool = withThumbs.take(n).toList();
  return pool[Random(seed ^ channel.id.hashCode).nextInt(pool.length)];
}
