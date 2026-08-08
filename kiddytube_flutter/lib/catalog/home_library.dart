import 'dart:math';

import 'models.dart';

/// Flatten enabled channel libraries and shuffle with a stable seed.
List<PlayableVideo> flattenEnabledVideos(
  List<ContentChannel> channels,
  int seed,
) {
  final items = <PlayableVideo>[
    for (final ch in channels.where((c) => c.enabled))
      for (final video in ch.videos) PlayableVideo(channelId: ch.id, video: video),
  ];
  items.shuffle(Random(seed));
  return items;
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
