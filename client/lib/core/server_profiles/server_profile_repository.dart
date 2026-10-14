import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'credential_vault.dart';
import 'server_profile.dart';

class ServerProfileRepository {
  ServerProfileRepository(this._preferences, this._vault);

  static const _profilesKey = 'server_profiles_v1';
  final SharedPreferences _preferences;
  final CredentialVault _vault;

  List<ServerProfile> load() {
    final encoded = _preferences.getString(_profilesKey);
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded) as List<Object?>;
    return decoded
        .map((value) => ServerProfile.fromJson(value! as Map<String, Object?>))
        .toList(growable: false);
  }

  Future<void> save(ServerProfile profile) async {
    final profiles = load().where((item) => item.id != profile.id).toList()
      ..add(profile);
    await _persist(profiles);
  }

  Future<void> remove(String profileId) async {
    await _persist(load().where((profile) => profile.id != profileId).toList());
    await _vault.delete(profileId);
    await _vault.delete('refresh_$profileId');
  }

  Future<String?> readCredential(String profileId) => _vault.read(profileId);
  Future<void> saveCredential(String profileId, String token) =>
      _vault.write(profileId, token);

  Future<void> _persist(List<ServerProfile> profiles) => _preferences.setString(
    _profilesKey,
    jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
  );
}
