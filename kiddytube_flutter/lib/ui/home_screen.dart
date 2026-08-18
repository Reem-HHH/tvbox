import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/home_library.dart';
import '../catalog/models.dart';
import '../catalog/recent_watch.dart';
import '../app_version.dart';
import '../parent/parent_settings_screen.dart';
import '../parent/pin_gate.dart';
import '../parent/release_pin_policy.dart';
import '../player/player_screen.dart';
import 'focus_tile.dart';
import 'layout_metrics.dart';

const _ytRed = Color(0xFFFF0000);

/// Tiny header stamp so you can tell debug vs release on the TV.
/// `flutter run` → D·… ; `flutter run --release` / release APK → R·…
String get kiddyTubeBuildStamp {
  if (kReleaseMode) return 'R·$kiddyTubeVersion';
  if (kProfileMode) return 'P·$kiddyTubeVersion';
  return 'D·$kiddyTubeVersion';
}

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

  List<ContentChannel> _homeChannels = const [];
  List<PlayableVideo> _homeVideos = const [];
  int? _homeListToken;
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
        _refreshHomeLists(settings);
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

  void _refreshHomeLists(CatalogSettings settings) {
    final token = Object.hash(
      widget.repository.channelThumbSeed,
      settings.homeLibraryMode,
      Object.hashAll(
        settings.channels.map(
          (c) => Object.hash(
            c.id,
            c.enabled,
            c.sortOrder,
            c.videos.length,
            c.videos.isEmpty ? 0 : c.videos.first.id,
          ),
        ),
      ),
    );
    if (_homeListToken == token) return;
    _homeListToken = token;
    _homeChannels = enabledChannelsInCatalogOrder(settings.channels);
    _homeVideos = flattenEnabledVideos(settings.channels);
  }

  Future<void> _maybeDailySync() async {
    // Cloud catalog + watch history are manual-only (Parent → Home & Sync).
    await widget.repository.ensureCloudEnrolled();
    final youtubeChanged = await widget.repository.maybeRefreshDaily();
    if (!mounted) return;
    if (youtubeChanged) {
      await _reloadAfterSync();
    }
  }

  Future<void> _reloadRecentOnly() async {
    try {
      final recent = await widget.repository.recentWatch.load();
      if (!mounted) return;
      setState(() => _recent = recent);
    } catch (_) {}
  }

  Future<void> _reloadAfterSync() async {
    try {
      final settings = await widget.repository.load();
      final recent = await widget.repository.recentWatch.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _recent = recent;
        _refreshHomeLists(settings);
      });
    } catch (_) {}
  }

  /// Phone/tablet pull-down: refresh YouTube playlists only (not cloud).
  Future<void> _onPullToRefresh() async {
    _dailySyncTimer?.cancel();
    widget.repository.reshuffleHome();
    try {
      await widget.repository.refreshAllPlaylists(force: true);
    } catch (_) {}
    await _reloadAfterSync();
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
          onPlayed: _reloadRecentOnly,
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
    await _reloadRecentOnly();
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
    final layout = LayoutMetrics.of(context);
    // Touch devices only — not Android TV / leanback-style layouts.
    // Tablets (incl. iPad landscape) stay eligible even when also "tv-like" wide.
    final allowPullRefresh = layout.isTablet || !layout.isTvLike;
    final isMix = settings.homeLibraryMode == HomeLibraryMode.mixVideos;
    final channels = _homeChannels;
    final sections = splitEnabledChannelsByHomeSection(channels);
    final arabicChannels = sections.arabic;
    final englishChannels = sections.english;
    final videos = _homeVideos;
    final crossAxisCount = layout.gridColumns(isMix: isMix);
    final tileCacheWidth = _tileMemCacheWidth(context, crossAxisCount);

    final homeScroll = CustomScrollView(
      primary: true,
      physics: allowPullRefresh
          ? const AlwaysScrollableScrollPhysics()
          : null,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.pagePadding,
                      layout.isTablet || layout.isTvLike ? 12 : 8,
                      layout.pagePadding,
                      12,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/kiddytube_logo_header.png',
                                height: layout.logoSize,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 2),
                              child: Text(
                                kiddyTubeBuildStamp,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1,
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface.withValues(alpha: 0.38),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        HomeModeToggle(
                          isMix: isMix,
                          onSelectShows: () =>
                              _setHomeMode(HomeLibraryMode.channels),
                          onSelectMix: () =>
                              _setHomeMode(HomeLibraryMode.mixVideos),
                        ),
                        const SizedBox(width: 10),
                        FocusTile(
                          onActivated: _openParent,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: scheme.onSurface,
                              size: 22,
                            ),
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
                        10,
                      ),
                      child: Text(
                        'Continue watching',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: layout.sectionTitleSize,
                          color: scheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: layout.continueHeight,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.pagePadding,
                        ),
                        scrollDirection: Axis.horizontal,
                        scrollCacheExtent:
                            const ScrollCacheExtent.pixels(400),
                        itemCount: _recent.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = _recent[index];
                          final progress = item.positionMs > 0 ? 0.35 : 0.0;
                          return SizedBox(
                            width: layout.continueWidth,
                            child: FocusTile(
                              autofocus: index == 0,
                              onActivated: () => _openVideo(
                                item.toPlayable(),
                                startPositionMs: item.positionMs,
                              ),
                              child: YtCard(
                                title: item.title,
                                subtitle: 'Continue',
                                imageUrl: item.youtubeVideoId == null
                                    ? null
                                    : 'https://i.ytimg.com/vi/${item.youtubeVideoId}/mqdefault.jpg',
                                contentKey:
                                    item.youtubeVideoId ?? item.videoId,
                                memCacheWidth: tileCacheWidth,
                                progress: progress,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
                if (isMix) ...[
                  _HomeSectionTitle(label: 'Recommended', layout: layout),
                  if (videos.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No videos yet.\nAsk a parent to sync playlists.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    VideoGridSliver(
                      items: videos,
                      crossAxisCount: crossAxisCount,
                      memCacheWidth: tileCacheWidth,
                      onOpen: _openVideo,
                      autofocusFirst: _recent.isEmpty,
                      aspectRatio: layout.youtubeCardAspect,
                    ),
                ] else ...[
                  if (channels.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No channels yet.')),
                    )
                  else ...[
                    if (arabicChannels.isNotEmpty) ...[
                      _HomeSectionTitle(label: 'Arabic Shows', layout: layout),
                      ChannelGridSliver(
                        channels: arabicChannels,
                        thumbSeed: widget.repository.channelThumbSeed,
                        crossAxisCount: crossAxisCount,
                        memCacheWidth: tileCacheWidth,
                        onOpen: _openChannel,
                        autofocusFirst: _recent.isEmpty,
                        aspectRatio: layout.youtubeCardAspect,
                      ),
                    ],
                    if (englishChannels.isNotEmpty) ...[
                      _HomeSectionTitle(
                        label: 'English Shows',
                        layout: layout,
                        padTop: arabicChannels.isNotEmpty,
                      ),
                      ChannelGridSliver(
                        channels: englishChannels,
                        thumbSeed: widget.repository.channelThumbSeed,
                        crossAxisCount: crossAxisCount,
                        memCacheWidth: tileCacheWidth,
                        onOpen: _openChannel,
                        autofocusFirst:
                            _recent.isEmpty && arabicChannels.isEmpty,
                        aspectRatio: layout.youtubeCardAspect,
                      ),
                    ],
                  ],
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
            child: allowPullRefresh
                ? RefreshIndicator(
                    color: _ytRed,
                    onRefresh: _onPullToRefresh,
                    child: homeScroll,
                  )
                : homeScroll,
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

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.label,
    required this.layout,
    this.padTop = false,
  });

  final String label;
  final LayoutMetrics layout;
  final bool padTop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.pagePadding,
          padTop ? 12 : 0,
          layout.pagePadding,
          10,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: layout.sectionTitleSize,
            color: scheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Side-by-side Shows | Mix control; selected segment uses YouTube red.
class HomeModeToggle extends StatelessWidget {
  const HomeModeToggle({
    super.key,
    required this.isMix,
    required this.onSelectShows,
    required this.onSelectMix,
  });

  final bool isMix;
  final VoidCallback onSelectShows;
  final VoidCallback onSelectMix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSegment(
              label: 'Shows',
              selected: !isMix,
              onActivated: onSelectShows,
            ),
            _ModeSegment(
              label: 'Mix',
              selected: isMix,
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
    required this.onActivated,
  });

  final String label;
  final bool selected;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) {
    return FocusTile(
      onActivated: onActivated,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _ytRed : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class ChannelGridSliver extends StatelessWidget {
  const ChannelGridSliver({
    super.key,
    required this.channels,
    required this.thumbSeed,
    required this.crossAxisCount,
    required this.memCacheWidth,
    required this.onOpen,
    required this.aspectRatio,
    this.autofocusFirst = true,
  });

  final List<ContentChannel> channels;
  final int thumbSeed;
  final int crossAxisCount;
  final int memCacheWidth;
  final double aspectRatio;
  final ValueChanged<ContentChannel> onOpen;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    final pad = LayoutMetrics.of(context).pagePadding;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final channel = channels[index];
            final preview = previewVideoForChannel(channel, thumbSeed);
            return FocusTile(
              key: ValueKey(
                'channel-${channel.id}-${preview?.id ?? 'none'}-$thumbSeed',
              ),
              autofocus: autofocusFirst && index == 0,
              onActivated: () => onOpen(channel),
              child: YtCard(
                title: channel.title,
                subtitle: '${channel.videos.length} videos',
                imageUrl: preview?.youtubeThumbnail,
                contentKey: preview?.youtubeVideoId ?? preview?.id,
                memCacheWidth: memCacheWidth,
                placeholderColor: Color(channel.color),
                imageFit: BoxFit.contain,
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

class VideoGridSliver extends StatelessWidget {
  const VideoGridSliver({
    super.key,
    required this.items,
    required this.crossAxisCount,
    required this.memCacheWidth,
    required this.onOpen,
    required this.aspectRatio,
    this.autofocusFirst = true,
  });

  final List<PlayableVideo> items;
  final int crossAxisCount;
  final int memCacheWidth;
  final double aspectRatio;
  final ValueChanged<PlayableVideo> onOpen;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    final pad = LayoutMetrics.of(context).pagePadding;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final video = item.video;
            return FocusTile(
              key: ValueKey('mix-${item.channelId}-${video.id}'),
              autofocus: autofocusFirst && index == 0,
              onActivated: () => onOpen(item),
              child: YtCard(
                title: video.title,
                subtitle: item.channelId.replaceAll('_', ' '),
                imageUrl: video.youtubeThumbnail,
                contentKey: video.youtubeVideoId ?? video.id,
                memCacheWidth: memCacheWidth,
                imageFit: BoxFit.contain,
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

/// YouTube-style card: 16:9 thumb, title + muted subtitle under.
class YtCard extends StatelessWidget {
  const YtCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.fallbackImageUrl,
    this.contentKey,
    this.memCacheWidth,
    this.placeholderColor,
    this.progress = 0,
    this.accent = _ytRed,
    this.imageFit = BoxFit.contain,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final String? contentKey;
  final int? memCacheWidth;
  final Color? placeholderColor;
  final double progress;
  final Color accent;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final layout = LayoutMetrics.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memWidth = memCacheWidth ??
        (MediaQuery.sizeOf(context).width / 3 * dpr).clamp(160.0, 480.0).round();
    final titleSize = layout.isTvLike ? 14.0 : (layout.isTablet ? 13.0 : 12.0);
    final subtitleSize = titleSize - 1.5;
    final fill = placeholderColor ?? scheme.surfaceContainerHighest;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: fill),
          if (imageUrl != null)
            CachedNetworkImage(
              key: ValueKey('thumb-${contentKey ?? imageUrl}'),
              cacheKey: contentKey == null ? imageUrl : 'yt-mq-$contentKey',
              imageUrl: imageUrl!,
              fit: imageFit,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              filterQuality: FilterQuality.low,
              memCacheWidth: memWidth,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, url, _) {
                final fallback = fallbackImageUrl;
                if (fallback != null &&
                    fallback.isNotEmpty &&
                    fallback != url) {
                  return CachedNetworkImage(
                    key: ValueKey('thumb-fallback-$contentKey'),
                    cacheKey: 'yt-fb-$contentKey',
                    imageUrl: fallback,
                    fit: imageFit,
                    fadeInDuration: Duration.zero,
                    filterQuality: FilterQuality.low,
                    memCacheWidth: memWidth,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  );
                }
                final id = contentKey;
                if (id != null &&
                    id.length == 11 &&
                    !url.contains('hqdefault')) {
                  return CachedNetworkImage(
                    key: ValueKey('thumb-hq-$id'),
                    cacheKey: 'yt-hq-$id',
                    imageUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                    fit: imageFit,
                    fadeInDuration: Duration.zero,
                    filterQuality: FilterQuality.low,
                    memCacheWidth: memWidth,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          if (progress > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: accent,
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: thumb),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: titleSize,
              height: 1.2,
            ),
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: subtitleSize,
                height: 1.15,
              ),
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
    final videos = newestVideosFirst(channel.videos);
    final queue = [
      for (final v in videos)
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
    final videos = newestVideosFirst(channel.videos);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          channel.title,
          style: TextStyle(
            fontSize: layout.isTablet || layout.isTvLike ? 22 : 18,
          ),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        toolbarHeight:
            layout.isTablet || layout.isTvLike ? 64 : kToolbarHeight,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
          child: videos.isEmpty
              ? const Center(child: Text('No videos yet.'))
              : GridView.builder(
                  padding: EdgeInsets.all(layout.pagePadding),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  addAutomaticKeepAlives: false,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 12,
                    childAspectRatio: layout.youtubeCardAspect,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return FocusTile(
                      key: ValueKey('lib-${channel.id}-${video.id}'),
                      autofocus: index == 0,
                      onActivated: () => _play(context, index),
                      child: YtCard(
                        title: video.title,
                        subtitle: channel.title,
                        imageUrl: video.youtubeThumbnail,
                        contentKey: video.youtubeVideoId ?? video.id,
                        memCacheWidth: memCacheWidth,
                        placeholderColor: Color(channel.color),
                        imageFit: BoxFit.contain,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
