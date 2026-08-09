import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/home_library.dart';
import '../catalog/models.dart';
import '../catalog/recent_watch.dart';
import '../parent/parent_settings_screen.dart';
import '../parent/pin_gate.dart';
import '../parent/release_pin_policy.dart';
import '../player/player_screen.dart';
import 'focus_tile.dart';
import 'layout_metrics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CatalogSettings? _settings;
  List<RecentWatchItem> _recent = const [];
  Object? _error;

  List<ContentChannel> _shuffledChannels = const [];
  List<PlayableVideo> _shuffledVideos = const [];
  int? _shuffleToken;
  Timer? _dailySyncTimer;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _dailySyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final settings = await widget.repository.load();
      final recent = await widget.repository.recentWatch.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _recent = recent;
        _error = null;
        _refreshShuffled(settings);
      });
      // Let first frame paint before network sync (avoids hitchy startup).
      _dailySyncTimer?.cancel();
      _dailySyncTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) unawaited(_maybeDailySync());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _refreshShuffled(CatalogSettings settings) {
    final token = Object.hash(
      widget.repository.channelShuffleSeed,
      widget.repository.videoShuffleSeed,
      settings.homeLibraryMode,
      Object.hashAll(
        settings.channels.map(
          (c) => Object.hash(c.id, c.enabled, c.videos.length, c.previewVideoId),
        ),
      ),
    );
    if (_shuffleToken == token) return;
    _shuffleToken = token;
    _shuffledChannels = shuffleEnabledChannels(
      settings.channels,
      widget.repository.channelShuffleSeed,
    );
    _shuffledVideos = flattenEnabledVideos(
      settings.channels,
      widget.repository.videoShuffleSeed,
    );
  }

  Future<void> _maybeDailySync() async {
    final cloudChanged = await widget.repository.maybePullCloudDaily();
    final youtubeChanged = await widget.repository.maybeRefreshDaily();
    if ((cloudChanged || youtubeChanged) && mounted) {
      await _reloadAfterSync();
    }
  }

  Future<void> _reloadAfterSync() async {
    try {
      final settings = await widget.repository.load();
      final recent = await widget.repository.recentWatch.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _recent = recent;
        _refreshShuffled(settings);
      });
    } catch (_) {}
  }

  Future<void> _setHomeMode(HomeLibraryMode mode) async {
    final current = _settings;
    if (current == null || current.homeLibraryMode == mode) return;
    final unlocked = await ensureParentUnlocked(context, widget.repository);
    if (!unlocked || !mounted) return;
    await widget.repository.setHomeLibraryMode(mode);
    await _reload();
  }

  Future<void> _openParent() async {
    final unlocked = await ensureParentUnlocked(context, widget.repository);
    if (!unlocked || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentSettingsScreen(repository: widget.repository),
      ),
    );
    await _reload();
  }

  void _openChannel(ContentChannel channel) {
    if (!_ensureKidPlaybackAllowed()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LibraryScreen(
          channel: channel,
          repository: widget.repository,
          onPlayed: _reload,
        ),
      ),
    );
  }

  bool _ensureKidPlaybackAllowed() {
    final settings = _settings;
    if (settings == null) return false;
    if (!ReleasePinPolicy.requirePinChangeForKidPlayback(
      isDebugBuild: !kReleaseMode,
      pinChangedFromDefault: settings.pinChangedFromDefault,
    )) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Change the default parent PIN before kids can watch (release build).',
        ),
      ),
    );
    return false;
  }

  Future<void> _openVideo(
    PlayableVideo item, {
    int startPositionMs = 0,
  }) async {
    if (!_ensureKidPlaybackAllowed()) return;
    final settings = _settings;
    if (settings == null) return;
    ContentChannel? channel;
    for (final c in settings.channels) {
      if (c.id == item.channelId) {
        channel = c;
        break;
      }
    }
    final videos = channel?.videos ?? [item.video];
    var index = videos.indexWhere((v) => v.id == item.video.id);
    if (index < 0) index = 0;
    final queue = [
      for (final v in videos)
        PlayableVideo(channelId: item.channelId, video: v),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          repository: widget.repository,
          queue: queue,
          startIndex: index,
          startPositionMs: startPositionMs,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Failed to load catalog: $_error')),
      );
    }
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = LayoutMetrics.of(context);
    final isMix = settings.homeLibraryMode == HomeLibraryMode.mixVideos;
    _refreshShuffled(settings);
    final channels = _shuffledChannels;
    final videos = _shuffledVideos;
    final crossAxisCount = layout.gridColumns(isMix: isMix);
    final tileCacheWidth = _tileMemCacheWidth(context, crossAxisCount);
    final accent = isDark ? scheme.primary : const Color(0xFF0D47A1);
    final chipBg = scheme.surfaceContainerHighest.withValues(alpha: 0.85);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    scheme.surface,
                    Color.lerp(scheme.surface, scheme.primary, 0.18)!,
                  ]
                : const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: CustomScrollView(
                primary: true,
                scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.pagePadding,
                        layout.isTablet || layout.isTvLike ? 16 : 12,
                        layout.pagePadding,
                        8,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/kiddytube_logo_header.png',
                              height: layout.logoSize,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'KiddyTube',
                              style: TextStyle(
                                fontSize: layout.titleSize,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          _HomeModeToggle(
                            isMix: isMix,
                            accent: accent,
                            chipBg: chipBg,
                            onSelectShows: () =>
                                _setHomeMode(HomeLibraryMode.channels),
                            onSelectMix: () =>
                                _setHomeMode(HomeLibraryMode.mixVideos),
                          ),
                          const SizedBox(width: 8),
                          FocusTile(
                            onActivated: _openParent,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.lock_outline, color: accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_recent.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.pagePadding,
                          4,
                          layout.pagePadding,
                          8,
                        ),
                        child: Text(
                          'Continue watching',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: layout.sectionTitleSize,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: layout.continueHeight,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.pagePadding - 4,
                          ),
                          scrollDirection: Axis.horizontal,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(400),
                          itemCount: _recent.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = _recent[index];
                            return SizedBox(
                              width: layout.continueWidth,
                              child: FocusTile(
                                autofocus: index == 0,
                                onActivated: () => _openVideo(
                                  item.toPlayable(),
                                  startPositionMs: item.positionMs,
                                ),
                                child: _ColoredCard(
                                  color: const Color(0xFF5C6BC0),
                                  title: item.title,
                                  subtitle: 'Continue',
                                  imageUrl: item.youtubeVideoId == null
                                      ? null
                                      : 'https://i.ytimg.com/vi/${item.youtubeVideoId}/mqdefault.jpg',
                                  contentKey:
                                      item.youtubeVideoId ?? item.videoId,
                                  memCacheWidth: tileCacheWidth,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.pagePadding,
                        0,
                        layout.pagePadding,
                        8,
                      ),
                      child: Text(
                        isMix ? 'All videos' : 'Shows',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: layout.sectionTitleSize,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  if (isMix)
                    _VideoGridSliver(
                      items: videos,
                      crossAxisCount: crossAxisCount,
                      memCacheWidth: tileCacheWidth,
                      onOpen: _openVideo,
                      autofocusFirst: _recent.isEmpty,
                    )
                  else
                    _ChannelGridSliver(
                      channels: channels,
                      crossAxisCount: crossAxisCount,
                      memCacheWidth: tileCacheWidth,
                      onOpen: _openChannel,
                      autofocusFirst: _recent.isEmpty,
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _tileMemCacheWidth(BuildContext context, int crossAxisCount) {
    final mq = MediaQuery.of(context);
    final cols = crossAxisCount.clamp(1, 8);
    final tileLogical = mq.size.width / cols;
    return (tileLogical * mq.devicePixelRatio).clamp(160.0, 480.0).round();
  }
}

/// Side-by-side Shows | Mix control; selected segment is highlighted.
class _HomeModeToggle extends StatelessWidget {
  const _HomeModeToggle({
    required this.isMix,
    required this.accent,
    required this.chipBg,
    required this.onSelectShows,
    required this.onSelectMix,
  });

  final bool isMix;
  final Color accent;
  final Color chipBg;
  final VoidCallback onSelectShows;
  final VoidCallback onSelectMix;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSegment(
              label: 'Shows',
              selected: !isMix,
              accent: accent,
              onActivated: onSelectShows,
            ),
            _ModeSegment(
              label: 'Mix',
              selected: isMix,
              accent: accent,
              onActivated: onSelectMix,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onActivated,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) {
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return FocusTile(
      onActivated: onActivated,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? onAccent : accent,
          ),
        ),
      ),
    );
  }
}

class _ChannelGridSliver extends StatelessWidget {
  const _ChannelGridSliver({
    required this.channels,
    required this.crossAxisCount,
    required this.memCacheWidth,
    required this.onOpen,
    this.autofocusFirst = true,
  });

  final List<ContentChannel> channels;
  final int crossAxisCount;
  final int memCacheWidth;
  final ValueChanged<ContentChannel> onOpen;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No channels yet.')),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 16 / 11,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final channel = channels[index];
            return FocusTile(
              key: ValueKey('channel-${channel.id}-${channel.previewVideoId}'),
              autofocus: autofocusFirst && index == 0,
              onActivated: () => onOpen(channel),
              child: _ColoredCard(
                color: Color(channel.color),
                title: channel.title,
                subtitle: '${channel.videos.length} videos',
                imageUrl: channel.previewThumbnail,
                contentKey: channel.previewVideoId ?? channel.id,
                memCacheWidth: memCacheWidth,
              ),
            );
          },
          childCount: channels.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

class _VideoGridSliver extends StatelessWidget {
  const _VideoGridSliver({
    required this.items,
    required this.crossAxisCount,
    required this.memCacheWidth,
    required this.onOpen,
    this.autofocusFirst = true,
  });

  final List<PlayableVideo> items;
  final int crossAxisCount;
  final int memCacheWidth;
  final ValueChanged<PlayableVideo> onOpen;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No videos yet.\nAsk a parent to sync playlists.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 16 / 11,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final video = item.video;
            return FocusTile(
              key: ValueKey('mix-${item.channelId}-${video.id}'),
              autofocus: autofocusFirst && index == 0,
              onActivated: () => onOpen(item),
              child: _ColoredCard(
                color: const Color(0xFF5C6BC0),
                title: video.title,
                subtitle: item.channelId,
                imageUrl: video.youtubeThumbnail,
                contentKey: video.youtubeVideoId ?? video.id,
                memCacheWidth: memCacheWidth,
              ),
            );
          },
          childCount: items.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

class _ColoredCard extends StatelessWidget {
  const _ColoredCard({
    required this.color,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.contentKey,
    this.memCacheWidth,
  });

  final Color color;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? contentKey;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memWidth = memCacheWidth ??
        (MediaQuery.sizeOf(context).width / 3 * dpr).clamp(160.0, 480.0).round();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            key: ValueKey('thumb-${contentKey ?? imageUrl}'),
            cacheKey: contentKey == null ? imageUrl : 'yt-mq-$contentKey',
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            filterQuality: FilterQuality.low,
            memCacheWidth: memWidth,
            placeholder: (_, _) => ColoredBox(color: color),
            errorWidget: (_, url, _) {
              final id = contentKey;
              if (id != null &&
                  id.length == 11 &&
                  !url.contains('hqdefault')) {
                return CachedNetworkImage(
                  key: ValueKey('thumb-hq-$id'),
                  cacheKey: 'yt-hq-$id',
                  imageUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  filterQuality: FilterQuality.low,
                  memCacheWidth: memWidth,
                  placeholder: (_, _) => ColoredBox(color: color),
                  errorWidget: (_, _, _) => ColoredBox(color: color),
                );
              }
              return ColoredBox(color: color);
            },
          )
        else
          ColoredBox(color: color),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.channel,
    required this.repository,
    this.onPlayed,
  });

  final ContentChannel channel;
  final CatalogRepository repository;
  final Future<void> Function()? onPlayed;

  Future<void> _play(BuildContext context, int index) async {
    final settings = await repository.load();
    if (ReleasePinPolicy.requirePinChangeForKidPlayback(
      isDebugBuild: !kReleaseMode,
      pinChangedFromDefault: settings.pinChangedFromDefault,
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Change the default parent PIN before kids can watch (release build).',
            ),
          ),
        );
      }
      return;
    }
    final queue = [
      for (final v in channel.videos)
        PlayableVideo(channelId: channel.id, video: v),
    ];
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          repository: repository,
          queue: queue,
          startIndex: index,
        ),
      ),
    );
    await onPlayed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final layout = LayoutMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final crossAxisCount = layout.libraryColumns();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memCacheWidth =
        (MediaQuery.sizeOf(context).width / crossAxisCount * dpr)
            .clamp(160.0, 480.0)
            .round();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          channel.title,
          style: TextStyle(
            fontSize: layout.isTablet || layout.isTvLike ? 22 : 18,
          ),
        ),
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        toolbarHeight:
            layout.isTablet || layout.isTvLike ? 64 : kToolbarHeight,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
          child: channel.videos.isEmpty
              ? const Center(child: Text('No videos yet.'))
              : GridView.builder(
                  padding: EdgeInsets.all(layout.pagePadding),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  addAutomaticKeepAlives: false,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 16 / 11,
                  ),
                  itemCount: channel.videos.length,
                  itemBuilder: (context, index) {
                    final video = channel.videos[index];
                    return FocusTile(
                      key: ValueKey('lib-${channel.id}-${video.id}'),
                      autofocus: index == 0,
                      onActivated: () => _play(context, index),
                      child: _ColoredCard(
                        color: Color(channel.color),
                        title: video.title,
                        subtitle: channel.title,
                        imageUrl: video.youtubeThumbnail,
                        contentKey: video.youtubeVideoId ?? video.id,
                        memCacheWidth: memCacheWidth,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
