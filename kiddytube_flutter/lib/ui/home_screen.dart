import 'package:flutter/material.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/home_library.dart';
import '../catalog/models.dart';
import '../catalog/recent_watch.dart';
import '../parent/parent_settings_screen.dart';
import '../parent/pin_gate.dart';
import '../player/player_screen.dart';
import 'focus_tile.dart';

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
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

  Future<void> _openVideo(
    PlayableVideo item, {
    int startPositionMs = 0,
  }) async {
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

    final isMix = settings.homeLibraryMode == HomeLibraryMode.mixVideos;
    final channels = shuffleEnabledChannels(
      settings.channels,
      widget.repository.channelShuffleSeed,
    );
    final videos = flattenEnabledVideos(
      settings.channels,
      widget.repository.videoShuffleSeed,
    );

    final width = MediaQuery.sizeOf(context).width;
    // Phone < 600, tablet/iPad ~600–1100, Android TV / wide ≥ 1100.
    final isTvWide = width >= 1100;
    final isTablet = width >= 600;
    final crossAxisCount = isMix
        ? (isTvWide ? 5 : (isTablet ? 4 : 2))
        : (isTvWide ? 4 : (isTablet ? 4 : 2));

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'KiddyTube',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1),
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
                        color: const Color(0xCCFFFFFF),
                        child: Text(
                          isMix ? 'Mix' : 'Shows',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FocusTile(
                      onActivated: _openParent,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: const Color(0xCCFFFFFF),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_recent.isNotEmpty && !isMix) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    'Continue watching',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
                SizedBox(
                  height: isTablet ? 140 : 120,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _recent[index];
                      return SizedBox(
                        width: isTablet ? 220 : 180,
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
                                : 'https://i.ytimg.com/vi/${item.youtubeVideoId}/hqdefault.jpg',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: isMix
                    ? _VideoGrid(
                        items: videos,
                        crossAxisCount: crossAxisCount,
                        onOpen: _openVideo,
                      )
                    : _ChannelGrid(
                        channels: channels,
                        crossAxisCount: crossAxisCount,
                        onOpen: _openChannel,
                        autofocusFirst: _recent.isEmpty,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
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
      return const Center(child: Text('No channels yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 16 / 11,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return FocusTile(
          autofocus: autofocusFirst && index == 0,
          onActivated: () => onOpen(channel),
          child: _ColoredCard(
            color: Color(channel.color),
            title: channel.title,
            subtitle: '${channel.videos.length} videos',
          ),
        );
      },
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.items,
    required this.crossAxisCount,
    required this.onOpen,
  });

  final List<PlayableVideo> items;
  final int crossAxisCount;
  final ValueChanged<PlayableVideo> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No videos yet.\nAsk a parent to sync playlists.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 16 / 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return FocusTile(
          autofocus: index == 0,
          onActivated: () => onOpen(item),
          child: _ColoredCard(
            color: const Color(0xFF5C6BC0),
            title: item.video.title,
            subtitle: item.channelId,
            imageUrl: item.video.youtubeThumbnail,
          ),
        );
      },
    );
  }
}

class _ColoredCard extends StatelessWidget {
  const _ColoredCard({
    required this.color,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });

  final Color color;
  final String title;
  final String subtitle;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: color),
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
          padding: const EdgeInsets.all(12),
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
    final queue = [
      for (final v in channel.videos)
        PlayableVideo(channelId: channel.id, video: v),
    ];
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
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100 ? 5 : (width >= 600 ? 4 : 2);
    return Scaffold(
      appBar: AppBar(
        title: Text(channel.title),
        backgroundColor: const Color(0xFFE3F2FD),
        foregroundColor: const Color(0xFF0D47A1),
      ),
      body: channel.videos.isEmpty
          ? const Center(child: Text('No videos yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 16 / 12,
              ),
              itemCount: channel.videos.length,
              itemBuilder: (context, index) {
                final video = channel.videos[index];
                return FocusTile(
                  autofocus: index == 0,
                  onActivated: () => _play(context, index),
                  child: _ColoredCard(
                    color: Color(channel.color),
                    title: video.title,
                    subtitle: channel.title,
                    imageUrl: video.youtubeThumbnail,
                  ),
                );
              },
            ),
    );
  }
}
