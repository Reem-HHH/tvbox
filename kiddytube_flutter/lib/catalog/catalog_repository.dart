import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parent/parent_pin.dart';
import '../parent/release_pin_policy.dart';
import 'media_ids.dart';
import 'models.dart';
import 'recent_watch.dart';
import 'seed.dart';
import 'youtube_sync.dart';

class CatalogSettings {
  CatalogSettings({
    List<ContentChannel>? channels,
    this.homeLibraryMode = HomeLibraryMode.channels,
    this.seedVersion = 0,
    this.youtubeApiKey,
    this.pinSalt,
    this.pinHash,
    this.pinChangedFromDefault = false,
    this.releaseReady = false,
    this.failCount = 0,
    this.lockedUntilMs = 0,
    this.lastSyncMs = 0,
  }) : channels = channels ?? DefaultChannels.seed();

  final List<ContentChannel> channels;
  final HomeLibraryMode homeLibraryMode;
  final int seedVersion;
  final String? youtubeApiKey;
  final String? pinSalt;
  final String? pinHash;
  final bool pinChangedFromDefault;
  final bool releaseReady;
  final int failCount;
  final int lockedUntilMs;
  final int lastSyncMs;

  CatalogSettings copyWith({
    List<ContentChannel>? channels,
    HomeLibraryMode? homeLibraryMode,
    int? seedVersion,
    String? youtubeApiKey,
    bool clearApiKey = false,
    String? pinSalt,
    String? pinHash,
    bool? pinChangedFromDefault,
    bool? releaseReady,
    int? failCount,
    int? lockedUntilMs,
    int? lastSyncMs,
  }) {
    return CatalogSettings(
      channels: channels ?? this.channels,
      homeLibraryMode: homeLibraryMode ?? this.homeLibraryMode,
      seedVersion: seedVersion ?? this.seedVersion,
      youtubeApiKey: clearApiKey ? null : (youtubeApiKey ?? this.youtubeApiKey),
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      pinChangedFromDefault:
          pinChangedFromDefault ?? this.pinChangedFromDefault,
      releaseReady: releaseReady ?? this.releaseReady,
      failCount: failCount ?? this.failCount,
      lockedUntilMs: lockedUntilMs ?? this.lockedUntilMs,
      lastSyncMs: lastSyncMs ?? this.lastSyncMs,
    );
  }
}

abstract class SecretsStore {
  Future<String?> readApiKey();
  Future<void> writeApiKey(String? key);
  Future<String?> readPinSalt();
  Future<String?> readPinHash();
  Future<void> writePin(String? salt, String? hash);
}

class SecureSecretsStore implements SecretsStore {
  SecureSecretsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _apiKeySecure = 'youtube_api_key';
  static const _pinSalt = 'parent_pin_salt';
  static const _pinHash = 'parent_pin_hash';

  @override
  Future<String?> readApiKey() => _storage.read(key: _apiKeySecure);

  @override
  Future<void> writeApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _apiKeySecure);
    } else {
      await _storage.write(key: _apiKeySecure, value: key);
    }
  }

  @override
  Future<String?> readPinSalt() => _storage.read(key: _pinSalt);

  @override
  Future<String?> readPinHash() => _storage.read(key: _pinHash);

  @override
  Future<void> writePin(String? salt, String? hash) async {
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) {
      await _storage.delete(key: _pinSalt);
      await _storage.delete(key: _pinHash);
    } else {
      await _storage.write(key: _pinSalt, value: salt);
      await _storage.write(key: _pinHash, value: hash);
    }
  }
}

class MemorySecretsStore implements SecretsStore {
  String? _apiKey;
  String? _pinSalt;
  String? _pinHash;

  @override
  Future<String?> readApiKey() async => _apiKey;

  @override
  Future<void> writeApiKey(String? key) async {
    _apiKey = (key == null || key.isEmpty) ? null : key;
  }

  @override
  Future<String?> readPinSalt() async => _pinSalt;

  @override
  Future<String?> readPinHash() async => _pinHash;

  @override
  Future<void> writePin(String? salt, String? hash) async {
    _pinSalt = salt;
    _pinHash = hash;
  }
}

class CatalogRepository {
  CatalogRepository({
    SharedPreferences? prefs,
    SecretsStore? secrets,
    RecentWatchStore? recentWatch,
    YoutubeCatalogSource? youtube,
  })  : _prefs = prefs,
        _secrets = secrets ?? SecureSecretsStore(),
        recentWatch = recentWatch ?? RecentWatchStore(prefs),
        _youtube = youtube ?? YoutubeCatalogSource();

  SharedPreferences? _prefs;
  final SecretsStore _secrets;
  final RecentWatchStore recentWatch;
  final YoutubeCatalogSource _youtube;

  CatalogSettings? _cached;

  /// Stable for the process lifetime (mirrors Kotlin home shuffle seeds).
  final int channelShuffleSeed = DateTime.now().microsecondsSinceEpoch;
  final int videoShuffleSeed =
      DateTime.now().microsecondsSinceEpoch ^ 0x5f3759df;

  static const _modeKey = 'home_library_mode';
  static const _seedKey = 'seed_version';
  static const _catalogKey = 'catalog_channels_v1';
  static const _failCountKey = 'pin_fail_count';
  static const _lockedUntilKey = 'pin_locked_until_ms';
  static const _pinChangedKey = 'pin_changed_from_default';
  static const _releaseReadyKey = 'release_ready';
  static const _lastSyncKey = 'last_sync_ms';
  static const syncTtlMs = 24 * 60 * 60 * 1000;

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  CatalogSettings current() =>
      _cached ??
      CatalogSettings(
        channels: DefaultChannels.seed(),
        seedVersion: DefaultChannels.seedVersion,
      );

  Future<CatalogSettings> load() async {
    await _ensurePrefs();
    final mode = HomeLibraryMode.fromStored(_prefs!.getString(_modeKey));
    final storedSeed = _prefs!.getInt(_seedKey) ?? 0;
    final apiKey = await _secrets.readApiKey();
    var pinSalt = await _secrets.readPinSalt();
    var pinHash = await _secrets.readPinHash();

    if (pinSalt == null ||
        pinSalt.isEmpty ||
        pinHash == null ||
        pinHash.isEmpty) {
      pinSalt = ParentPinManager.newSaltHex();
      pinHash = ParentPinManager.hashPin(
            ParentPinManager.defaultDevPin,
            pinSalt,
          ) ??
          '';
      await _secrets.writePin(pinSalt, pinHash);
    }

    var channels = _readPersistedChannels() ?? DefaultChannels.seed();
    if (storedSeed < DefaultChannels.seedVersion) {
      channels = DefaultChannels.mergeSeedUpdates(channels);
      await _persistChannels(channels);
      await _prefs!.setInt(_seedKey, DefaultChannels.seedVersion);
    }

    final sanitized = ReleasePinPolicy.sanitizePinFlags(
      pinSalt: pinSalt,
      pinHash: pinHash,
      pinChangedFromDefault: _prefs!.getBool(_pinChangedKey) ?? false,
      releaseReady: _prefs!.getBool(_releaseReadyKey) ?? false,
    );
    if (sanitized.pinChangedFromDefault !=
            (_prefs!.getBool(_pinChangedKey) ?? false) ||
        sanitized.releaseReady != (_prefs!.getBool(_releaseReadyKey) ?? false)) {
      await _prefs!.setBool(_pinChangedKey, sanitized.pinChangedFromDefault);
      await _prefs!.setBool(_releaseReadyKey, sanitized.releaseReady);
    }

    final settings = CatalogSettings(
      channels: channels,
      homeLibraryMode: mode,
      seedVersion: DefaultChannels.seedVersion,
      youtubeApiKey: apiKey,
      pinSalt: pinSalt,
      pinHash: pinHash,
      pinChangedFromDefault: sanitized.pinChangedFromDefault,
      releaseReady: sanitized.releaseReady,
      failCount: _prefs!.getInt(_failCountKey) ?? 0,
      lockedUntilMs: _prefs!.getInt(_lockedUntilKey) ?? 0,
      lastSyncMs: _prefs!.getInt(_lastSyncKey) ?? 0,
    );
    _cached = settings;
    return settings;
  }

  List<ContentChannel>? _readPersistedChannels() {
    final raw = _prefs?.getString(_catalogKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => ContentChannel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistChannels(List<ContentChannel> channels) async {
    await _ensurePrefs();
    await _prefs!.setString(
      _catalogKey,
      jsonEncode(channels.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _persistLockout(int failCount, int lockedUntilMs) async {
    await _ensurePrefs();
    await _prefs!.setInt(_failCountKey, failCount);
    await _prefs!.setInt(_lockedUntilKey, lockedUntilMs);
  }

  Future<CatalogSettings> update(
    CatalogSettings Function(CatalogSettings) transform,
  ) async {
    final current = _cached ?? await load();
    var next = transform(current);
    final sanitized = ReleasePinPolicy.sanitizePinFlags(
      pinSalt: next.pinSalt,
      pinHash: next.pinHash,
      pinChangedFromDefault: next.pinChangedFromDefault,
      releaseReady: next.releaseReady,
    );
    next = next.copyWith(
      pinChangedFromDefault: sanitized.pinChangedFromDefault,
      releaseReady: sanitized.releaseReady,
    );
    await _persistChannels(next.channels);
    await _ensurePrefs();
    await _prefs!.setString(_modeKey, next.homeLibraryMode.storageName);
    await _prefs!.setInt(_seedKey, next.seedVersion);
    await _persistLockout(next.failCount, next.lockedUntilMs);
    await _prefs!.setBool(_pinChangedKey, next.pinChangedFromDefault);
    await _prefs!.setBool(_releaseReadyKey, next.releaseReady);
    await _prefs!.setInt(_lastSyncKey, next.lastSyncMs);
    if (next.youtubeApiKey != current.youtubeApiKey) {
      await _secrets.writeApiKey(next.youtubeApiKey);
    }
    if (next.pinSalt != current.pinSalt || next.pinHash != current.pinHash) {
      await _secrets.writePin(next.pinSalt, next.pinHash);
    }
    _cached = next;
    return next;
  }

  Future<void> setHomeLibraryMode(HomeLibraryMode mode) async {
    await update((s) => s.copyWith(homeLibraryMode: mode));
  }

  Future<void> setYoutubeApiKey(String? key) async {
    await update(
      (s) => s.copyWith(
        youtubeApiKey: key,
        clearApiKey: key == null || key.isEmpty,
      ),
    );
  }

  Future<void> setChannelEnabled(String channelId, bool enabled) async {
    await update((s) {
      final channels = s.channels
          .map((c) => c.id == channelId ? c.copyWith(enabled: enabled) : c)
          .toList();
      return s.copyWith(channels: channels);
    });
  }

  Future<void> setChannelAllowSeek(String channelId, bool allowSeek) async {
    await update((s) {
      final channels = s.channels.map((c) {
        if (c.id != channelId) return c;
        return c.copyWith(
          defaultAllowSeek: allowSeek,
          videos: [
            for (final v in c.videos) v.copyWith(allowSeek: allowSeek),
          ],
        );
      }).toList();
      return s.copyWith(channels: channels);
    });
  }

  Future<void> setFollowUploads(String channelId, bool follow) async {
    await update((s) {
      final channels = s.channels.map((c) {
        if (c.id != channelId) return c;
        return c.copyWith(
          followUploads: follow,
          playlistManagedByParent: true,
        );
      }).toList();
      return s.copyWith(channels: channels);
    });
  }

  Future<void> _updateChannel(
    String channelId,
    ContentChannel Function(ContentChannel) transform,
  ) async {
    await update((s) {
      final channels = [
        for (final c in s.channels)
          if (c.id == channelId) transform(c) else c,
      ];
      return s.copyWith(channels: channels);
    });
  }

  /// Append YouTube videos from bare ids / URLs (CSV). Marks them manual.
  Future<int> addManualVideoIds(String channelId, String csvOrUrls) async {
    final ids = MediaIds.parseVideoIdsCsv(csvOrUrls);
    if (ids.isEmpty) return 0;
    final settings = await load();
    final channel = settings.channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => throw ArgumentError('Unknown channel'),
    );
    final existing = channel.videos.map((v) => v.id).toSet();
    final newIds = ids.where((id) => !existing.contains(id)).toList();
    if (newIds.isEmpty) return 0;

    final tagged = [
      for (final id in newIds)
        VideoItem(
          id: id,
          title: 'Video $id',
          youtubeVideoId: id,
          thumbnailUrl: MediaIds.defaultThumbnail(id),
          publishedAtMs: DateTime.now().millisecondsSinceEpoch,
          manual: true,
          allowSeek: channel.defaultAllowSeek,
        ),
    ];

    await _updateChannel(channelId, (ch) {
      final merged = _newestFirst([...tagged, ...ch.videos]);
      final byId = <String, VideoItem>{};
      for (final v in merged) {
        byId.putIfAbsent(v.id, () => v);
      }
      return ch.copyWith(
        videos: byId.values.toList(),
        sourceType: SourceType.youtubeVideoList,
      );
    });
    return newIds.length;
  }

  Future<void> addDirectVideo(
    String channelId,
    String title,
    String url,
  ) async {
    if (!MediaIds.isDirectMediaUrl(url)) {
      throw ArgumentError('Invalid direct media URL (HTTPS .mp4/.m3u8/.mpd)');
    }
    final id = 'direct_${DateTime.now().millisecondsSinceEpoch}';
    await _updateChannel(channelId, (ch) {
      final item = VideoItem(
        id: id,
        title: title.trim().isEmpty ? 'Video' : title.trim(),
        directUrl: url.trim(),
        publishedAtMs: DateTime.now().millisecondsSinceEpoch,
        manual: true,
        allowSeek: ch.defaultAllowSeek,
      );
      final hasYoutube = ch.videos.any((v) => v.isYoutube);
      return ch.copyWith(
        videos: _newestFirst([item, ...ch.videos]),
        sourceType: hasYoutube ? ch.sourceType : SourceType.directUrl,
      );
    });
  }

  Future<void> removeVideo(String channelId, String videoId) async {
    await _updateChannel(channelId, (ch) {
      return ch.copyWith(
        videos: ch.videos.where((v) => v.id != videoId).toList(),
      );
    });
  }

  /// Drops synced/remote items; keeps parent-added manual and direct URLs.
  Future<void> clearSyncedVideos(String channelId) async {
    await _updateChannel(channelId, (ch) {
      return ch.copyWith(
        videos: ch.videos.where((v) => v.manual || v.isDirect).toList(),
      );
    });
  }

  static List<VideoItem> _newestFirst(List<VideoItem> items) {
    final indexed = items.asMap().entries.toList();
    indexed.sort((a, b) {
      final aMs = a.value.publishedAtMs ?? -1;
      final bMs = b.value.publishedAtMs ?? -1;
      final byDate = bMs.compareTo(aMs);
      if (byDate != 0) return byDate;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  Future<void> changePin(String newPin) async {
    if (!ParentPinManager.isValidPinFormat(newPin)) {
      throw ArgumentError('PIN must be 4–8 digits');
    }
    if (newPin == ParentPinManager.defaultDevPin) {
      throw ArgumentError('Choose a non-default PIN');
    }
    final salt = ParentPinManager.newSaltHex();
    final hash = ParentPinManager.hashPin(newPin, salt);
    if (hash == null) {
      throw StateError('Failed to hash PIN');
    }
    await update(
      (s) => s.copyWith(
        pinSalt: salt,
        pinHash: hash,
        pinChangedFromDefault: true,
      ),
    );
  }

  Future<void> setReleaseReady(bool ready) async {
    await update((s) {
      if (ready && !s.pinChangedFromDefault) {
        throw StateError('Change the default PIN first');
      }
      return s.copyWith(releaseReady: ready);
    });
  }

  Future<void> recordPinFailure(ParentPinManager pinManager) async {
    await update(
      (s) => s.copyWith(
        failCount: pinManager.failureCount,
        lockedUntilMs: pinManager.lockedUntilMs,
      ),
    );
  }

  Future<void> clearPinFailures() async {
    await update((s) => s.copyWith(failCount: 0, lockedUntilMs: 0));
  }

  String exportJson() {
    final settings = current();
    return const JsonEncoder.withIndent('  ').convert({
      'seedVersion': settings.seedVersion,
      'homeLibraryMode': settings.homeLibraryMode.storageName,
      'channels': settings.channels.map((c) => c.toJson()).toList(),
    });
  }

  /// Refresh playlist-backed channels that have Follow uploads enabled.
  /// Returns a human-readable summary.
  Future<String> refreshAllPlaylists({bool force = false}) async {
    final settings = await load();
    final apiKey = settings.youtubeApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return 'Add a YouTube Data API key in Parent settings first.';
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - settings.lastSyncMs < syncTtlMs) {
      return 'Already synced today.';
    }

    var updated = 0;
    var skipped = 0;
    final errors = <String>[];
    final channels = [...settings.channels];

    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final playlistId = ch.youtubePlaylistId?.trim();
      if (!ch.enabled ||
          playlistId == null ||
          playlistId.isEmpty ||
          !ch.followUploads) {
        skipped++;
        continue;
      }
      try {
        final videos = await _youtube.fetchPlaylistVideos(
          apiKey: apiKey,
          playlistId: playlistId,
        );
        if (videos.isEmpty) {
          skipped++;
          continue;
        }
        // Keep manual entries; preserve allowSeek for matching synced ids.
        final seekById = {
          for (final v in ch.videos) v.id: v.allowSeek,
        };
        final synced = [
          for (final v in videos)
            v.copyWith(
              allowSeek: seekById[v.id] ?? ch.defaultAllowSeek,
            ),
        ];
        final manuals = ch.videos.where((v) => v.manual).toList();
        channels[i] = ch.copyWith(videos: [...synced, ...manuals]);
        updated++;
      } catch (e) {
        errors.add('${ch.title}: $e');
      }
    }

    await update(
      (s) => s.copyWith(
        channels: channels,
        lastSyncMs: updated > 0
            ? DateTime.now().millisecondsSinceEpoch
            : s.lastSyncMs,
      ),
    );
    if (errors.isNotEmpty) {
      return 'Updated $updated playlists; ${errors.length} failed.\n'
          '${errors.take(3).join('\n')}';
    }
    return 'Updated $updated playlists ($skipped skipped).';
  }

  /// Home/launch path: sync playlists at most once per 24h when an API key exists.
  Future<bool> maybeRefreshDaily() async {
    final settings = await load();
    final apiKey = settings.youtubeApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - settings.lastSyncMs < syncTtlMs) return false;
    final summary = await refreshAllPlaylists(force: true);
    return !summary.startsWith('Already synced') &&
        !summary.startsWith('Add a YouTube');
  }
}