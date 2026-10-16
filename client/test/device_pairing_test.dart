import 'dart:async';
import 'dart:convert';

import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/session/device_pairing.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _profile = ServerProfile(
  id: 'profile-1',
  label: 'Media server',
  origin: Uri.parse('https://media.example'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('device pairing session', () {
    late DateTime now;
    late _Vault vault;
    late _PairingAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      now = DateTime.utc(2030, 1, 1);
      vault = _Vault();
      adapter = _PairingAdapter();
      container = _container(adapter, vault, () => now);
    });
    tearDown(() => container.dispose());

    test('early polls are suppressed and HTTP 202 is never parsed as tokens',
        () async {
      adapter.exchangeStatuses.addAll([202, 200]);
      final controller = container.read(clientSessionProvider.notifier);
      final code = await controller.beginPairing(_profile, 'Living Room TV');
      expect(code.intervalSeconds, 5);

      expect(await controller.pollPairing(), isFalse);
      expect(adapter.exchangeCount, 0);
      now = now.add(const Duration(seconds: 5));
      expect(await controller.pollPairing(), isFalse);
      expect(adapter.exchangeCount, 1);
      expect(container.read(clientSessionProvider), isNull);
      expect(vault.values, isEmpty);

      expect(await controller.pollPairing(), isFalse);
      expect(adapter.exchangeCount, 1);
      now = now.add(const Duration(seconds: 5));
      expect(await controller.pollPairing(), isTrue);
      expect(adapter.exchangeCount, 2);
      expect(container.read(clientSessionProvider)?.tokens.accessToken,
          'paired-access');
    });

    test('approved exchange installs session and stores only refresh token',
        () async {
      final controller = container.read(clientSessionProvider.notifier);
      await controller.beginPairing(_profile, 'Living Room TV');
      now = now.add(const Duration(seconds: 5));

      expect(await controller.pollPairing(), isTrue);
      expect(container.read(clientSessionProvider)?.profile, _profile);
      expect(container.read(clientSessionProvider)?.tokens.accessToken,
          'paired-access');
      expect(vault.values, {'refresh_profile-1': 'refresh-paired-access'});
      expect(adapter.exchangeBodies.single['deviceSecret'],
          _PairingAdapter.deviceSecret);
    });

    test('cancellation blocks a delayed approval from installing credentials',
        () async {
      adapter.exchangeGate = Completer<void>();
      adapter.exchangeStarted = Completer<void>();
      final controller = container.read(clientSessionProvider.notifier);
      await controller.beginPairing(_profile, 'Living Room TV');
      now = now.add(const Duration(seconds: 5));

      final poll = controller.pollPairing();
      await adapter.exchangeStarted!.future;
      controller.cancelPairing();
      adapter.exchangeGate!.complete();

      expect(await poll, isFalse);
      expect(container.read(clientSessionProvider), isNull);
      expect(vault.values, isEmpty);
    });

    test('replacing profile blocks a stale pairing exchange', () async {
      adapter.exchangeGate = Completer<void>();
      adapter.exchangeStarted = Completer<void>();
      final controller = container.read(clientSessionProvider.notifier);
      await controller.beginPairing(_profile, 'Living Room TV');
      now = now.add(const Duration(seconds: 5));
      final poll = controller.pollPairing();
      await adapter.exchangeStarted!.future;

      final replacement = ServerProfile(
        id: 'profile-2',
        label: 'Replacement server',
        origin: Uri.parse('https://replacement.example'),
      );
      adapter.loginAccessToken = 'replacement-access';
      await controller.login(replacement, 'member', 'password');
      adapter.exchangeGate!.complete();

      expect(await poll, isFalse);
      expect(container.read(clientSessionProvider)?.profile, replacement);
      expect(container.read(clientSessionProvider)?.tokens.accessToken,
          'replacement-access');
      expect(vault.values, {'refresh_profile-2': 'refresh-replacement-access'});
    });

    test('expired pairing stops polling and clears private attempt', () async {
      final controller = container.read(clientSessionProvider.notifier);
      final code = await controller.beginPairing(_profile, 'Living Room TV');
      now = code.expiresAt;

      await expectLater(controller.pollPairing(), throwsA(isA<StateError>()));
      expect(adapter.exchangeCount, 0);
      expect(await controller.pollPairing(), isFalse);
      expect(vault.values, isEmpty);
    });
  });

  testWidgets('TV displays only human code and never persists private secret',
      (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter();
    final container = _container(adapter, vault, DateTime.now);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => DeviceLinkScreen(profile: _profile),
        ),
        GoRoute(
          path: '/signin/:id',
          builder: (_, _) => const Scaffold(body: Text('Sign in route')),
        ),
        GoRoute(
          path: '/libraries',
          builder: (_, _) => const Scaffold(body: Text('Libraries route')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request device code'));
    // The approval wait shows an indeterminate indicator, so settle by time.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(_PairingAdapter.userCode), findsOneWidget);
    expect(find.textContaining(_PairingAdapter.deviceSecret), findsNothing);
    expect(vault.values, isEmpty);
    expect(adapter.exchangeCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });

  testWidgets('approval preview shows returned device and server before approval',
      (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter();
    final container = _container(adapter, vault, DateTime.now);
    await tester.runAsync(() => container
        .read(clientSessionProvider.notifier)
        .login(_profile, 'member', 'password'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ApproveDeviceDialog.show(context),
                child: const Text('Link a device'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Link a device'));
    await tester.pumpAndSettle();
    // The eighth character checks the code without a separate button press.
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();

    expect(adapter.inspectCount, 1);
    expect(adapter.inspectedCode, 'ABCD2345');
    expect(find.textContaining('Living Room TV'), findsOneWidget);
    expect(find.text('Server: Media server'), findsOneWidget);
    expect(find.text('https://media.example'), findsOneWidget);
    expect(adapter.approveCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('invalid human code is rejected before any HTTP request',
      (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter();
    final container = _container(adapter, vault, DateTime.now);
    await tester.runAsync(() => container
        .read(clientSessionProvider.notifier)
        .login(_profile, 'member', 'password'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ApproveDeviceDialog.show(context),
                child: const Text('Open approve'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open approve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.tap(find.text('Check device'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the eight-character code shown on the device.'),
        findsOneWidget);
    expect(adapter.inspectCount, 0);
    expect(adapter.approveCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  testWidgets('pasted code is normalised into one box per character',
      (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter();
    final container = _container(adapter, vault, DateTime.now);
    await tester.runAsync(() => container
        .read(clientSessionProvider.notifier)
        .login(_profile, 'member', 'password'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ApproveDeviceDialog.show(context),
                child: const Text('Open approve'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open approve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab-cd');
    await tester.pump();

    // Separators are dropped, letters are upper-cased, and each character
    // is drawn in its own box; nothing is sent before the code is complete.
    for (final char in ['A', 'B', 'C', 'D']) {
      expect(find.text(char), findsOneWidget);
    }
    expect(adapter.inspectCount, 0);

    await tester.enterText(find.byType(TextField), 'abcd 2345 extra');
    await tester.pumpAndSettle();
    expect(adapter.inspectCount, 1);
    expect(adapter.inspectedCode, 'ABCD2345');
    expect(find.textContaining('Living Room TV'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('expired TV code says so instead of blaming the server',
      (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter()..codeExpiresAt = '2020-01-01T00:00:00Z';
    final container = _container(adapter, vault, DateTime.now);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => DeviceLinkScreen(profile: _profile),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request device code'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('This code expired. Request a new code.'), findsOneWidget);
    expect(find.textContaining('did not explain'), findsNothing);
    expect(find.text('Waiting for approval…'), findsNothing);
    expect(adapter.exchangeCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });

  testWidgets('TV pairing code can be copied', (tester) async {
    final vault = _Vault();
    final adapter = _PairingAdapter();
    final container = _container(adapter, vault, DateTime.now);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => DeviceLinkScreen(profile: _profile),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request device code'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Copy code'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(copied, _PairingAdapter.userCode);
    expect(find.text('Code copied.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });
}

ProviderContainer _container(
  _PairingAdapter adapter,
  _Vault vault,
  DateTime Function() clock,
) =>
    ProviderContainer(
      overrides: [
        credentialVaultProvider.overrideWithValue(vault),
        serverHttpClientAdapterProvider.overrideWithValue(adapter),
        sessionClockProvider.overrideWithValue(clock),
      ],
    );

class _Vault implements CredentialVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String profileId) async => values[profileId];
  @override
  Future<void> write(String profileId, String token) async =>
      values[profileId] = token;
  @override
  Future<void> delete(String profileId) async => values.remove(profileId);
}

class _PairingAdapter implements HttpClientAdapter {
  static const deviceSecret = 'server-private-device-secret';
  static const userCode = 'ABCD2345';
  String codeExpiresAt = '2030-01-01T00:05:00Z';

  final exchangeStatuses = <int>[];
  final exchangeBodies = <Map<String, dynamic>>[];
  Completer<void>? exchangeGate;
  Completer<void>? exchangeStarted;
  String loginAccessToken = 'login-access';
  int exchangeCount = 0;
  int inspectCount = 0;
  int approveCount = 0;
  String? approvedCode;
  String? inspectedCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final Object? rawBody = options.data;
    final requestBody = _asMap(rawBody);
    var status = 200;
    Object? body;

    if (path == '/api/v1/auth/device-code' && options.method == 'POST') {
      body = {
        'deviceSecret': deviceSecret,
        'userCode': userCode,
        'expiresAt': codeExpiresAt,
        'pollIntervalSeconds': 5,
      };
    } else if (path == '/api/v1/auth/device-code/token') {
      exchangeCount++;
      exchangeBodies.add(requestBody);
      if (exchangeStarted?.isCompleted == false) exchangeStarted!.complete();
      await exchangeGate?.future;
      status = exchangeStatuses.isEmpty ? 200 : exchangeStatuses.removeAt(0);
      body = _tokens(status == 200 ? 'paired-access' : 'pending-access');
    } else if (path == '/api/v1/auth/login') {
      body = _tokens(loginAccessToken);
    } else if (path == '/api/v1/auth/device-code/inspect') {
      inspectCount++;
      inspectedCode = requestBody['userCode'] as String?;
      body = {
        'deviceName': 'Living Room TV',
        'expiresAt': '2030-01-01T00:05:00Z',
      };
    } else if (path == '/api/v1/auth/device-code/approve') {
      approveCount++;
      approvedCode = requestBody['userCode'] as String?;
      status = 204;
    } else {
      status = 404;
      body = {'status': 404, 'title': 'Not found'};
    }

    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) return Map<String, dynamic>.from(jsonDecode(value) as Map);
    if (value is List) {
      final result = <String, dynamic>{};
      for (var index = 0; index + 1 < value.length; index += 2) {
        result[value[index] as String] = value[index + 1];
      }
      return result;
    }
    return const {};
  }

  static Map<String, Object?> _tokens(String accessToken) => {
        'accessToken': accessToken,
        'accessExpiresAt': '2030-01-01T01:00:00Z',
        'refreshToken': 'refresh-$accessToken',
        'refreshExpiresAt': '2030-02-01T00:00:00Z',
        'sessionId': 'session-1',
        'user': {
          'id': 'user-1',
          'username': 'member',
          'displayName': 'Member',
          'role': 'member',
          'enabled': true,
          'version': 1,
        },
      };

  @override
  void close({bool force = false}) {}
}
