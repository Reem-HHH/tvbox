import 'dart:math';

import 'models.dart';

/// Flatten enabled channel libraries and shuffle with a stable seed.
/// Caps Mix size so Android TV does not decode hundreds of thumbs at once.
const kMixVideoCap = 100;

List<PlayableVideo> flattenEnabledVideos(
  List<ContentChannel> channels,
  int seed, {
  int maxItems = kMixVideoCap,
}) {
  final items = <PlayableVideo>[
    for (final ch in channels.where((c) => c.enabled))
      for (final video in ch.videos) PlayableVideo(channelId: ch.id, video: video),
  ];
  items.shuffle(Random(seed));
  if (items.length <= maxItems) return items;
  return items.sublist(0, maxItems);
}

/// Enabled channels shuffled with a process-stable seed.
List<ContentChannel> shuffleEnabledChannels(
  List<ContentChannel> channels,
  int seed,
) {
  final enabled = channels.where((c) => c.enabled).toList();
  enabled.shuffle(Random(seed));
  return enabled;
}
