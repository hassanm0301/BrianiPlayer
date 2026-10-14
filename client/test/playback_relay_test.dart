import 'dart:async';
import 'dart:io';
import 'package:briani_player/core/playback/playback_relay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relay preserves exact ranges, HEAD and never forwards ordinary credentials', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <HttpRequest>[];
    final subscription = upstream.listen((request) async {
      seen.add(request);
      request.response.statusCode = request.method == 'HEAD' ? 200 : 206;
      request.response.contentLength = 4;
      request.response.headers.set('content-range', 'bytes 2-5/10');
      if (request.method != 'HEAD') request.response.add([2, 3, 4, 5]);
      await request.response.close();
    });
    final relay = await PlaybackRelay.open(Uri.parse('http://127.0.0.1:${upstream.port}/stream/issued/file%20café.mp4'));
    final client = HttpClient();
    try {
      final request = await client.getUrl(relay.mediaUrl);
      request.headers.set('range', 'bytes=2-5'); request.headers.set('authorization', 'Bearer ordinary-secret');
      request.headers.set('cookie', 'ordinary-secret');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [2, 3, 4, 5]);
      expect(seen.single.headers.value('range'), 'bytes=2-5');
      expect(seen.single.headers.value('authorization'), null);
      expect(seen.single.headers.value('cookie'), null);
      final head = await client.headUrl(relay.mediaUrl);
      final headers = await head.close();
      expect(headers.statusCode, 200); expect(headers.contentLength, 4); expect(await headers.length, 0);
    } finally { client.close(force: true); await relay.close(); await upstream.close(force: true); await subscription.cancel(); }
  });
  test('redirect response does not contact the redirect target', () async {
    final secondary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var forbidden = 0;
    final sub2 = secondary.listen((request) async { forbidden++; await request.response.close(); });
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sub1 = upstream.listen((request) async {
      request.response.statusCode = 302;
      request.response.headers.set('location', 'http://127.0.0.1:${secondary.port}/forbidden');
      await request.response.close();
    });
    final relay = await PlaybackRelay.open(Uri.parse('http://127.0.0.1:${upstream.port}/issued.mp4'));
    final client = HttpClient();
    try {
      final result = await (await client.getUrl(relay.mediaUrl)).close();
      expect(result.statusCode, 502); await result.drain<void>(); expect(forbidden, 0);
    } finally { client.close(force: true); await relay.close(); await upstream.close(force: true); await secondary.close(force: true); await sub1.cancel(); await sub2.cancel(); }
  });
  test('unknown paths are denied and sidecar registration is deduplicated and bounded', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var calls = 0;
    final subscription = upstream.listen((request) async { calls++; await request.response.close(); });
    final origin = Uri.parse('http://127.0.0.1:${upstream.port}');
    final relay = await PlaybackRelay.open(origin.resolve('/issued.mp4'));
    final client = HttpClient();
    try {
      final first = relay.subtitleUrl(origin.resolve('/issued.srt'));
      for (var i = 0; i < 100; i++) { expect(relay.subtitleUrl(origin.resolve('/issued.srt')), first); }
      for (var i = 0; i < 15; i++) { relay.subtitleUrl(origin.resolve('/subtitle-$i.srt')); }
      expect(() => relay.subtitleUrl(origin.resolve('/too-many.srt')), throwsStateError);
      expect(() => relay.subtitleUrl(Uri.parse('http://foreign.example/subtitle.srt')), throwsFormatException);
      final denied = await (await client.getUrl(relay.mediaUrl.replace(path: '/arbitrary'))).close();
      expect(denied.statusCode, 404); await denied.drain<void>(); expect(calls, 0);
    } finally { client.close(force: true); await relay.close(); await upstream.close(force: true); await subscription.cancel(); }
  });
  for (final withHeaders in [false, true]) {
    test('individual cancelled ranges release slots during ${withHeaders ? 'body gap' : 'header wait'}', () async {
      final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var entered = 0;
      var ended = 0;
      final upstreamSockets = <Socket>[];
      final downstreamSockets = <Socket>[];
      final sub = upstream.listen((socket) {
        upstreamSockets.add(socket);
        var first = true;
        socket.listen((bytes) async {
          if (!first) return;
          first = false;
          entered++;
          if (String.fromCharCodes(bytes).contains('bytes=10-13')) {
            socket.add('HTTP/1.1 206 Partial Content\r\nContent-Length: 4\r\nContent-Range: bytes 10-13/1024\r\nConnection: close\r\n\r\n'.codeUnits);
            socket.add([10, 11, 12, 13]); await socket.flush(); await socket.close();
          } else if (withHeaders) {
            socket.add('HTTP/1.1 206 Partial Content\r\nContent-Length: 1024\r\n\r\n'.codeUnits);
            socket.add([1]); await socket.flush();
          }
        }, onDone: () { ended++; }, onError: (_) { ended++; });
      });
      final relay = await PlaybackRelay.open(Uri.parse('http://127.0.0.1:${upstream.port}/issued.mp4'));
      final client = HttpClient();
      try {
        for (var i = 0; i < 4; i++) {
          final socket = await Socket.connect(relay.mediaUrl.host, relay.mediaUrl.port);
          downstreamSockets.add(socket);
          socket.listen((_) {}, onError: (_) {});
          socket.add('GET ${relay.mediaUrl.path} HTTP/1.1\r\nHost: ${relay.mediaUrl.host}:${relay.mediaUrl.port}\r\nRange: bytes=0-1023\r\n\r\n'.codeUnits);
          await socket.flush();
        }
        final wait = Stopwatch()..start();
        while (entered < 4 && wait.elapsed < const Duration(seconds: 3)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(entered, 4);
        final cancellation = Stopwatch()..start();
        for (final socket in downstreamSockets) { socket.destroy(); }
        while (ended < 4 && cancellation.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ended, 4, reason: 'All cancelled ranges must abort upstream without closing the relay.');
        expect(cancellation.elapsed, lessThan(const Duration(seconds: 2)));
        final request = await client.getUrl(relay.mediaUrl);
        request.headers.set('range', 'bytes=10-13');
        final response = await request.close().timeout(const Duration(seconds: 2));
        expect(response.statusCode, 206);
        expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [10, 11, 12, 13]);
      } finally {
        client.close(force: true); await relay.close();
        for (final socket in [...upstreamSockets, ...downstreamSockets]) { socket.destroy(); }
        await upstream.close(); await sub.cancel();
      }
    });
  }
  test('closing player relay cancels an upstream response waiting for missing data', () async {
    final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final entered = Completer<void>();
    final ended = Completer<void>();
    final sockets = <Socket>[];
    final subscription = upstream.listen((socket) {
      sockets.add(socket);
      var sent = false;
      socket.listen((bytes) async {
        if (sent) return;
        sent = true;
        socket.add('HTTP/1.1 200 OK\r\nContent-Length: 1024\r\nContent-Type: video/mp4\r\n\r\n'.codeUnits);
        socket.add([1]); await socket.flush(); entered.complete();
      }, onDone: () { if (!ended.isCompleted) ended.complete(); },
        onError: (_) { if (!ended.isCompleted) ended.complete(); });
    });
    final relay = await PlaybackRelay.open(Uri.parse('http://127.0.0.1:${upstream.port}/issued.mp4'));
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(relay.mediaUrl)).close().timeout(const Duration(seconds: 3));
      final first = Completer<void>();
      final body = response.listen((bytes) { if (!first.isCompleted) { expect(bytes, [1]); first.complete(); } }, onError: (_) {});
      await entered.future; await first.future.timeout(const Duration(seconds: 3));
      final timer = Stopwatch()..start(); await relay.close().timeout(const Duration(seconds: 2));
      await ended.future.timeout(const Duration(seconds: 2));
      expect(timer.elapsed, lessThan(const Duration(seconds: 2))); await body.cancel();
    } finally {
      client.close(force: true); await relay.close();
      for (final socket in sockets) { socket.destroy(); }
      await upstream.close(); await subscription.cancel();
    }
  });
}
