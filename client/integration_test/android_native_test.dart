import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:briani_player/core/platform/platform_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'fixtures/baseline.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  mk.MediaKit.ensureInitialized();
  for (final extension in ['mp4', 'mkv']) {
    testWidgets('Android packaged player renders progressive $extension', (tester) async {
      expect(Platform.isAndroid, true, reason: 'Run on an actual Android emulator/device.');
      final platform = NativePlatformService();
      final capabilities = await platform.capabilities();
      expect(capabilities.sdk, greaterThanOrEqualTo(26));
      expect(await platform.requestAudioFocus(), true);
      final bytes = base64Decode(nativeBaselineFixtures[extension]!);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      final release = Completer<void>();
      var upstreamFinished = false;
      final requests = <String>[];
      final subscription = server.listen((request) async {
        final range = request.headers.value('range');
        requests.add('${request.method} ${range ?? 'full'}');
        final match = range == null ? null : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
        final start = match == null ? 0 : int.parse(match.group(1)!);
        if (start >= bytes.length) { request.response.statusCode = 416; await request.response.close(); return; }
        final end = match == null || match.group(2)!.isEmpty ? bytes.length - 1 : int.parse(match.group(2)!).clamp(start, bytes.length - 1);
        request.response.bufferOutput = false;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType('video', extension == 'mkv' ? 'x-matroska' : 'mp4');
        request.response.contentLength = end - start + 1;
        if (range != null) { request.response.statusCode = 206; request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${bytes.length}'); }
        if (request.method == 'HEAD') { await request.response.close(); return; }
        try {
          if (end == bytes.length - 1) {
            request.response.add(bytes.sublist(start, end)); await request.response.flush();
            await release.future; request.response.add([bytes[end]]);
          } else { request.response.add(bytes.sublist(start, end + 1)); }
          await request.response.close(); upstreamFinished = true;
        } catch (_) { /* Owned fixture connection is cancelled during teardown. */ }
      });
      final adapter = MediaKitPlaybackAdapter(cacheBytes: 8 * 1024 * 1024);
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: adapter.buildView())));
        final diagnosticNative = adapter.player.platform as mk.NativePlayer;
        // ignore: avoid_print
        print('BRIANI_ANDROID_OPTIONS ${jsonEncode({'version': await diagnosticNative.getProperty('mpv-version'),
          'flags': {for (final option in ['config','load-scripts','ytdl','access-references','ordered-chapters','autoload-files','cache-on-disk'])
            option: await diagnosticNative.getProperty('options/$option')}})}');
        await adapter.open(PlaybackSource('$origin/stream/${List.filled(43, 'a').join()}/baseline.$extension', serverOrigin: origin));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (adapter.state.position <= Duration.zero && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await adapter.controller!.waitUntilFirstFrameRendered.timeout(const Duration(seconds: 15));
        expect(adapter.state.position, greaterThan(Duration.zero));
        expect(adapter.player.state.videoParams.w, 160);
        expect(adapter.player.state.videoParams.h, 90);
        expect(adapter.state.audio.any((t) => t.id != 'auto' && t.id != 'no'), true);
        expect(upstreamFinished, false, reason: 'First render must precede the held final upstream byte.');
        final native = adapter.player.platform as mk.NativePlayer;
        // Sanitized local generated-fixture evidence only; no playback URLs.
        // ignore: avoid_print
        print('BRIANI_ANDROID_NATIVE_EVIDENCE ${jsonEncode({'fixture': extension, 'sdk': capabilities.sdk, 'television': capabilities.television,
          'mpv': await native.getProperty('mpv-version'), 'options': {for(final option in ['config','load-scripts','ytdl','access-references','ordered-chapters','autoload-files','cache-on-disk']) option: await native.getProperty('options/$option')}, 'positionMs': adapter.state.position.inMilliseconds,
          'videoCodec': await native.getProperty('video-codec'), 'audioCodec': await native.getProperty('audio-codec'),
          'renderedBeforeCompleteBody': !upstreamFinished, 'requests': requests})}');
        await adapter.pause();
        for (var attempt = 0; attempt < 20 && adapter.state.playing; attempt++) { await tester.pump(const Duration(milliseconds: 50)); }
        expect(adapter.state.playing, false);
        await adapter.play();
        final source = PlaybackSource('$origin/stream/${List.filled(43, 'a').join()}/baseline.$extension', serverOrigin: origin);
        final handlers = await platform.handlers(source, 'video/mp4');
        if (handlers.isEmpty) {
          await expectLater(platform.launchVideo(source, 'video/mp4', package: 'org.brianiplayer.missing'), throwsA(anything));
        }
      } finally {
        if (!release.isCompleted) release.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await adapter.dispose().timeout(const Duration(seconds: 5));
        await platform.abandonAudioFocus(); platform.dispose();
        await server.close(force: true); await subscription.cancel();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
