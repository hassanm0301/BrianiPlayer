import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A per-player loopback endpoint. It forwards only the exact issued media and
/// subtitle capabilities, never redirects or arbitrary native-engine URLs.
/// Bytes remain streamed unchanged; no decoding or whole-file buffering occurs.
class PlaybackRelay {
  PlaybackRelay._(this._server, this._client, this._nonce);
  final HttpServer _server;
  final HttpClient _client;
  final String _nonce;
  final Map<String, Uri> _targets = {};
  StreamSubscription<HttpRequest>? _subscription;
  bool _closed = false;
  int _active = 0;
  final Set<void Function()> _cancelRanges = {};
  static Future<PlaybackRelay> open(Uri target) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.idleTimeout = const Duration(seconds: 15);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8)
      ..autoUncompress = false ..findProxy = (_) => 'DIRECT';
    final random = Random.secure();
    final nonce = base64Url.encode(List.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
    final relay = PlaybackRelay._(server, client, nonce);
    relay._register('media', target);
    relay._subscription = server.listen(relay._forward);
    return relay;
  }
  Uri _register(String id, Uri target) {
    final path = Uri(pathSegments: ['', 'media', _nonce, id, target.pathSegments.last]).path;
    _targets[path] = target;
    return Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _server.port, path: path);
  }
  Uri get mediaUrl => Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address,
    port: _server.port, path: _targets.keys.first);
  Uri subtitleUrl(Uri target) {
    if (_closed) throw StateError('Playback is closed.');
    final media = _targets.values.first;
    if (target.scheme != media.scheme || target.host != media.host || target.port != media.port) {
      throw const FormatException('Subtitle origin changed.');
    }
    for (final entry in _targets.entries) {
      if (entry.value == target) return Uri(scheme: 'http', host: _server.address.address, port: _server.port, path: entry.key);
    }
    if (_targets.length >= 17) throw StateError('Subtitle limit reached.');
    return _register('subtitle-${_targets.length}', target);
  }
  Future<void> _forward(HttpRequest request) async {
    final response = request.response;
    response.bufferOutput = false;
    final target = _targets[request.uri.path];
    if (_closed || target == null || request.uri.hasQuery ||
      !const ['GET', 'HEAD'].contains(request.method) || request.contentLength > 0 || request.headers.value(HttpHeaders.transferEncodingHeader) != null ||
      request.headers.value(HttpHeaders.hostHeader) != '${_server.address.address}:${_server.port}') {
      response.statusCode = HttpStatus.notFound; await response.close(); return;
    }
    if (_active >= 4) {
      response.statusCode = HttpStatus.tooManyRequests;
      response.headers.set(HttpHeaders.retryAfterHeader, '1'); await response.close(); return;
    }
    _active++;
    HttpClientRequest? outgoing;
    Socket? socket;
    StreamSubscription<List<int>>? socketEvents;
    StreamIterator<List<int>>? body;
    final disconnected = Completer<void>();
    var cancelled = false;
    void cancel() {
      if (cancelled) return;
      cancelled = true;
      outgoing?.abort();
      body?.cancel().ignore();
      if (!disconnected.isCompleted) disconnected.complete();
    }
    void closeRange() { cancel(); socket?.destroy(); }
    _cancelRanges.add(closeRange);
    Future<T> untilDisconnect<T>(Future<T> pending) => Future.any([
      pending,
      disconnected.future.then<T>((_) => throw const HttpException('Playback range cancelled.')),
    ]);
    try {
      // HttpResponse.done does not observe a peer disconnect while headers or
      // body data are withheld. Own this one-request connection before waiting.
      // No headers are emitted until the upstream response actually arrives.
      socket = await response.detachSocket(writeHeaders: false);
      if (_closed) { closeRange(); return; }
      socketEvents = socket.listen((_) => cancel(), onDone: cancel, onError: (_) => cancel());
      final opened = _client.openUrl(request.method, target).then((value) {
        if (cancelled) value.abort();
        return value;
      });
      final sent = await untilDisconnect(opened);
      outgoing = sent;
      sent.followRedirects = false;
      for (final name in ['range', 'if-range', 'if-match', 'if-none-match', 'if-modified-since']) {
        final value = request.headers.value(name);
        if (value != null) {
          if (value.length > 4096) {
            socket.add('HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'.codeUnits);
            await socket.flush(); return;
          }
          sent.headers.set(name, value);
        }
      }
      final incoming = await untilDisconnect(sent.close().timeout(const Duration(seconds: 65)));
      if (incoming.statusCode >= 300 && incoming.statusCode < 400 && incoming.statusCode != 304) {
        sent.abort();
        socket.add('HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'.codeUnits);
        await socket.flush(); return;
      }
      final hasBody = request.method != 'HEAD' && incoming.statusCode != 204 && incoming.statusCode != 304;
      final chunked = hasBody && incoming.contentLength < 0;
      final headers = StringBuffer('HTTP/1.1 ${incoming.statusCode} ${incoming.reasonPhrase}\r\n');
      for (final name in ['content-type', 'content-length', 'content-range', 'accept-ranges',
        'etag', 'last-modified', 'cache-control', 'retry-after']) {
        final value = incoming.headers.value(name);
        if (value != null) headers.write('$name: $value\r\n');
      }
      if (chunked) headers.write('Transfer-Encoding: chunked\r\n');
      headers.write('Connection: close\r\n\r\n');
      socket.add(latin1.encode(headers.toString()));
      await untilDisconnect(socket.flush());
      if (hasBody) {
        body = StreamIterator(incoming);
        var received = 0;
        while (await untilDisconnect(body.moveNext().timeout(const Duration(seconds: 125)))) {
          final chunk = body.current;
          if (chunk.isEmpty) continue;
          received += chunk.length;
          if (incoming.contentLength >= 0 && received > incoming.contentLength) {
            throw const HttpException('Upstream body exceeded its declared length.');
          }
          if (chunked) socket.add('${chunk.length.toRadixString(16)}\r\n'.codeUnits);
          socket.add(chunk);
          if (chunked) socket.add('\r\n'.codeUnits);
          await untilDisconnect(socket.flush());
        }
        if (incoming.contentLength >= 0 && received != incoming.contentLength) {
          throw const HttpException('Upstream body ended before its declared length.');
        }
        if (chunked) { socket.add('0\r\n\r\n'.codeUnits); await untilDisconnect(socket.flush()); }
      }
    } catch (_) {
      // Closing the connection preserves detectable truncation on a begun body.
    } finally {
      cancel();
      socket?.destroy();
      await socketEvents?.cancel();
      _cancelRanges.remove(closeRange);
      _active--;
    }
  }
  Future<void> close() async {
    if (_closed) return;
    _closed = true; _targets.clear();
    for (final cancel in _cancelRanges.toList()) { cancel(); }
    _client.close(force: true);
    await _server.close(force: true); await _subscription?.cancel();
  }
}
