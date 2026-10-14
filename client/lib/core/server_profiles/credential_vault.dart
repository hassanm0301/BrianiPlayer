import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialVault {
  Future<String?> read(String profileId);
  Future<void> write(String profileId, String token);
  Future<void> delete(String profileId);
}

class SecureCredentialVault implements CredentialVault {
  SecureCredentialVault(this._storage);

  final FlutterSecureStorage _storage;
  static const _prefix = 'server_access_token_';

  @override
  Future<String?> read(String profileId) =>
      _storage.read(key: '$_prefix$profileId');

  @override
  Future<void> write(String profileId, String token) =>
      _storage.write(key: '$_prefix$profileId', value: token);

  @override
  Future<void> delete(String profileId) =>
      _storage.delete(key: '$_prefix$profileId');
}
