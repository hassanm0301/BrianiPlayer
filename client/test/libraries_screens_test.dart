import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:briani_player/features/libraries/libraries_screen.dart';
import 'package:briani_player/features/photos/photo_viewer_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.response);
  final Object response;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(response),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _MoveAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> moveRequests = [];
  final List<Object?> folderPageCursors = [];
  final List<Object?> nestedFolderRequests = [];
  final List<Object?> folderNextCursorPayloads = [];
  int operationPolls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object data;
    if (options.path.endsWith('/entries')) {
      if (options.queryParameters['kind'] == 'folder') {
        final parent = options.queryParameters['folderId'];
        if (parent != null) nestedFolderRequests.add(parent);
        final cursor = options.queryParameters['cursor'];
        folderPageCursors.add(cursor);
        final folders = parent != null
            ? [
                {
                  'id': 'nested-destination',
                  'libraryId': 'lib-1',
                  'parentId': parent,
                  'kind': 'folder',
                  'name': 'Nested destination',
                  'thumbnailAvailable': false,
                  'version': 1,
                },
              ]
            : cursor == null
            ? List.generate(
                50,
                (index) => {
                  'id': 'folder-$index',
                  'libraryId': 'lib-1',
                  'parentId': null,
                  'kind': 'folder',
                  'name': 'Folder $index',
                  'thumbnailAvailable': false,
                  'version': 1,
                },
              )
            : [
                {
                  'id': 'folder-later',
                  'libraryId': 'lib-1',
                  'parentId': null,
                  'kind': 'folder',
                  'name': 'Later folder',
                  'thumbnailAvailable': false,
                  'version': 1,
                },
              ];
        data = {
          'items': folders,
          'nextCursor': parent == null && cursor == null ? 'next-page' : null,
          'totalKnown': folders.length,
          'truncated': false,
          'warnings': [],
        };
        folderNextCursorPayloads.add(
          (data as Map<String, dynamic>)['nextCursor'],
        );
      } else {
        data = {
          'items': [
            {
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
            },
          ],
          'nextCursor': null,
          'totalKnown': 1,
          'truncated': false,
          'warnings': [],
        };
      }
    } else if (options.path.endsWith('/move')) {
      moveRequests.add(Map<String, dynamic>.from(options.data as Map));
      data = {
        'id': 'op-1',
        'state': 'pending',
        'createdAt': '2026-10-12T00:00:00Z',
        'updatedAt': '2026-10-12T00:00:00Z',
      };
    } else if (options.path.endsWith('/operations/op-1')) {
      operationPolls++;
      data = {
        'id': 'op-1',
        'state': 'completed',
        'createdAt': '2026-10-12T00:00:00Z',
        'updatedAt': '2026-10-12T00:00:00Z',
      };
    } else {
      data = [
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

class _PathAdapter implements HttpClientAdapter {
  _PathAdapter(this.libraries, {this.entries = const []});
  final Object libraries;
  final List<Object?> entries;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.path.endsWith('/entries')
        ? {
            'items': entries,
            'nextCursor': null,
            'totalKnown': 0,
            'truncated': false,
            'warnings': [],
          }
        : libraries;
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

class _PhotoFailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/image')) {
      return ResponseBody.fromString(
        jsonEncode({'title': 'Not ready'}),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'media-1',
        'libraryId': 'lib-1',
        'entryId': 'entry-1',
        'name': 'Photo.jpg',
        'kind': 'photo',
        'mimeType': 'image/jpeg',
        'sizeBytes': 10,
        'complete': true,
        'probeState': 'ready',
        'version': 1,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _app(Widget child, {Object response = const []}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = _FixtureAdapter(response);
  final api = BrianiApi(dio: dio);
  api.setBearerAuth('AccessToken', 'test-access-token');
  return ProviderScope(
    overrides: [activeApiProvider.overrideWithValue(api)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('mounted libraries tolerate a disconnected API transition', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _FixtureAdapter(const []);
    BrianiApi? current = BrianiApi(dio: dio);
    final container = ProviderContainer(overrides: [
      activeApiProvider.overrideWith((ref) => current),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: LibrariesScreen())));
    await tester.pumpAndSettle();
    expect(find.text('No libraries are available to this account.'), findsOneWidget);
    current = null;
    container.invalidate(activeApiProvider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No libraries are available to this account.'), findsNothing);
  });
  testWidgets(
    'libraries show a useful empty state when the account has no grants',
    (tester) async {
      await tester.pumpWidget(_app(const LibrariesScreen()));
      await tester.pumpAndSettle();
      expect(
        find.text('No libraries are available to this account.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('folder shows its empty state after a successful page response', (
    tester,
  ) async {
    final response = [
      {
        'id': 'lib-1',
        'name': 'Films',
        'description': '',
        'readOnly': true,
        'enabled': true,
        'version': 1,
        'capabilities': {'read': true, 'download': false, 'manage': false},
      },
    ];
    // The fixture adapter returns the library list for both requests, so use a
    // focused adapter response with an empty entry page via the request path.
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _PathAdapter(response);
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FolderScreen(libraryId: 'lib-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This folder is empty.'), findsOneWidget);
  });

  testWidgets('folder shows the supplied full breadcrumb ancestry', (
    tester,
  ) async {
    final api = BrianiApi(
      dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = _PathAdapter([
          {
            'id': 'lib-1',
            'name': 'Films',
            'description': '',
            'readOnly': true,
            'enabled': true,
            'version': 1,
            'capabilities': {'read': true, 'download': false, 'manage': false},
          },
        ]),
    )..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: FolderScreen(
            libraryId: 'lib-1',
            folderId: 'leaf',
            breadcrumbs: const [
              FolderBreadcrumb(id: 'root', name: 'Films'),
              FolderBreadcrumb(id: 'a', name: 'Season 1'),
              FolderBreadcrumb(id: 'b', name: 'Extras'),
              FolderBreadcrumb(id: 'leaf', name: 'Behind the scenes'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Films'), findsWidgets);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Extras'), findsOneWidget);
    expect(find.text('Behind the scenes'), findsOneWidget);
  });

  testWidgets('read-only library entries do not offer mutation controls', (
    tester,
  ) async {
    final response = [
      {
        'id': 'lib-1',
        'name': 'Films',
        'description': '',
        'readOnly': true,
        'enabled': true,
        'version': 1,
        'capabilities': {'read': true, 'download': false, 'manage': false},
      },
    ];
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = _PathAdapter(
        response,
        entries: [
          {
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
          },
        ],
      );
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FolderScreen(libraryId: 'lib-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example.mkv'), findsOneWidget);
    expect(find.byTooltip('File actions'), findsNothing);
  });

  testWidgets('cancelling a move never sends a mutation request', (
    tester,
  ) async {
    final adapter = _MoveAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FolderScreen(libraryId: 'lib-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(adapter.moveRequests, isEmpty);
  });

  testWidgets('selecting library root explicitly moves to a null folder id', (
    tester,
  ) async {
    final adapter = _MoveAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FolderScreen(libraryId: 'lib-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select library root'));
    await tester.pumpAndSettle();
    expect(adapter.moveRequests, hasLength(1));
    expect(adapter.moveRequests.single, containsPair('version', 1));
    expect(adapter.moveRequests.single['targetFolderId'], isNull);
    expect(adapter.operationPolls, 1);
  });

  testWidgets('move picker loads later pages and browses nested folders', (
    tester,
  ) async {
    final adapter = _MoveAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FolderScreen(libraryId: 'lib-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move').last);
    await tester.pumpAndSettle();
    expect(adapter.folderPageCursors, isNotEmpty);
    expect(adapter.folderNextCursorPayloads, contains('next-page'));
    expect(find.text('No subfolders here.'), findsNothing);
    await tester.tap(find.text('Load more folders'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Later folder'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Later folder'));
    await tester.pumpAndSettle();
    expect(find.text('Nested destination'), findsOneWidget);
    expect(adapter.folderPageCursors, contains('next-page'));
    expect(adapter.nestedFolderRequests, contains('folder-later'));
  });

  testWidgets(
    'photo viewer reports an unavailable authorized image and offers retry',
    (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = _PhotoFailureAdapter();
      final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: PhotoViewerScreen(mediaId: 'media-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'A required service or media data is not ready. Retry shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('Flutter decodes the generated EXIF-oriented JPEG upright', (
    tester,
  ) async {
    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File('test/fixtures/exif_orientation_6.jpg').readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      final dimensions = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return dimensions;
    });
    // The generated source is 3x2 with EXIF orientation 6 (rotate 90°).
    expect(decoded, (2, 3));
  });
}
