import 'dart:convert';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/administration/administration_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _goodKey = 'fixture-secret-123';

class _AdminSession extends SessionController {
  _AdminSession(this.api);
  final BrianiApi api;
  @override
  ClientSession? build() => ClientSession(
    profile: ServerProfile(
      id: 'profile',
      label: 'Server',
      origin: Uri.parse('https://fixture.invalid'),
    ),
    api: api,
    tokens: AuthTokens(
      (b) => b
        ..accessToken = 'token'
        ..accessExpiresAt = DateTime.utc(2026, 10, 13)
        ..refreshToken = 'refresh'
        ..refreshExpiresAt = DateTime.utc(2026, 11, 13)
        ..sessionId = 'session'
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

Map<String, Object?> _indexer(
  String id,
  String name, {
  bool enabled = true,
  String privacy = 'private',
}) => {
  'id': id,
  'name': name,
  'definition': 'brianifixture',
  'enabled': enabled,
  'privacy': privacy,
  'priority': 25,
  'supportsSearch': true,
  'supportsRecent': true,
  'state': enabled ? 'healthy' : 'unknown',
  'stateDetail': enabled ? 'No recent failures in Prowlarr.' : null,
};

/// Answers the administration reads plus the indexer endpoints the way the
/// Briani server does, and records every request the screen makes.
class _IndexerAdapter implements HttpClientAdapter {
  _IndexerAdapter({this.indexersUnavailable = false});
  final bool indexersUnavailable;
  final requests = <(String, String, Object?)>[];
  final indexers = [
    _indexer('3', 'Fixture One'),
    _indexer('5', 'Fixture Two', enabled: false, privacy: 'public'),
  ];

  Iterable<(String, String, Object?)> calls(String method, String path) =>
      requests.where((r) => r.$1 == method && r.$2 == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;
    final data = options.data is String
        ? jsonDecode(options.data as String)
        : options.data;
    requests.add((method, path, data));
    ResponseBody json(Object? body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [
              status >= 400
                  ? 'application/problem+json'
                  : Headers.jsonContentType,
            ],
          },
        );
    final indexerPath = RegExp(r'^/api/v1/admin/indexers/(\d+)$');
    if (path == '/api/v1/admin/indexers' && method == 'GET') {
      if (indexersUnavailable) {
        return json({
          'title': 'Credentials for this service have not been configured.',
          'status': 503,
          'code': 'credentials_missing',
          'detail': 'Credentials for this service have not been configured.',
        }, 503);
      }
      return json(indexers);
    }
    if (path == '/api/v1/admin/indexers' && method == 'POST') {
      final settings = (data as Map)['settings'] as Map?;
      if (settings?['apikey'] != _goodKey) {
        return json({
          'title': 'Prowlarr did not accept this indexer change.',
          'status': 400,
          'code': 'indexer_rejected',
          'detail': 'Prowlarr did not add this indexer: Unable to connect to indexer. Unexpected response status Unauthorized code from indexer request',
        }, 400);
      }
      final created = _indexer(
        '9',
        data['name'] as String? ?? 'Briani Fixture',
      );
      indexers.add(created);
      return json(created, 201);
    }
    if (indexerPath.firstMatch(path) case final match? when method == 'PATCH') {
      final row = indexers.firstWhere((x) => x['id'] == match[1]);
      row['enabled'] = (data as Map)['enabled'];
      return json(row);
    }
    if (indexerPath.firstMatch(path) case final match?
        when method == 'DELETE') {
      indexers.removeWhere((x) => x['id'] == match[1]);
      return ResponseBody.fromString('', 204);
    }
    if (path.endsWith('/test') && method == 'POST') {
      return json({
        'id': path.split('/')[5],
        'state': 'healthy',
        'detail': 'Prowlarr reached this indexer and it returned results.',
        'checkedAt': '2026-10-17T10:00:00Z',
      });
    }
    if (path == '/api/v1/admin/indexers/definitions') {
      return json([
        {
          'key': 'brianifixture',
          'name': 'Briani Fixture',
          'description': 'Local generated fixture indexer',
          'language': 'en-US',
          'privacy': 'private',
          'supportsSearch': true,
          'supportsRecent': true,
          'addable': true,
          'setupNote': null,
        },
        {
          'key': 'fixturecaptcha',
          'name': 'Fixture Captcha',
          'description': 'Needs a CAPTCHA',
          'language': 'en-US',
          'privacy': 'private',
          'supportsSearch': true,
          'supportsRecent': true,
          'addable': false,
          'setupNote': "This indexer needs settings Briani does not show (such as a CAPTCHA), so it is set up in Prowlarr's own page.",
        },
        {
          'key': 'fixturepublic',
          'name': 'Fixture Public',
          'description': 'Public fixture',
          'language': 'en-US',
          'privacy': 'public',
          'supportsSearch': true,
          'supportsRecent': false,
          'addable': true,
          'setupNote': null,
        },
      ]);
    }
    if (path == '/api/v1/admin/indexers/definitions/brianifixture') {
      return json({
        'key': 'brianifixture',
        'name': 'Briani Fixture',
        'description': 'Local generated fixture indexer',
        'privacy': 'private',
        'addable': true,
        'setupNote': null,
        'fields': [
          {
            'name': 'baseUrl',
            'label': 'Base Url',
            'kind': 'select',
            'advanced': false,
            'helpText': 'Select which base url Prowlarr will use',
            'value': 'http://fixture-indexer/',
            'options': [
              {
                'value': 'http://fixture-indexer/',
                'label': 'http://fixture-indexer/',
              },
            ],
          },
          {
            'name': 'apikey',
            'label': 'APIKey',
            'kind': 'secret',
            'advanced': false,
            'value': null,
          },
          {
            'name': 'sort',
            'label': 'Sort requested from site',
            'kind': 'select',
            'advanced': false,
            'value': '0',
            'options': [
              {'value': '0', 'label': 'created'},
              {'value': '1', 'label': 'seeders'},
            ],
          },
          {
            'name': 'freeleech',
            'label': 'Search freeleech only',
            'kind': 'checkbox',
            'advanced': false,
            'value': 'false',
          },
          {
            'name': 'info_key',
            'label': 'About your API key',
            'kind': 'info',
            'advanced': false,
            'value': 'Find the key on the site.',
          },
          {
            'name': 'minimumRatio',
            'label': 'Minimum Ratio',
            'kind': 'decimal',
            'advanced': true,
            'value': '1.5',
          },
        ],
      });
    }
    final Object body = switch (path) {
      '/api/v1/admin/settings' => {
        'version': 1,
        'enabledProviderIds': null,
        'enabledCategoryIds': null,
      },
      '/api/v1/admin/audit' => {
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      },
      _ => [],
    };
    return json(body);
  }

  @override
  void close({bool force = false}) {}
}

BrianiApi _api(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  return BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
}

Widget _app(_IndexerAdapter adapter, {bool television = false}) =>
    ProviderScope(
      overrides: [
        clientSessionProvider.overrideWith(() => _AdminSession(_api(adapter))),
      ],
      child: MaterialApp(
        builder: (context, child) => RemoteNavigationScope(
          television: television,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              navigationMode: television
                  ? NavigationMode.directional
                  : NavigationMode.traditional,
            ),
            child: child!,
          ),
        ),
        home: const AdministrationScreen(),
      ),
    );

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

Finder _rowSwitch(String id) => find.descendant(
  of: find.byKey(ValueKey('indexer-$id')),
  matching: find.byType(Switch),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

bool _focusWithin(Finder finder) {
  final targets = finder.evaluate().toSet();
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((element) {
    if (targets.contains(element)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Presses [key] until focus lands inside [target], like a person on a remote.
Future<void> _pressUntil(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Finder target, {
  int max = 80,
}) async {
  for (var i = 0; i < max && !_focusWithin(target); i++) {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }
  expect(
    _focusWithin(target),
    isTrue,
    reason: 'focus is on ${FocusManager.instance.primaryFocus}',
  );
}

Future<void> _select(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('indexer rows toggle, test and remove through the server', (
    tester,
  ) async {
    final adapter = _IndexerAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Fixture Two'));
    expect(find.text('Indexers'), findsWidgets);
    expect(find.text('Fixture One'), findsOneWidget);
    expect(find.text('No recent failures in Prowlarr.'), findsOneWidget);
    expect(find.textContaining('Public · brianifixture'), findsOneWidget);

    await _tapVisible(tester, _rowSwitch('3'));
    expect(adapter.calls('PATCH', '/api/v1/admin/indexers/3').single.$3, {
      'enabled': false,
    });
    expect(find.text('Fixture One disabled.'), findsOneWidget);
    // Toasts queue; dismiss this one so the next action's message shows.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byTooltip('Test Fixture Two'));
    expect(
      adapter.calls('POST', '/api/v1/admin/indexers/5/test'),
      hasLength(1),
    );
    expect(
      find.text(
        'Fixture Two: Prowlarr reached this indexer and it returned results.',
      ),
      findsOneWidget,
    );

    await _tapVisible(tester, find.byTooltip('Remove Fixture Two'));
    expect(find.text('Remove Fixture Two?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(adapter.calls('DELETE', '/api/v1/admin/indexers/5'), isEmpty);
    await _tapVisible(tester, find.byTooltip('Remove Fixture Two'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(adapter.calls('DELETE', '/api/v1/admin/indexers/5'), hasLength(1));
    expect(find.text('Fixture Two'), findsNothing);
  });

  testWidgets(
    'adding keeps the dialog open with the server message, then sends the settings',
    (tester) async {
      final adapter = _IndexerAdapter();
      await tester.pumpWidget(_app(adapter));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _button('Add indexer'));
      await _tapVisible(tester, _button('Add indexer'));

      expect(find.text('Briani Fixture'), findsOneWidget);
      final captcha = tester.widget<ListTile>(
        find.byKey(const ValueKey('definition-fixturecaptcha')),
      );
      expect(captcha.enabled, isFalse);
      expect(find.textContaining('such as a CAPTCHA'), findsOneWidget);
      // Addable definitions are listed before the ones left to Prowlarr.
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(titles, ['Briani Fixture', 'Fixture Public', 'Fixture Captcha']);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search indexers'),
        'public',
      );
      await tester.pumpAndSettle();
      expect(find.text('Briani Fixture'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search indexers'),
        '',
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Briani Fixture'));
      expect(find.text('Add Briani Fixture'), findsOneWidget);
      expect(find.text('Find the key on the site.'), findsOneWidget);
      expect(find.text('Minimum Ratio'), findsNothing);
      final key = find.widgetWithText(TextField, 'APIKey');
      expect(tester.widget<TextField>(key).obscureText, isTrue);

      await tester.enterText(key, 'wrong-key');
      await _tapVisible(tester, _button('Add'));
      expect(
        find.text(
          'Prowlarr did not add this indexer: Unable to connect to indexer. Unexpected response status Unauthorized code from indexer request',
        ),
        findsOneWidget,
      );
      expect(find.text('Add Briani Fixture'), findsOneWidget);

      await tester.enterText(key, _goodKey);
      await _tapVisible(tester, find.text('Search freeleech only'));
      await _tapVisible(tester, _button('Add'));
      expect(find.text('Add Briani Fixture'), findsNothing);
      expect(find.text('Briani Fixture added.'), findsOneWidget);
      final sent =
          adapter.calls('POST', '/api/v1/admin/indexers').last.$3 as Map;
      expect(sent['definition'], 'brianifixture');
      expect(sent['name'], 'Briani Fixture');
      expect(sent['enabled'], isTrue);
      expect(sent['settings'], {
        'apikey': _goodKey,
        'minimumRatio': '1.5',
        'baseUrl': 'http://fixture-indexer/',
        'sort': '0',
        'freeleech': 'true',
      });
      expect(
        adapter.calls('GET', '/api/v1/admin/indexers').length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  testWidgets('an unavailable indexer list shows the server message', (
    tester,
  ) async {
    final adapter = _IndexerAdapter(indexersUnavailable: true);
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.text('Credentials for this service have not been configured.'),
    );
    expect(
      tester.widget<ButtonStyleButton>(_button('Add indexer')).onPressed,
      isNull,
    );
    expect(find.text('Fixture One'), findsNothing);
  });

  testWidgets('a TV remote reaches every indexer action and the add flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _IndexerAdapter();
    await tester.pumpWidget(_app(adapter, television: true));
    await tester.pumpAndSettle();

    // From the top of the page, Down alone reaches the Indexers section.
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      _button('Add indexer'),
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.byKey(const ValueKey('indexer-3')),
      max: 2,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowRight,
      find.byTooltip('Remove Fixture One'),
      max: 3,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowLeft,
      find.byTooltip('Test Fixture One'),
      max: 2,
    );
    await _select(tester);
    expect(
      adapter.calls('POST', '/api/v1/admin/indexers/3/test'),
      hasLength(1),
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowLeft,
      _rowSwitch('3'),
      max: 3,
    );
    await _select(tester);
    expect(adapter.calls('PATCH', '/api/v1/admin/indexers/3').single.$3, {
      'enabled': false,
    });
    expect(_focusWithin(_rowSwitch('3')), isTrue);

    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.byKey(const ValueKey('indexer-5')),
      max: 2,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowRight,
      find.byTooltip('Remove Fixture Two'),
      max: 3,
    );
    await _select(tester);
    expect(find.text('Remove Fixture Two?'), findsOneWidget);
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowRight,
      _button('Continue'),
      max: 6,
    );
    await _select(tester);
    expect(adapter.calls('DELETE', '/api/v1/admin/indexers/5'), hasLength(1));

    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowUp,
      _button('Add indexer'),
      max: 40,
    );
    await _select(tester);
    expect(find.text('Briani Fixture'), findsOneWidget);
    // The search field does not grab focus on TV, so the on-screen keyboard stays closed.
    expect(
      _focusWithin(find.widgetWithText(TextField, 'Search indexers')),
      isFalse,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.byKey(const ValueKey('definition-brianifixture')),
      max: 4,
    );
    await _select(tester);
    expect(find.text('Add Briani Fixture'), findsOneWidget);

    final key = find.widgetWithText(TextField, 'APIKey');
    await _pressUntil(tester, LogicalKeyboardKey.arrowDown, key, max: 6);
    tester.testTextInput.enterText(_goodKey);
    await tester.pumpAndSettle();

    final sort = find.ancestor(
      of: find.text('Sort requested from site'),
      matching: find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<String>,
      ),
    );
    await _pressUntil(tester, LogicalKeyboardKey.arrowDown, sort, max: 4);
    await _select(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await _select(tester);

    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.ancestor(
        of: find.text('Search freeleech only'),
        matching: find.byType(SwitchListTile),
      ),
      max: 4,
    );
    await _select(tester);

    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.ancestor(
        of: find.text('Enable now'),
        matching: find.byType(SwitchListTile),
      ),
      max: 6,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowDown,
      find.byType(OverflowBar),
      max: 4,
    );
    await _pressUntil(
      tester,
      LogicalKeyboardKey.arrowRight,
      _button('Add'),
      max: 4,
    );
    await _select(tester);

    expect(find.text('Add Briani Fixture'), findsNothing);
    final sent =
        adapter.calls('POST', '/api/v1/admin/indexers').single.$3 as Map;
    expect(sent['settings'], containsPair('apikey', _goodKey));
    expect(sent['settings'], containsPair('sort', '1'));
    expect(sent['settings'], containsPair('freeleech', 'true'));
  });
}
