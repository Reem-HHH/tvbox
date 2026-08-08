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

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  CatalogSettings? _settings;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reload();
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

  Future<void> _changePin() async {
    if (!_sessionOk()) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
          ],
          decoration: const InputDecoration(
            hintText: 'New 4–8 digit PIN (not 2580)',
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
      await widget.repository.changePin(controller.text.trim());
      if (!mounted) return;
      setState(() => _status = 'PIN updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '$e');
    }
  }

  Future<void> _editApiKey() async {
    if (!_sessionOk()) return;
    final controller =
        TextEditingController(text: _settings?.youtubeApiKey ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('YouTube API key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'AIza… (stored securely)',
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
    await _reload();
    if (!mounted) return;
    setState(() => _status = 'API key saved');
  }

  Future<void> _refreshPlaylists() async {
    if (!_sessionOk()) return;
    setState(() {
      _busy = true;
      _status = 'Refreshing…';
    });
    final summary = await widget.repository.refreshAllPlaylists();
    await _reload();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = summary;
    });
  }

  Future<void> _clearContinue() async {
    if (!_sessionOk()) return;
    await widget.repository.recentWatch.clear();
    if (!mounted) return;
    setState(() => _status = 'Continue watching cleared');
  }

  Future<void> _exportCatalog() async {
    if (!_sessionOk()) return;
    final json = widget.repository.exportJson();
    await SharePlus.instance.share(
      ShareParams(text: json, subject: 'KiddyTube catalog'),
    );
  }

  Future<void> _toggleChannel(ContentChannel channel) async {
    if (!_sessionOk()) return;
    await widget.repository.setChannelEnabled(channel.id, !channel.enabled);
    await _reload();
  }

  Future<void> _toggleSeek(ContentChannel channel) async {
    if (!_sessionOk()) return;
    await widget.repository
        .setChannelAllowSeek(channel.id, !channel.defaultAllowSeek);
    await _reload();
  }

  Future<void> _toggleReleaseReady(bool value) async {
    if (!_sessionOk()) return;
    try {
      await widget.repository.setReleaseReady(value);
      await _reload();
      if (!mounted) return;
      setState(() => _status = value ? 'Release ready on' : 'Release ready off');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '$e');
    }
  }

  Future<void> _setHomeMode(HomeLibraryMode mode) async {
    if (!_sessionOk()) return;
    await widget.repository.setHomeLibraryMode(mode);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
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
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 720 : double.infinity,
                ),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 28 : 16,
                    vertical: 16,
                  ),
                  children: [
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _status!,
                          style: const TextStyle(color: Color(0xFF1565C0)),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Change PIN'),
                      subtitle: Text(
                        settings.pinChangedFromDefault
                            ? 'Custom PIN set'
                            : 'Default dev PIN is 2580 until changed',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Release ready'),
                      subtitle: Text(
                        settings.pinChangedFromDefault
                            ? 'Reject factory PIN after unlock'
                            : 'Change PIN first',
                      ),
                      value: settings.releaseReady,
                      onChanged: settings.pinChangedFromDefault
                          ? _toggleReleaseReady
                          : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('YouTube API key'),
                      subtitle: Text(
                        (settings.youtubeApiKey?.isNotEmpty ?? false)
                            ? 'Saved (hidden)'
                            : 'Not set — needed for playlist refresh',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editApiKey,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Refresh playlists'),
                      subtitle:
                          const Text('Sync YouTube playlist items (API key)'),
                      trailing: _busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onTap: _busy ? null : _refreshPlaylists,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Home mode',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<HomeLibraryMode>(
                        segments: const [
                          ButtonSegment(
                            value: HomeLibraryMode.channels,
                            label: Text('Shows'),
                          ),
                          ButtonSegment(
                            value: HomeLibraryMode.mixVideos,
                            label: Text('Mix'),
                          ),
                        ],
                        selected: {settings.homeLibraryMode},
                        onSelectionChanged: (s) => _setHomeMode(s.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Clear continue watching'),
                      trailing: const Icon(Icons.delete_outline),
                      onTap: _clearContinue,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Export / share catalog JSON'),
                      trailing: const Icon(Icons.ios_share),
                      onTap: _exportCatalog,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Channels',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...settings.channels.map(
                      (ch) => Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(ch.title),
                            subtitle: Text(
                              '${ch.enabled ? 'ON' : 'OFF'} · ${ch.videos.length} videos'
                              '${ch.youtubePlaylistId != null ? ' · playlist' : ''}',
                            ),
                            value: ch.enabled,
                            onChanged: (_) => _toggleChannel(ch),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Allow seek (FF/RW)'),
                            value: ch.defaultAllowSeek,
                            onChanged:
                                ch.enabled ? (_) => _toggleSeek(ch) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
