import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../catalog/recent_watch.dart';
import '../ui/app_orientations.dart';
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

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late int _index;
  WebViewController? _webController;
  VideoPlayerController? _videoController;
  String? _error;
  bool _loading = true;
  Timer? _progressTimer;
  String? _seekHint;

  bool _scrubbing = false;
  bool _scrubReady = false;
  bool _showScrubOverlay = false;
  int _pendingPosMs = 0;
  int _scrubDurationMs = 0;
  int _queuedDeltaMs = 0;
  int _scrubStartMs = 0;
  Timer? _commitTimer;
  Timer? _hideScrubTimer;
  static const _seekStepMs = 10000;
  static const _scrubFastStepMs = 30000;
  static const _scrubAccelerateAfterMs = 400;
  static const _scrubCommitIdleMs = 400;

  PlayableVideo get _current => widget.queue[_index];
  bool get _allowSeek => _current.video.allowSeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.startIndex.clamp(0, widget.queue.length - 1);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(kPlayerOrientations);
    unawaited(WakelockPlus.enable());
    _loadCurrent(startMs: widget.startPositionMs);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _commitTimer?.cancel();
    _hideScrubTimer?.cancel();
    unawaited(_persistProgress());
    _disposePlayers();
    unawaited(WakelockPlus.disable());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(kBrowseOrientations);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistProgress());
    }
    if (state == AppLifecycleState.paused) {
      unawaited(WakelockPlus.disable());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
    }
  }

  void _disposePlayers() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _commitTimer?.cancel();
    _hideScrubTimer?.cancel();
    _scrubbing = false;
    _scrubReady = false;
    _showScrubOverlay = false;
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
    await widget.repository.recordWatch(
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
    await widget.repository.recordWatch(
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

  Future<void> _scrubBy(int deltaMs, {bool commitNow = false}) async {
    if (!_allowSeek) {
      setState(() => _seekHint = 'Seek disabled for this video');
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _seekHint = null);
      });
      return;
    }
    setState(() => _seekHint = null);
    _hideScrubTimer?.cancel();
    final step = _scrubStepFor(deltaMs);
    if (!_scrubbing) {
      _scrubbing = true;
      _showScrubOverlay = true;
      _scrubReady = false;
      _queuedDeltaMs = step;
      _scrubStartMs = DateTime.now().millisecondsSinceEpoch;
      await _beginScrubSession();
      if (!mounted) return;
      _scrubReady = true;
      _applyQueuedScrubDeltas();
      setState(() {});
      if (commitNow) {
        await _commitScrub();
      } else {
        _scheduleScrubCommit();
      }
      return;
    }
    if (!_scrubReady) {
      _queuedDeltaMs += step;
    } else {
      _applyScrubDelta(step);
      setState(() {});
    }
    if (commitNow) {
      await _commitScrub();
    } else {
      _scheduleScrubCommit();
    }
  }

  int _scrubStepFor(int baseDeltaMs) {
    if (!_scrubbing) return baseDeltaMs;
    final held = DateTime.now().millisecondsSinceEpoch - _scrubStartMs;
    if (held < _scrubAccelerateAfterMs) return baseDeltaMs;
    return baseDeltaMs >= 0 ? _scrubFastStepMs : -_scrubFastStepMs;
  }

  Future<void> _beginScrubSession() async {
    final snap = await _progressSnapshot();
    _pendingPosMs = snap?.pos ?? 0;
    _scrubDurationMs = snap?.dur ?? 0;
  }

  void _applyQueuedScrubDeltas() {
    if (_queuedDeltaMs == 0) return;
    _applyScrubDelta(_queuedDeltaMs);
    _queuedDeltaMs = 0;
  }

  void _applyScrubDelta(int deltaMs) {
    final max = _scrubDurationMs > 0
        ? (_scrubDurationMs - 250).clamp(0, _scrubDurationMs)
        : 1 << 30;
    _pendingPosMs = (_pendingPosMs + deltaMs).clamp(0, max);
  }

  void _scheduleScrubCommit() {
    _commitTimer?.cancel();
    _commitTimer = Timer(
      const Duration(milliseconds: _scrubCommitIdleMs),
      () => unawaited(_commitScrub()),
    );
  }

  Future<void> _commitScrub() async {
    _commitTimer?.cancel();
    if (!_scrubbing) return;
    if (!_scrubReady) {
      _scheduleScrubCommit();
      return;
    }
    _scrubbing = false;
    _scrubReady = false;
    _queuedDeltaMs = 0;
    await _seekToAbsolute(_pendingPosMs);
    if (!mounted) return;
    setState(() => _showScrubOverlay = true);
    _hideScrubTimer?.cancel();
    _hideScrubTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_scrubbing) {
        setState(() => _showScrubOverlay = false);
      }
    });
  }

  Future<void> _seekToAbsolute(int positionMs) async {
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      final dur = video.value.duration;
      var next = Duration(milliseconds: positionMs);
      if (next < Duration.zero) next = Duration.zero;
      if (dur > Duration.zero && next > dur) next = dur;
      await video.seekTo(next);
      return;
    }
    final web = _webController;
    if (web != null) {
      final sec = positionMs / 1000.0;
      await web.runJavaScript('seekToAbs($sec)');
    }
  }

  String _formatPlayerTime(int ms) {
    final totalSec = (ms ~/ 1000).clamp(0, 24 * 3600);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool _isSeekLogicalKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.mediaTrackPrevious;
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
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const _SeekIntent(-_seekStepMs),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _SeekIntent(_seekStepMs),
        LogicalKeySet(LogicalKeyboardKey.select): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const _ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaFastForward):
            const _SeekIntent(_seekStepMs),
        LogicalKeySet(LogicalKeyboardKey.mediaRewind):
            const _SeekIntent(-_seekStepMs),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SeekIntent: CallbackAction<_SeekIntent>(
            onInvoke: (intent) {
              unawaited(_scrubBy(intent.deltaMs));
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
          onKeyEvent: (node, event) {
            if (event is KeyUpEvent &&
                _isSeekLogicalKey(event.logicalKey) &&
                _scrubbing) {
              unawaited(_commitScrub());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
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
                if (_showScrubOverlay) _buildScrubOverlay(),
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

  Widget _buildScrubOverlay() {
    final progress = _scrubDurationMs > 0
        ? (_pendingPosMs / _scrubDurationMs).clamp(0.0, 1.0)
        : 0.0;
    final posLabel = _formatPlayerTime(_pendingPosMs);
    final durLabel = _scrubDurationMs > 0
        ? _formatPlayerTime(_scrubDurationMs)
        : '--:--';
    return Positioned(
      left: 48,
      right: 48,
      bottom: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _scrubDurationMs > 0 ? progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$posLabel / $durLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
