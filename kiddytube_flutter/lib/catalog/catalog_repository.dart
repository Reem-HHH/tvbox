import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parent/parent_pin.dart';
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
    this.failCount = 0,
    this.lockedUntilMs = 0,
  }) : channels = channels ?? DefaultChannels.seed();

  final List<ContentChannel> channels;
  final HomeLibraryMode homeLibraryMode;
  final int seedVersion;
  final String? youtubeApiKey;
  final String? pinSalt;
  final String? pinHash;
  final int failCount;
  final int lockedUntilMs;

  CatalogSettings copyWith({
    List<ContentChannel>? channels,
    HomeLibraryMode? homeLibraryMode,
    int? seedVersion,
    String? youtubeApiKey,
    bool clearApiKey = false,
    String? pinSalt,
    String? pinHash,
    int? failCount,
    int? lockedUntilMs,
  }) {
    return CatalogSettings(
      channels: channels ?? this.channels,
      homeLibraryMode: homeLibraryMode ?? this.homeLibraryMode,
      seedVersion: seedVersion ?? this.seedVersion,
      youtubeApiKey: clearApiKey ? null : (youtubeApiKey ?? this.youtubeApiKey),
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      failCount: failCount ?? this.failCount,
      lockedUntilMs: lockedUntilMs ?? this.lockedUntilMs,
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

    final settings = CatalogSettings(
      channels: channels,
      homeLibraryMode: mode,
      seedVersion: DefaultChannels.seedVersion,
      youtubeApiKey: apiKey,
      pinSalt: pinSalt,
      pinHash: pinHash,
      failCount: _prefs!.getInt(_failCountKey) ?? 0,
      lockedUntilMs: _prefs!.getInt(_lockedUntilKey) ?? 0,
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
    final next = transform(current);
    await _persistChannels(next.channels);
    await _ensurePrefs();
    await _prefs!.setString(_modeKey, next.homeLibraryMode.storageName);
    await _prefs!.setInt(_seedKey, next.seedVersion);
    await _persistLockout(next.failCount, next.lockedUntilMs);
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
    await update((s) => s.copyWith(pinSalt: salt, pinHash: hash));
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

  /// Refresh all playlist-backed channels. Returns a human-readable summary.
  Future<String> refreshAllPlaylists() async {
    final settings = await load();
    final apiKey = settings.youtubeApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return 'Add a YouTube Data API key in Parent settings first.';
    }

    var updated = 0;
    var skipped = 0;
    final errors = <String>[];
    final channels = [...settings.channels];

    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final playlistId = ch.youtubePlaylistId?.trim();
      if (playlistId == null || playlistId.isEmpty) {
        skipped++;
        continue;
      }
      if (!ch.enabled && !ch.followUploads) {
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
        // Keep manual entries, replace synced YouTube list.
        final manuals = ch.videos.where((v) => v.manual).toList();
        channels[i] = ch.copyWith(videos: [...videos, ...manuals]);
        updated++;
      } catch (e) {
        errors.add('${ch.title}: $e');
      }
    }

    await update((s) => s.copyWith(channels: channels));
    if (errors.isNotEmpty) {
      return 'Updated $updated playlists; ${errors.length} failed.\n'
          '${errors.take(3).join('\n')}';
    }
    return 'Updated $updated playlists ($skipped skipped).';
  }
}
