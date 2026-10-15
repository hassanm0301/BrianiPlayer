import 'dart:convert';
import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:briani_player/core/preferences/preferences_providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/administration/administration_screen.dart';
import 'package:briani_player/features/settings/settings_screen.dart';

int preferenceWrites = 0;

class _Preferences extends UserPreferencesController {
  @override
  AsyncValue<UserPreferences> build() => AsyncData(defaultUserPreferences());
  @override
  Future<UserPreferences> update(
    void Function(UserPreferencesBuilder) change,
  ) async {
    preferenceWrites++;
    final current = state.requireValue;
    final updated = current.rebuild(change);
    state = AsyncData(updated);
    return updated;
  }
}

class _DevicePreferences extends DevicePreferencesController {
  @override
  DevicePreferences build() => const DevicePreferences();
}

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

class _AdminAdapter implements HttpClientAdapter {
  _AdminAdapter({this.failUsers = false});
  final bool failUsers;
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (failUsers && options.path.endsWith('/admin/users')) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final Object body = switch (true) {
      _ when options.path.endsWith('/admin/settings') => {
        'version': 1,
        'enabledProviderIds': null,
        'enabledCategoryIds': null,
      },
      _ when options.path.endsWith('/admin/users') => [],
      _ when options.path.endsWith('/admin/health') => [],
      _ when options.path.endsWith('/admin/storage') => [],
      _ when options.path.endsWith('/admin/integrations') => [],
      _ when options.path.endsWith('/admin/audit') => {
        'items': [],
        'nextCursor': null,
        'totalKnown': 0,
        'truncated': false,
        'warnings': [],
      },
      _ when options.path.endsWith('/libraries') => [],
      _ when options.path.endsWith('/discovery/providers') => [],
      _ => {'title': 'Not found', 'status': 404},
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

BrianiApi _api(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  return BrianiApi(dio: dio)..setBearerAuth('AccessToken', 'token');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings slider saves once at the end of a drag', (
    tester,
  ) async {
    preferenceWrites = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWith(_Preferences.new),
          devicePreferencesProvider.overrideWith(_DevicePreferences.new),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Playback and photos'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(45, 0));
    await tester.pumpAndSettle();
    expect(preferenceWrites, 1);
  });

  testWidgets('one failed admin read leaves healthy sections available', (
    tester,
  ) async {
    final adapter = _AdminAdapter(failUsers: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientSessionProvider.overrideWith(
            () => _AdminSession(_api(adapter)),
          ),
        ],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server and transfer settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Users and access'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Users and access'), findsOneWidget);
    expect(
      find.text(
        'This information could not be loaded. Other administration sections remain available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Service health and integrations'), findsOneWidget);
  });

  testWidgets('invalid create-member fields stay open with inline feedback', (
    tester,
  ) async {
    final adapter = _AdminAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientSessionProvider.overrideWith(
            () => _AdminSession(_api(adapter)),
          ),
        ],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create user');
    await tester.scrollUntilVisible(
      create,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await tester.pumpAndSettle();
    expect(find.text('Create member account'), findsOneWidget);
    expect(find.text('Enter a username.'), findsOneWidget);
    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(find.text('Use 12–128 characters.'), findsOneWidget);
  });
}
