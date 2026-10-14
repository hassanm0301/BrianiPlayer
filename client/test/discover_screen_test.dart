import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/discover/discover_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
    expect(find.text('Seeders —'), findsOneWidget);
    expect(find.text('Leechers —'), findsOneWidget);
    expect(find.text('Peers —'), findsOneWidget);
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
}

class _DiscoveryAdapter implements HttpClientAdapter {
  _DiscoveryAdapter({this.providerFailure = false});
  final bool providerFailure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
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
    if (path.endsWith('/discovery/providers') || path.endsWith('/libraries')) {
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
            'downloadable': false,
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
