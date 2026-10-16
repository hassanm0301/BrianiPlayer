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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
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
