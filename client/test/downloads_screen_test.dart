import 'dart:convert';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/downloads/download_formatters.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
      expect(find.text('Downloads could not be loaded'), findsOneWidget);
      expect(
        find.text('No downloads yet. Discover a release or add a magnet.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'TV remote opens a download, toggles a file and reaches Save selection',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DownloadsScreen()),
          GoRoute(
            path: '/downloads/:id',
            builder: (_, state) =>
                DownloadDetailsScreen(requestId: state.pathParameters['id']!),
          ),
        ],
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = _SelectionAdapter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeApiProvider.overrideWithValue(BrianiApi(dio: dio))],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => RemoteNavigationScope(
              television: true,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(navigationMode: NavigationMode.directional),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<bool> moveDownUntil(bool Function() focused) async {
        for (var i = 0; i < 20 && !focused(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        return focused();
      }

      expect(
        await moveDownUntil(() => _focusInside(find.byType(Card))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Download details'), findsOneWidget);
      expect(find.text('Episode 1.mkv'), findsOneWidget);

      final checkbox = find.byType(Checkbox).first;
      expect(await moveDownUntil(() => _focusInside(checkbox)), isTrue);
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);

      final save = find.widgetWithText(
        FilledButton,
        'Save selection and start',
      );
      expect(await moveDownUntil(() => _focusInside(save)), isTrue);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}

bool _focusInside(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var inside = false;
  focused.visitAncestorElements((ancestor) {
    inside = targets.contains(ancestor);
    return !inside;
  });
  return inside;
}

class _SelectionAdapter implements HttpClientAdapter {
  static const _download = {
    'id': 'dl-1',
    'libraryId': 'library-1',
    'ownerId': 'owner-1',
    'name': 'Season pack',
    'state': 'awaitingSelection',
    'selectedBytes': null,
    'downloadedSelectedBytes': 0,
    'torrentBytes': 300,
    'downloadBps': 0,
    'uploadBps': 0,
    'seedersConnected': null,
    'peersConnected': null,
    'etaSeconds': null,
    'sequential': true,
    'firstLastMetadataAssist': true,
    'generation': 'generation-1',
    'version': 1,
    'errorCode': null,
    'errorDetail': null,
    'createdAt': '2026-10-12T00:00:00Z',
    'updatedAt': '2026-10-12T00:00:00Z',
    'tags': <String>[],
    'sourceState': 'ready',
    'transferState': 'metadata',
    'importState': 'notReady',
  };

  static Map<String, Object?> _file(String id, String name) => {
    'id': id,
    'downloadId': 'dl-1',
    'name': name,
    'relativePath': name,
    'sizeBytes': 100,
    'downloadedBytes': 0,
    'contiguousBytes': 0,
    'kind': 'video',
    'selected': false,
    'priority': 'normal',
    'playbackState': 'notSelected',
    'version': 1,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final Object body = switch (path) {
      _ when path.endsWith('/libraries') => [
        {
          'id': 'library-1',
          'name': 'Shows',
          'description': '',
          'readOnly': false,
          'enabled': true,
          'version': 1,
          'capabilities': {'read': true, 'download': true, 'manage': false},
        },
      ],
      _ when path.endsWith('/files') => [
        _file('file-1', 'Episode 1.mkv'),
        _file('file-2', 'Episode 2.mkv'),
      ],
      _ when path.endsWith('/settings') => {'version': 1, 'tags': <String>[]},
      _ when path.endsWith('/downloads') => {
        'items': [_download],
        'nextCursor': null,
        'totalKnown': 1,
        'truncated': false,
        'warnings': <String>[],
      },
      _ => _download,
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
