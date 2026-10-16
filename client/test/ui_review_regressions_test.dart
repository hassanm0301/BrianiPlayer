// Regressions found by the independent review of the UI redesign.
import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/administration/administration_screen.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:briani_player/core/widgets/media_tile.dart';
import 'package:briani_player/features/playback/immersive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.endsWith('/libraries')) {
      return _json([
        {
          'id': 'lib-1',
          'name': 'Films',
          'description': '',
          'readOnly': false,
          'enabled': true,
          'version': 1,
          'capabilities': {'read': true, 'download': true, 'manage': true},
        },
      ]);
    }
    if (path.endsWith('/entries')) {
      return _json({
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      });
    }
    return _json({'title': 'Unavailable', 'detail': 'Unavailable'}, 503);
  }

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

BrianiApi _api() => BrianiApi(
  dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = _Adapter(),
);

class _Admin extends SessionController {
  _Admin(this.api);
  final BrianiApi api;
  @override
  ClientSession? build() => ClientSession(
    profile: ServerProfile(
      id: 'p',
      label: 'Server',
      origin: Uri.parse('https://fixture.invalid'),
    ),
    api: api,
    tokens: AuthTokens(
      (b) => b
        ..accessToken = 'token'
        ..accessExpiresAt = DateTime.utc(2030)
        ..refreshToken = 'refresh'
        ..refreshExpiresAt = DateTime.utc(2030)
        ..sessionId = 's'
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

class _ChromeProbe extends StatefulWidget {
  const _ChromeProbe();
  @override
  State<_ChromeProbe> createState() => _ChromeProbeState();
}

class _ChromeProbeState extends State<_ChromeProbe> with AutoHideChrome {
  @override
  bool get chromeMayHide => true;

  @override
  void initState() {
    super.initState();
    chromeConditionsChanged();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => holdChrome(true),
    onPointerUp: (_) => holdChrome(false),
    child: SizedBox.expand(
      child: Text(chromeVisible ? 'chrome visible' : 'chrome hidden'),
    ),
  );
}

void main() {
  testWidgets('breadcrumb keeps its scroll position and crumb focus at the start', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final path = [
      const FolderBreadcrumb(id: 'root', name: 'Films'),
      for (var i = 1; i <= 6; i++)
        FolderBreadcrumb(id: 'folder-$i', name: 'Long folder name $i'),
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: [activeApiProvider.overrideWithValue(_api())],
        child: MaterialApp(
          home: FolderScreen(
            libraryId: 'lib-1',
            folderId: 'folder-6',
            breadcrumbs: path,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final scrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.left,
    );
    expect(scrollable, findsOneWidget);
    final before = t.state<ScrollableState>(scrollable);
    final first = find.widgetWithText(TextButton, 'Films');
    await t.ensureVisible(first);
    await t.pumpAndSettle();
    final after = t.state<ScrollableState>(scrollable);
    expect(identical(before, after), isTrue, reason: 'The trail must not be rebuilt.');
    expect(t.getTopLeft(first).dx, greaterThanOrEqualTo(0));

    // Keyboard focus on the first ancestor survives the fade toggling.
    final crumbFocus = Focus.of(t.element(find.text('Films')));
    crumbFocus.requestFocus();
    await t.pumpAndSettle();
    expect(crumbFocus.hasFocus, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('administration jump list reaches sections below the fold', (t) async {
    t.view.physicalSize = const Size(1440, 520);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [clientSessionProvider.overrideWith(() => _Admin(_api()))],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await t.pumpAndSettle();
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    expect(t.state<ScrollableState>(list.first).position.pixels, 0);
    await t.tap(find.widgetWithText(ListTile, 'Maintenance'));
    await t.pumpAndSettle();
    expect(t.state<ScrollableState>(list.first).position.pixels, greaterThan(0));
    final tile = t.widget<ListTile>(find.widgetWithText(ListTile, 'Maintenance'));
    expect(tile.selected, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('TV top navigation fits a long server label at large text', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            navigationMode: NavigationMode.directional,
          ),
          child: child!,
        ),
        home: TvNavigationScaffold(
          index: 0,
          onSelected: (_) {},
          profile: const Text('Living room media server (Synology NAS)'),
          account: const CircleAvatar(child: Text('A')),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('touching the controls keeps auto-hiding chrome visible', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: _ChromeProbe())));
    final gesture = await t.startGesture(t.getCenter(find.byType(_ChromeProbe)));
    await t.pump(const Duration(seconds: 5));
    expect(find.text('chrome visible'), findsOneWidget);
    await gesture.up();
    await t.pump(const Duration(seconds: 4));
    expect(find.text('chrome hidden'), findsOneWidget);
  });

  test('thumbnail cache is bounded and remembers missing thumbnails', () {
    final cache = ThumbnailCache(maxEntries: 2, maxBytes: 10);
    cache.store('a', Uint8List(4));
    cache.store('b', null);
    expect(cache.contains('b'), isTrue);
    expect(cache.lookup('b'), isNull);
    cache.lookup('a'); // 'a' becomes the most recently used entry.
    cache.store('c', Uint8List(4));
    expect(cache.contains('b'), isFalse, reason: 'least recently used is evicted');
    expect(cache.contains('a'), isTrue);
    cache.store('d', Uint8List(8));
    expect(cache.contains('a'), isFalse, reason: 'byte budget is enforced');
    expect(cache.lookup('d'), hasLength(8));
  });
}
