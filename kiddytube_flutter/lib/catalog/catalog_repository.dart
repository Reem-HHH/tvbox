import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'seed.dart';

class CatalogSettings {
  CatalogSettings({
    List<ContentChannel>? channels,
    this.homeLibraryMode = HomeLibraryMode.channels,
    this.seedVersion = 0,
    this.youtubeApiKey,
  }) : channels = channels ?? DefaultChannels.seed();

  final List<ContentChannel> channels;
  final HomeLibraryMode homeLibraryMode;
  final int seedVersion;
  final String? youtubeApiKey;

  CatalogSettings copyWith({
    List<ContentChannel>? channels,
    HomeLibraryMode? homeLibraryMode,
    int? seedVersion,
    String? youtubeApiKey,
    bool clearApiKey = false,
  }) {
    return CatalogSettings(
      channels: channels ?? this.channels,
      homeLibraryMode: homeLibraryMode ?? this.homeLibraryMode,
      seedVersion: seedVersion ?? this.seedVersion,
      youtubeApiKey: clearApiKey ? null : (youtubeApiKey ?? this.youtubeApiKey),
    );
  }
}

abstract class SecretsStore {
  Future<String?> readApiKey();
  Future<void> writeApiKey(String? key);
}

class SecureSecretsStore implements SecretsStore {
  SecureSecretsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _apiKeySecure = 'youtube_api_key';

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
}

class MemorySecretsStore implements SecretsStore {
  String? _apiKey;

  @override
  Future<String?> readApiKey() async => _apiKey;

  @override
  Future<void> writeApiKey(String? key) async {
    _apiKey = (key == null || key.isEmpty) ? null : key;
  }
}

class CatalogRepository {
  CatalogRepository({
    this._prefs,
    SecretsStore? secrets,
  }) : _secrets = secrets ?? SecureSecretsStore();

  SharedPreferences? _prefs;
  final SecretsStore _secrets;

  /// Stable for the process lifetime (mirrors Kotlin home shuffle seeds).
  final int channelShuffleSeed = DateTime.now().microsecondsSinceEpoch;
  final int videoShuffleSeed = DateTime.now().microsecondsSinceEpoch ^ 0x5f3759df;

  static const _modeKey = 'home_library_mode';
  static const _seedKey = 'seed_version';

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<CatalogSettings> load() async {
    await _ensurePrefs();
    final mode = HomeLibraryMode.fromStored(_prefs!.getString(_modeKey));
    final storedSeed = _prefs!.getInt(_seedKey) ?? 0;
    final apiKey = await _secrets.readApiKey();
    // Phase 1: always present hardcoded seed; merge upgrades later.
    final channels = DefaultChannels.seed();
    if (storedSeed < DefaultChannels.seedVersion) {
      await _prefs!.setInt(_seedKey, DefaultChannels.seedVersion);
    }
    return CatalogSettings(
      channels: channels,
      homeLibraryMode: mode,
      seedVersion: DefaultChannels.seedVersion,
      youtubeApiKey: apiKey,
    );
  }

  Future<void> setHomeLibraryMode(HomeLibraryMode mode) async {
    await _ensurePrefs();
    await _prefs!.setString(_modeKey, mode.storageName);
  }

  Future<void> setYoutubeApiKey(String? key) => _secrets.writeApiKey(key);
}
