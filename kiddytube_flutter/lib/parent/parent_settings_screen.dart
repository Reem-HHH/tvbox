import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../ui/focus_tile.dart';
import '../ui/tv_text_dialog.dart';
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
    _tabs.addListener(_onTabChanged);
    _reload();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
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
                      // Keep inactive tabs out of D-pad traversal (TV).
                      ExcludeFocus(
                        excluding: _tabs.index != 0,
                        child: _ChannelsTab(
                          settings: settings,
                          repository: widget.repository,
                          isTablet: isTablet,
                          sessionOk: _sessionOk,
                          onChanged: _reload,
                          toast: _toast,
                        ),
                      ),
                      ExcludeFocus(
                        excluding: _tabs.index != 1,
                        child: _SecurityTab(
                          settings: settings,
                          repository: widget.repository,
                          sessionOk: _sessionOk,
                          onChanged: _reload,
                          toast: _toast,
                        ),
                      ),
                      ExcludeFocus(
                        excluding: _tabs.index != 2,
                        child: _HomeSyncTab(
                          settings: settings,
                          repository: widget.repository,
                          sessionOk: _sessionOk,
                          onChanged: _reload,
                          toast: _toast,
                        ),
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
      builder: (ctx) => TvTextDialog(
        title: const Text('Change PIN'),
        submitLabel: 'Save',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, fieldFocus, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: fieldFocus,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
            ],
            decoration: const InputDecoration(
              hintText: 'New 4–8 digit PIN (not 2580)',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Save, or Select to submit',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
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
  CloudLinkStatus? _cloud;

  @override
  void initState() {
    super.initState();
    _reloadCloud();
  }

  Future<void> _reloadCloud() async {
    final status = await widget.repository.cloudStatus();
    if (!mounted) return;
    setState(() => _cloud = status);
  }

  Future<void> _editApiKey() async {
    if (!widget.sessionOk()) return;
    final controller =
        TextEditingController(text: widget.settings.youtubeApiKey ?? '');
    var cleared = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('YouTube API key'),
        submitLabel: 'Save',
        secondaryLabel: 'Clear',
        onCancel: () => Navigator.pop(ctx, false),
        onSecondary: () {
          cleared = true;
          Navigator.pop(ctx, true);
        },
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, fieldFocus, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: fieldFocus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'AIza… (stored securely)',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Save',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
      ),
    );
    if (ok != true) return;
    if (cleared) {
      await widget.repository.setYoutubeApiKey(null);
    } else {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        await widget.repository.setYoutubeApiKey(value);
      }
    }
    await widget.onChanged();
    widget.toast(cleared ? 'API key cleared' : 'API key saved');
  }

  Future<void> _editCloudUrl() async {
    if (!widget.sessionOk()) return;
    final current = _cloud?.baseUrl ?? '';
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('Cloud server URL'),
        submitLabel: 'Save',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, fieldFocus, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: fieldFocus,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:8787',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Save · Mac on same Wi‑Fi',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.setCloudBaseUrl(controller.text);
      await _reloadCloud();
      widget.toast('Cloud URL saved');
    } catch (e) {
      widget.toast('$e');
    }
  }

  Future<void> _pairDevice() async {
    if (!widget.sessionOk()) return;
    final codeController = TextEditingController();
    final nameController = TextEditingController(
      text: _cloud?.deviceName.isNotEmpty == true
          ? _cloud!.deviceName
          : 'Living room',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('Pair this device'),
        submitLabel: 'Pair',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, fieldFocus, submitFromField) {
          final codeFocus = FocusNode(
            onKeyEvent: (node, event) => handleTvTextFieldKeys(
              event,
              moveNext: () => fieldFocus.requestFocus(),
              onSubmit: () => fieldFocus.requestFocus(),
            ),
          );
          return _DisposableFocusColumn(
            focusNodes: [codeFocus],
            children: [
              TextField(
                controller: codeController,
                focusNode: codeFocus,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  hintText: 'From cloud admin → Devices',
                  border: OutlineInputBorder(),
                  helperText: 'Down → device name',
                ),
                onSubmitted: (_) => fieldFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                focusNode: fieldFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  border: OutlineInputBorder(),
                  helperText: 'Press Down for Pair',
                ),
                onSubmitted: (_) => submitFromField(),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final summary = await widget.repository.pairWithCloud(
        code: codeController.text.trim(),
        deviceName: nameController.text.trim(),
      );
      await _reloadCloud();
      widget.toast(summary);
    } catch (e) {
      widget.toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pullCloud() async {
    if (!widget.sessionOk()) return;
    setState(() => _busy = true);
    try {
      final summary = await widget.repository.pullCloudCatalog(force: true);
      await widget.onChanged();
      await _reloadCloud();
      widget.toast(summary);
    } catch (e) {
      widget.toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair() async {
    if (!widget.sessionOk()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair this device?'),
        content: const Text(
          'Removes the local cloud token. Revoke it in the admin UI too if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.unpairCloud();
    await _reloadCloud();
    widget.toast('Device unpaired');
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
    final cloud = _cloud;
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
          'Cloud family catalog',
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
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Cloud server URL'),
                subtitle: Text(
                  cloud == null
                      ? '…'
                      : (cloud.baseUrl.isEmpty
                          ? 'Not set — e.g. http://192.168.x.x:8787'
                          : cloud.baseUrl),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _editCloudUrl,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phonelink_setup_outlined),
                title: Text(cloud?.paired == true ? 'Re-pair device' : 'Pair device'),
                subtitle: Text(
                  cloud?.paired == true
                      ? 'Paired as ${cloud!.deviceName.isEmpty ? 'device' : cloud.deviceName}'
                          '${cloud.tokenPrefix.isEmpty ? '' : ' · ${cloud.tokenPrefix}…'}'
                      : 'Enter the 6-digit code from the web admin',
                ),
                onTap: _busy ? null : _pairDevice,
              ),
              const Divider(height: 1),
              ListTile(
                leading: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                title: const Text('Pull catalog from cloud'),
                subtitle: Text(
                  cloud?.paired != true
                      ? 'Pair first'
                      : cloud!.lastCloudSyncMs == 0
                          ? 'Never pulled'
                          : 'Last pull ${_formatRelative(cloud.lastCloudSyncMs)}'
                              '${cloud.lastRevision == null ? '' : ' · rev ${cloud.lastRevision}'}',
                ),
                onTap: _busy || cloud?.paired != true ? null : _pullCloud,
              ),
              if (cloud?.paired == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link_off_outlined),
                  title: const Text('Unpair this device'),
                  onTap: _busy ? null : _unpair,
                ),
              ],
            ],
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

  String _formatRelative(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
      // TextField eats ArrowDown for caret movement; move to the channel list.
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
              helperText: 'Press Down to browse channels',
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
        fieldBuilder: (context, fieldFocus, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: fieldFocus,
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
      toast('$e');
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
        fieldBuilder: (context, fieldFocus, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: fieldFocus,
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
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, fieldFocus, submitFromField) {
          final titleFocus = FocusNode(
            onKeyEvent: (node, event) => handleTvTextFieldKeys(
              event,
              moveNext: () => fieldFocus.requestFocus(),
              onSubmit: () => fieldFocus.requestFocus(),
            ),
          );
          return _DisposableFocusColumn(
            focusNodes: [titleFocus],
            children: [
              TextField(
                controller: title,
                focusNode: titleFocus,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  helperText: 'Down → URL',
                ),
                onSubmitted: (_) => fieldFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                focusNode: fieldFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'HTTPS URL (.mp4 / .m3u8 / .mpd)',
                  border: OutlineInputBorder(),
                  helperText: 'Press Down for Add',
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
          subtitle: const Text('Default for this channel’s videos'),
          value: channel.defaultAllowSeek,
          onChanged: channel.enabled ? _toggleSeek : null,
        ),
        ListTile(
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

/// Owns extra [FocusNode]s created inside dialog builders so they are disposed.
class _DisposableFocusColumn extends StatefulWidget {
  const _DisposableFocusColumn({
    required this.focusNodes,
    required this.children,
  });

  final List<FocusNode> focusNodes;
  final List<Widget> children;

  @override
  State<_DisposableFocusColumn> createState() => _DisposableFocusColumnState();
}

class _DisposableFocusColumnState extends State<_DisposableFocusColumn> {
  @override
  void dispose() {
    for (final node in widget.focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.children,
    );
  }
}
