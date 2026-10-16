import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/discover/discover_screen.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rename keeps its value and controller through route dismissal',
      (tester) async {
    final adapter = _DialogAdapter();
    await tester.pumpWidget(_app(FolderScreen(libraryId: 'lib-1'), adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed.mkv');
    await tester.tap(find.text('Rename').last);

    await _pumpDialogExit(tester);
    await tester.pumpAndSettle();
    expect(adapter.renameBody?['name'], 'Renamed.mkv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('magnet cancel dismisses cleanly without creating a download',
      (tester) async {
    final adapter = _DialogAdapter();
    await tester.pumpWidget(_app(const DiscoverScreen(), adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Magnet link…'));
    await tester.pumpAndSettle();
    expect(find.text('Add magnet link'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'magnet:?xt=test');
    await tester.tap(find.text('Cancel').last);

    await _pumpDialogExit(tester);
    await tester.pumpAndSettle();
    expect(adapter.createDownloadCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved download settings survive dialog exit and preserve values',
      (tester) async {
    final adapter = _DialogAdapter();
    await tester.pumpWidget(
      _app(const DownloadDetailsScreen(requestId: 'download-1'), adapter),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Transfer settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Download limit (bytes/sec)'),
      '4096',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Upload limit (bytes/sec)'),
      '1024',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Seed time limit (minutes)'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tags (comma-separated)'),
      'tv, favorites',
    );
    expect(find.text('4096'), findsOneWidget);
    expect(find.text('tv, favorites'), findsOneWidget);
    await tester.tap(find.text('Save').last);

    await _pumpDialogExit(tester);
    expect(find.text('Transfer settings'), findsNothing);
    await tester.pumpAndSettle();
    expect(adapter.settingsPatch?['downloadLimitBytesPerSecond'], 4096);
    expect(adapter.settingsPatch?['tags'], ['tv', 'favorites']);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDialogExit(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 40));
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 220));
  expect(tester.takeException(), isNull);
}

Widget _app(Widget child, _DialogAdapter adapter) => ProviderScope(
      overrides: [
        activeApiProvider.overrideWithValue(
          BrianiApi(
            dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
              ..httpClientAdapter = adapter,
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );

class _DialogAdapter implements HttpClientAdapter {
  Map<String, dynamic>? renameBody;
  Map<String, dynamic>? settingsPatch;
  var createDownloadCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;
    Object body;
    if (path.endsWith('/libraries') && method == 'GET') {
      body = [_library];
    } else if (path.endsWith('/entries')) {
      body = {
        'items': [_entry],
        'nextCursor': null,
        'totalKnown': 1,
        'truncated': false,
        'warnings': [],
      };
    } else if (path.endsWith('/media/media-1/rename')) {
      renameBody = Map<String, dynamic>.from(options.data as Map);
      body = _completedOperation;
    } else if (path.endsWith('/discovery/providers')) {
      body = [];
    } else if (path.endsWith('/discovery/queries')) {
      body = {
        'id': 'snapshot-1',
        'state': 'complete',
        'createdAt': '2026-10-12T00:00:00Z',
        'expiresAt': '2026-10-12T01:00:00Z',
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      };
    } else if (path.endsWith('/downloads/download-1') && method == 'GET') {
      body = _download;
    } else if (path.endsWith('/downloads/download-1/files')) {
      body = [];
    } else if (path.endsWith('/downloads/download-1/settings') && method == 'GET') {
      body = _settings;
    } else if (path.endsWith('/downloads/download-1/settings') && method == 'PATCH') {
      settingsPatch = Map<String, dynamic>.from(options.data as Map);
      body = settingsPatch!;
    } else if (path.endsWith('/downloads') && method == 'POST') {
      createDownloadCount++;
      body = _download;
    } else if (path.endsWith('/operations/op-1')) {
      body = _completedOperation;
    } else {
      body = {'title': 'Not found', 'status': 404};
    }

    final status = body is Map<String, dynamic> &&
            body['status'] == 404
        ? 404
        : 200;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

final _library = {
  'id': 'lib-1',
  'name': 'Fixture library',
  'description': '',
  'readOnly': false,
  'enabled': true,
  'version': 1,
  'capabilities': {'read': true, 'download': true, 'manage': true},
};

final _entry = {
  'id': 'entry-1',
  'libraryId': 'lib-1',
  'parentId': null,
  'kind': 'video',
  'name': 'Example.mkv',
  'sizeBytes': 100,
  'modifiedAt': '2026-10-12T00:00:00Z',
  'mediaId': 'media-1',
  'thumbnailAvailable': false,
  'version': 1,
};

final _completedOperation = {
  'id': 'op-1',
  'state': 'completed',
  'createdAt': '2026-10-12T00:00:00Z',
  'updatedAt': '2026-10-12T00:00:00Z',
};

final _download = {
  'id': 'download-1',
  'libraryId': 'lib-1',
  'ownerId': 'user-1',
  'name': 'Fixture download',
  'state': 'downloading',
  'selectedBytes': 100,
  'downloadedSelectedBytes': 20,
  'torrentBytes': 100,
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
  'tags': [],
  'sourceState': 'ready',
  'transferState': 'downloading',
  'importState': 'notReady',
};

final _settings = {
  'version': 1,
  'downloadLimitBytesPerSecond': 2048,
  'uploadLimitBytesPerSecond': null,
  'ratioLimit': null,
  'seedTimeMinutes': null,
  'queuePosition': 1,
  'tags': ['existing'],
};
