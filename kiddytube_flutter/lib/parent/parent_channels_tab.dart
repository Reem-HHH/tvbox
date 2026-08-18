part of 'parent_settings_screen.dart';

class _ChannelsTab extends StatefulWidget {
  const _ChannelsTab({
    required this.settings,
    required this.repository,
    required this.useSplitPane,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final bool useSplitPane;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  final _search = TextEditingController();
  late final FocusNode _searchFocus = FocusNode(onKeyEvent: _onSearchKey);
  final FocusNode _firstChannelFocus = FocusNode();
  String? _selectedId;

  @override
  void dispose() {
    _searchFocus.dispose();
    _firstChannelFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      if (_firstChannelFocus.canRequestFocus) {
        _firstChannelFocus.requestFocus();
      } else {
        FocusScope.of(context).nextFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
    if (widget.useSplitPane) {
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
              searchFocus: _searchFocus,
              firstChannelFocus: _firstChannelFocus,
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
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              if (_firstChannelFocus.canRequestFocus) {
                _firstChannelFocus.requestFocus();
              } else {
                FocusScope.of(context).nextFocus();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search channels',
              helperText: '↓ browse · Select to expand',
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
                key: ValueKey('channel-card-${ch.id}'),
                channel: ch,
                repository: widget.repository,
                sessionOk: widget.sessionOk,
                onChanged: widget.onChanged,
                toast: widget.toast,
                focusNode: index == 0 ? _firstChannelFocus : null,
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
    required this.searchFocus,
    required this.firstChannelFocus,
    required this.selectedId,
    required this.onSearch,
    required this.onSelect,
  });

  final List<ContentChannel> channels;
  final TextEditingController search;
  final FocusNode searchFocus;
  final FocusNode firstChannelFocus;
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
            focusNode: searchFocus,
            onChanged: (_) => onSearch(),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              if (firstChannelFocus.canRequestFocus) {
                firstChannelFocus.requestFocus();
              } else {
                FocusScope.of(context).nextFocus();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search',
              helperText: 'Down → channels',
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
              return FocusTile(
                focusNode: index == 0 ? firstChannelFocus : null,
                onActivated: () => onSelect(ch.id),
                child: ListTile(
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelExpansionCard extends StatefulWidget {
  const _ChannelExpansionCard({
    super.key,
    required this.channel,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
    this.focusNode,
  });

  final ContentChannel channel;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;
  final FocusNode? focusNode;

  @override
  State<_ChannelExpansionCard> createState() => _ChannelExpansionCardState();
}

class _ChannelExpansionCardState extends State<_ChannelExpansionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusTile(
            focusNode: widget.focusNode,
            onActivated: () => setState(() => _expanded = !_expanded),
            child: ListTile(
              title: Text(channel.title),
              subtitle: Text(
                '${channel.enabled ? 'On' : 'Off'} · ${channel.videos.length} videos'
                '${channel.followUploads ? ' · Follow' : ''}',
              ),
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ),
          if (_expanded)
            _ChannelDetailPane(
              channel: channel,
              repository: widget.repository,
              sessionOk: widget.sessionOk,
              onChanged: widget.onChanged,
              toast: widget.toast,
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

  Future<void> _editPlaylist(BuildContext context) async {
    if (!sessionOk()) return;
    final controller = TextEditingController(
      text: channel.youtubePlaylistId ?? '',
    );
    var cleared = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('Playlist ID'),
        submitLabel: 'Save',
        secondaryLabel: 'Clear',
        onCancel: () => Navigator.pop(ctx, false),
        onSecondary: () {
          cleared = true;
          Navigator.pop(ctx, true);
        },
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, focuses, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: focuses.first,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'PL… or YouTube playlist URL',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Save',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
      ),
    );
    if (result != true) return;
    final value = cleared ? '' : controller.text.trim();
    try {
      await repository.setPlaylistId(
        channel.id,
        value.isEmpty ? null : value,
      );
      await onChanged();
      toast(value.isEmpty ? 'Playlist cleared' : 'Playlist updated');
    } catch (e) {
      toast(friendlyParentError(e));
    }
  }

  Future<void> _toggleVideoSeek(VideoItem video, bool value) async {
    if (!sessionOk()) return;
    await repository.setVideoAllowSeek(channel.id, video.id, value);
    await onChanged();
  }

  Future<void> _addYoutube(BuildContext context) async {
    if (!sessionOk()) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('Add YouTube videos'),
        submitLabel: 'Add',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, focuses, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: focuses.first,
            autofocus: true,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText:
                  'Paste video IDs or YouTube URLs\n(one or comma-separated)',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Add',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
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
      builder: (ctx) => TvTextDialog(
        title: const Text('Add direct media'),
        submitLabel: 'Add',
        fieldCount: 2,
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, focuses, submitFromField) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: title,
                focusNode: focuses[0],
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  helperText: 'Down → URL · Up to go back',
                ),
                onSubmitted: (_) => focuses[1].requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                focusNode: focuses[1],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'HTTPS URL (.mp4 / .m3u8 / .mpd)',
                  border: OutlineInputBorder(),
                  helperText: 'Down → Cancel/Add · Up → title',
                ),
                onSubmitted: (_) => submitFromField(),
              ),
            ],
          );
        },
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
      toast(friendlyParentError(e));
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
    final controls = <Widget>[
      if (!compact)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            channel.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
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
              : 'Daily sync adds new playlist items (keeps existing)',
        ),
        value: channel.followUploads,
        onChanged: channel.youtubePlaylistId == null ||
                channel.youtubePlaylistId!.isEmpty
            ? null
            : _toggleFollow,
      ),
      SwitchListTile(
        title: const Text('Allow seek (FF/RW)'),
        subtitle: const Text('Default for this channel’s videos'),
        value: channel.defaultAllowSeek,
        onChanged: channel.enabled ? _toggleSeek : null,
      ),
      FocusTile(
        onActivated: () => _editPlaylist(context),
        child: ListTile(
          title: const Text('Playlist'),
          subtitle: Text(
            channel.youtubePlaylistId?.isNotEmpty == true
                ? channel.youtubePlaylistId!
                : 'None — Follow uploads stays off',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editPlaylist(context),
        ),
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
    ];

    Widget videoTile(VideoItem v) {
      return FocusTile(
        onActivated: () => _toggleVideoSeek(v, !v.allowSeek),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              v.allowSeek ? 'Seek on' : 'Seek off',
            ].join(' · '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: v.allowSeek ? 'Disable seek' : 'Enable seek',
                icon: Icon(
                  v.allowSeek
                      ? Icons.fast_forward
                      : Icons.fast_forward_outlined,
                ),
                onPressed: () => _toggleVideoSeek(v, !v.allowSeek),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteVideo(context, v),
              ),
            ],
          ),
        ),
      );
    }

    final videos = channel.videos;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controls,
          if (videos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No videos in this channel yet.'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) => videoTile(videos[index]),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: controls.length + (videos.isEmpty ? 1 : videos.length),
      itemBuilder: (context, index) {
        if (index < controls.length) return controls[index];
        if (videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No videos in this channel yet.'),
          );
        }
        return videoTile(videos[index - controls.length]);
      },
    );
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
                memCacheWidth: 128,
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
