import 'dart:async';
import 'dart:convert';

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

part 'parent_security_tab.dart';
part 'parent_home_sync_tab.dart';
part 'parent_channels_tab.dart';


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
  }

  @override
  void dispose() {
    _sessionWatch?.cancel();
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
