import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _reload();
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
      });
      unawaited(_maybeDailySync());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
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
      });
    } catch (_) {}
  }

  Future<void> _toggleMode() async {
    final unlocked = await ensureParentUnlocked(context, widget.repository);
    if (!unlocked || !mounted) return;
    final current = _settings;
    if (current == null) return;
    final next = current.homeLibraryMode == HomeLibraryMode.channels
        ? HomeLibraryMode.mixVideos
        : HomeLibraryMode.channels;
    await widget.repository.setHomeLibraryMode(next);
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
    final channels = shuffleEnabledChannels(
      settings.channels,
      widget.repository.channelShuffleSeed,
    );
    final videos = flattenEnabledVideos(
      settings.channels,
      widget.repository.videoShuffleSeed,
    );
    final crossAxisCount = layout.gridColumns(isMix: isMix);
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
                              'assets/kiddytube_logo.png',
                              height: layout.logoSize,
                              width: layout.logoSize,
                              fit: BoxFit.cover,
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
                          FocusTile(
                            onActivated: _toggleMode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isMix ? 'Mix' : 'Shows',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
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
                                      : 'https://i.ytimg.com/vi/${item.youtubeVideoId}/sddefault.jpg',
                                  contentKey:
                                      item.youtubeVideoId ?? item.videoId,
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
                      onOpen: _openVideo,
                      autofocusFirst: _recent.isEmpty,
                    )
                  else
                    _ChannelGridSliver(
                      channels: channels,
                      crossAxisCount: crossAxisCount,
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
}

class _ChannelGridSliver extends StatelessWidget {
  const _ChannelGridSliver({
    required this.channels,
    required this.crossAxisCount,
    required this.onOpen,
    this.autofocusFirst = true,
  });

  final List<ContentChannel> channels;
  final int crossAxisCount;
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
              ),
            );
          },
          childCount: channels.length,
        ),
      ),
    );
  }
}

class _VideoGridSliver extends StatelessWidget {
  const _VideoGridSliver({
    required this.items,
    required this.crossAxisCount,
    required this.onOpen,
    this.autofocusFirst = true,
  });

  final List<PlayableVideo> items;
  final int crossAxisCount;
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
                imageUrl: video.youtubeThumbnailLarge ?? video.youtubeThumbnail,
                contentKey: video.youtubeVideoId ?? video.id,
              ),
            );
          },
          childCount: items.length,
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
  });

  final Color color;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? contentKey;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final memWidth = (width * MediaQuery.devicePixelRatioOf(context))
        .clamp(480.0, 1280.0)
        .round();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            key: ValueKey('thumb-${contentKey ?? imageUrl}'),
            cacheKey: contentKey == null ? imageUrl : 'yt-$contentKey',
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 180),
            memCacheWidth: memWidth,
            placeholder: (_, _) => ColoredBox(color: color),
            errorWidget: (_, url, _) {
              final id = contentKey;
              if (id != null &&
                  id.length == 11 &&
                  url.contains('sddefault')) {
                return CachedNetworkImage(
                  key: ValueKey('thumb-hq-$id'),
                  cacheKey: 'yt-hq-$id',
                  imageUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                  fit: BoxFit.cover,
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
                        imageUrl: video.youtubeThumbnailLarge ??
                            video.youtubeThumbnail,
                        contentKey: video.youtubeVideoId ?? video.id,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
