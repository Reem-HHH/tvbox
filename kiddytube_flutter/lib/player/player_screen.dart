import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../catalog/recent_watch.dart';
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
  Timer? _progressTimer;
  String? _seekHint;

  PlayableVideo get _current => widget.queue[_index];
  bool get _allowSeek => _current.video.allowSeek;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.queue.length - 1);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadCurrent(startMs: widget.startPositionMs);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_persistProgress());
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
    _progressTimer?.cancel();
    _progressTimer = null;
    _webController = null;
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_persistProgress()),
    );
  }

  Future<void> _persistProgress() async {
    final snap = await _progressSnapshot();
    if (snap == null) return;
    final item = _current;
    await widget.repository.recentWatch.record(
      channelId: item.channelId,
      video: item.video,
      positionMs: clampedResumePosition(snap.pos, snap.dur),
    );
  }

  Future<({int pos, int dur})?> _progressSnapshot() async {
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      return (
        pos: video.value.position.inMilliseconds,
        dur: video.value.duration.inMilliseconds,
      );
    }
    final web = _webController;
    if (web == null) return null;
    try {
      final raw = await web.runJavaScriptReturningResult('progressSnapshot()');
      var text = raw.toString().trim();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      text = text.replaceAll(r'\"', '"');
      final map = jsonDecode(text) as Map<String, dynamic>;
      return (
        pos: (map['pos'] as num?)?.toInt() ?? 0,
        dur: (map['dur'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCurrent({int startMs = 0}) async {
    await _persistProgress();
    _disposePlayers();
    setState(() {
      _loading = true;
      _error = null;
      _seekHint = null;
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
    _startProgressTimer();
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
      _startProgressTimer();
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

  Future<void> _onEnded() async {
    await _persistProgress();
    if (!mounted) return;
    if (_index + 1 < widget.queue.length) {
      setState(() => _index += 1);
      await _loadCurrent();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _seekBy(int deltaMs) async {
    if (!_allowSeek) {
      setState(() => _seekHint = 'Seek disabled for this video');
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _seekHint = null);
      });
      return;
    }
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      final next = video.value.position + Duration(milliseconds: deltaMs);
      final clamped = next < Duration.zero
          ? Duration.zero
          : (next > video.value.duration ? video.value.duration : next);
      await video.seekTo(clamped);
      return;
    }
    final web = _webController;
    if (web != null) {
      final sec = deltaMs / 1000.0;
      await web.runJavaScript('seekBy($sec)');
    }
  }

  Future<void> _togglePlayPause() async {
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      if (video.value.isPlaying) {
        await video.pause();
      } else {
        await video.play();
      }
      return;
    }
    final web = _webController;
    if (web != null) {
      await web.runJavaScript('togglePlayPause()');
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
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekIntent(-10000),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekIntent(10000),
        LogicalKeySet(LogicalKeyboardKey.select): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaFastForward):
            const _SeekIntent(10000),
        LogicalKeySet(LogicalKeyboardKey.mediaRewind): const _SeekIntent(-10000),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SeekIntent: CallbackAction<_SeekIntent>(
            onInvoke: (intent) {
              unawaited(_seekBy(intent.deltaMs));
              return null;
            },
          ),
          _ToggleIntent: CallbackAction<_ToggleIntent>(
            onInvoke: (_) {
              unawaited(_togglePlayPause());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (_webController != null)
                  WebViewWidget(controller: _webController!)
                else if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width == 0
                          ? 16
                          : _videoController!.value.size.width,
                      height: _videoController!.value.size.height == 0
                          ? 9
                          : _videoController!.value.size.height,
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
                if (_seekHint != null)
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          _seekHint!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Focus(
                          autofocus: !kIsWeb && Platform.isAndroid,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () async {
                              await _persistProgress();
                              if (context.mounted) {
                                Navigator.of(context).maybePop();
                              }
                            },
                            tooltip: 'Back',
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 8,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekIntent extends Intent {
  const _SeekIntent(this.deltaMs);
  final int deltaMs;
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}
