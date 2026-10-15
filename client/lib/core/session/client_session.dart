import 'dart:convert';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server_profiles/credential_vault.dart';
import '../server_profiles/providers.dart';
import '../server_profiles/server_profile.dart';

/// Shows the server's own message. Client-written text is limited to cases where
/// no server reply exists (unreachable server, certificate failure, or a reply
/// without a message). Transport URLs, headers and credentials are never shown.
String clientError(Object error) {
  if (error is DioException) {
    if (error.type == DioExceptionType.badCertificate) {
      return 'The server certificate could not be verified. Check its certificate and address.';
    }
    final message = serverMessage(error.response?.data);
    if (message != null) return message;
    if (error.response == null) {
      return 'The server could not be reached. Check your connection and the server address.';
    }
  }
  return 'The server did not explain this error. Retry or check the server status.';
}

/// Extracts the human-readable message from a server problem body.
String? serverMessage(Object? data) {
  if (data is Problem) return _text(data.detail) ?? _text(data.title);
  if (data is Map) return _text(data['detail']) ?? _text(data['title']);
  // Binary and plain-text endpoints still return JSON problems on failure.
  if (data is List<int> && data.length <= 65536) {
    return serverMessage(utf8.decode(data, allowMalformed: true));
  }
  if (data is String && data.trimLeft().startsWith('{')) {
    try {
      return serverMessage(jsonDecode(data));
    } on FormatException {
      return null;
    }
  }
  return null;
}

String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value : null;

class SessionCredentials {
  SessionCredentials(this.vault);
  final CredentialVault vault;
  final Map<String, String> _memory = {};
  final Set<String> _sessionOnly = {};
  final Map<String, Future<void>> _writes = {};
  bool get sessionOnly => _sessionOnly.isNotEmpty;
  bool isSessionOnly(String id) => _sessionOnly.contains(id);
  Future<String?> read(String id) async {
    if (_memory.containsKey(id)) return _memory[id];
    if (_sessionOnly.contains(id)) return null;
    try {
      final stored = await vault.read('refresh_$id');
      if (_memory.containsKey(id)) return _memory[id];
      return _sessionOnly.contains(id) ? null : stored;
    } catch (_) { _sessionOnly.add(id); return _memory[id]; }
  }
  Future<void> _ordered(String id, Future<void> Function() action) {
    final previous = _writes[id] ?? Future<void>.value();
    final next = previous.then((_) => action());
    _writes[id] = next;
    return next.whenComplete(() { if (identical(_writes[id], next)) _writes.remove(id); });
  }
  Future<void> save(String id, String refresh, {bool Function()? isCurrent}) {
    if (isCurrent != null && !isCurrent()) return Future<void>.value();
    _memory[id] = refresh;
    return _ordered(id, () async {
      if (isCurrent != null && !isCurrent()) {
        if (_memory[id] == refresh) _memory.remove(id);
        return;
      }
      if (_sessionOnly.contains(id)) return;
      try {
        await vault.write('refresh_$id', refresh);
        if (isCurrent != null && !isCurrent()) {
          if (_memory[id] == refresh) _memory.remove(id);
          await vault.delete('refresh_$id');
        }
      } catch (_) {
        _sessionOnly.add(id);
        try { await vault.delete('refresh_$id'); } catch (_) {}
      }
    });
  }
  Future<void> clear(String id) {
    final alreadySessionOnly = _sessionOnly.contains(id);
    _memory.remove(id);
    // A failed delete must never make a previously rotated token readable again.
    _sessionOnly.add(id);
    return _ordered(id, () async {
      try {
        await vault.delete('refresh_$id');
        if (!alreadySessionOnly) _sessionOnly.remove(id);
      } catch (_) {}
    });
  }
}

class ClientSession {
  ClientSession({required this.profile, required this.api, required this.tokens,
    required this.sessionOnly});
  final ServerProfile profile;
  final BrianiApi api;
  final AuthTokens tokens;
  final bool sessionOnly;
  bool get administrator => tokens.user.role == UserRoleEnum.administrator;
}

final sessionClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final sessionCredentialsProvider = Provider<SessionCredentials>(
  (ref) => SessionCredentials(ref.watch(credentialVaultProvider)),
);
final clientSessionProvider = NotifierProvider<SessionController, ClientSession?>(SessionController.new);
// A route can remain mounted for a frame after disconnect. Expose absence as
// state so its render subscription cannot throw during that transition.
final activeApiProvider = Provider<BrianiApi?>((ref) => ref.watch(clientSessionProvider)?.api);

BrianiApi requireActiveApi(WidgetRef ref) =>
    ref.read(activeApiProvider) ?? (throw StateError('Sign in to a server first.'));

class PairingCode {
  const PairingCode({required this.userCode, required this.deviceName, required this.expiresAt, required this.intervalSeconds});
  final String userCode, deviceName;
  final DateTime expiresAt;
  final int intervalSeconds;
}

class SessionController extends Notifier<ClientSession?> {
  Dio? _dio;
  Dio? _pairDio;
  DeviceCode? _pair;
  ServerProfile? _pairProfile;
  int? _pairEpoch;
  DateTime? _nextPairPoll;
  final Set<Dio> _pending = {};
  Future<void>? _refreshing;
  int _epoch = 0;
  bool _disposed = false;
  bool _current(int epoch) => !_disposed && _epoch == epoch;
  @override
  ClientSession? build() {
    ref.onDispose(() {
      _disposed = true; _epoch++;
      _dio?.close(force: true);
      for (final dio in _pending.toList()) { dio.close(force: true); }
      _pending.clear();
    });
    return null;
  }
  Dio _transport(ServerProfile profile) {
    profile.validateCredentialTransport();
    final dio = Dio(BaseOptions(baseUrl: profile.origin.toString(),
      connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20), followRedirects: false));
    final adapter = ref.read(serverHttpClientAdapterProvider);
    if (adapter != null) dio.httpClientAdapter = adapter;
    return dio;
  }
  int _begin(ServerProfile profile) {
    profile.validateCredentialTransport();
    _epoch++;
    _pair = null; _pairProfile = null; _pairDio = null; _pairEpoch = null; _nextPairPoll = null;
    for (final dio in _pending.toList()) { dio.close(force: true); }
    _pending.clear();
    _dio?.close(force: true); _dio = null; _refreshing = null;
    state = null;
    return _epoch;
  }
  Future<ServerInfo> inspect(ServerProfile profile, {CancelToken? cancelToken}) async {
    final dio = _transport(profile);
    _pending.add(dio);
    try { return (await BrianiApi(dio: dio).getServerApi().getServer(cancelToken: cancelToken)).data!; }
    finally { _pending.remove(dio); dio.close(); }
  }
  Future<bool> restore(ServerProfile profile, {CancelToken? cancelToken}) async {
    final epoch = _begin(profile);
    final credentials = ref.read(sessionCredentialsProvider);
    final refresh = await credentials.read(profile.id);
    if (!_current(epoch) || refresh == null) return false;
    final dio = _transport(profile); _pending.add(dio);
    try {
      final tokens = (await BrianiApi(dio: dio).getIdentityApi().refresh(
        refreshRequest: RefreshRequest((b) => b.refreshToken = refresh), cancelToken: cancelToken)).data!;
      return await _install(profile, tokens, epoch, cancelToken: cancelToken);
    } on DioException catch (error) {
      if (_current(epoch) && error.response?.statusCode == 401) await credentials.clear(profile.id);
      rethrow;
    } finally { _pending.remove(dio); dio.close(); }
  }
  Future<void> login(ServerProfile profile, String username, String password,
      {String? bootstrapCode, String? displayName, String? confirmPassword, CancelToken? cancelToken}) async {
    final epoch = _begin(profile);
    final dio = _transport(profile); _pending.add(dio);
    try {
      final identity = BrianiApi(dio: dio).getIdentityApi();
      final AuthTokens tokens;
      if (bootstrapCode != null) {
        tokens = (await identity.bootstrapAdmin(bootstrapRequest: BootstrapRequest((b) => b
          ..code = bootstrapCode ..username = username ..displayName = displayName ?? username
          ..password = password ..confirmPassword = confirmPassword ?? ''), cancelToken: cancelToken)).data!;
      } else {
        tokens = (await identity.login(loginRequest: LoginRequest((b) => b
          ..username = username ..password = password ..deviceName = 'Briani native client'), cancelToken: cancelToken)).data!;
      }
      await _install(profile, tokens, epoch, cancelToken: cancelToken);
    } finally { _pending.remove(dio); dio.close(); }
  }
  Future<PairingCode> beginPairing(ServerProfile profile, String deviceName) async {
    final epoch = _begin(profile);
    final dio = _transport(profile); _pending.add(dio);
    try {
      final code = (await BrianiApi(dio: dio).getIdentityApi().createDeviceCode(
        deviceCodeRequest: DeviceCodeRequest((b) => b.deviceName = deviceName))).data!;
      if (!_current(epoch)) throw StateError('Connection changed.');
      _pair = code; _pairProfile = profile; _pairDio = dio; _pairEpoch = epoch;
      _nextPairPoll = ref.read(sessionClockProvider)().add(Duration(seconds: code.pollIntervalSeconds.clamp(5, 30)));
      return PairingCode(userCode: code.userCode, deviceName: deviceName, expiresAt: code.expiresAt,
        intervalSeconds: code.pollIntervalSeconds.clamp(5, 30));
    } catch (_) { _pending.remove(dio); dio.close(force: true); rethrow; }
  }
  Future<bool> pollPairing() async {
    final code = _pair, dio = _pairDio, profile = _pairProfile, epoch = _pairEpoch;
    if (code == null || dio == null || profile == null || epoch == null || !_current(epoch)) return false;
    final now = ref.read(sessionClockProvider)();
    if (!now.isBefore(code.expiresAt)) { cancelPairing(); throw StateError('Device code expired.'); }
    if (_nextPairPoll != null && now.isBefore(_nextPairPoll!)) return false;
    _nextPairPoll = now.add(Duration(seconds: code.pollIntervalSeconds.clamp(5, 30)));
    try {
      // The generator selects the 200 model. Reject 202 before deserialization,
      // so a typed pending response cannot be mistaken for authentication tokens.
      final tokens = (await BrianiApi(dio: dio).getIdentityApi().exchangeDeviceCode(
        deviceCodePoll: DeviceCodePoll((b) => b.deviceSecret = code.deviceSecret),
        validateStatus: (status) => status == 200)).data!;
      final installed = await _install(profile, tokens, epoch);
      if (_current(epoch)) { _pair = null; _pairProfile = null; _pairDio = null; _pairEpoch = null; }
      _pending.remove(dio); dio.close();
      return installed;
    } on DioException catch (error) {
      if (error.response?.statusCode == 202) return false;
      if (error.response?.statusCode == 429) {
        _nextPairPoll = now.add(const Duration(seconds: 10)); return false;
      }
      if (_current(epoch)) cancelPairing();
      rethrow;
    }
  }
  void cancelPairing() {
    if (_pairEpoch == null || !_current(_pairEpoch!)) return;
    _epoch++;
    final dio = _pairDio;
    _pair = null; _pairProfile = null; _pairDio = null; _pairEpoch = null; _nextPairPoll = null;
    if (dio != null) { _pending.remove(dio); dio.close(force: true); }
  }
  Future<bool> _install(ServerProfile profile, AuthTokens tokens, int epoch, {CancelToken? cancelToken}) async {
    bool current() => _current(epoch) && cancelToken?.isCancelled != true;
    if (!current()) return false;
    final credentials = ref.read(sessionCredentialsProvider);
    await credentials.save(profile.id, tokens.refreshToken, isCurrent: current);
    if (!current()) return false;
    final dio = _transport(profile); _dio = dio;
    final api = BrianiApi(dio: dio);
    api.setBearerAuth('AccessToken', tokens.accessToken);
    state = ClientSession(profile: profile, api: api, tokens: tokens,
      sessionOnly: credentials.isSessionOnly(profile.id));
    dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) async {
      if (!_current(epoch) || !identical(state?.api, api) ||
          error.response?.statusCode != 401 || error.requestOptions.extra['sessionRetried'] == true
          || error.requestOptions.path.startsWith('/api/v1/auth/')) {
        handler.next(error); return;
      }
      try {
        if (error.requestOptions.headers['Authorization'] == 'Bearer ${state?.tokens.accessToken}') {
          await (_refreshing ??= _refresh(epoch));
        }
        if (!_current(epoch) || !identical(state?.api, api)) { handler.next(error); return; }
        final request = error.requestOptions;
        final data = request.data;
        if (data is FormData) request.data = data.clone();
        request.extra['sessionRetried'] = true;
        request.headers['Authorization'] = 'Bearer ${state!.tokens.accessToken}';
        handler.resolve(await dio.fetch<dynamic>(request));
      } catch (_) { handler.next(error); }
    }));
    return true;
  }
  Future<void> _refresh(int epoch) async {
    final original = state;
    if (original == null || !_current(epoch)) return;
    final credentials = ref.read(sessionCredentialsProvider);
    final dio = _transport(original.profile); _pending.add(dio);
    try {
      final tokens = (await BrianiApi(dio: dio).getIdentityApi().refresh(
        refreshRequest: RefreshRequest((b) => b.refreshToken = original.tokens.refreshToken))).data!;
      if (!_current(epoch)) return;
      await credentials.save(original.profile.id, tokens.refreshToken, isCurrent: () => _current(epoch));
      if (!_current(epoch)) return;
      original.api.setBearerAuth('AccessToken', tokens.accessToken);
      state = ClientSession(profile: original.profile, api: original.api, tokens: tokens,
        sessionOnly: credentials.isSessionOnly(original.profile.id));
    } on DioException catch (error) {
      if (_current(epoch) && error.response?.statusCode == 401) {
        await credentials.clear(original.profile.id);
        if (_current(epoch)) state = null;
      }
      rethrow;
    } finally {
      _pending.remove(dio); dio.close();
      if (_current(epoch)) _refreshing = null;
    }
  }
  Future<void> disconnect({bool logout = false}) async {
    final original = state;
    _epoch++; state = null; _refreshing = null;
    for (final dio in _pending.toList()) { dio.close(force: true); }
    _pending.clear(); _dio?.close(force: true); _dio = null;
    if (original != null && logout) {
      final clearing = ref.read(sessionCredentialsProvider).clear(original.profile.id);
      final dio = _transport(original.profile);
      try {
        final api = BrianiApi(dio: dio)..setBearerAuth('AccessToken', original.tokens.accessToken);
        await api.getIdentityApi().logout();
      } catch (_) {} finally { dio.close(); }
      await clearing;
    }
  }
}
