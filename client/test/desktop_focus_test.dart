import 'dart:async';
import 'dart:convert';

import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/core/widgets/adaptive.dart';
import 'package:briani_player/features/downloads/download_formatters.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:briani_player/features/playback/player_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _profile = ServerProfile(
  id: 'profile-1',
  label: 'Media server',
  origin: Uri.parse('https://media.example'),
);

class _Vault implements CredentialVault {
  @override
  Future<String?> read(String profileId) async => null;
  @override
  Future<void> write(String profileId, String token) async {}
  @override
  Future<void> delete(String profileId) async {}
}

class _Server implements HttpClientAdapter {
  _Server({this.download = const {}});
  final Map<String, Object?> download;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    requests.add('${options.method} $path');
    Object? body;
    var status = 200;
    if (path == '/api/v1/auth/login') {
      body = {
        'accessToken': 'access',
        'accessExpiresAt': '2030-01-01T01:00:00Z',
        'refreshToken': 'refresh',
        'refreshExpiresAt': '2030-02-01T00:00:00Z',
        'sessionId': 'session-1',
        'user': {
          'id': 'owner',
          'username': 'member',
          'displayName': 'Member',
          'role': 'member',
          'enabled': true,
          'version': 1,
        },
      };
    } else if (path == '/api/v1/libraries') {
      body = [
        {
          'id': 'library-1',
          'name': 'Library',
          'description': '',
          'readOnly': false,
          'enabled': true,
          'version': 1,
          'capabilities': {'read': true, 'download': true, 'manage': true},
        },
      ];
    } else if (path == '/api/v1/downloads') {
      body = {
        'items': [download],
        'nextCursor': null,
        'totalKnown': 1,
        'truncated': false,
        'warnings': <String>[],
      };
    } else if (path.endsWith('/files')) {
      body = <Object>[];
    } else if (path.endsWith('/settings')) {
      body = {'version': 1, 'tags': <String>[]};
    } else if (path.startsWith('/api/v1/downloads/')) {
      body = download;
    } else if (path == '/api/v1/playback/sessions') {
      body = {
        'id': 'playback-1',
        'state': 'ready',
        'streamUrl': 'https://media.example/stream/${'a' * 43}/clip.mp4',
        'activationExpiresAt': '2030-01-01T00:10:00Z',
        'absoluteExpiresAt': '2030-01-02T00:00:00Z',
        'generation': 'g',
        'contiguousBytes': 100,
        'totalBytes': 100,
        'mimeType': 'video/mp4',
        'fileName': 'clip.mp4',
        'sidecars': <Object>[],
      };
      status = 201;
    } else if (options.method == 'DELETE') {
      status = 204;
    } else {
      status = 404;
      body = {'status': 404, 'title': 'Not found'};
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Player implements PlaybackAdapter {
  final _states = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  int pauses = 0;

  void _emit(PlaybackState next) {
    _state = next;
    _states.add(next);
  }

  PlaybackState _with({required bool playing}) => PlaybackState(
    position: const Duration(seconds: 3),
    duration: const Duration(minutes: 10),
    playing: playing,
  );

  @override
  Stream<PlaybackState> get states => _states.stream;
  @override
  PlaybackState get state => _state;
  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => const SizedBox.expand();
  @override
  Future<void> open(PlaybackSource source, {Duration? startPosition}) async =>
      _emit(_with(playing: true));
  @override
  Future<void> play() async => _emit(_with(playing: true));
  @override
  Future<void> pause() async {
    pauses++;
    _emit(_with(playing: false));
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> setSpeed(double value) async {}
  @override
  Future<void> selectAudioTrack(String id) async {}
  @override
  Future<void> selectSubtitleTrack(String? id) async {}
  @override
  Future<void> selectSidecar(
    String url, {
    String? title,
    String? language,
  }) async {}
  @override
  Future<void> setSubtitleDelay(Duration delay) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => _states.close();
}

Map<String, Object?> _download({
  required String state,
  required String transferState,
  int? selectedBytes = 100,
  int? etaSeconds,
}) => {
  'id': 'download-1',
  'libraryId': 'library-1',
  'ownerId': 'owner',
  'name': 'Sintel',
  'state': state,
  'selectedBytes': selectedBytes,
  'downloadedSelectedBytes': 100,
  'torrentBytes': 100,
  'downloadBps': 0,
  'uploadBps': 0,
  'etaSeconds': etaSeconds,
  'sequential': true,
  'firstLastMetadataAssist': true,
  'generation': 'generation-1',
  'version': 1,
  'createdAt': '2026-10-14T00:00:00Z',
  'updatedAt': '2026-10-14T00:00:00Z',
  'tags': <String>[],
  'sourceState': 'ready',
  'transferState': transferState,
  'importState': 'complete',
};

/// Signs in through [server] and returns the container the screen runs in.
Future<ProviderContainer> _signedIn(
  WidgetTester tester,
  _Server server, {
  _Player? player,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      credentialVaultProvider.overrideWithValue(_Vault()),
      serverHttpClientAdapterProvider.overrideWithValue(server),
      if (player != null)
        playbackAdapterFactoryProvider.overrideWithValue(() => player),
    ],
  );
  await tester.runAsync(
    () => container
        .read(clientSessionProvider.notifier)
        .login(_profile, 'member', 'password'),
  );
  return container;
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _dispose(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Let delayed work scheduled while closing (progress saves, retries) end.
  await tester.pump(const Duration(minutes: 1));
  container.dispose();
  debugDefaultTargetPlatformOverride = null;
}

int _loads(_Server server) => server.requests
    .where((r) => r == 'GET /api/v1/downloads/download-1')
    .length;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('foreground lifecycle', () {
    test('desktop windows stay foreground when they only lose focus', () {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(isForegroundLifecycle(AppLifecycleState.resumed), isTrue);
        expect(isForegroundLifecycle(AppLifecycleState.inactive), isTrue);
        expect(isForegroundLifecycle(AppLifecycleState.hidden), isFalse);
        expect(isForegroundLifecycle(AppLifecycleState.paused), isFalse);
        expect(isForegroundLifecycle(null), isTrue);
      }
    });

    test('phones and TVs still treat inactive as background', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isForegroundLifecycle(AppLifecycleState.resumed), isTrue);
      expect(isForegroundLifecycle(AppLifecycleState.inactive), isFalse);
      expect(isForegroundLifecycle(AppLifecycleState.paused), isFalse);
    });
  });

  test("qBittorrent's unbounded ETA is shown as unknown", () {
    expect(formatEta(8640000), '—');
    expect(formatEta(9000000), '—');
    expect(formatEta(3660), '1h 1m');
  });

  testWidgets('a stopped download with a selection offers Resume, not Pause', (
    tester,
  ) async {
    final server = _Server(
      download: _download(
        state: 'completeSelected',
        transferState: 'stopped',
        etaSeconds: 8640000,
      ),
    );
    final container = await _signedIn(tester, server);
    await _show(
      tester,
      container,
      const DownloadDetailsScreen(requestId: 'download-1'),
    );

    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('100d 0h'), findsNothing);
    await _dispose(tester, container);
  });

  testWidgets('a request still awaiting file selection offers no Resume', (
    tester,
  ) async {
    final server = _Server(
      download: _download(
        state: 'awaitingSelection',
        transferState: 'stopped',
        selectedBytes: null,
      ),
    );
    final container = await _signedIn(tester, server);
    await _show(
      tester,
      container,
      const DownloadDetailsScreen(requestId: 'download-1'),
    );

    expect(find.text('Resume'), findsNothing);
    await _dispose(tester, container);
  });

  testWidgets('the downloads list offers Resume for a stopped download', (
    tester,
  ) async {
    final server = _Server(
      download: _download(state: 'completeSelected', transferState: 'stopped'),
    );
    final container = await _signedIn(tester, server);
    await _show(tester, container, const DownloadsScreen());

    // The first transfer action is the card's inline control.
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    await _dispose(tester, container);
  });

  for (final (platform, keepsPolling) in [
    (TargetPlatform.linux, true),
    (TargetPlatform.android, false),
  ]) {
    testWidgets(
      'download details ${keepsPolling ? 'keep' : 'stop'} refreshing while '
      'inactive on ${platform.name}',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final server = _Server(
          download: _download(
            state: 'downloading',
            transferState: 'downloading',
          ),
        );
        final container = await _signedIn(tester, server);
        await _show(
          tester,
          container,
          const DownloadDetailsScreen(requestId: 'download-1'),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        final before = _loads(server);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        if (keepsPolling) {
          expect(_loads(server), greaterThan(before));
        } else {
          expect(_loads(server), before);
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _dispose(tester, container);
      },
    );

    testWidgets(
      'the player ${keepsPolling ? 'keeps playing' : 'pauses'} when the app '
      'becomes inactive on ${platform.name}',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final player = _Player();
        final server = _Server();
        final container = await _signedIn(tester, server, player: player);
        await _show(
          tester,
          container,
          const PlayerScreen(kind: 'downloadFile', targetId: 'file-1'),
        );
        expect(player.state.playing, isTrue);
        final pausesBefore = player.pauses;

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        if (keepsPolling) {
          expect(player.pauses, pausesBefore);
          expect(player.state.playing, isTrue);
        } else {
          expect(player.pauses, greaterThan(pausesBefore));
          expect(player.state.playing, isFalse);
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _dispose(tester, container);
      },
    );
  }
}
