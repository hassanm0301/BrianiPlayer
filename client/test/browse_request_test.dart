import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:briani_player/features/discover/discover_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/input/route_activity.dart';
import 'package:briani_player/features/libraries/libraries_screen.dart';

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
Widget app(
  Widget screen,
  Adapter adapter, {
  UserPreferencesController Function()? preferences,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  return ProviderScope(
    overrides: [
      activeApiProvider.overrideWithValue(BrianiApi(dio: dio)),
      if (preferences != null)
        userPreferencesProvider.overrideWith(preferences),
    ],
    child: MaterialApp(home: screen),
  );
}

/// A Discover mode segment (Latest / Most seeded / Search).
Finder _discoveryMode(String label) => find.descendant(
  of: find.byType(SegmentedButton<String>),
  matching: find.text(label),
);

void main() {
  for (final option in {
    'Recently changed': 'date',
    'Largest first': 'size',
  }.entries) {
    testWidgets(
      'sort ${option.key} sends a supported wire value and keeps content',
      (t) async {
        final sorts = <Object?>[];
        final adapter = Adapter((o) {
          if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
          final sort = o.queryParameters['sort'];
          sorts.add(sort);
          // This is the whitelist enforced by LibraryQueries.cs:53-55.
          if (!{'name', 'date', 'size'}.contains(sort)) {
            return jsonResponse({
              'status': 400,
              'code': 'validation_failed',
              'title': 'Invalid sort',
            }, 400);
          }
          return jsonResponse(page([entry('Visible film.mkv')]));
        });
        await t.pumpWidget(
          app(const FolderScreen(libraryId: 'lib-1'), adapter),
        );
        await t.pumpAndSettle();
        expect(find.text('Visible film.mkv'), findsOneWidget);
        await t.tap(find.byTooltip('Sort'));
        await t.pumpAndSettle();
        await t.tap(find.text(option.key));
        await t.pumpAndSettle();
        expect(sorts.last, option.value);
        expect(find.text('Invalid sort'), findsNothing);
        expect(find.text('This folder is empty.'), findsNothing);
        expect(find.text('Visible film.mkv'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('late folder search cannot overwrite newer results', (t) async {
    final older = Completer<ResponseBody>();
    final adapter = Adapter((o) {
      if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
      final query = o.queryParameters['query'];
      if (query == 'older') return older.future;
      return jsonResponse(
        page([entry(query == 'newer' ? 'New result.mkv' : 'Initial.mkv')]),
      );
    });
    await t.pumpWidget(app(const FolderScreen(libraryId: 'lib-1'), adapter));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'older');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.enterText(find.byType(TextField), 'newer');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('New result.mkv'), findsOneWidget);
    older.complete(jsonResponse(page([entry('Old result.mkv')])));
    await t.pumpAndSettle();
    expect(find.text('Old result.mkv'), findsNothing);
    expect(find.text('New result.mkv'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'newer',
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('old discovery page cannot contaminate a new query', (t) async {
    final oldPage = Completer<ResponseBody>();
    var queries = 0;
    final adapter = Adapter((o) {
      if (o.path.endsWith('/libraries') || o.path.endsWith('/providers')) {
        return jsonResponse([]);
      }
      if (o.path.endsWith('/queries')) {
        queries++;
        return jsonResponse(
          queries == 1
              ? snapshot('old-query', 'Old first result', cursor: 'old-page-2')
              : snapshot('new-query', 'New query result'),
        );
      }
      return oldPage.future;
    });
    await t.pumpWidget(app(const DiscoverScreen(), adapter));
    await t.pumpAndSettle();
    await t.tap(find.text('Load next page'));
    await t.pump();
    await t.tap(find.text('Most seeded'));
    await t.pumpAndSettle();
    expect(find.text('New query result'), findsOneWidget);
    oldPage.complete(jsonResponse(snapshot('old-query', 'Old second result')));
    await t.pumpAndSettle();
    expect(find.text('Old second result'), findsNothing);
    expect(find.text('New query result'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('failed folder refresh retains loaded entries and offers retry', (
    t,
  ) async {
    final refresh = Completer<ResponseBody>();
    final adapter = Adapter((o) {
      if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
      if (o.queryParameters['query'] == 'refresh') return refresh.future;
      return jsonResponse(page([entry('Keep visible.mkv')]));
    });
    await t.pumpWidget(app(const FolderScreen(libraryId: 'lib-1'), adapter));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'refresh');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.text('Keep visible.mkv'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    refresh.complete(jsonResponse({'status': 503, 'title': 'Offline'}, 503));
    await t.pumpAndSettle();
    expect(find.text('Keep visible.mkv'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('This folder is empty.'), findsNothing);
    expect(find.text('No matching files.'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('failed initial folder load never reports an empty folder', (
    t,
  ) async {
    final adapter = Adapter(
      (o) => o.path.endsWith('/libraries')
          ? jsonResponse(libraries)
          : jsonResponse({'status': 503, 'title': 'Offline'}, 503),
    );
    await t.pumpWidget(app(const FolderScreen(libraryId: 'lib-1'), adapter));
    await t.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('This folder is empty.'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('switching to Search cancels a pending discovery page', (
    t,
  ) async {
    final pending = Completer<ResponseBody>();
    final adapter = Adapter((o) {
      if (o.path.endsWith('/libraries') || o.path.endsWith('/providers')) {
        return jsonResponse([]);
      }
      if (o.path.endsWith('/queries')) {
        return jsonResponse(snapshot('initial', 'Initial', cursor: 'page2'));
      }
      return pending.future;
    });
    await t.pumpWidget(app(const DiscoverScreen(), adapter));
    await t.pumpAndSettle();
    await t.tap(find.text('Load next page'));
    await t.pump();
    await t.tap(_discoveryMode('Search'));
    await t.pump();
    expect(find.text('Enter a torrent name to search.'), findsOneWidget);
    pending.complete(jsonResponse(snapshot('initial', 'Outdated page')));
    await t.pumpAndSettle();
    expect(find.text('Outdated page'), findsNothing);
    expect(find.text('Load next page'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'late preferences preserve the discovery mode chosen by the user',
    (t) async {
      final adapter = Adapter((o) {
        if (o.path.endsWith('/libraries') || o.path.endsWith('/providers')) {
          return jsonResponse([]);
        }
        return jsonResponse(snapshot('initial', 'Initial'));
      });
      await t.pumpWidget(
        app(
          const DiscoverScreen(),
          adapter,
          preferences: _DelayedPreferences.new,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(_discoveryMode('Search'));
      await t.pump();
      _delayedPreferences.complete(defaultUserPreferences());
      await t.pumpAndSettle();
      expect(
        t
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'search'},
      );
      expect(find.text('Enter a torrent name to search.'), findsOneWidget);
      expect(find.text('Initial'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late preferences do not reset a folder sort chosen by the user',
    (t) async {
      final sorts = <Object?>[];
      final adapter = Adapter((o) {
        if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
        sorts.add(o.queryParameters['sort']);
        return jsonResponse(page([entry('Film.mkv')]));
      });
      await t.pumpWidget(
        app(
          const FolderScreen(libraryId: 'lib-1'),
          adapter,
          preferences: _DelayedPreferences.new,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Sort'));
      await t.pumpAndSettle();
      await t.tap(find.text('Largest first'));
      await t.pumpAndSettle();
      expect(sorts.last, 'size');
      final requestsBeforePreferences = sorts.length;
      _delayedPreferences.complete(defaultUserPreferences());
      await t.pumpAndSettle();
      expect(sorts.length, requestsBeforePreferences);
      expect(sorts.last, 'size');
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Continue Watching refreshes after Libraries becomes visible again',
    (t) async {
      var calls = 0;
      var visible = true;
      late StateSetter updateVisibility;
      final adapter = Adapter((o) {
        if (o.path.endsWith('/libraries')) return jsonResponse(libraries);
        calls++;
        return jsonResponse(page([]));
      });
      await t.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              updateVisibility = setState;
              return RouteActivity(
                visible: visible,
                child: const LibrariesScreen(),
              );
            },
          ),
          adapter,
        ),
      );
      await t.pumpAndSettle();
      expect(calls, 1);
      updateVisibility(() => visible = false);
      await t.pumpAndSettle();
      expect(calls, 1);
      updateVisibility(() => visible = true);
      await t.pumpAndSettle();
      expect(calls, 2);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('library grid uses responsive lazy slivers at large text scale', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final adapter = Adapter(
      (o) => jsonResponse(
        List.generate(
          100,
          (index) => {
            ...libraries.single,
            'id': 'library-$index',
            'name': 'Library ${index.toString().padLeft(3, '0')}',
          },
        ),
      ),
    );
    await t.pumpWidget(
      app(const LibrariesScreen(), adapter, preferences: _GridPreferences.new),
    );
    await t.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    final grid = t.widget<SliverGrid>(find.byType(SliverGrid));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    expect(find.byType(Card).evaluate().length, lessThan(20));
    expect(find.text('Library 099'), findsNothing);
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(find.text('Library 099'), 1000);
    expect(find.text('Library 099'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}

late _DelayedPreferences _delayedPreferences;

class _DelayedPreferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() {
    _delayedPreferences = this;
    return const AsyncLoading();
  }

  void complete(UserPreferences preferences) => state = AsyncData(preferences);
}

class _GridPreferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(
    defaultUserPreferences().rebuild(
      (b) => b
        ..libraryLayout = UserPreferencesLibraryLayoutEnum.grid
        ..showContinueWatching = false,
    ),
  );
}
