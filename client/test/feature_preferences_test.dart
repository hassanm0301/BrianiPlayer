import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/features/administration/administration_screen.dart';
import 'package:briani_player/features/discover/discover_screen.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(_fixturePreferences);

  @override
  Future<UserPreferences> update(
    void Function(UserPreferencesBuilder) change,
  ) async {
    _fixturePreferences = _fixturePreferences.rebuild(change);
    state = AsyncData(_fixturePreferences);
    return _fixturePreferences;
  }
}

late UserPreferences _fixturePreferences;

class _FolderAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object data;
    if (options.path.endsWith('/entries')) {
      data = {
        'items': [
          {
            'id': 'video-1',
            'libraryId': 'library-1',
            'parentId': null,
            'kind': 'video',
            'name': 'Example.mkv',
            'thumbnailAvailable': false,
            'version': 1,
          },
        ],
        'nextCursor': null,
        'totalKnown': 1,
        'truncated': false,
        'warnings': [],
      };
    } else {
      data = [
        {
          'id': 'library-1',
          'name': 'Films',
          'description': '',
          'readOnly': true,
          'enabled': true,
          'version': 1,
          'capabilities': {'read': true, 'download': false, 'manage': false},
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DiscoveryAdapter implements HttpClientAdapter {
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body;
    if (options.path.endsWith('/discovery/providers') ||
        options.path.endsWith('/libraries')) {
      body = [];
    } else if (options.path.endsWith('/discovery/queries')) {
      final data = options.data;
      final query = data is String ? jsonDecode(data) : data;
      queries.add(
        query is Map<String, dynamic> ? query : _alternatingMap(query as List),
      );
      body = {
        'id': 'snapshot-${queries.length}',
        'state': 'complete',
        'createdAt': '2026-10-12T00:00:00Z',
        'expiresAt': '2026-10-12T01:00:00Z',
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      };
    } else {
      body = {'title': 'Not found', 'status': 404};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _alternatingMap(List values) => {
  for (var i = 0; i + 1 < values.length; i += 2)
    values[i] as String: values[i + 1],
};

class _AdminAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    paths.add(path);
    final Object body = switch (true) {
      _ when path.endsWith('/admin/settings') => {
        'version': 1,
        'enabledProviderIds': null,
        'enabledCategoryIds': null,
      },
      _ when path.endsWith('/admin/users') => [],
      _ when path.endsWith('/admin/health') => [],
      _ when path.endsWith('/admin/storage') => [],
      _ when path.endsWith('/admin/integrations') => [],
      _ when path.endsWith('/admin/audit') => {
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      },
      _ when path.endsWith('/libraries') => [],
      _ when path.endsWith('/discovery/providers') => [
        {
          'id': 'provider-a',
          'name': 'Provider A',
          'enabled': true,
          'supportsSearch': true,
          'supportsRecent': true,
          'categories': [1, 4],
          'state': 'healthy',
        },
      ],
      _ => {'title': 'Not found', 'status': 404},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'folder screen applies saved sort, layout, and filename display',
    (tester) async {
      _fixturePreferences = defaultUserPreferences().rebuild(
        (b) => b
          ..showFilenameExtensions = false
          ..rememberFolderSort = true
          ..folderPreferences.add(
            UserPreferencesFolderPreferencesInner(
              (p) => p
                ..libraryId = 'library-1'
                ..folderId = null
                ..layout = UserPreferencesFolderPreferencesInnerLayoutEnum.grid
                ..sort = UserPreferencesFolderPreferencesInnerSortEnum.size
                ..order = UserPreferencesFolderPreferencesInnerOrderEnum.desc,
            ),
          ),
      );
      final adapter = _FolderAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = adapter;
      final api = BrianiApi(dio: dio)
        ..setBearerAuth('AccessToken', 'session-token');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeApiProvider.overrideWithValue(api),
            userPreferencesProvider.overrideWith(_Preferences.new),
          ],
          child: const MaterialApp(home: FolderScreen(libraryId: 'library-1')),
        ),
      );
      await tester.pumpAndSettle();

      final entriesRequest = adapter.requests.singleWhere(
        (request) => request.path.endsWith('/entries'),
      );
      expect(entriesRequest.queryParameters['sort'], 'size');
      expect(entriesRequest.queryParameters['order'], 'desc');
      // The saved grid layout renders files in a lazily built sliver grid.
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Example.mkv'), findsNothing);
    },
  );

  testWidgets('Most seeded sorts seeders descending and stores its mode view', (
    tester,
  ) async {
    _fixturePreferences = defaultUserPreferences();
    final adapter = _DiscoveryAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeApiProvider.overrideWithValue(api),
          userPreferencesProvider.overrideWith(_Preferences.new),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most seeded'));
    await tester.pumpAndSettle();
    expect(adapter.queries.last['sort'], 'seeders');
    expect(adapter.queries.last['order'], 'desc');
    expect(
      _fixturePreferences.discoveryViews?.any(
        (view) => view.mode.name == 'mostSeeded',
      ),
      isTrue,
    );
  });

  testWidgets('administration exposes curated discovery scope controls', (
    tester,
  ) async {
    final adapter = _AdminAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientSessionProvider.overrideWith(() => _AdminSession(api)),
        ],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Discovery scope'),
      500,
      scrollable: find.descendant(
        of: find.byType(ListView).first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(find.text('Discovery scope'), findsOneWidget);
    expect(
      find.textContaining('server enforces this scope for every user'),
      findsOneWidget,
    );
    final providerScope = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Providers scope',
    );
    await tester.ensureVisible(providerScope);
    await tester.pumpAndSettle();
    await tester.tap(providerScope);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected IDs').last);
    await tester.pumpAndSettle();
    expect(find.text('Provider IDs'), findsOneWidget);
    expect(find.byTooltip('Choose configured provider IDs'), findsOneWidget);
  });
}
