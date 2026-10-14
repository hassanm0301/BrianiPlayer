import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'fixtures/baseline.dart';

Uint8List _ownedPcm(int seconds) {
  final data = ByteData(44 + 16000 * seconds);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
  ascii(0, 'RIFF'); data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  ascii(8, 'WAVE'); ascii(12, 'fmt '); data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little); data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little); data.setUint16(34, 16, Endian.little);
  ascii(36, 'data'); data.setUint32(40, data.lengthInBytes - 44, Endian.little);
  return data.buffer.asUint8List();
}

String _sanitize(String text, Directory root) => text
  .replaceAll(RegExp(r'/media/[A-Za-z0-9_-]{43}/'), '/media/<relay-redacted>/')
  .replaceAll(RegExp(r'/stream/[A-Za-z0-9_-]{43}/'), '/stream/<fixture-redacted>/')
  .replaceAll(root.path, '<owned-cache>');

Future<Map<String, Object?>> _pixelEvidence(List<int> png) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final image = (await codec.getNextFrame()).image;
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (pixels == null) throw StateError('Cannot read screenshot pixels.');
  var saturated = 0, red = 0, green = 0, blue = 0, sampled = 0;
  for (var y = image.height ~/ 10; y < image.height * 9 ~/ 10; y++) {
    for (var x = image.width ~/ 10; x < image.width * 9 ~/ 10; x++) {
      final offset = (y * image.width + x) * 4;
      final r = pixels.getUint8(offset), g = pixels.getUint8(offset + 1), b = pixels.getUint8(offset + 2);
      final maximum = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final minimum = r < g ? (r < b ? r : b) : (g < b ? g : b);
      sampled++;
      if (maximum > 96 && maximum - minimum > 60) saturated++;
      if (r > g + 40 && r > b + 40) red++;
      if (g > r + 40 && g > b + 40) green++;
      if (b > r + 40 && b > g + 40) blue++;
    }
  }
  final result = <String, Object?>{'width': image.width, 'height': image.height,
    'sampledPixels': sampled, 'saturatedPixels': saturated,
    'redPixels': red, 'greenPixels': green, 'bluePixels': blue};
  image.dispose(); codec.dispose();
  return result;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android packaged native parser stays inside issued capabilities', (tester) async {
    expect(Platform.isAndroid, true, reason: 'Execute on an actual Android emulator/device.');
    mk.MediaKit.ensureInitialized();
    final root = await Directory.systemTemp.createTemp('briani-m08-android-security-');
    final localAudio = File('${root.path}/owned-three-second.wav');
    await localAudio.writeAsBytes(_ownedPcm(3));
    final bytes = base64Decode(nativeBaselineFixtures['mp4']!);
    final requests = <Map<String, Object?>>[];
    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final secondary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = Uri.parse('http://127.0.0.1:${primary.port}');
    final other = Uri.parse('http://127.0.0.1:${secondary.port}');
    final ticket = List.filled(43, 'a').join();
    const fixtures = ['baseline.mp4', 'foreign-playlist.mp4', 'same-playlist.mp4',
      'foreign-hls.mp4', 'redirect.mp4', 'http-folder.mp4', 'local-folder.mp4',
      'local-file.mp4'];
    final secondarySubscription = secondary.listen((request) async {
      requests.add({'origin': 'secondary', 'method': request.method,
        'path': _sanitize(request.uri.path, root)});
      try {
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.contentLength = bytes.length;
        request.response.add(bytes); await request.response.close();
      } catch (_) { /* Owned native request may be cancelled during cleanup. */ }
    });
    final primarySubscription = primary.listen((request) async {
      final name = request.uri.pathSegments.isEmpty ? '' : request.uri.pathSegments.last;
      requests.add({'origin': 'primary', 'method': request.method,
        'path': _sanitize(request.uri.path, root), 'fixture': name,
        'range': request.headers.value('range')});
      try {
        if (name == 'baseline.mp4' || name == 'unscoped-target.mp4') {
          final range = request.headers.value('range');
          final match = range == null ? null : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
          final start = match == null ? 0 : int.parse(match.group(1)!);
          if (start >= bytes.length) {
            request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            await request.response.close(); return;
          }
          final end = match == null || match.group(2)!.isEmpty ? bytes.length - 1
            : int.parse(match.group(2)!).clamp(start, bytes.length - 1);
          request.response.headers.contentType = ContentType('video', 'mp4');
          request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          request.response.contentLength = end - start + 1;
          if (range != null) {
            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(HttpHeaders.contentRangeHeader,
              'bytes $start-$end/${bytes.length}');
          }
          if (request.method != 'HEAD') request.response.add(bytes.sublist(start, end + 1));
        } else if (name == 'redirect.mp4') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(HttpHeaders.locationHeader, '$other/redirect-target.mp4');
        } else if (fixtures.contains(name)) {
          final target = switch (name) {
            'foreign-playlist.mp4' => '$other/foreign-target.mp4',
            'same-playlist.mp4' => '$origin/unscoped-target.mp4',
            'foreign-hls.mp4' => '$other/hls-target.ts',
            'http-folder.mp4' => '$origin/unscoped-folder/',
            'local-folder.mp4' => root.uri.toString(),
            'local-file.mp4' => localAudio.uri.toString(),
            _ => '',
          };
          final payload = name == 'foreign-hls.mp4'
            ? '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:8\n'
              '#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:8,Owned fixture\n$target\n#EXT-X-ENDLIST\n'
            : '#EXTM3U\n#EXTINF:3,Owned fixture\n$target\n';
          final payloadBytes = utf8.encode(payload);
          request.response.headers.contentType = name == 'foreign-hls.mp4'
            ? ContentType('application', 'vnd.apple.mpegurl') : ContentType('video', 'mp4');
          request.response.contentLength = payloadBytes.length;
          request.response.add(payloadBytes);
        } else { request.response.statusCode = HttpStatus.notFound; }
        await request.response.close();
      } catch (_) { /* Owned native request may be cancelled during cleanup. */ }
    });
    MediaKitPlaybackAdapter? adapter;
    StreamSubscription<mk.PlayerLog>? nativeLog;
    final errors = <String>[];
    final observations = <Map<String, Object?>>[];
    Map<String, Object?>? renderedPixels;
    Map<String, Object?>? decodedPixels;
    Map<String, String>? rendererProperties;
    try {
      adapter = MediaKitPlaybackAdapter(cacheBytes: 8 * 1024 * 1024);
      nativeLog = adapter.player.stream.log.listen((log) {
        if (log.level == 'error') errors.add(_sanitize('${log.prefix}: ${log.text}', root));
      });
      final native = adapter.player.platform as mk.NativePlayer;
      await tester.pumpWidget(MaterialApp(home: Scaffold(backgroundColor: Colors.black,
        body: adapter.buildView())));
      for (final name in fixtures) {
        final requestStart = requests.length;
        final errorStart = errors.length;
        await adapter.open(PlaybackSource('$origin/stream/$ticket/$name', serverOrigin: origin))
          .timeout(const Duration(seconds: 10));
        if (name == 'baseline.mp4') {
          final deadline = DateTime.now().add(const Duration(seconds: 20));
          while (adapter.state.position <= Duration.zero && DateTime.now().isBefore(deadline)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await adapter.controller!.waitUntilFirstFrameRendered.timeout(const Duration(seconds: 10));
          expect(adapter.state.position, greaterThan(Duration.zero));
          expect(adapter.player.state.videoParams.w, 160);
          expect(adapter.player.state.videoParams.h, 90);
          expect(adapter.state.audio.any((track) => track.id != 'auto' && track.id != 'no'), true);
          await tester.pump(const Duration(seconds: 2));
          rendererProperties = {for (final option in ['current-vo', 'vo-configured',
            'video-format', 'video-dec-params', 'video-params/pixelformat',
            'estimated-frame-number', 'options/vo'])
            option: _sanitize(await native.getProperty(option), root)};
          final decodedFrame = File('${Directory.systemTemp.path}/briani-m08-decoded-baseline.png');
          if (await decodedFrame.exists()) await decodedFrame.delete();
          await native.command(['screenshot-to-file', decodedFrame.path, 'video']);
          if (await decodedFrame.exists()) decodedPixels = await _pixelEvidence(await decodedFrame.readAsBytes());
          // The host captures adb screencap during this bounded original-surface
          // phase, before conversion to FlutterImageView affects capture semantics.
          // ignore: avoid_print
          print('BRIANI_ANDROID_RENDER_HOLD ${jsonEncode({
            'rendererProperties': rendererProperties, 'decodedPixels': decodedPixels,
            'stateError': adapter.state.error,
            'generatedEvidenceCache': Directory.systemTemp.path,
          })}');
          await tester.pump(const Duration(seconds: 5));
          // The controller's first-frame future is dimension-driven in this
          // locked Android wrapper. Verify actual rendered pixels separately.
          await binding.convertFlutterSurfaceToImage();
          await tester.pump(const Duration(milliseconds: 200));
          final screenshot = await binding.takeScreenshot('android-security-baseline');
          final screenshotFile = File('${Directory.systemTemp.path}/briani-m08-security-baseline.png');
          await screenshotFile.writeAsBytes(screenshot);
          renderedPixels = {...await _pixelEvidence(screenshot),
            'screenshotCacheName': screenshotFile.uri.pathSegments.last};
          // Generated image measurements only; retain evidence even on failure.
          // ignore: avoid_print
          print('BRIANI_ANDROID_RENDER_PIXELS ${jsonEncode(renderedPixels)}');
        } else {
          for (var attempt = 0; attempt < 10; attempt++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        observations.add({'fixture': name, 'requests': requests.sublist(requestStart),
          'nativeErrors': errors.sublist(errorStart), 'durationMs': adapter.state.duration.inMilliseconds,
          'positionMs': adapter.state.position.inMilliseconds,
          'nativePath': _sanitize(await native.getProperty('path'), root),
          'videoCodec': await native.getProperty('video-codec'),
          'decodedVideoParameters': await native.getProperty('video-dec-params'),
          'audioCodec': await native.getProperty('audio-codec')});
        await adapter.stop().timeout(const Duration(seconds: 5));
      }
      final flags = {for (final name in ['config', 'load-scripts', 'ytdl', 'cache-on-disk',
        'access-references', 'ordered-chapters', 'autoload-files', 'demuxer-max-bytes',
        'demuxer-max-back-bytes', 'network-timeout']) name: await native.getProperty('options/$name')};
      final inventory = await native.getProperty('options');
      final ytdlEntries = RegExp(r'\bytdl(?:-format|-raw-options)?\b')
        .allMatches(inventory).map((match) => match.group(0)).toList();
      // Fixture-only evidence; native capability paths and owned cache paths are redacted.
      // ignore: avoid_print
      print('BRIANI_ANDROID_SECURITY_EVIDENCE ${jsonEncode({
        'nativeVersion': await native.getProperty('mpv-version'), 'flags': flags,
        'inventoryCharacters': inventory.length, 'inventoryPrefix': inventory.substring(0, inventory.length.clamp(0, 256)),
        'inventoryYtdlEntries': ytdlEntries, 'scenarios': observations,
        'renderedPixels': renderedPixels,
        'decodedPixels': decodedPixels, 'rendererProperties': rendererProperties,
      })}');
      expect(inventory, isNotEmpty, reason: 'Absent optional features require real native inventory evidence.');
      for (final name in ['config', 'load-scripts', 'cache-on-disk', 'access-references',
        'ordered-chapters', 'autoload-files']) {
        expect(flags[name], 'no', reason: '$name remains a required fail-closed setting.');
      }
      if (flags['ytdl'] == '') {
        expect(ytdlEntries, isEmpty, reason: 'A missing value must never enable present ytdl features.');
      } else { expect(flags['ytdl'], 'no'); }
      for (final name in fixtures) {
        expect(requests.any((request) => request['origin'] == 'primary' && request['fixture'] == name), true,
          reason: 'Each negative payload must reach native parsing, rather than silently skip.');
      }
      expect(requests.where((request) => request['origin'] == 'secondary'), isEmpty);
      expect(requests.where((request) => request['origin'] == 'primary' &&
        !fixtures.contains(request['fixture'])), isEmpty);
      for (final name in ['local-folder.mp4', 'local-file.mp4']) {
        final observed = observations.singleWhere((item) => item['fixture'] == name);
        expect(observed['nativePath'], isNot(contains('<owned-cache>')),
          reason: 'The HTTP payload must not load the owned local path.');
        expect(observed['durationMs'], isNot(3000),
          reason: 'The distinct local PCM fixture must not decode.');
      }
      final sampled = renderedPixels!['sampledPixels']! as int;
      expect(renderedPixels['saturatedPixels'], greaterThan(sampled * .01),
        reason: 'Actual video color pixels must be rendered; dimensions alone are insufficient.');
      for (final color in ['redPixels', 'greenPixels', 'bluePixels']) {
        expect(renderedPixels[color], greaterThan(100));
      }
    } finally {
      await nativeLog?.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await adapter?.dispose().timeout(const Duration(seconds: 5));
      await primary.close(force: true); await secondary.close(force: true);
      await primarySubscription.cancel(); await secondarySubscription.cancel();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('Android ACTION_VIEW bridge rejects malformed capabilities before discovery', (tester) async {
    expect(Platform.isAndroid, true);
    const channel = MethodChannel('org.brianiplayer.app/platform');
    final ticket = List.filled(43, 'a').join();
    final valid = 'http://127.0.0.1:9/stream/$ticket/owned.mp4';
    final invalid = ['file:///owned.mp4', 'intent://owned.mp4',
      'http://member:secret@127.0.0.1:9/stream/$ticket/owned.mp4',
      '$valid?access=fixture', '$valid#fragment',
      'http://127.0.0.1:9/stream/short/owned.mp4',
      'http://127.0.0.1:9/arbitrary/$ticket/owned.mp4',
      'http://127.0.0.1:9/stream/$ticket/bad%0Aname.mp4',
      'http://127.0.0.1:9/stream/$ticket/bad%2Fname.mp4'];
    for (final value in invalid) {
      await expectLater(channel.invokeListMethod<dynamic>('videoHandlers', {'url': value, 'mime': 'video/mp4'}),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'invalid_media')));
    }
    await expectLater(channel.invokeListMethod<dynamic>('videoHandlers', {'url': valid, 'mime': 'text/html'}),
      throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'invalid_media')));
    // Handler discovery only: this test never launches another app or fetches a URL.
    final handlers = await channel.invokeListMethod<dynamic>('videoHandlers', {'url': valid, 'mime': 'video/mp4'});
    expect(handlers?.length ?? 0, lessThanOrEqualTo(32));
    // ignore: avoid_print
    print('BRIANI_ANDROID_INTENT_SECURITY_EVIDENCE ${jsonEncode({
      'invalidRequestsRejected': invalid.length + 1, 'boundedHandlerCount': handlers?.length ?? 0,
      'externalApplicationLaunched': false,
    })}');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
