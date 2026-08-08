import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import 'youtube_iframe.dart';

/// Fullscreen-ish player with YouTube iframe (kid chrome) or direct HTTPS media.
/// On end: autoplay next in the same channel queue; else pop.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.repository,
    required this.queue,
    this.startIndex = 0,
    this.startPositionMs = 0,
  });

  final CatalogRepository repository;
  final List<PlayableVideo> queue;
  final int startIndex;
  final int startPositionMs;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _index;
  WebViewController? _webController;
  VideoPlayerController? _videoController;
  String? _error;
  bool _loading = true;

  PlayableVideo get _current => widget.queue[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.queue.length - 1);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadCurrent(startMs: widget.startPositionMs);
  }

  @override
  void dispose() {
    _disposePlayers();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _disposePlayers() {
    _webController = null;
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
  }

  Future<void> _loadCurrent({int startMs = 0}) async {
    _disposePlayers();
    setState(() {
      _loading = true;
      _error = null;
    });

    final item = _current;
    await widget.repository.recentWatch.record(
      channelId: item.channelId,
      video: item.video,
      positionMs: startMs,
    );

    if (item.video.isDirect) {
      await _playDirect(item.video.directUrl!, startMs: startMs);
    } else if (item.video.isYoutube) {
      await _playYoutube(item.video.youtubeVideoId!, startMs: startMs);
    } else {
      setState(() {
        _loading = false;
        _error = 'No playable source for ${item.video.title}';
      });
    }
  }

  Future<void> _playYoutube(String videoId, {int startMs = 0}) async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'KiddyNative',
        onMessageReceived: (message) {
          final data = message.message;
          if (data == 'ended') {
            _onEnded();
          } else if (data.startsWith('error')) {
            if (!mounted) return;
            setState(() {
              _error = 'Playback error';
              _loading = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final host = Uri.tryParse(request.url)?.host ?? '';
            if (_isAllowedYoutubeHost(host) ||
                request.url.startsWith('data:') ||
                request.url.startsWith('about:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    }

    final html = youtubeIframeHtml(
      videoId: videoId,
      startSec: startMs / 1000.0,
    );
    await controller.loadHtmlString(
      html,
      baseUrl: 'https://www.youtube-nocookie.com',
    );

    if (!mounted) return;
    setState(() {
      _webController = controller;
      _loading = false;
    });
  }

  Future<void> _playDirect(String url, {int startMs = 0}) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (startMs > 0) {
        await controller.seekTo(Duration(milliseconds: startMs));
      }
      controller.addListener(_onVideoTick);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _loading = false;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _error = 'Could not play media';
        _loading = false;
      });
    }
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null) return;
    if (c.value.isInitialized &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      c.removeListener(_onVideoTick);
      _onEnded();
    }
  }

  void _onEnded() {
    if (!mounted) return;
    if (_index + 1 < widget.queue.length) {
      setState(() => _index += 1);
      _loadCurrent();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  static bool _isAllowedYoutubeHost(String host) {
    final h = host.toLowerCase();
    return h == 'youtube.com' ||
        h == 'www.youtube.com' ||
        h == 'm.youtube.com' ||
        h == 'youtube-nocookie.com' ||
        h == 'www.youtube-nocookie.com' ||
        h.endsWith('.youtube.com') ||
        h.endsWith('.youtube-nocookie.com') ||
        h.endsWith('.googlevideo.com') ||
        h == 'i.ytimg.com' ||
        h.endsWith('.ytimg.com') ||
        h == 'www.youtube.com' ||
        h.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final title = _current.video.title;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_webController != null)
              WebViewWidget(controller: _webController!)
            else if (_videoController != null &&
                _videoController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio == 0
                      ? 16 / 9
                      : _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_error != null)
              Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Focus(
                autofocus: Platform.isAndroid,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
