import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/core/widgets/playback_seek_bar.dart';
import 'package:briani_player/features/downloads/downloads_screen.dart';
import 'package:briani_player/features/photos/photo_viewer_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InteractionAdapter implements HttpClientAdapter {
  _InteractionAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Widget _app(Widget screen, _InteractionAdapter adapter) => ProviderScope(
  overrides: [
    activeApiProvider.overrideWithValue(
      BrianiApi(
        dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
          ..httpClientAdapter = adapter,
      ),
    ),
  ],
  child: MaterialApp(home: screen),
);

Map<String, Object?> _download(int index) => {
  'id': 'download-$index',
  'libraryId': 'library-1',
  'ownerId': 'owner',
  'name': 'Download ${index.toString().padLeft(3, '0')}',
  'state': 'downloading',
  'selectedBytes': 100,
  'downloadedSelectedBytes': 20,
  'torrentBytes': 100,
  'downloadBps': 10,
  'uploadBps': 0,
  'sequential': true,
  'firstLastMetadataAssist': true,
  'generation': 'generation-1',
  'version': 1,
  'createdAt': '2026-10-14T00:00:00Z',
  'updatedAt': '2026-10-14T00:00:00Z',
  'tags': <String>[],
  'sourceState': 'ready',
  'transferState': 'downloading',
  'importState': 'notReady',
};

Map<String, Object?> _page(List<Object?> items, {String? cursor}) => {
  'items': items,
  'nextCursor': cursor,
  'totalKnown': null,
  'truncated': false,
  'warnings': <String>[],
};

void main() {
  testWidgets('seek drag previews without seeking until the gesture ends', (
    tester,
  ) async {
    final seeks = <Duration>[];
    Widget seekBar(Duration position) => MaterialApp(
      home: Scaffold(
        body: PlaybackSeekBar(
          position: position,
          duration: const Duration(seconds: 100),
          onSeek: seeks.add,
        ),
      ),
    );
    await tester.pumpWidget(seekBar(Duration.zero));
    final bounds = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(bounds.left + 24, bounds.center.dy),
    );
    await gesture.moveTo(bounds.center);
    await tester.pump();
    final firstPreview = tester.widget<Slider>(find.byType(Slider)).value;
    expect(firstPreview, greaterThan(20000));
    expect(seeks, isEmpty);
    // Incoming player position updates must not replace an active drag preview.
    await tester.pumpWidget(seekBar(const Duration(seconds: 1)));
    expect(tester.widget<Slider>(find.byType(Slider)).value, firstPreview);
    await gesture.moveTo(
      Offset(bounds.left + bounds.width * .75, bounds.center.dy),
    );
    await tester.pump();
    final finalPreview = tester.widget<Slider>(find.byType(Slider)).value;
    expect(finalPreview, greaterThan(firstPreview));
    expect(seeks, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(seeks, [Duration(milliseconds: finalPreview.round())]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keyboard slider adjustment commits one seek', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSeekBar(
            position: const Duration(seconds: 10),
            duration: const Duration(seconds: 100),
            onSeek: seeks.add,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(seeks, hasLength(1));
    expect(seeks.single, greaterThan(const Duration(seconds: 10)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retained photo viewer updates media and adjacent navigation and stops slideshow',
    (tester) async {
      final bytes = File('test/fixtures/exif_orientation_6.jpg')
          .readAsBytesSync();
      final metadataRequests = <String>[];
      final imageRequests = <String>[];
      final adapter = _InteractionAdapter((options) {
        final components = options.path.split('/');
        final image = components.last == 'image';
        final id = image ? components[components.length - 2] : components.last;
        if (image) {
          imageRequests.add(id);
          return ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              Headers.contentTypeHeader: ['image/jpeg'],
            },
          );
        }
        metadataRequests.add(id);
        return _json({
          'id': id,
          'libraryId': 'library-1',
          'entryId': 'entry-$id',
          'name': '$id.jpg',
          'kind': 'photo',
          'mimeType': 'image/jpeg',
          'sizeBytes': bytes.length,
          'complete': true,
          'probeState': 'ready',
          'version': 1,
        });
      });
      var id = 'a';
      var adjacent = ['a', 'b'];
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PhotoViewerScreen(
                key: const ValueKey('retained-photo'),
                mediaId: id,
                adjacentMediaIds: adjacent,
              );
            },
          ),
          adapter,
        ),
      );
      await tester.pumpAndSettle();
      final originalState = tester.state(find.byType(PhotoViewerScreen));
      expect(find.text('a.jpg'), findsOneWidget);
      await tester.tap(find.byTooltip('Start slideshow'));
      await tester.pump();
      expect(find.byTooltip('Stop slideshow'), findsOneWidget);
      update(() {
        id = 'c';
        adjacent = ['b', 'c', 'd'];
      });
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(PhotoViewerScreen)), same(originalState));
      expect(find.text('c.jpg'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byTooltip('Start slideshow'), findsOneWidget);
      expect(metadataRequests.last, 'c');
      expect(imageRequests.last, 'c');
      await tester.pump(const Duration(seconds: 6));
      expect(imageRequests.last, 'c');
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('d.jpg'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      update(() {
        id = 'd';
        adjacent = ['d', 'e'];
      });
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(PhotoViewerScreen)), same(originalState));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('e.jpg'), findsOneWidget);
      expect(imageRequests.last, 'e');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'photo viewer arrow keys browse with wrap-around and Space toggles slideshow',
    (tester) async {
      final bytes = File('test/fixtures/exif_orientation_6.jpg')
          .readAsBytesSync();
      final imageRequests = <String>[];
      final adapter = _InteractionAdapter((options) {
        final components = options.path.split('/');
        final image = components.last == 'image';
        final id = image ? components[components.length - 2] : components.last;
        if (image) {
          imageRequests.add(id);
          return ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              Headers.contentTypeHeader: ['image/jpeg'],
            },
          );
        }
        return _json({
          'id': id,
          'libraryId': 'library-1',
          'entryId': 'entry-$id',
          'name': '$id.jpg',
          'kind': 'photo',
          'mimeType': 'image/jpeg',
          'sizeBytes': bytes.length,
          'complete': true,
          'probeState': 'ready',
          'version': 1,
        });
      });
      await tester.pumpWidget(
        _app(
          const PhotoViewerScreen(
            mediaId: 'a',
            adjacentMediaIds: ['a', 'b', 'c'],
          ),
          adapter,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('b.jpg'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('c.jpg'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(imageRequests.last, 'c');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.byTooltip('Stop slideshow'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.byTooltip('Start slideshow'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quiet download refresh reconciles the loaded window without rewinding pagination',
    (tester) async {
      final cursors = <Object?>[];
      final adapter = _InteractionAdapter((options) {
        final cursor = options.queryParameters['cursor'];
        cursors.add(cursor);
        return _json(switch (cursor) {
          null => _page(List.generate(50, _download), cursor: 'page-2'),
          'page-2' => _page(
            List.generate(50, (index) => _download(index + 50)),
            cursor: 'page-3',
          ),
          'page-3' => _page([_download(100)]),
          _ => throw StateError('Unexpected cursor $cursor'),
        });
      });
      await tester.pumpWidget(_app(const DownloadsScreen(), adapter));
      await tester.pumpAndSettle();
      expect(cursors, [null]);
      await tester.tap(find.text('Load next page'));
      await tester.pumpAndSettle();
      expect(cursors, [null, null, 'page-2']);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(cursors, [null, null, 'page-2', null, 'page-2']);
      await tester.tap(find.text('Load next page'));
      await tester.pumpAndSettle();
      expect(cursors, [
        null,
        null,
        'page-2',
        null,
        'page-2',
        null,
        'page-2',
        'page-3',
      ]);
      expect(find.text('Load next page'), findsNothing);
      await tester.scrollUntilVisible(find.text('Download 100'), 1000);
      expect(find.text('Download 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quiet download refresh removes requests absent from a successful snapshot',
    (tester) async {
      var calls = 0;
      final adapter = _InteractionAdapter(
        (options) => _json(_page(++calls == 1 ? [_download(0)] : [])),
      );
      await tester.pumpWidget(_app(const DownloadsScreen(), adapter));
      await tester.pumpAndSettle();
      expect(find.text('Download 000'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Download 000'), findsNothing);
      expect(
        find.text('No downloads yet. Discover a release or add a magnet.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mounted download list and details tolerate disconnected polling and resumed lifecycle',
    (tester) async {
      for (final screen in <Widget>[
        const DownloadsScreen(),
        const DownloadDetailsScreen(requestId: 'download-A'),
      ]) {
        var requests = 0;
        final adapter = _InteractionAdapter((options) {
          requests++;
          if (options.path.endsWith('/libraries')) {
            return _json([_managedLibrary]);
          }
          if (options.path.endsWith('/files')) return _json([]);
          if (options.path.endsWith('/settings')) {
            return _json(_settings(1024, 'A'));
          }
          if (options.path.endsWith('/downloads')) {
            return _json(_page([_detailDownload('download-A')]));
          }
          return _json(_detailDownload('download-A'));
        });
        BrianiApi? currentApi = BrianiApi(
          dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
            ..httpClientAdapter = adapter,
        );
        final container = ProviderContainer(
          overrides: [activeApiProvider.overrideWith((ref) => currentApi)],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pumpAndSettle();
        final requestsBeforeDisconnect = requests;
        expect(requestsBeforeDisconnect, greaterThan(0));
        currentApi = null;
        container.invalidate(activeApiProvider);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(requests, requestsBeforeDisconnect);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );

  testWidgets(
    'late settings write for detail A cannot replace detail B settings in retained State',
    (tester) async {
      final lateWrite = Completer<ResponseBody>();
      final writtenIds = <String>[];
      final adapter = _InteractionAdapter((options) {
        final components = options.path.split('/');
        final settings = components.last == 'settings';
        final id = settings || components.last == 'files'
            ? components[components.length - 2]
            : components.last;
        if (settings && options.method == 'PATCH') {
          writtenIds.add(id);
          return lateWrite.future;
        }
        if (settings) {
          return _json(
            id == 'download-A' ? _settings(1024, 'A') : _settings(8192, 'B'),
          );
        }
        if (components.last == 'libraries') return _json([_managedLibrary]);
        if (components.last == 'files') return _json([]);
        return _json(_detailDownload(id));
      });
      var id = 'download-A';
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return DownloadDetailsScreen(
                key: const ValueKey('retained-details'),
                requestId: id,
              );
            },
          ),
          adapter,
        ),
      );
      await tester.pumpAndSettle();
      final originalState = tester.state(find.byType(DownloadDetailsScreen));
      await tester.tap(find.byTooltip('Transfer settings'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Download limit (bytes/sec)'),
        '4096',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writtenIds, ['download-A']);
      update(() => id = 'download-B');
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(DownloadDetailsScreen)),
        same(originalState),
      );
      await tester.tap(find.byTooltip('Transfer settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Download limit (bytes/sec)'),
            )
            .controller!
            .text,
        '8192',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      lateWrite.complete(_json(_settings(4096, 'A-updated')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Transfer settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Download limit (bytes/sec)'),
            )
            .controller!
            .text,
        '8192',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Tags (comma-separated)'),
            )
            .controller!
            .text,
        'B',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}

final _managedLibrary = {
  'id': 'library-1',
  'name': 'Managed library',
  'description': '',
  'readOnly': false,
  'enabled': true,
  'version': 1,
  'capabilities': {'read': true, 'download': true, 'manage': true},
};

Map<String, Object?> _detailDownload(String id) => {
  ..._download(0),
  'id': id,
  'name': id,
};

Map<String, Object?> _settings(int limit, String tag) => {
  'version': 1,
  'downloadLimitBytesPerSecond': limit,
  'tags': [tag],
};
