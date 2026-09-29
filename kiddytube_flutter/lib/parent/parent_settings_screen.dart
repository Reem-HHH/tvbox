import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../ui/focus_tile.dart';
import '../ui/friendly_message.dart';
import '../ui/layout_metrics.dart';
import '../ui/tv_text_dialog.dart';
import 'parent_biometrics.dart';
import 'parent_pin.dart';
import 'parent_session.dart';

part 'parent_security_tab.dart';
part 'parent_home_sync_tab.dart';
part 'parent_channels_tab.dart';

class _ParentTabStepIntent extends Intent {
  const _ParentTabStepIntent(this.delta);
  final int delta;
}

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
  Timer? _sessionWatch;
  final FocusNode _railFocus = FocusNode(debugLabel: 'parent_rail');

  static const _tabLabels = ['Channels', 'Security', 'Home & Sync'];
  static const _tabIcons = [
    Icons.video_library_outlined,
    Icons.lock_outline,
    Icons.cloud_sync_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _sessionWatch = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      if (ParentSession.isActive()) return;
      ParentSession.clear();
      Navigator.of(context).maybePop();
    });
    _reload();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    ParentSession.touch();
    setState(() {});
    // Move D-pad focus into the newly visible tab body (not stuck on the chip).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).focusInDirection(TraversalDirection.down);
    });
  }

  void _selectTab(int index) {
    final next = index.clamp(0, _tabs.length - 1);
    if (next == _tabs.index) return;
    _tabs.animateTo(next);
  }

  @override
  void dispose() {
    _sessionWatch?.cancel();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _railFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final settings = await widget.repository.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  bool _sessionOk() {
    if (ParentSession.isActive()) {
      ParentSession.touch();
      return true;
    }
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

  Widget _tabBody({
    required CatalogSettings settings,
    required bool useSplitChannels,
  }) {
    return IndexedStack(
      index: _tabs.index,
      sizing: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _tabs.index != 0,
          child: _ChannelsTab(
            settings: settings,
            repository: widget.repository,
            useSplitPane: useSplitChannels,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final layout = LayoutMetrics.of(context);
    final isWide = layout.isTablet || layout.isTvLike;
    final isTv = layout.isTvLike;
    final scheme = Theme.of(context).colorScheme;

    final lockAction = TextButton(
      onPressed: () {
        ParentSession.clear();
        Navigator.of(context).pop();
      },
      child: const Text('Lock'),
    );

    final content = settings == null
        ? const Center(child: CircularProgressIndicator())
        : ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1100 : double.infinity,
                ),
                child: _tabBody(
                  settings: settings,
                  useSplitChannels: isWide,
                ),
              ),
            ),
          );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.channelUp):
            const _ParentTabStepIntent(-1),
        const SingleActivator(LogicalKeyboardKey.channelDown):
            const _ParentTabStepIntent(1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ParentTabStepIntent: CallbackAction<_ParentTabStepIntent>(
            onInvoke: (intent) {
              _selectTab(_tabs.index + intent.delta);
              return null;
            },
          ),
        },
        child: isTv
            ? Scaffold(
                body: Row(
                  children: [
                    Material(
                      color: scheme.surfaceContainerLow,
                      child: SafeArea(
                        child: SizedBox(
                          width: 220,
                          child: Focus(
                            focusNode: _railFocus,
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown) {
                                _selectTab(_tabs.index + 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                _selectTab(_tabs.index - 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight) {
                                FocusScope.of(context)
                                    .focusInDirection(TraversalDirection.right);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    20,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      FocusTile(
                                        onActivated: () =>
                                            Navigator.of(context).maybePop(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.arrow_back),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Parent',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: Text(
                                    '↑↓ tabs · → browse',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                for (var i = 0; i < _tabLabels.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    child: FocusTile(
                                      autofocus: i == 0,
                                      onActivated: () => _selectTab(i),
                                      child: ListTile(
                                        selected: _tabs.index == i,
                                        selectedTileColor:
                                            scheme.primaryContainer,
                                        leading: Icon(_tabIcons[i]),
                                        title: Text(_tabLabels[i]),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: FocusTile(
                                    onActivated: () {
                                      ParentSession.clear();
                                      Navigator.of(context).pop();
                                    },
                                    child: const ListTile(
                                      leading: Icon(Icons.lock),
                                      title: Text('Lock'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                ),
              )
            : Scaffold(
                appBar: AppBar(
                  title: Text(
                    'Parent settings',
                    style: TextStyle(fontSize: isWide ? 22 : 18),
                  ),
                  toolbarHeight: isWide ? 64 : kToolbarHeight,
                  actions: [lockAction],
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(isWide ? 64 : 48),
                    child: TabBar(
                      controller: _tabs,
                      tabs: [
                        for (var i = 0; i < _tabLabels.length; i++)
                          Tab(
                            icon: Icon(_tabIcons[i], size: isWide ? 22 : 20),
                            text: _tabLabels[i],
                            height: isWide ? 64 : 48,
                          ),
                      ],
                    ),
                  ),
                ),
                body: content,
              ),
      ),
    );
  }
}
