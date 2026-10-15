import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:briani_player/core/session/client_session.dart';

DioException _reply(int status, Object? data) {
  final options = RequestOptions(path: '/api/v1/bootstrap');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  test('shows the server detail verbatim', () {
    expect(
      clientError(_reply(400, {
        'title': 'Some of the values are not valid.',
        'status': 400,
        'code': 'validation_failed',
        'detail': 'Usernames must be 3–64 characters.',
      })),
      'Usernames must be 3–64 characters.',
    );
  });

  test('falls back to the server title when detail is absent', () {
    expect(
      clientError(_reply(409, {'title': 'This item was changed.', 'status': 409, 'code': 'version_conflict'})),
      'This item was changed.',
    );
  });

  test('never invents a message from the status code', () {
    final message = clientError(_reply(400, 'not a problem body'));
    expect(message, isNot(contains('Check the values')));
    expect(message, 'The server did not explain this error. Retry or check the server status.');
  });

  test('reports an unreachable server without a server reply', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/v1/server'),
      type: DioExceptionType.connectionError,
    );
    expect(clientError(error), contains('could not be reached'));
  });
}
