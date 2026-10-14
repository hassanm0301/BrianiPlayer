import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

class _NativeTestBinding extends AutomatedTestWidgetsFlutterBinding {
  // This explicit native suite reaches only owned loopback fixture servers.
  // Flutter's default HTTP-400 mock cannot exercise the production relay.
  @override bool get overrideHttpClient => false;
}

// Explicit native review suite. Requires the installed libmpv and an owned
// MPV_HOME equal to BRIANI_NATIVE_REVIEW_ROOT; never changes a user's config.
Uint8List _wav(int seconds) {
  final size = 8000 * seconds * 2;
  final data = ByteData(44 + size);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
  ascii(0, 'RIFF'); data.setUint32(4, 36 + size, Endian.little);
  ascii(8, 'WAVE'); ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little); data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little); data.setUint16(34, 16, Endian.little);
  ascii(36, 'data'); data.setUint32(40, size, Endian.little);
  return data.buffer.asUint8List();
}

void main() {
  _NativeTestBinding();
  test('native configuration isolation and nested URL boundary', () async {
    final ownedRoot = Platform.environment['BRIANI_NATIVE_REVIEW_ROOT'];
    expect(ownedRoot, isNotNull, reason: 'Run with an owned temporary MPV_HOME.');
    expect(ownedRoot, startsWith('/tmp/briani-m07-native-review-'));
    expect(Platform.environment['MPV_HOME'], ownedRoot);
    final root = Directory(ownedRoot!);
    expect(await root.exists(), true);
    final marker = File('${root.path}/script-executed.marker');
    await File('${root.path}/mpv.conf').writeAsString('volume=13\n');
    await Directory('${root.path}/scripts').create();
    await File('${root.path}/scripts/owned-marker.lua').writeAsString(
      'local f = io.open(${jsonEncode(marker.path)}, "w")\n'
      'if f then f:write("executed"); f:close() end\n');
    final localAudio = File('${root.path}/owned-three-second.wav');
    await localAudio.writeAsBytes(_wav(3));

    final requests = <Map<String, Object?>>[];
    final report = <String, Object?>{};
    final secondary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final primaryOrigin = Uri.parse('http://127.0.0.1:${primary.port}');
    final secondaryOrigin = Uri.parse('http://127.0.0.1:${secondary.port}');
    final ticket = List.filled(43, 'a').join();
    final secondarySubscription = secondary.listen((request) async {
      requests.add({'origin': 'secondary', 'method': request.method,
        'path': request.uri.path, 'range': request.headers.value('range')});
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.contentLength = _wav(2).length;
      request.response.add(_wav(2)); await request.response.close();
    });
    final primarySubscription = primary.listen((request) async {
      requests.add({'origin': 'primary', 'method': request.method,
        'path': request.uri.path, 'range': request.headers.value('range')});
      final name = request.uri.pathSegments.last;
      if (name == 'redirect.mp4') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '$secondaryOrigin/redirect-target.wav');
      } else if (name == 'baseline.mp4' || name == 'same-target.wav') {
        final bytes = _wav(name == 'baseline.mp4' ? 1 : 2);
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
      } else {
        final target = switch (name) {
          'foreign-playlist.mp4' => '$secondaryOrigin/foreign-target.wav',
          'foreign-hls.mp4' => '$secondaryOrigin/hls-target.wav',
          'foreign-hls-mime.mp4' => '$secondaryOrigin/recognized-hls-target.wav',
          'same-playlist.mp4' => '$primaryOrigin/same-target.wav',
          'file-playlist.mp4' => localAudio.uri.toString(),
          _ => throw StateError('Unexpected owned fixture request'),
        };
        // The bytes are generated M3U, even though the scoped source is .mp4.
        final playlist = name.startsWith('foreign-hls')
          ? '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n'
            '#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:2,Owned generated fixture\n'
            '$target\n#EXT-X-ENDLIST\n'
          : '#EXTM3U\n#EXTINF:2,Owned generated fixture\n$target\n';
        final bytes = utf8.encode(playlist);
        request.response.headers.contentType = name == 'foreign-hls-mime.mp4'
          ? ContentType('application', 'vnd.apple.mpegurl') : ContentType('video', 'mp4');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
      }
      await request.response.close();
    });
    MediaKitPlaybackAdapter? adapter;
    StreamSubscription<mk.PlayerLog>? logSubscription;
    final nativeErrors = <String>[];
    try {
      adapter = MediaKitPlaybackAdapter(headless: true, cacheBytes: 8 * 1024 * 1024);
      logSubscription = adapter.player.stream.log.listen((log) {
        if (log.level == 'error') {
          nativeErrors.add('${log.prefix}: ${log.text}'.replaceAll(
            RegExp(r'/media/[A-Za-z0-9_-]{43}/'), '/media/<relay-redacted>/'));
        }
      });
      final native = adapter.player.platform as mk.NativePlayer;
      final snapshots = <Map<String, Object?>>[];
      for (final name in ['baseline.mp4', 'foreign-playlist.mp4',
        'same-playlist.mp4', 'file-playlist.mp4', 'redirect.mp4', 'foreign-hls.mp4',
        'foreign-hls-mime.mp4']) {
        final before = requests.length;
        final errorBefore = nativeErrors.length;
        await adapter.open(PlaybackSource('$primaryOrigin/stream/$ticket/$name',
          serverOrigin: primaryOrigin)).timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 700));
        snapshots.add({'fixture': name, 'requests': requests.sublist(before),
          'nativeErrors': nativeErrors.sublist(errorBefore),
          'durationMs': adapter.state.duration.inMilliseconds,
          'nativePath': (await native.getProperty('path')).replaceAll(
            RegExp(r'/media/[A-Za-z0-9_-]{43}/'), '/media/<relay-redacted>/'),
          'nativeDemuxer': await native.getProperty('demuxer'),
          'nativeAudioCodec': await native.getProperty('audio-codec')});
        await adapter.stop().timeout(const Duration(seconds: 2));
      }
      report.addAll({'nativeVersion': await native.getProperty('mpv-version'),
        'options': {for (final option in ['config', 'load-scripts', 'ytdl',
          'cache-on-disk', 'access-references', 'ordered-chapters',
          'autoload-files', 'demuxer-lavf-o', 'demuxer-max-bytes',
          'demuxer-max-back-bytes', 'network-timeout'])
          option: await native.getProperty('options/$option')},
        'volume': adapter.state.volume,
        'userScriptMarkerExists': await marker.exists(), 'scenarios': snapshots});
      // Print evidence before assertions, so a captured boundary failure cannot
      // be lost to an early exit. Fixture tickets contain no real credentials.
      // This explicit native suite emits sanitized evidence into its test log.
      // ignore: avoid_print
      print('BRIANI_NATIVE_SECURITY_EVIDENCE ${jsonEncode(report)}');
      final baseline = snapshots.first;
      expect(baseline['durationMs'], 1000,
        reason: 'The real native engine must decode the owned positive fixture.');
      expect(baseline['nativeAudioCodec'], contains('PCM'),
        reason: 'A disabled/broken player is not boundary enforcement.');
      final options = report['options']! as Map<String, String>;
      for (final option in ['config', 'load-scripts', 'ytdl', 'cache-on-disk',
        'access-references', 'ordered-chapters', 'autoload-files']) {
        expect(options[option], 'no', reason: '$option must stay disabled.');
      }
      expect(adapter.state.volume, isNot(13), reason: 'User mpv.conf must not load.');
      expect(await marker.exists(), false, reason: 'User scripts must not execute.');
      expect(requests.where((r) => r['origin'] == 'secondary'), isEmpty,
        reason: 'Scoped playback must not follow media/redirect URLs to another origin.');
      expect(requests.where((r) => r['path'] == '/same-target.wav'), isEmpty,
        reason: 'Playlist content must not open arbitrary paths on the server.');
      final local = snapshots.singleWhere((s) => s['fixture'] == 'file-playlist.mp4');
      expect(local['nativePath'], isNot(localAudio.path),
        reason: 'HTTP playlist content must not open a local file.');
      expect(local['durationMs'], isNot(3000),
        reason: 'The distinct local WAV must not be decoded.');
    } finally {
      await logSubscription?.cancel();
      await adapter?.dispose().timeout(const Duration(seconds: 2));
      await primary.close(force: true); await secondary.close(force: true);
      await primarySubscription.cancel(); await secondarySubscription.cancel();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
