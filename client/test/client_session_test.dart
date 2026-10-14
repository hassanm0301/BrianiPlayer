import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Vault implements CredentialVault {
  final values = <String, String>{};
  bool unavailable = false;
  Completer<void>? writeBarrier, deleteBarrier;
  Completer<void>? writeStarted, deleteStarted;
  @override Future<String?> read(String id) async { if (unavailable) throw StateError('No keyring'); return values[id]; }
  @override Future<void> write(String id, String token) async {
    if (writeStarted?.isCompleted == false) writeStarted!.complete();
    await writeBarrier?.future;
    if (unavailable) throw StateError('No keyring'); values[id] = token;
  }
  @override Future<void> delete(String id) async {
    if (deleteStarted?.isCompleted == false) deleteStarted!.complete();
    await deleteBarrier?.future;
    if (unavailable) throw StateError('No keyring'); values.remove(id);
  }
}

class SessionAdapter implements HttpClientAdapter {
  int refreshes = 0;
  bool rejectedRefresh = false;
  Completer<void>? loginBarrier, loginStarted;
  int logins = 0;
  final requests = <RequestOptions>[];
  final uploads = <List<int>>[];
  final user = {'id': '1', 'username': 'member', 'displayName': 'Member', 'role': 'member', 'enabled': true, 'version': 1};
  Map<String, dynamic> tokens(String access) => {
    'accessToken': access, 'accessExpiresAt': '2026-10-12T20:00:00Z',
    'refreshToken': 'refresh-$access', 'refreshExpiresAt': '2026-11-12T20:00:00Z',
    'sessionId': '2', 'user': user,
  };
  @override Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.copyWith(headers: Map.of(options.headers)));
    var status = 200;
    Object? body;
    if (options.path == '/api/v1/auth/login') {
      logins++;
      if (logins == 1) {
        if (loginStarted?.isCompleted == false) loginStarted!.complete();
        await loginBarrier?.future;
      }
      body = tokens('initial');
    }
    else if (options.path == '/api/v1/auth/refresh') {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      status = rejectedRefresh ? 401 : 200;
      body = rejectedRefresh ? {'status': 401, 'title': 'Unauthorized'} : tokens('renewed');
    } else if (options.path == '/api/v1/me') {
      status = options.headers['Authorization'] == 'Bearer renewed' ? 200 : 401;
      body = status == 200 ? user : {'status': 401, 'title': 'Unauthorized'};
    } else if (options.path == '/api/v1/torrent-uploads') {
      final bytes = <int>[];
      if (requestStream != null) { await for (final chunk in requestStream) { bytes.addAll(chunk); } }
      uploads.add(bytes);
      status = options.headers['Authorization'] == 'Bearer renewed' ? 201 : 401;
      body = status == 201 ? {'id': 'upload-1', 'expiresAt': '2026-10-12T20:00:00Z', 'sizeBytes': 20}
        : {'status': 401, 'title': 'Unauthorized'};
    } else if (options.path == '/api/v1/auth/logout') { status = 204; }
    else { throw StateError('Unexpected test request'); }
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final profile = ServerProfile(id: 'profile', label: 'Test', origin: Uri.parse('https://media.example'));
  late Vault vault;
  late SessionAdapter adapter;
  late ProviderContainer container;
  setUp(() {
    vault = Vault(); adapter = SessionAdapter();
    container = ProviderContainer(overrides: [
      credentialVaultProvider.overrideWithValue(vault),
      serverHttpClientAdapterProvider.overrideWithValue(adapter),
    ]);
  });
  tearDown(() => container.dispose());

  test('simultaneous unauthorized calls share rotating refresh and retry once', () async {
    await container.read(clientSessionProvider.notifier).login(profile, 'member', 'password');
    final api = container.read(activeApiProvider)!;
    final results = await Future.wait(List.generate(3, (_) => api.getIdentityApi().getMe()));
    expect(results.every((r) => r.data?.username == 'member'), true);
    expect(adapter.refreshes, 1);
    expect(vault.values, {'refresh_profile': 'refresh-renewed'});
    expect(adapter.requests.every((r) => !r.uri.toString().contains('initial') && !r.uri.toString().contains('refresh-')), true);
  });

  test('rejected refresh clears session and secure credential without retry loop', () async {
    await container.read(clientSessionProvider.notifier).login(profile, 'member', 'password');
    adapter.rejectedRefresh = true;
    await expectLater(container.read(activeApiProvider)!.getIdentityApi().getMe(), throwsA(isA<DioException>()));
    expect(container.read(clientSessionProvider), null);
    expect(vault.values, isEmpty);
    expect(adapter.refreshes, 1);
  });

  test('keyring failure retains refresh only in memory and reports session-only login', () async {
    vault.unavailable = true;
    await container.read(clientSessionProvider.notifier).login(profile, 'member', 'password');
    expect(container.read(clientSessionProvider)?.sessionOnly, true);
    expect(vault.values, isEmpty);
    expect(await container.read(sessionCredentialsProvider).read(profile.id), 'refresh-initial');
    await container.read(clientSessionProvider.notifier).disconnect(logout: true);
    expect(await container.read(sessionCredentialsProvider).read(profile.id), null);
  });

  test('unsafe transport is rejected before credentials or HTTP', () async {
    final unsafe = ServerProfile(id: 'unsafe', label: 'Unsafe', origin: Uri.parse('http://example.com'));
    await expectLater(container.read(clientSessionProvider.notifier).login(unsafe, 'member', 'password'),
      throwsA(isA<InsecureServerTransportException>()));
    expect(adapter.requests, isEmpty);
  });

  test('error presentation never reveals private headers, URLs or response detail', () {
    final error = DioException(requestOptions: RequestOptions(path: 'https://private/secret', headers: {'Authorization': 'secret'}),
      response: Response(requestOptions: RequestOptions(path: ''), statusCode: 403, data: {'detail': 'secret'}));
    expect(clientError(error), isNot(contains('secret')));
    expect(clientError(error), contains('permission'));
  });

  test('disconnect during login response cannot resurrect the session', () async {
    adapter.loginBarrier = Completer<void>(); adapter.loginStarted = Completer<void>();
    final login = container.read(clientSessionProvider.notifier).login(profile, 'member', 'password').catchError((_) {});
    await adapter.loginStarted!.future;
    await container.read(clientSessionProvider.notifier).disconnect();
    adapter.loginBarrier!.complete(); await login;
    expect(container.read(clientSessionProvider), null);
    expect(vault.values, isEmpty);
  });

  test('new profile survives an old login finishing its secure write', () async {
    vault.writeBarrier = Completer<void>(); vault.writeStarted = Completer<void>();
    final first = container.read(clientSessionProvider.notifier).login(profile, 'member', 'password').catchError((_) {});
    await vault.writeStarted!.future;
    final nextProfile = ServerProfile(id: 'second', label: 'Second', origin: Uri.parse('https://second.example'));
    final secondLogin = container.read(clientSessionProvider.notifier).login(nextProfile, 'member', 'password');
    vault.writeBarrier!.complete(); await Future.wait([first, secondLogin]);
    expect(container.read(clientSessionProvider)?.profile.id, 'second');
    expect(vault.values.containsKey('refresh_profile'), false);
    expect(vault.values['refresh_second'], 'refresh-initial');
  });

  test('failed refresh deletion cannot sign out a newer profile', () async {
    await container.read(clientSessionProvider.notifier).login(profile, 'member', 'password');
    adapter.rejectedRefresh = true;
    vault.deleteBarrier = Completer<void>(); vault.deleteStarted = Completer<void>();
    final failed = container.read(activeApiProvider)!.getIdentityApi().getMe().then<void>((_) {}, onError: (_) {});
    await vault.deleteStarted!.future;
    final nextProfile = ServerProfile(id: 'next', label: 'Next', origin: Uri.parse('https://next.example'));
    await container.read(clientSessionProvider.notifier).login(nextProfile, 'member', 'password');
    vault.deleteBarrier!.complete(); await failed;
    expect(container.read(clientSessionProvider)?.profile.id, 'next');
  });

  test('failed rotated-token storage never falls back to the older secure value', () async {
    vault.values['refresh_profile'] = 'old-rotated-token';
    final credentials = SessionCredentials(vault);
    vault.unavailable = true;
    await credentials.save('profile', 'new-token');
    vault.unavailable = false;
    expect(await credentials.read('profile'), 'new-token');
    vault.unavailable = true; await credentials.clear('profile'); vault.unavailable = false;
    expect(await credentials.read('profile'), null);
  });

  test('expired access multipart upload is replayed with identical file payload', () async {
    await container.read(clientSessionProvider.notifier).login(profile, 'member', 'password');
    final response = await container.read(activeApiProvider)!.getDownloadsApi().uploadTorrent(
      file: MultipartFile.fromBytes(utf8.encode('briani-test-metainfo'), filename: 'fixture.torrent'));
    expect(response.data?.id, 'upload-1');
    expect(adapter.refreshes, 1);
    expect(adapter.uploads.length, 2);
    for (final bytes in adapter.uploads) {
      expect(utf8.decode(bytes), contains('briani-test-metainfo'));
    }
  });
}
