import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/server_profiles/server_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryVault implements CredentialVault {
  final values = <String, String>{};

  @override
  Future<void> delete(String profileId) async => values.remove(profileId);

  @override
  Future<String?> read(String profileId) async => values[profileId];

  @override
  Future<void> write(String profileId, String token) async =>
      values[profileId] = token;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'remote HTTP requires opt-in while HTTPS and loopback HTTP are accepted',
    () {
      expect(
        ServerProfile.parseOrigin(' https://media.example/library/ ')
            .toString(),
        'https://media.example/library',
      );
      expect(
        () => ServerProfile.parseOrigin('ftp://media.example'),
        throwsFormatException,
      );
      expect(
        () => ServerProfile.parseOrigin('https://user:secret@media.example'),
        throwsFormatException,
      );
      expect(
        () => ServerProfile.parseOrigin('/relative/path'),
        throwsFormatException,
      );
      expect(
        () => ServerProfile.parseOrigin('http://media.example'),
        throwsFormatException,
      );
      expect(
        ServerProfile.parseOrigin(
          'http://media.example',
          allowInsecureHttp: true,
        ).scheme,
        'http',
      );
      expect(ServerProfile.parseOrigin('http://localhost').host, 'localhost');
      expect(ServerProfile.parseOrigin('http://127.0.0.1').host, '127.0.0.1');
      expect(ServerProfile.parseOrigin('http://[::1]').host, '::1');
    },
  );

  test(
    'trusted-network HTTP opt-in persists and legacy HTTP remains blocked',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = ServerProfileRepository(preferences, MemoryVault());
      final optedIn = ServerProfile(
        id: 'profile-http',
        label: 'Trusted LAN',
        origin: ServerProfile.parseOrigin(
          'http://media.lan',
          allowInsecureHttp: true,
        ),
        allowInsecureHttp: true,
      );
      await repository.save(optedIn);
      expect(repository.load(), [optedIn]);
      expect(
        preferences.getString('server_profiles_v1'),
        contains('allowInsecureHttp'),
      );

      final legacy = ServerProfile.fromJson({
        'id': 'legacy',
        'label': 'Old HTTP profile',
        'origin': 'http://media.example',
      });
      expect(legacy.allowInsecureHttp, isFalse);
      expect(
        legacy.validateCredentialTransport,
        throwsA(isA<InsecureServerTransportException>()),
      );
    },
  );

  test('profile metadata persists separately from credentials and removal clears token', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final vault = MemoryVault();
    final repository = ServerProfileRepository(preferences, vault);
    final profile = ServerProfile(
      id: 'profile-1',
      label: 'Home',
      origin: Uri(scheme: 'https', host: 'media.example'),
    );

    await repository.save(profile);
    await repository.saveCredential(profile.id, 'secret-token');

    expect(repository.load(), [profile]);
    expect(
      preferences.getString('server_profiles_v1'),
      isNot(contains('secret-token')),
    );
    expect(await repository.readCredential(profile.id), 'secret-token');

    await repository.remove(profile.id);
    expect(repository.load(), isEmpty);
    expect(await repository.readCredential(profile.id), isNull);
  });
}
