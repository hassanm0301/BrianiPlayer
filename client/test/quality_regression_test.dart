// Regression checks for defects identified in the polish audit.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/app/app.dart';
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/platform/platform_capabilities.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class Adapter implements HttpClientAdapter {
  Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async => await handler(o);
  @override
  void close({bool force = false}) {}
}

const libraries = [
  {
    'id': 'lib-1',
    'name': 'Films',
    'description': '',
    'readOnly': false,
    'enabled': true,
    'version': 1,
    'capabilities': {'read': true, 'download': true, 'manage': true},
  },
];
Map<String, Object?> page(List<Object?> items, {String? cursor}) => {
  'items': items,
  'nextCursor': cursor,
  'totalKnown': items.length,
  'truncated': false,
  'warnings': <String>[],
};
Map<String, Object?> entry(String name) => {
  'id': name,
  'libraryId': 'lib-1',
  'parentId': null,
  'kind': 'video',
  'name': name,
  'sizeBytes': 100,
  'mediaId': name,
  'thumbnailAvailable': false,
  'version': 1,
};
Map<String, Object?> download(String id) => {
  'id': id,
  'libraryId': 'lib-1',
  'ownerId': 'owner',
  'name': id,
  'state': 'downloading',
  'selectedBytes': 100,
  'downloadedSelectedBytes': 20,
  'torrentBytes': 100,
  'downloadBps': 10,
  'uploadBps': 0,
  'sequential': true,
  'firstLastMetadataAssist': true,
  'generation': 'g1',
  'version': 1,
  'createdAt': '2026-10-14T00:00:00Z',
  'updatedAt': '2026-10-14T00:00:00Z',
  'tags': <String>[],
  'sourceState': 'ready',
  'transferState': 'downloading',
  'importState': 'notReady',
};
Map<String, Object?> snapshot(String id, String title, {String? cursor}) => {
  'id': id,
  'state': 'complete',
  'createdAt': '2026-10-14T00:00:00Z',
  'expiresAt': '2026-10-14T01:00:00Z',
  ...page([
    {
      'id': title,
      'title': title,
      'providerId': 'provider',
      'providerName': 'Provider',
      'fetchedAt': '2026-10-14T00:00:00Z',
      'stale': false,
      'downloadable': false,
      'categories': <int>[],
    },
  ], cursor: cursor),
};
Widget app(Widget screen, Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..transformer = SyncTransformer()
    ..httpClientAdapter = adapter;
  return ProviderScope(
    overrides: [activeApiProvider.overrideWithValue(BrianiApi(dio: dio))],
    child: MaterialApp(home: screen),
  );
}

class _AdminSession extends SessionController {
  _AdminSession(this.api);
  final BrianiApi api;
  @override
  ClientSession? build() => ClientSession(
    profile: ServerProfile(
      id: 'profile',
      label: 'Server',
      origin: Uri.parse('https://fixture.invalid'),
    ),
    api: api,
    tokens: AuthTokens(
      (b) => b
        ..accessToken = 'token'
        ..accessExpiresAt = DateTime.utc(2026, 10, 13)
        ..refreshToken = 'refresh'
        ..refreshExpiresAt = DateTime.utc(2026, 11, 13)
        ..sessionId = 'session'
        ..user = User(
          (u) => u
            ..id = 'admin'
            ..username = 'admin'
            ..displayName = 'Admin'
            ..role = UserRoleEnum.administrator
            ..enabled = true
            ..version = 1,
        ).toBuilder(),
    ),
    sessionOnly: true,
  );
}

class _Preferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(defaultUserPreferences());
}

class _DevicePreferences extends DevicePreferencesController {
  @override
  DevicePreferences build() => const DevicePreferences();
}

void main() {
  testWidgets('system accessibility scaling remains effective', (t) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Text(
              'Effective size ${MediaQuery.textScalerOf(context).scale(10)}',
            ),
          ),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appRouterProvider.overrideWithValue(router),
          deviceCapabilitiesProvider.overrideWith(
            (ref) async =>
                const DeviceCapabilities(television: false, platform: 'linux'),
          ),
        ],
        child: const BrianiApp(),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Effective size 10.0'), findsNothing);
    expect(find.text('Effective size 20.0'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets(
    'quiet refresh removes requests absent from the reconciled window',
    (t) async {
      var calls = 0;
      final adapter = Adapter(
        (o) => jsonResponse(
          page(++calls == 1 ? [download('Removed request')] : []),
        ),
      );
      await t.pumpWidget(app(const DownloadsScreen(), adapter));
      await t.pumpAndSettle();
      expect(find.text('Removed request'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(calls, greaterThanOrEqualTo(2));
      expect(find.text('Removed request'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('valid partial transfer settings are submitted', (t) async {
    var writes = 0;
    final adapter = Adapter((o) {
      if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
      if (o.path.endsWith('/files')) return jsonResponse([]);
      if (o.path.endsWith('/settings')) {
        if (o.method != 'GET') writes++;
        return jsonResponse({'version': 1, 'tags': <String>[]});
      }
      return jsonResponse(download('download-1'));
    });
    await t.pumpWidget(
      app(const DownloadDetailsScreen(requestId: 'download-1'), adapter),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Transfer settings'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Download limit (bytes/sec)'),
      '1048576',
    );
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Enter valid numeric limits.'), findsNothing);
    expect(writes, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'tabs preserve folder search and Back; hidden downloads stop polling',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var downloadCalls = 0;
      final adapter = Adapter((o) {
        if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
        if (o.path.endsWith('/downloads')) {
          downloadCalls++;
          return jsonResponse(page([]));
        }
        if (o.path.endsWith('/entries')) {
          return jsonResponse(page([entry('Sample')]));
        }
        if (o.path.contains('/discovery/searches')) {
          return jsonResponse(snapshot('search1', 'Result'));
        }
        if (o.path.endsWith('/discovery/providers')) return jsonResponse([]);
        return jsonResponse(page([]));
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = adapter;
      final api = BrianiApi(dio: dio);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          clientSessionProvider.overrideWith(() => _AdminSession(api)),
          userPreferencesProvider.overrideWith(_Preferences.new),
          devicePreferencesProvider.overrideWith(_DevicePreferences.new),
          deviceCapabilitiesProvider.overrideWith(
            (ref) async =>
                const DeviceCapabilities(television: false, platform: 'linux'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrianiApp(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      await t.tap(find.text('Films'));
      await t.pumpAndSettle();
      final search = find.byType(TextField).first;
      await t.enterText(search, 'kept search');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      final router = container.read(appRouterProvider);
      final location = router.routeInformationProvider.value.uri.path;
      final downloadsTab = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Downloads'),
      );
      await t.tap(downloadsTab);
      await t.pumpAndSettle();
      expect(downloadCalls, 1);
      await t.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Libraries'),
        ),
      );
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, location);
      expect(find.widgetWithText(TextField, 'kept search'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(downloadCalls, 1);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/libraries');
      expect(find.text('Your libraries'), findsOneWidget);
      await t.tap(downloadsTab);
      await t.pumpAndSettle();
      expect(downloadCalls, 2);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'download detail polls live data without repeatedly loading metadata',
    (t) async {
      final calls = <String, int>{};
      final adapter = Adapter((o) {
        final endpoint = o.path.split('/').last;
        calls.update(endpoint, (v) => v + 1, ifAbsent: () => 1);
        if (endpoint == 'libraries') return jsonResponse(libraries);
        if (endpoint == 'settings') {
          return jsonResponse({'version': 1, 'tags': <String>[]});
        }
        if (endpoint == 'files') {
          return jsonResponse(
            List.generate(
              1000,
              (i) => {
                'id': 'file-$i',
                'downloadId': 'download-1',
                'name': 'Video $i.mp4',
                'relativePath': 'Video $i.mp4',
                'sizeBytes': 100,
                'downloadedBytes': 20,
                'contiguousBytes': 20,
                'kind': 'video',
                'selected': false,
                'priority': 'normal',
                'playbackState': 'notSelected',
                'version': 1,
              },
            ),
          );
        }
        return jsonResponse({
          ...download('download-1'),
          'state': 'awaitingSelection',
        });
      });
      await t.pumpWidget(
        app(const DownloadDetailsScreen(requestId: 'download-1'), adapter),
      );
      await t.pumpAndSettle();
      expect(calls, {
        'download-1': 1,
        'files': 1,
        'settings': 1,
        'libraries': 1,
      });
      final boxes = find.byType(Checkbox);
      expect(boxes, findsWidgets);
      expect(
        boxes.evaluate().length,
        lessThan(30),
        reason: 'Off-screen files are built lazily.',
      );
      expect(t.widget<Checkbox>(boxes.first).value, isTrue);
      await t.tap(boxes.first);
      await t.pump();
      expect(t.widget<Checkbox>(boxes.first).value, isFalse);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(calls, {
        'download-1': 2,
        'files': 2,
        'settings': 1,
        'libraries': 1,
      });
      expect(
        t.widget<Checkbox>(boxes.first).value,
        isFalse,
        reason: 'Polling must not silently reselect a file the user unchecked.',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
