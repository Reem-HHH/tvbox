import 'package:flutter/material.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/home_library.dart';
import '../catalog/models.dart';
import 'focus_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CatalogSettings? _settings;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final settings = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _toggleMode() async {
    final current = _settings;
    if (current == null) return;
    final next = current.homeLibraryMode == HomeLibraryMode.channels
        ? HomeLibraryMode.mixVideos
        : HomeLibraryMode.channels;
    await widget.repository.setHomeLibraryMode(next);
    await _reload();
  }

  void _openChannel(ContentChannel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LibraryScreen(channel: channel),
      ),
    );
  }

  void _openVideo(PlayableVideo item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player coming soon: ${item.video.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
    final isTvWide = width >= 900;
    final crossAxisCount = isMix
        ? (isTvWide ? 4 : (width >= 600 ? 3 : 2))
        : (isTvWide ? 3 : (width >= 600 ? 4 : 2));

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
                  ],
                ),
              ),
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
  });

  final List<ContentChannel> channels;
  final int crossAxisCount;
  final ValueChanged<ContentChannel> onOpen;

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
          autofocus: index == 0,
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
  const LibraryScreen({super.key, required this.channel});

  final ContentChannel channel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
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
                  onActivated: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Player coming soon: ${video.title}')),
                    );
                  },
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
