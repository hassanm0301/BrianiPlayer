import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryVault implements CredentialVault {
  final Map<String, String> values = {};
  int reads = 0;

  @override
  Future<void> delete(String profileId) async => values.remove(profileId);

  @override
  Future<String?> read(String profileId) async {
    reads++;
    return values[profileId];
  }

  @override
  Future<void> write(String profileId, String token) async =>
      values[profileId] = token;
}

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'type': 'about:blank',
        'title': 'Unauthorized',
        'status': 401,
      }),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generated authenticated requests receive the vault token without putting it in the URL', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final vault = MemoryVault()..values['profile-1'] = 'private-token';
    final adapter = RecordingAdapter();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        credentialVaultProvider.overrideWithValue(vault),
        serverHttpClientAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    final profile = ServerProfile(
      id: 'profile-1',
      label: 'Test server',
      origin: ServerProfile.parseOrigin('https://media.example'),
    );
    final api = await container.read(serverApiProvider(profile).future);
    await expectLater(
      api.getIdentityApi().getMe(),
      throwsA(isA<DioException>()),
    );

    expect(adapter.request?.uri.toString(), 'https://media.example/api/v1/me');
    expect(adapter.request?.headers['Authorization'], 'Bearer private-token');
    expect(adapter.request?.uri.toString(), isNot(contains('private-token')));
  });

  test('blocked remote HTTP profiles are rejected before credentials or network are touched', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final vault = MemoryVault()..values['legacy-profile'] = 'private-token';
    final adapter = RecordingAdapter();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        credentialVaultProvider.overrideWithValue(vault),
        serverHttpClientAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    // This simulates a legacy or manually constructed profile that bypassed the editor.
    final profile = ServerProfile(
      id: 'legacy-profile',
      label: 'Legacy HTTP',
      origin: Uri.parse('http://public.example'),
    );
    final providerError = Completer<Object>();
    final subscription = container.listen(serverApiProvider(profile), (
      previous,
      next,
    ) {
      if (next.hasError && !providerError.isCompleted) {
        providerError.complete(next.error!);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await expectLater(
      providerError.future,
      completion(isA<InsecureServerTransportException>()),
    );

    expect(vault.reads, 0);
    expect(adapter.request, isNull);
  });
}
