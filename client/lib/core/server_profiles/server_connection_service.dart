import 'package:briani_api/briani_api.dart';
import 'package:dio/dio.dart';

class ServerConnectionException implements Exception {
  const ServerConnectionException();

  @override
  String toString() => 'Unable to connect to this Briani server.';
}

class ServerConnectionService {
  const ServerConnectionService(this._api);

  final ServerApi _api;

  Future<ServerInfo> check() async {
    try {
      final server = (await _api.getServer()).data;
      if (server == null) throw const ServerConnectionException();
      return server;
    } on DioException {
      throw const ServerConnectionException();
    } on ServerConnectionException {
      rethrow;
    } catch (_) {
      // Generated-client and transport details can contain private URLs or headers.
      throw const ServerConnectionException();
    }
  }
}
