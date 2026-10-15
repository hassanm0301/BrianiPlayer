import 'package:briani_api/briani_api.dart';
import 'package:dio/dio.dart';

import '../session/client_session.dart';

class ServerConnectionException implements Exception {
  const ServerConnectionException([this.message]);

  /// The server's own message when it replied; null when it could not be reached.
  final String? message;

  @override
  String toString() =>
      message ?? 'Could not reach the server. Check the address and that the server is running.';
}

class ServerConnectionService {
  const ServerConnectionService(this._api);

  final ServerApi _api;

  Future<ServerInfo> check() async {
    try {
      final server = (await _api.getServer()).data;
      if (server == null) throw const ServerConnectionException();
      return server;
    } on DioException catch (error) {
      // Only the server's problem text is surfaced; transport details stay private.
      throw ServerConnectionException(serverMessage(error.response?.data));
    } on ServerConnectionException {
      rethrow;
    } catch (_) {
      // Generated-client and transport details can contain private URLs or headers.
      throw const ServerConnectionException();
    }
  }
}
