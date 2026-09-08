part of 'parent_settings_screen.dart';

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
        fieldBuilder: (context, focuses, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: focuses.first,
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
        fieldBuilder: (context, focuses, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: focuses.first,
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
      widget.toast(friendlyParentError(e));
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
        fieldCount: 2,
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, focuses, submitFromField) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: codeController,
                focusNode: focuses[0],
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
                  helperText: 'Down → device name · Up to go back',
                ),
                onSubmitted: (_) => focuses[1].requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                focusNode: focuses[1],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  border: OutlineInputBorder(),
                  helperText: 'Down → Cancel/Pair · Up → code',
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
      widget.toast(friendlyParentError(e));
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
      widget.toast(friendlyParentError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncWatch() async {
    if (!widget.sessionOk()) return;
    setState(() => _busy = true);
    try {
      final summary = await widget.repository.syncWatchWithCloud();
      widget.toast(summary);
    } catch (e) {
      widget.toast(friendlyParentError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair() async {
    if (!widget.sessionOk()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect this device?'),
        content: const Text(
          'Removes the local cloud token and stops auto-reconnect. '
          'Pair again (or clear opt-out by pairing) to reconnect. '
          'Revoke the device in the admin UI too if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.unpairCloud();
    await _reloadCloud();
    widget.toast('Device disconnected');
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

  Future<void> _importCatalog() async {
    if (!widget.sessionOk()) return;
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return TvTextDialog(
          title: const Text('Import catalog JSON'),
          submitLabel: 'Import',
          onCancel: () => Navigator.pop(ctx),
          onSubmit: () => Navigator.pop(ctx, controller.text),
          fieldBuilder: (context, focuses, submitFromField) {
            return TextField(
              controller: controller,
              focusNode: focuses.first,
              autofocus: true,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste exported catalog JSON',
              ),
              onSubmitted: (_) => submitFromField(),
            );
          },
        );
      },
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) {
        throw const FormatException('JSON root must be an object');
      }
      final summary = await widget.repository.applyCatalogPayload(
        Map<String, dynamic>.from(decoded),
      );
      await widget.onChanged();
      widget.toast(summary);
    } catch (e) {
      widget.toast(friendlyParentError(e));
    }
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
                leading: Icon(
                  cloud?.paired == true
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: cloud?.paired == true ? scheme.primary : null,
                ),
                title: Text(
                  cloud?.paired == true
                      ? 'Connected to family cloud'
                      : (cloud?.autoEnrollConfigured == true
                          ? 'Connecting to family cloud…'
                          : 'Not connected'),
                ),
                subtitle: Text(
                  cloud == null
                      ? '…'
                      : cloud.paired
                          ? '${cloud.deviceName.isEmpty ? 'Device' : cloud.deviceName}'
                              '${cloud.baseUrl.isEmpty ? '' : ' · ${cloud.baseUrl}'}'
                              '${cloud.tokenPrefix.isEmpty ? '' : ' · ${cloud.tokenPrefix}…'}'
                          : cloud.autoEnrollConfigured
                              ? 'This install auto-connects on launch. Check Wi‑Fi if this sticks.'
                              : 'Set the cloud URL and pair with a code from the admin (preferred). Auto-enroll needs CLOUD_AUTO_ENROLL=true.',
                ),
              ),
              const Divider(height: 1),
              FocusTile(
                autofocus: true,
                onActivated: () {
                  if (_busy || cloud?.paired != true) return;
                  _pullCloud();
                },
                child: ListTile(
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
                        ? (cloud?.autoEnrollConfigured == true
                            ? 'Waiting for connection'
                            : 'Connect first')
                        : cloud!.lastCloudSyncMs == 0
                            ? 'Manual only — tap to download the cloud catalog'
                            : 'Manual only · last pull ${_formatRelative(cloud.lastCloudSyncMs)}'
                                '${cloud.lastRevision == null ? '' : ' · rev ${cloud.lastRevision}'}',
                  ),
                  onTap: () {
                    if (_busy || cloud?.paired != true) return;
                    _pullCloud();
                  },
                ),
              ),
              const Divider(height: 1),
              FocusTile(
                onActivated: () {
                  if (_busy || cloud?.paired != true) return;
                  _syncWatch();
                },
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Sync watch history'),
                  subtitle: Text(
                    cloud?.paired != true
                        ? 'Connect first'
                        : 'Manual only — upload Continue Watching to the cloud',
                  ),
                  onTap: () {
                    if (_busy || cloud?.paired != true) return;
                    _syncWatch();
                  },
                ),
              ),
              if (cloud?.paired == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link_off_outlined),
                  title: const Text('Disconnect this device'),
                  subtitle: const Text(
                    'Clears the local token and disables auto-enroll until you pair again.',
                  ),
                  onTap: () {
                    if (_busy) return;
                    _unpair();
                  },
                ),
              ],
              if (cloud?.autoEnrollConfigured != true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Cloud server URL'),
                  subtitle: Text(
                    cloud == null
                        ? '…'
                        : (cloud.baseUrl.isEmpty
                            ? 'Not set — e.g. https://….onrender.com'
                            : cloud.baseUrl),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_busy) return;
                    _editCloudUrl();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phonelink_setup_outlined),
                  title: Text(
                    cloud?.paired == true ? 'Re-pair device' : 'Pair device',
                  ),
                  subtitle: Text(
                    cloud?.paired == true
                        ? 'Paired as ${cloud!.deviceName.isEmpty ? 'device' : cloud.deviceName}'
                        : 'Enter the 6-digit code from the web admin',
                  ),
                  onTap: () {
                    if (_busy) return;
                    _pairDevice();
                  },
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
              FocusTile(
                onActivated: _editApiKey,
                child: ListTile(
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
                  'Pull Follow-on channels (morning and night; force anytime)',
                ),
                onTap: () {
                  if (_busy) return;
                  _refreshPlaylists();
                },
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Import catalog JSON'),
                subtitle: const Text('Paste a previously exported backup'),
                onTap: _importCatalog,
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

