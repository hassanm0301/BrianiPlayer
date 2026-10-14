import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/administration/administration_screen.dart';
import 'package:briani_player/features/settings/settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final writes = <Map<String, dynamic>>[];
  final readCompleters = <String, Completer<void>>{};
  bool forceOneRefresh = false;
  Completer<void>? writeGate, writeStarted;
  int _meCalls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    final uri = options.uri;
    final profile = uri.host.split('.').first;
    if (options.path == '/api/v1/auth/login' || options.path == '/api/v1/auth/refresh') {
      return _json({
        'accessToken': 'access-$profile',
        'accessExpiresAt': '2026-10-12T20:00:00Z',
        'refreshToken': 'refresh-$profile',
        'refreshExpiresAt': '2026-11-12T20:00:00Z',
        'sessionId': 'session-$profile',
        'user': {'id': 'user-1', 'username': 'member', 'displayName': 'Member',
          'role': 'member', 'enabled': true, 'version': 1},
      });
    }
    if (options.path == '/api/v1/me') {
      _meCalls++;
      if (forceOneRefresh && _meCalls == 1) return _json({'status': 401, 'title': 'Unauthorized'}, 401);
      return _json({'id': 'user-1', 'username': 'member', 'displayName': 'Member',
        'role': 'member', 'enabled': true, 'version': 1});
    }
    if (options.path == '/api/v1/auth/logout') return _json({}, 204);
    if (options.path == '/api/v1/me/preferences') {
      if (options.method == 'GET') {
        await readCompleters[profile]?.future;
        return _json(_preferences(locale: profile == 'second' ? 'fr' : 'en'));
      }
      final body = _bodyMap(options.data);
      writes.add(body);
      if(profile=='first' && writeGate!=null) { writeStarted?.complete(); await writeGate!.future; }
      final response = {..._preferences(), ...body, 'version': (body['version'] as int) + 1};
      return _json(response);
    }
    if (options.path == '/api/v1/me') return _json({'status': 404, 'title': 'Not found'}, 404);
    if (options.path == '/api/v1/admin/settings' || options.path.startsWith('/api/v1/admin/')) {
      throw StateError('A non-administrator screen attempted an admin request.');
    }
    throw StateError('Unexpected fake API request ${options.method} ${options.path}');
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body), status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
}

Map<String, dynamic> _bodyMap(Object? value) {
  if (value is String) return jsonDecode(value) as Map<String, dynamic>;
  if (value is Map<String, dynamic>) return value;
  if (value is List) {
    final result = <String, dynamic>{};
    for (var i = 0; i + 1 < value.length; i += 2) {
      result[value[i] as String] = value[i + 1];
    }
    return result;
  }
  throw StateError('Unexpected preferences request body.');
}

Map<String, dynamic> _preferences({String locale = 'en'}) => {
  'version': 1,
  'theme': 'system',
  'density': 'comfortable',
  'libraryLayout': 'grid',
  'showFilenameExtensions': true,
  'showContinueWatching': true,
  'rememberFolderSort': true,
  'torrentColumns': ['title', 'size', 'seeders', 'leechers'],
  'defaultSort': 'name',
  'defaultSortOrder': 'asc',
  'resumePolicy': 'ask',
  'defaultPlaybackSpeed': 1.0,
  'subtitleScale': 1.0,
  'preferredAudioLanguage': null,
  'preferredSubtitleLanguage': null,
  'slideshowSeconds': 5,
  'locale': locale,
  'accentPreset': 'blue',
  'playbackMode': 'internal',
  'pinnedLibraryIds': <String>[],
  'keyboardShortcutPreset': 'standard',
  'folderPreferences': <Object>[],
};

class _Vault implements CredentialVault {
  final Map<String, String> entries = {};
  @override
  Future<String?> read(String id) async => entries[id];
  @override
  Future<void> write(String id, String token) async => entries[id] = token;
  @override
  Future<void> delete(String id) async => entries.remove(id);
}

class _DevicePrefs extends DevicePreferencesController {
  @override
  DevicePreferences build() => const DevicePreferences();
}

class _Prefs extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(defaultUserPreferences());
}

ProviderContainer _container(_Adapter adapter, {bool withDevicePreferences = false}) => ProviderContainer(overrides: [
  serverHttpClientAdapterProvider.overrideWithValue(adapter),
  credentialVaultProvider.overrideWithValue(_Vault()),
  if (withDevicePreferences) devicePreferencesProvider.overrideWith(_DevicePrefs.new),
]);

Future<void> _login(ProviderContainer container, {String profile = 'first'}) =>
    container.read(clientSessionProvider.notifier).login(
    ServerProfile(id: profile, label: profile, origin: Uri.parse('https://$profile.example')),
    'member', 'verysecurepassword');

int _preferenceGets(_Adapter adapter) =>
    adapter.requests.where((r) => r.path == '/api/v1/me/preferences' && r.method == 'GET').length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('device preferences validate locally and cap cache at 64 MiB', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    final controller = container.read(devicePreferencesProvider.notifier);
    await controller.update(const DevicePreferences(
      cachePreset: PlayerCachePreset.large,
      executablePath: '/usr/bin/mpv',
      arguments: ['--no-config', '{url}'],
      displayScale: 1.25,
    ));
    expect(container.read(devicePreferencesProvider).cacheBytes, 64 * 1024 * 1024);
    expect(container.read(devicePreferencesProvider).arguments, ['--no-config', '{url}']);

    await prefs.setString('device_preferences_v1:guest', jsonEncode({
      'cachePreset': 'unbounded', 'hardwareDecoder': 'shell', 'displayScale': 9,
      'windowWidth': 50000, 'executablePath': 'relative/player',
      'arguments': ['--flag', 'https://attacker/{url}'],
    }));
    container.invalidate(devicePreferencesProvider);
    final safe = container.read(devicePreferencesProvider);
    expect(safe.cacheBytes, 64 * 1024 * 1024);
    expect(safe.displayScale, 1);
    expect(safe.windowWidth, 1280);
    expect(safe.executablePath, isNull);
    expect(safe.arguments, ['{url}']);
    expect(safe.hardwareDecoder, DecoderPreference.automatic);
  });

  test('queued writes from the old session never target the replacement account', () async {
    final adapter = _Adapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await _login(container);
    container.read(userPreferencesProvider);
    await _waitFor(() => container.read(userPreferencesProvider).hasValue);
    adapter.writeGate = Completer<void>(); adapter.writeStarted = Completer<void>();
    final controller=container.read(userPreferencesProvider.notifier);
    final first=controller.update((b)=>b.theme=UserPreferencesThemeEnum.dark).then<Object?>((v)=>v,onError:(Object e)=>e);
    final queued=controller.update((b)=>b.density=UserPreferencesDensityEnum.compact).then<Object?>((v)=>v,onError:(Object e)=>e);
    await adapter.writeStarted!.future;
    await _login(container,profile:'second');
    container.read(userPreferencesProvider);
    await _waitFor(() => container.read(userPreferencesProvider).hasValue);
    adapter.writeGate!.complete();
    await first; expect(await queued,isA<StateError>());
    expect(adapter.requests.where((r)=>r.uri.host=='second.example' && r.method=='PUT'),isEmpty);
    expect(container.read(userPreferencesProvider).requireValue.locale,'fr');
  });

  test('device preferences survive relogin only for the same server and user', () async {
    SharedPreferences.setMockInitialValues({});final local=await SharedPreferences.getInstance();
    final adapter=_Adapter(); final container=ProviderContainer(overrides:[serverHttpClientAdapterProvider.overrideWithValue(adapter),credentialVaultProvider.overrideWithValue(_Vault()),sharedPreferencesProvider.overrideWithValue(local)]);
    addTearDown(container.dispose);
    await _login(container);
    await container.read(devicePreferencesProvider.notifier).update(const DevicePreferences(cachePreset:PlayerCachePreset.small,displayScale:1.25));
    await _login(container,profile:'second');
    expect(container.read(devicePreferencesProvider).displayScale,1);
    expect(container.read(devicePreferencesProvider).cacheBytes,64*1024*1024);
    await _login(container);
    expect(container.read(devicePreferencesProvider).displayScale,1.25);
    expect(container.read(devicePreferencesProvider).cacheBytes,16*1024*1024);
  });

  test('section reset changes only that scope and keeps optimistic version', () async {
    final adapter = _Adapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await _login(container);
    final loaded = Completer<void>();
    adapter.readCompleters['first'] = loaded;
    final initial = container.read(userPreferencesProvider);
    expect(initial.isLoading, true);
    loaded.complete();
    await _waitFor(() => container.read(userPreferencesProvider).hasValue);

    await container.read(userPreferencesProvider.notifier).update((b) => b
      ..theme = UserPreferencesThemeEnum.dark
      ..libraryLayout = UserPreferencesLibraryLayoutEnum.list
      ..defaultPlaybackSpeed = 1.5);
    final beforeResetVersion = container.read(userPreferencesProvider).requireValue.version;
    await container.read(userPreferencesProvider.notifier).reset(PreferenceSection.appearance);
    final posted = adapter.writes.last;
    expect(posted['version'], beforeResetVersion);
    expect(posted['theme'], 'system');
    expect(posted['libraryLayout'], 'list');
    expect(posted['defaultPlaybackSpeed'], 1.5);
    expect(container.read(userPreferencesProvider).requireValue.version, beforeResetVersion + 1);
  });

  test('preferences stay scoped across token refresh but reload for a new session', () async {
    final adapter = _Adapter();
    adapter.forceOneRefresh = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await _login(container);
    await _waitFor(() => container.read(userPreferencesProvider).hasValue);
    expect(_preferenceGets(adapter), 1);

    await container.read(activeApiProvider)!.getIdentityApi().getMe();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(userPreferencesProvider).requireValue.locale, 'en');
    expect(_preferenceGets(adapter), 1);

    await _login(container, profile: 'second');
    await _waitFor(() => container.read(userPreferencesProvider).hasValue &&
        container.read(userPreferencesProvider).requireValue.locale == 'fr');
    expect(_preferenceGets(adapter), 2);
  });

  test('a slow old-profile preference response cannot replace the new profile', () async {
    final adapter = _Adapter();
    final firstLoad = Completer<void>();
    adapter.readCompleters['first'] = firstLoad;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await _login(container);
    container.read(userPreferencesProvider);
    await _waitFor(() => _preferenceGets(adapter) == 1);

    await _login(container, profile: 'second');
    await _waitFor(() => container.read(userPreferencesProvider).hasValue &&
        container.read(userPreferencesProvider).requireValue.locale == 'fr');
    firstLoad.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(userPreferencesProvider).requireValue.locale, 'fr');
    expect(_preferenceGets(adapter), 2);
  });

  testWidgets('settings screen exposes synced preference controls', (tester) async {
    await tester.pumpWidget(ProviderScope(key: const ValueKey('settings'), overrides: [
      userPreferencesProvider.overrideWith(_Prefs.new),
      devicePreferencesProvider.overrideWith(_DevicePrefs.new),
    ], child: const MaterialApp(home: SettingsScreen())));
    await _waitWidget(tester, find.text('Show filename extensions'));
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Libraries and discovery'), 300, scrollable: list);
    expect(find.text('Libraries and discovery'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Playback and photos'), 500, scrollable: list);
    expect(find.text('Playback and photos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('This device'), 700, scrollable: list);
    expect(find.text('This device'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reset all synced preferences'), 1000, scrollable: list);
    expect(find.text('Reset all synced preferences'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('Reset Libraries and discovery'), -1500, scrollable: list);
    expect(find.byTooltip('Reset Libraries and discovery'), findsOneWidget);

    await tester.pumpWidget(ProviderScope(key: const ValueKey('admin'), overrides: [
      clientSessionProvider.overrideWith(SessionController.new),
    ], child: const MaterialApp(home: AdministrationScreen())));
    expect(find.text('Administrator access is required.'), findsOneWidget);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Expected asynchronous provider response.');
}

Future<void> _waitWidget(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsOneWidget);
}
