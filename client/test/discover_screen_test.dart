import 'dart:convert';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/discover/discover_results.dart';
import 'package:briani_player/features/discover/discover_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('discovery preserves unknown counts instead of showing zero', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _DiscoveryAdapter();
    final api = BrianiApi(dio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example release'), findsOneWidget);
    // Counts render as an icon plus value; each is labelled for assistive
    // technology, and unknown values stay an em dash rather than zero.
    expect(_metric('Seeders —'), findsOneWidget);
    expect(_metric('Leechers —'), findsOneWidget);
    expect(_metric('Peers —'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.text('0'), findsNothing);
  });

  testWidgets(
    'provider lookup failure is visible while query results still load',
    (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = _DiscoveryAdapter(providerFailure: true);
      final api = BrianiApi(dio: dio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: DiscoverScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Example release'), findsOneWidget);
      expect(
        find.textContaining('Provider details are unavailable'),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing download library shows the server explanation once', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _DiscoveryAdapter(discoveryForbidden: true);
    final api = BrianiApi(dio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Provider details are unavailable'),
      findsNothing,
    );
    expect(find.text('Retry providers'), findsNothing);
    expect(find.text(_noLibrary), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('TV remote reaches a result and opens Add download', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _DiscoveryAdapter(downloadable: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(BrianiApi(dio: dio))],
        child: _television(const DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 12 && !_focusInside<DiscoveryResultTile>(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(_focusInside<DiscoveryResultTile>(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add download'), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Add download'), findsNothing);
  });

  testWidgets('Enter in the desktop search bar submits the search', (
    tester,
  ) async {
    final adapter = _DiscoveryAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(BrianiApi(dio: dio))],
        child: _desktop(const DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();
    expect(find.text('Search your indexers'), findsOneWidget);
    adapter.queries.clear();

    await tester.tap(find.byType(SearchBar));
    await tester.enterText(find.byType(SearchBar), 'ubuntu');
    await tester.pump();
    expect(find.text('Search your indexers'), findsNothing);
    expect(find.text('Ready to search'), findsOneWidget);

    // The app-wide remote bindings must leave Enter to the text field so the
    // platform text input turns it into the field's search action.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(adapter.queries, hasLength(1));
    expect(adapter.queries.single['mode'], 'search');
    expect(adapter.queries.single['query'], 'ubuntu');
    expect(find.text('Example release'), findsWidgets);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Example release'), findsWidgets);
  });

  testWidgets('Ready to search offers a Search button', (tester) async {
    final adapter = _DiscoveryAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(BrianiApi(dio: dio))],
        child: _desktop(const DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();
    adapter.queries.clear();
    await tester.enterText(find.byType(SearchBar), 'ubuntu');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();
    expect(adapter.queries.single['query'], 'ubuntu');
    expect(find.text('Example release'), findsWidgets);
  });

  testWidgets('Enter still activates a focused button', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _desktop(
        Scaffold(
          body: FilledButton(
            autofocus: true,
            onPressed: () => pressed++,
            child: const Text('Go'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });
}

Finder _metric(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

const _noLibrary = 'Discovery needs a library to download into.';

const _downloadLibrary = {
  'id': 'library-1',
  'name': 'Films',
  'description': '',
  'readOnly': false,
  'enabled': true,
  'version': 1,
  'capabilities': {'read': true, 'download': true, 'manage': false},
};

/// Wraps [home] the way the app does on Android TV: D-pad navigation mode and
/// the shared remote key bindings.
Widget _television(Widget home) => MaterialApp(
  builder: (context, child) => RemoteNavigationScope(
    television: true,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(navigationMode: NavigationMode.directional),
      child: child!,
    ),
  ),
  home: home,
);

/// Wraps [home] the way the app does on desktop: the shared remote key
/// bindings without D-pad navigation mode.
Widget _desktop(Widget home) => MaterialApp(
  builder: (context, child) => RemoteNavigationScope(child: child!),
  home: home,
);

bool _focusInside<T extends Widget>() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      (context.widget is T ||
          context.findAncestorWidgetOfExactType<T>() != null);
}

class _DiscoveryAdapter implements HttpClientAdapter {
  _DiscoveryAdapter({
    this.providerFailure = false,
    this.discoveryForbidden = false,
    this.downloadable = false,
  });
  final bool providerFailure;
  final bool discoveryForbidden;
  final bool downloadable;
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.endsWith('/discovery/queries') && requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      queries.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    }
    if (discoveryForbidden && path.contains('/discovery/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'title': _noLibrary,
          'status': 403,
          'code': 'forbidden',
          'detail': _noLibrary,
        }),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/discovery/providers') && providerFailure) {
      return ResponseBody.fromString(
        jsonEncode({'title': 'Offline', 'status': 503}),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final Object body;
    if (path.endsWith('/libraries') && downloadable) {
      body = [_downloadLibrary];
    } else if (path.endsWith('/discovery/providers') ||
        path.endsWith('/libraries')) {
      body = [];
    } else if (path.endsWith('/discovery/queries')) {
      body = {
        'id': 'snapshot-1',
        'state': 'complete',
        'createdAt': '2026-10-12T00:00:00Z',
        'expiresAt': '2026-10-12T01:00:00Z',
        'items': [
          {
            'id': 'result-1',
            'title': 'Example release',
            'sizeBytes': null,
            'seeders': null,
            'leechers': null,
            'peers': null,
            'providerId': 'provider-1',
            'providerName': 'Example provider',
            'publishedAt': null,
            'fetchedAt': '2026-10-12T00:00:00Z',
            'stale': false,
            'downloadable': downloadable,
            'categories': [],
          },
        ],
        'nextCursor': null,
        'totalKnown': 1,
        'truncated': false,
        'warnings': [],
      };
    } else {
      body = {'title': 'Not found', 'status': 404};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      path.endsWith('/discovery/queries') ||
              path.endsWith('/libraries') ||
              path.endsWith('/discovery/providers')
          ? 200
          : 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
