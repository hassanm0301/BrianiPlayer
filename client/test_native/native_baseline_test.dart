import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

class _NativeTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get overrideHttpClient => false;
}

// Real installed FFmpeg generates legal fixtures; production adapter performs
// the decode. Explicit native suite only, independent of GUI/hardware claims.
void main() {
  _NativeTestBinding();
  for (final extension in ['mp4', 'mkv']) {
    test('generated $extension decodes through the production relay', () async {
      final ownedRoot = Platform.environment['BRIANI_NATIVE_REVIEW_ROOT'];
      expect(ownedRoot, startsWith('/tmp/briani-m07-native-review-'));
      final fixture = File('$ownedRoot/owned-baseline.$extension');
      final arguments = ['-hide_banner', '-loglevel', 'error', '-nostdin',
        '-f', 'lavfi', '-i', 'testsrc2=size=160x90:rate=24',
        '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=16000',
        '-t', '8', '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
        '-g', '24', '-threads', '1', '-filter_threads', '1',
        '-c:a', 'aac', '-b:a', '32k',
        if (extension == 'mp4') ...['-movflags', '+faststart'],
        '-y', fixture.path];
      final generator = await Process.start('/usr/bin/ffmpeg', arguments,
        runInShell: false);
      final errors = generator.stderr.transform(utf8.decoder).join();
      final stdoutDrained = generator.stdout.drain<void>();
      final generationExit = await generator.exitCode.timeout(
        const Duration(seconds: 4), onTimeout: () {
          generator.kill(ProcessSignal.sigkill);
          throw TimeoutException('Generated fixture process exceeded bound.');
        });
      await stdoutDrained;
      expect(generationExit, 0, reason: await errors);
      final bytes = await fixture.readAsBytes();
      expect(bytes.length, greaterThan(32768));
      final requestEvidence = <Map<String, Object?>>[];
      var responseFinished = false;
      var decodedBeforeFinish = false;
      final releaseTail = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      final subscription = server.listen((request) async {
        final range = request.headers.value('range');
        final match = range == null ? null : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
        final start = match == null ? 0 : int.parse(match.group(1)!);
        final end = match == null || match.group(2)!.isEmpty
          ? bytes.length - 1 : int.parse(match.group(2)!).clamp(start, bytes.length - 1);
        requestEvidence.add({'method': request.method, 'range': range,
          'start': start, 'end': end});
        if (start >= bytes.length) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await request.response.close(); return;
        }
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType('video', extension == 'mkv' ? 'x-matroska' : 'mp4');
        request.response.contentLength = end - start + 1;
        if (range != null) {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${bytes.length}');
        }
        if (request.method == 'HEAD') { await request.response.close(); return; }
        try {
          // Hold the final byte of every end-reaching response so any observed
          // decoded frame/position precedes complete upstream body delivery.
          if (end == bytes.length - 1) {
            request.response.add(bytes.sublist(start, end));
            await request.response.flush();
            await releaseTail.future;
            request.response.add([bytes[end]]);
          } else { request.response.add(bytes.sublist(start, end + 1)); }
          await request.response.close(); responseFinished = true;
        } catch (_) { /* Native stop/dispose can close an owned response. */ }
      });
      MediaKitPlaybackAdapter? adapter;
      try {
        adapter = MediaKitPlaybackAdapter(headless: true, cacheBytes: 8 * 1024 * 1024);
        final native = adapter.player.platform as mk.NativePlayer;
        final ticket = List.filled(43, 'a').join();
        await adapter.open(PlaybackSource('$origin/stream/$ticket/owned.$extension',
          serverOrigin: origin)).timeout(const Duration(seconds: 2));
        bool decoded() => adapter!.state.position > Duration.zero &&
          adapter.player.state.videoParams.w == 160 &&
          adapter.player.state.videoParams.h == 90 &&
          adapter.player.state.tracks.video.any((track) => track.id != 'auto' && track.id != 'no') &&
          adapter.state.audio.any((track) => track.id != 'auto' && track.id != 'no');
        final beforeDeadline = DateTime.now().add(const Duration(seconds: 3));
        while (!decoded() && DateTime.now().isBefore(beforeDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        decodedBeforeFinish = decoded() && !responseFinished;
        if (!releaseTail.isCompleted) releaseTail.complete();
        final completeDeadline = DateTime.now().add(const Duration(seconds: 2));
        while (!decoded() && DateTime.now().isBefore(completeDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        // Emit fixture-only measurements to the explicit native suite's log.
        // ignore: avoid_print
        print('BRIANI_NATIVE_BASELINE_EVIDENCE ${jsonEncode({
          'fixture': extension, 'generatedBytes': bytes.length,
          'generationExit': generationExit,
          'nativeVersion': await native.getProperty('mpv-version'),
          'options': {for (final option in ['demuxer-max-bytes',
            'demuxer-max-back-bytes', 'network-timeout', 'cache-on-disk',
            'config', 'load-scripts', 'ytdl', 'access-references',
            'ordered-chapters', 'autoload-files'])
            option: await native.getProperty('options/$option')},
          'positionMs': adapter.state.position.inMilliseconds,
          'durationMs': adapter.state.duration.inMilliseconds,
          'width': adapter.player.state.videoParams.w,
          'height': adapter.player.state.videoParams.h,
          'nativeVideoCodec': await native.getProperty('video-codec'),
          'nativeAudioCodec': await native.getProperty('audio-codec'),
          'videoTrackIds': adapter.player.state.tracks.video.map((track) => track.id).toList(),
          'audioTrackIds': adapter.state.audio.map((track) => track.id).toList(),
          'decodedBeforeCompleteUpstreamBody': decodedBeforeFinish,
          'requests': requestEvidence,
        })}');
        expect(decoded(), true, reason: 'Real native video/position/audio must be observed.');
      } finally {
        if (!releaseTail.isCompleted) releaseTail.complete();
        await adapter?.dispose().timeout(const Duration(seconds: 2));
        await server.close(force: true); await subscription.cancel();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  }
}
