import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import 'parent_pin.dart';
import 'parent_session.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen>
    with SingleTickerProviderStateMixin {
  CatalogSettings? _settings;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final settings = await widget.repository.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  bool _sessionOk() {
    if (ParentSession.isActive()) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parent session expired. Unlock again.')),
    );
    Navigator.of(context).maybePop();
    return false;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parent settings',
          style: TextStyle(fontSize: isTablet ? 22 : 18),
        ),
        toolbarHeight: isTablet ? 64 : kToolbarHeight,
        actions: [
          TextButton(
            onPressed: () {
              ParentSession.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Lock'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Channels'),
            Tab(text: 'Security'),
            Tab(text: 'Home & Sync'),
          ],
        ),
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ColoredBox(
              color: scheme.surfaceContainerLowest,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 960 : double.infinity,
                  ),
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ChannelsTab(
                        settings: settings,
                        repository: widget.repository,
                        isTablet: isTablet,
                        sessionOk: _sessionOk,
                        onChanged: _reload,
                        toast: _toast,
                      ),
                      _SecurityTab(
                        settings: settings,
                        repository: widget.repository,
                        sessionOk: _sessionOk,
                        onChanged: _reload,
                        toast: _toast,
                      ),
                      _HomeSyncTab(
                        settings: settings,
                        repository: widget.repository,
                        sessionOk: _sessionOk,
                        onChanged: _reload,
                        toast: _toast,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

typedef _SessionCheck = bool Function();
typedef _Toast = void Function(String message);

class _SecurityTab extends StatelessWidget {
  const _SecurityTab({
    required this.settings,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  Future<void> _changePin(BuildContext context) async {
    if (!sessionOk()) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
          ],
          decoration: const InputDecoration(
            hintText: 'New 4–8 digit PIN (not 2580)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repository.changePin(controller.text.trim());
      await onChanged();
      toast('PIN updated');
    } catch (e) {
      toast('$e');
    }
  }

  Future<void> _toggleReleaseReady(bool value) async {
    if (!sessionOk()) return;
    try {
      await repository.setReleaseReady(value);
      await onChanged();
      toast(value ? 'Release ready on' : 'Release ready off');
    } catch (e) {
      toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Keep the kids area locked. Change the default PIN before shipping.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('Change PIN'),
                subtitle: Text(
                  settings.pinChangedFromDefault
                      ? 'Custom PIN set'
                      : 'Default dev PIN is 2580 until changed',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _changePin(context),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.verified_user_outlined),
                title: const Text('Release ready'),
                subtitle: Text(
                  settings.pinChangedFromDefault
                      ? 'Reject factory PIN after unlock'
                      : 'Change PIN first',
                ),
                value: settings.releaseReady,
                onChanged:
                    settings.pinChangedFromDefault ? _toggleReleaseReady : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSyncTab extends StatefulWidget {
  const _HomeSyncTab({
    required this.settings,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  @override
  State<_HomeSyncTab> createState() => _HomeSyncTabState();
}

class _HomeSyncTabState extends State<_HomeSyncTab> {
  bool _busy = false;

  Future<void> _editApiKey() async {
    if (!widget.sessionOk()) return;
    final controller =
        TextEditingController(text: widget.settings.youtubeApiKey ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('YouTube API key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'AIza… (stored securely)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.repository.setYoutubeApiKey(null);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      await widget.repository.setYoutubeApiKey(value);
    }
    await widget.onChanged();
    widget.toast('API key saved');
  }

  Future<void> _refreshPlaylists() async {
    if (!widget.sessionOk()) return;
    setState(() => _busy = true);
    final summary =
        await widget.repository.refreshAllPlaylists(force: true);
    await widget.onChanged();
    if (!mounted) return;
    setState(() => _busy = false);
    widget.toast(summary);
  }

  Future<void> _clearContinue() async {
    if (!widget.sessionOk()) return;
    await widget.repository.recentWatch.clear();
    widget.toast('Continue watching cleared');
  }

  Future<void> _exportCatalog() async {
    if (!widget.sessionOk()) return;
    final json = widget.repository.exportJson();
    await SharePlus.instance.share(
      ShareParams(text: json, subject: 'KiddyTube catalog'),
    );
  }

  Future<void> _setHomeMode(HomeLibraryMode mode) async {
    if (!widget.sessionOk()) return;
    await widget.repository.setHomeLibraryMode(mode);
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Home',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kids home layout',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<HomeLibraryMode>(
                  segments: const [
                    ButtonSegment(
                      value: HomeLibraryMode.channels,
                      label: Text('Shows'),
                      icon: Icon(Icons.grid_view_rounded),
                    ),
                    ButtonSegment(
                      value: HomeLibraryMode.mixVideos,
                      label: Text('Mix'),
                      icon: Icon(Icons.shuffle_rounded),
                    ),
                  ],
                  selected: {settings.homeLibraryMode},
                  onSelectionChanged: (s) => _setHomeMode(s.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Sync',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('YouTube API key'),
                subtitle: Text(
                  (settings.youtubeApiKey?.isNotEmpty ?? false)
                      ? 'Saved (hidden)'
                      : 'Not set — needed for playlist refresh',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editApiKey,
              ),
              const Divider(height: 1),
              ListTile(
                leading: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
                title: const Text('Refresh playlists'),
                subtitle: const Text(
                  'Pull Follow-on channels (up to once forced)',
                ),
                onTap: _busy ? null : _refreshPlaylists,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Clear continue watching'),
                onTap: _clearContinue,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Export / share catalog JSON'),
                onTap: _exportCatalog,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelsTab extends StatefulWidget {
  const _ChannelsTab({
    required this.settings,
    required this.repository,
    required this.isTablet,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final bool isTablet;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  final _search = TextEditingController();
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ContentChannel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final all = widget.settings.channels;
    if (q.isEmpty) return all;
    return all.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  ContentChannel? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in widget.settings.channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filtered;
    if (widget.isTablet) {
      final selected = _selected ?? (channels.isEmpty ? null : channels.first);
      if (selected != null && _selectedId != selected.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedId = selected.id);
        });
      }
      return Row(
        children: [
          SizedBox(
            width: 320,
            child: _ChannelListPane(
              channels: channels,
              search: _search,
              selectedId: selected?.id,
              onSearch: () => setState(() {}),
              onSelect: (id) => setState(() => _selectedId = id),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? Center(
                    child: Text(
                      'Select a channel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : _ChannelDetailPane(
                    channel: selected,
                    repository: widget.repository,
                    sessionOk: widget.sessionOk,
                    onChanged: widget.onChanged,
                    toast: widget.toast,
                  ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search channels',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final ch = channels[index];
              return _ChannelExpansionCard(
                channel: ch,
                repository: widget.repository,
                sessionOk: widget.sessionOk,
                onChanged: widget.onChanged,
                toast: widget.toast,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelListPane extends StatelessWidget {
  const _ChannelListPane({
    required this.channels,
    required this.search,
    required this.selectedId,
    required this.onSearch,
    required this.onSelect,
  });

  final List<ContentChannel> channels;
  final TextEditingController search;
  final String? selectedId;
  final VoidCallback onSearch;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: search,
            onChanged: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final ch = channels[index];
              final selected = ch.id == selectedId;
              return ListTile(
                selected: selected,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                title: Text(ch.title),
                subtitle: Text(
                  '${ch.enabled ? 'On' : 'Off'} · ${ch.videos.length} videos',
                ),
                trailing: Icon(
                  ch.enabled ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onTap: () => onSelect(ch.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelExpansionCard extends StatelessWidget {
  const _ChannelExpansionCard({
    required this.channel,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final ContentChannel channel;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(channel.title),
        subtitle: Text(
          '${channel.enabled ? 'On' : 'Off'} · ${channel.videos.length} videos'
          '${channel.followUploads ? ' · Follow' : ''}',
        ),
        children: [
          _ChannelDetailPane(
            channel: channel,
            repository: repository,
            sessionOk: sessionOk,
            onChanged: onChanged,
            toast: toast,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ChannelDetailPane extends StatelessWidget {
  const _ChannelDetailPane({
    required this.channel,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
    this.compact = false,
  });

  final ContentChannel channel;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;
  final bool compact;

  Future<void> _toggleEnabled(bool value) async {
    if (!sessionOk()) return;
    await repository.setChannelEnabled(channel.id, value);
    await onChanged();
  }

  Future<void> _toggleFollow(bool value) async {
    if (!sessionOk()) return;
    await repository.setFollowUploads(channel.id, value);
    await onChanged();
    toast(value ? 'Follow uploads on' : 'Follow uploads off');
  }

  Future<void> _toggleSeek(bool value) async {
    if (!sessionOk()) return;
    await repository.setChannelAllowSeek(channel.id, value);
    await onChanged();
  }

  Future<void> _addYoutube(BuildContext context) async {
    if (!sessionOk()) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add YouTube videos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paste video IDs or YouTube URLs\n(one or comma-separated)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final added =
        await repository.addManualVideoIds(channel.id, controller.text);
    await onChanged();
    toast(added == 0 ? 'No new videos added' : 'Added $added video(s)');
  }

  Future<void> _addDirect(BuildContext context) async {
    if (!sessionOk()) return;
    final title = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add direct media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'HTTPS URL (.mp4 / .m3u8 / .mpd)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repository.addDirectVideo(
        channel.id,
        title.text,
        url.text.trim(),
      );
      await onChanged();
      toast('Direct video added');
    } catch (e) {
      toast('$e');
    }
  }

  Future<void> _clearSynced(BuildContext context) async {
    if (!sessionOk()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear synced videos?'),
        content: Text(
          'Removes playlist-synced items from ${channel.title}. '
          'Manual and direct videos stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repository.clearSyncedVideos(channel.id);
    await onChanged();
    toast('Synced videos cleared');
  }

  Future<void> _deleteVideo(BuildContext context, VideoItem video) async {
    if (!sessionOk()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove video?'),
        content: Text(video.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repository.removeVideo(channel.id, video.id);
    await onChanged();
    toast('Video removed');
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              channel.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
        SwitchListTile(
          title: const Text('Enabled on kids home'),
          value: channel.enabled,
          onChanged: _toggleEnabled,
        ),
        SwitchListTile(
          title: const Text('Follow uploads'),
          subtitle: Text(
            channel.youtubePlaylistId == null ||
                    channel.youtubePlaylistId!.isEmpty
                ? 'No playlist linked'
                : 'Daily sync pulls new playlist items',
          ),
          value: channel.followUploads,
          onChanged: channel.youtubePlaylistId == null ||
                  channel.youtubePlaylistId!.isEmpty
              ? null
              : _toggleFollow,
        ),
        SwitchListTile(
          title: const Text('Allow seek (FF/RW)'),
          value: channel.defaultAllowSeek,
          onChanged: channel.enabled ? _toggleSeek : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _addYoutube(context),
                icon: const Icon(Icons.add),
                label: const Text('Add YouTube'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addDirect(context),
                icon: const Icon(Icons.link),
                label: const Text('Add URL'),
              ),
              OutlinedButton.icon(
                onPressed: () => _clearSynced(context),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Clear synced'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (channel.videos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No videos in this channel yet.'),
          )
        else
          ...channel.videos.map(
            (v) => ListTile(
              leading: _VideoThumb(video: v),
              title: Text(
                v.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (v.manual) 'Manual',
                  if (v.isDirect) 'Direct',
                  if (v.isYoutube && !v.manual) 'Synced',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteVideo(context, v),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );

    if (compact) return body;
    return ListView(children: [body]);
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final url = video.youtubeThumbnail;
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 40,
        child: url == null
            ? ColoredBox(
                color: color,
                child: const Icon(Icons.videocam_outlined, size: 20),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: color),
                errorWidget: (_, _, _) => ColoredBox(
                  color: color,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
      ),
    );
  }
}
