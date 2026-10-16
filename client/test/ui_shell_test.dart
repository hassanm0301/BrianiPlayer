import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:briani_player/app/app.dart';
import 'package:briani_player/app/theme.dart';
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/platform/platform_capabilities.dart';
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/core/widgets/adaptive.dart';
import 'package:briani_player/core/widgets/states.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = options.path.endsWith('/libraries')
        ? [
            {
              'id': 'lib-1',
              'name': 'Films',
              'description': '',
              'readOnly': false,
              'enabled': true,
              'version': 1,
              'capabilities': {'read': true, 'download': true, 'manage': true},
            },
          ]
        : {
            'items': [],
            'nextCursor': null,
            'totalKnown': 0,
            'truncated': false,
            'warnings': [],
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

class _Session extends SessionController {
  _Session(this.api, this.role);
  final BrianiApi api;
  final UserRoleEnum role;
  @override
  ClientSession? build() => ClientSession(
    profile: ServerProfile(
      id: 'p',
      label: 'Home server',
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
            ..id = 'u'
            ..username = 'sam'
            ..displayName = 'Sam'
            ..role = role
            ..enabled = true
            ..version = 1,
        ).toBuilder(),
    ),
    sessionOnly: false,
  );
}

class _Preferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(defaultUserPreferences());
}

class _DevicePreferences extends DevicePreferencesController {
  @override
  DevicePreferences build() => const DevicePreferences();
}

Future<ProviderContainer> _pumpApp(
  WidgetTester t, {
  required Size size,
  UserRoleEnum role = UserRoleEnum.member,
  bool television = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = _Adapter();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      clientSessionProvider.overrideWith(() => _Session(BrianiApi(dio: dio), role)),
      userPreferencesProvider.overrideWith(_Preferences.new),
      devicePreferencesProvider.overrideWith(_DevicePreferences.new),
      deviceCapabilitiesProvider.overrideWith(
        (ref) async => DeviceCapabilities(
          television: television,
          platform: television ? 'android' : 'linux',
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const BrianiApp()),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  test('window size classes follow the Material 3 breakpoints', () {
    expect(WindowSize.ofWidth(599), WindowSize.compact);
    expect(WindowSize.ofWidth(600), WindowSize.medium);
    expect(WindowSize.ofWidth(839), WindowSize.medium);
    expect(WindowSize.ofWidth(840), WindowSize.expanded);
    expect(WindowSize.ofWidth(1200), WindowSize.large);
  });

  testWidgets('desktop shell uses a navigation rail and keeps the avatar out of page bars', (
    t,
  ) async {
    await _pumpApp(t, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Account · Home server'), findsOneWidget);
    // Only the page's own app bar is present inside the content panel.
    expect(find.byType(AppBar), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('phone shell uses a bottom bar and puts the avatar in the page app bar', (
    t,
  ) async {
    await _pumpApp(t, size: const Size(400, 800));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Account · Home server'),
      ),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('TV shell uses compact top tabs with focus on the selected tab', (
    t,
  ) async {
    await _pumpApp(t, size: const Size(1920, 1080), television: true);
    expect(find.byType(TvNavigationScaffold), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    final focused = FocusManager.instance.primaryFocus?.context;
    var withinTab = false;
    focused?.visitAncestorElements((element) {
      if (element.widget is FilledButton) {
        withinTab = true;
        return false;
      }
      return true;
    });
    expect(withinTab, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('account menu offers Administration only to administrators', (t) async {
    await _pumpApp(t, size: const Size(1280, 800));
    await t.tap(find.byTooltip('Account · Home server'));
    await t.pumpAndSettle();
    expect(find.text('Account and devices'), findsOneWidget);
    expect(find.text('Administration'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    await t.pumpWidget(const SizedBox());

    await _pumpApp(t, size: const Size(1280, 800), role: UserRoleEnum.administrator);
    await t.tap(find.byTooltip('Account · Home server'));
    await t.pumpAndSettle();
    expect(find.text('Administration'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('shared states render their message and action', (t) async {
    var retried = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(seed: Colors.blue, brightness: Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              const NoticeBanner(tone: NoticeTone.warning, message: 'Partial page'),
              const StatusPill(label: 'Seeding', tone: PillTone.success),
              Expanded(
                child: EmptyState.error(
                  message: 'Server unreachable',
                  onRetry: () => retried++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Partial page'), findsOneWidget);
    expect(find.text('Seeding'), findsOneWidget);
    expect(find.text('Server unreachable'), findsOneWidget);
    await t.tap(find.text('Retry'));
    expect(retried, 1);
  });

  test('both theme brightnesses provide status colors', () {
    for (final brightness in Brightness.values) {
      final theme = buildAppTheme(seed: accentSeed(null), brightness: brightness);
      expect(theme.extension<StatusColors>(), isNotNull);
      expect(theme.colorScheme.brightness, brightness);
    }
  });
}
