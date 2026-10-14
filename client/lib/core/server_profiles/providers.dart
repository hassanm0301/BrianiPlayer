import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:briani_api/briani_api.dart' hide Provider;

import 'credential_vault.dart';
import 'server_profile.dart';
import 'server_profile_repository.dart';

final credentialVaultProvider = Provider<CredentialVault>(
  (ref) => SecureCredentialVault(const FlutterSecureStorage()),
);

final serverProfileRepositoryProvider = Provider<ServerProfileRepository>((
  ref,
) {
  return ServerProfileRepository(
    ref.watch(sharedPreferencesProvider),
    ref.watch(credentialVaultProvider),
  );
});

final serverProfilesProvider = FutureProvider<List<ServerProfile>>(
  (ref) async => ref.watch(serverProfileRepositoryProvider).load(),
);

final serverApiProvider = FutureProvider.family<BrianiApi, ServerProfile>((
  ref,
  profile,
) async {
  profile.validateCredentialTransport();
  final token = await ref
      .read(serverProfileRepositoryProvider)
      .readCredential(profile.id);
  final dio = Dio(
    BaseOptions(
      baseUrl: profile.origin.toString(),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
    ),
  );
  final adapter = ref.watch(serverHttpClientAdapterProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;
  final api = BrianiApi(dio: dio);
  if (token != null && token.isNotEmpty) {
    api.setBearerAuth('AccessToken', token);
  }
  ref.onDispose(() => dio.close(force: true));
  return api;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences must be initialized before use.');
});

final serverHttpClientAdapterProvider = Provider<HttpClientAdapter?>(
  (ref) => null,
);
