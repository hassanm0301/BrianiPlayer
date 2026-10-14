import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server_profiles/providers.dart';
import '../session/client_session.dart';

/// Changes only when the authenticated identity/API session changes. Access
/// token refresh keeps the same API object, so it does not discard preferences.
final userPreferencesScopeProvider = Provider<String?>((ref) {
  final key = ref.watch(clientSessionProvider.select((session) => session == null
      ? null
      : '${session.profile.id}:${session.tokens.user.id}:${session.tokens.sessionId}:${identityHashCode(session.api)}'));
  return key;
});

final userPreferencesProvider = NotifierProvider<
    UserPreferencesController, AsyncValue<UserPreferences>>(
        UserPreferencesController.new);

class UserPreferencesController extends Notifier<AsyncValue<UserPreferences>> {
  CancelToken? _cancel;
  String? _scope;
  Future<void> _writeQueue = Future<void>.value();

  @override
  AsyncValue<UserPreferences> build() {
    _cancel?.cancel('Preference session changed.');
    _scope = ref.watch(userPreferencesScopeProvider);
    final scope = _scope;
    if (scope == null) {
      return AsyncError(StateError('Sign in to load your preferences.'), StackTrace.current);
    }
    final session = ref.read(clientSessionProvider);
    if (session == null) {
      return AsyncError(StateError('Sign in to load your preferences.'), StackTrace.current);
    }
    final api = session.api.getPreferencesApi();
    final cancel = _cancel = CancelToken();
    ref.onDispose(() {
      cancel.cancel('Preference session changed.');
      if (identical(_cancel, cancel)) _cancel = null;
    });
    unawaited(api.getPreferences(cancelToken: cancel).then((response) {
      if (ref.mounted && ref.read(userPreferencesScopeProvider) == scope) {
        state = AsyncData(response.data!);
      }
    }, onError: (Object error, StackTrace stack) {
      if (ref.mounted && ref.read(userPreferencesScopeProvider) == scope) {
        state = AsyncError(error, stack);
      }
    }));
    return const AsyncLoading();
  }

  Future<UserPreferences> update(void Function(UserPreferencesBuilder) change) {
    final scope = _scope;
    final previous = _writeQueue;
    final next = previous.then((_) {
      if (scope == null || !_isCurrent(scope)) throw StateError('The signed-in session changed.');
      return _updateNow(change);
    });
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<UserPreferences> _updateNow(
      void Function(UserPreferencesBuilder) change) async {
    final current = state.asData?.value;
    final scope = _scope;
    if (current == null || scope == null) {
      throw StateError('Preferences have not loaded.');
    }
    final updated = current.rebuild(change);
    state = AsyncData(updated);
    try {
      final response = await ref
          .read(clientSessionProvider)!
          .api
          .getPreferencesApi()
          .updatePreferences(userPreferences: updated, cancelToken: _cancel);
      final saved = response.data!;
      if (!_isCurrent(scope)) throw StateError('The signed-in session changed.');
      state = AsyncData(saved);
      return saved;
    } catch (error, stack) {
      if (_isCurrent(scope)) {
        state = AsyncData(current);
        if (error is DioException && error.response?.statusCode == 409) {
          try {
            final fresh = (await ref.read(clientSessionProvider)!.api.getPreferencesApi().getPreferences(cancelToken: _cancel)).data!;
            if (_isCurrent(scope)) state = AsyncData(fresh);
          } catch (_) { /* Keep last verified preferences available for explicit retry. */ }
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<UserPreferences> reset(PreferenceSection section) {
    if (section != PreferenceSection.all) return _resetSection(section);
    final scope = _scope;
    final previous = _writeQueue;
    final next = previous.then((_) {
      if (scope == null || !_isCurrent(scope)) throw StateError('The signed-in session changed.');
      return _resetAll();
    });
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<UserPreferences> _resetAll() async {
    final current = state.asData?.value;
    final scope = _scope;
    if (current == null || scope == null) {
      throw StateError('Preferences have not loaded.');
    }
    final response = await ref
        .read(clientSessionProvider)!
        .api
        .getPreferencesApi()
        .resetPreferences(
          versionRequest: VersionRequest((b) => b.version = current.version),
          cancelToken: _cancel,
          idempotencyKey: 'prefs-reset-${scope.hashCode}-${current.version}',
        );
    if (!_isCurrent(scope)) throw StateError('The signed-in session changed.');
    state = AsyncData(response.data!);
    return response.data!;
  }

  Future<UserPreferences> _resetSection(PreferenceSection section) async {
    final current = state.asData?.value;
    if (current == null) throw StateError('Preferences have not loaded.');
    final defaults = defaultUserPreferences();
    return update((b) {
      switch (section) {
        case PreferenceSection.appearance:
          b
            ..theme = defaults.theme
            ..accentPreset = defaults.accentPreset
            ..density = defaults.density
            ..locale = defaults.locale;
        case PreferenceSection.library:
          b
            ..libraryLayout = defaults.libraryLayout
            ..showFilenameExtensions = defaults.showFilenameExtensions
            ..showContinueWatching = defaults.showContinueWatching
            ..rememberFolderSort = defaults.rememberFolderSort
            ..torrentColumns.replace(defaults.torrentColumns!)
            ..defaultSort = defaults.defaultSort
            ..defaultSortOrder = defaults.defaultSortOrder
            ..pinnedLibraryIds.replace(defaults.pinnedLibraryIds!)
            ..folderPreferences.replace(defaults.folderPreferences!)
            ..discoveryViews.replace(defaults.discoveryViews!);
        case PreferenceSection.playback:
          b
            ..resumePolicy = defaults.resumePolicy
            ..defaultPlaybackSpeed = defaults.defaultPlaybackSpeed
            ..subtitleScale = defaults.subtitleScale
            ..preferredAudioLanguage = defaults.preferredAudioLanguage
            ..preferredSubtitleLanguage = defaults.preferredSubtitleLanguage
            ..slideshowSeconds = defaults.slideshowSeconds
            ..playbackMode = defaults.playbackMode;
        case PreferenceSection.accessibility:
          b.keyboardShortcutPreset = defaults.keyboardShortcutPreset;
        case PreferenceSection.all:
          throw StateError('Full reset uses the server reset endpoint.');
      }
    });
  }

  bool _isCurrent(String scope) =>
      ref.mounted && ref.read(userPreferencesScopeProvider) == scope;
}

enum PreferenceSection { appearance, library, playback, accessibility, all }

UserPreferences defaultUserPreferences() => UserPreferences((b) => b
  ..version = 1
  ..theme = UserPreferencesThemeEnum.system
  ..density = UserPreferencesDensityEnum.comfortable
  ..libraryLayout = UserPreferencesLibraryLayoutEnum.grid
  ..showFilenameExtensions = true
  ..showContinueWatching = true
  ..rememberFolderSort = true
  ..torrentColumns.replace([
    UserPreferencesTorrentColumnsEnum.title,
    UserPreferencesTorrentColumnsEnum.size,
    UserPreferencesTorrentColumnsEnum.seeders,
    UserPreferencesTorrentColumnsEnum.leechers,
  ])
  ..defaultSort = UserPreferencesDefaultSortEnum.byName
  ..defaultSortOrder = UserPreferencesDefaultSortOrderEnum.asc
  ..resumePolicy = UserPreferencesResumePolicyEnum.ask
  ..defaultPlaybackSpeed = 1.0
  ..subtitleScale = 1.0
  ..slideshowSeconds = 5
  ..locale = 'en'
  ..accentPreset = UserPreferencesAccentPresetEnum.blue
  ..playbackMode = UserPreferencesPlaybackModeEnum.internal
  ..pinnedLibraryIds.clear()
  ..keyboardShortcutPreset = UserPreferencesKeyboardShortcutPresetEnum.standard
  ..folderPreferences.clear()
  ..discoveryViews.clear());

enum PlayerCachePreset { small, medium, large }
enum DecoderPreference { automatic, safe, disabled }
enum DeviceModeOverride { automatic, mobile, television }

class DevicePreferences {
  const DevicePreferences({
    this.preferredPlayer,
    this.executablePath,
    this.arguments = const ['{url}'],
    this.displayScale = 1,
    this.windowWidth = 1280,
    this.windowHeight = 720,
    this.fullscreenByDefault = false,
    this.hardwareDecoder = DecoderPreference.automatic,
    this.cachePreset = PlayerCachePreset.medium,
    this.modeOverride = DeviceModeOverride.automatic,
  });

  final String? preferredPlayer;
  final String? executablePath;
  final List<String> arguments;
  final double displayScale;
  final int windowWidth;
  final int windowHeight;
  final bool fullscreenByDefault;
  final DecoderPreference hardwareDecoder;
  final PlayerCachePreset cachePreset;
  final DeviceModeOverride modeOverride;

  int get cacheBytes => switch (cachePreset) {
        PlayerCachePreset.small => 16 * 1024 * 1024,
        PlayerCachePreset.medium => 32 * 1024 * 1024,
        PlayerCachePreset.large => 64 * 1024 * 1024,
      };

  DevicePreferences copyWith({
    Object? preferredPlayer = _unset,
    Object? executablePath = _unset,
    List<String>? arguments,
    double? displayScale,
    int? windowWidth,
    int? windowHeight,
    bool? fullscreenByDefault,
    DecoderPreference? hardwareDecoder,
    PlayerCachePreset? cachePreset,
    DeviceModeOverride? modeOverride,
  }) => DevicePreferences(
        preferredPlayer: identical(preferredPlayer, _unset)
            ? this.preferredPlayer
            : preferredPlayer as String?,
        executablePath: identical(executablePath, _unset)
            ? this.executablePath
            : executablePath as String?,
        arguments: arguments ?? this.arguments,
        displayScale: displayScale ?? this.displayScale,
        windowWidth: windowWidth ?? this.windowWidth,
        windowHeight: windowHeight ?? this.windowHeight,
        fullscreenByDefault: fullscreenByDefault ?? this.fullscreenByDefault,
        hardwareDecoder: hardwareDecoder ?? this.hardwareDecoder,
        cachePreset: cachePreset ?? this.cachePreset,
        modeOverride: modeOverride ?? this.modeOverride,
      );

  Map<String, Object?> toJson() => {
        'preferredPlayer': preferredPlayer,
        'executablePath': executablePath,
        'arguments': arguments,
        'displayScale': displayScale,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'fullscreenByDefault': fullscreenByDefault,
        'hardwareDecoder': hardwareDecoder.name,
        'cachePreset': cachePreset.name,
        'modeOverride': modeOverride.name,
      };

  factory DevicePreferences.fromJson(Map<String, dynamic> json) {
    final defaults = DevicePreferences(cachePreset: Platform.isAndroid ? PlayerCachePreset.medium : PlayerCachePreset.large);
    final args = json['arguments'];
    final path = json['executablePath'];
    return DevicePreferences(
      preferredPlayer: _boundedString(json['preferredPlayer'], 128),
      executablePath: _safePath(path) ? path as String : null,
      arguments: args is List && args.length <= 32 && args.every(_safeArgument) &&
              args.where((item) => item == '{url}').length == 1 &&
              args.where((item) => item is String && item.contains('{url}')).length == 1
          ? List.unmodifiable(args.cast<String>())
          : defaults.arguments,
      displayScale: _boundedNumber(json['displayScale'], .75, 2, 1),
      windowWidth: _boundedInt(json['windowWidth'], 640, 3840, 1280),
      windowHeight: _boundedInt(json['windowHeight'], 360, 2160, 720),
      fullscreenByDefault: json['fullscreenByDefault'] is bool
          ? json['fullscreenByDefault'] as bool
          : defaults.fullscreenByDefault,
      hardwareDecoder: DecoderPreference.values
          .where((e) => e.name == json['hardwareDecoder'])
          .firstOrNull ?? defaults.hardwareDecoder,
      cachePreset: PlayerCachePreset.values
          .where((e) => e.name == json['cachePreset'])
          .firstOrNull ?? defaults.cachePreset,
      modeOverride: DeviceModeOverride.values
          .where((e) => e.name == json['modeOverride'])
          .firstOrNull ?? defaults.modeOverride,
    );
  }
}

const _unset = Object();
bool _safeArgument(Object? value) => value is String &&
    value.length <= 2048 &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) &&
    (!value.contains('{url}') || value == '{url}');
bool _safePath(Object? value) => value is String &&
    value.length <= 4096 &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) &&
    (value.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value));
String? _boundedString(Object? value, int max) =>
    value is String && value.trim().isNotEmpty && value.length <= max
        ? value.trim()
        : null;
double _boundedNumber(Object? value, double min, double max, double fallback) =>
    value is num && value.isFinite && value >= min && value <= max
        ? value.toDouble()
        : fallback;
int _boundedInt(Object? value, int min, int max, int fallback) =>
    value is int && value >= min && value <= max ? value : fallback;

final devicePreferencesProvider =
    NotifierProvider<DevicePreferencesController, DevicePreferences>(
        DevicePreferencesController.new);

class DevicePreferencesController extends Notifier<DevicePreferences> {
  String? _scope;
  Future<void> _writeQueue = Future.value();
  String _keyFor(String scope) => 'device_preferences_v1:$scope';
  DevicePreferences get _defaults => DevicePreferences(cachePreset: Platform.isAndroid ? PlayerCachePreset.medium : PlayerCachePreset.large);
  @override
  DevicePreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    _scope = ref.watch(clientSessionProvider.select((session) => session == null ? 'guest' : '${session.profile.id}:${session.tokens.user.id}'));
    final raw = prefs.getString(_keyFor(_scope!));
    if (raw == null || raw.length > 16000) return _defaults;
    try {
      return DevicePreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _defaults;
    }
  }

  Future<void> update(DevicePreferences value) {
    final validated = DevicePreferences.fromJson(value.toJson());
    final scope = _scope!;
    final previous = state;
    state = validated;
    final next = _writeQueue.then((_) async {
      if (!ref.mounted || _scope != scope) throw StateError('The signed-in session changed.');
      final prefs = ref.read(sharedPreferencesProvider);
      if (!await prefs.setString(_keyFor(scope), jsonEncode(validated.toJson()))) throw StateError('Device preferences could not be saved.');
    }).catchError((Object error, StackTrace stack) {
      if (ref.mounted && _scope == scope && identical(state, validated)) state = previous;
      Error.throwWithStackTrace(error, stack);
    });
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> reset() {
    final scope = _scope!;
    final previous = state;
    final defaults = _defaults;
    state = defaults;
    final next = _writeQueue.then((_) async {
      if (!ref.mounted || _scope != scope) throw StateError('The signed-in session changed.');
      if (!await ref.read(sharedPreferencesProvider).remove(_keyFor(scope))) throw StateError('Device preferences could not be reset.');
    }).catchError((Object error, StackTrace stack) {
      if (ref.mounted && _scope == scope && identical(state, defaults)) state = previous;
      Error.throwWithStackTrace(error, stack);
    });
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
