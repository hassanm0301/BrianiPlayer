import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/downloads/download_formatters.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown transfer values stay unknown', () {
    expect(formatCount(null), '—');
    expect(formatCount(-1), '—');
    expect(formatBytes(null), '—');
    expect(formatBytes(-1), '—');
  });

  testWidgets(
    'partial download snapshot shows its warning rather than a successful empty state',
    (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = _DownloadsAdapter();
      final api = BrianiApi(dio: dio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: DownloadsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The server returned only part of this page.'),
        findsOneWidget,
      );
      expect(find.text('Downloads could not be loaded.'), findsOneWidget);
      expect(
        find.text('No downloads yet. Discover a release or add a magnet.'),
        findsNothing,
      );
    },
  );
}

class _DownloadsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = {
      'items': [],
      'nextCursor': null,
      'totalKnown': null,
      'truncated': false,
      'warnings': ['The server returned only part of this page.'],
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
