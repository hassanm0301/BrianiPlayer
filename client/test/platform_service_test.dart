import 'dart:io';

import 'package:briani_player/core/platform/platform_capabilities.dart';
import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('org.brianiplayer.app/platform');
final _origin = Uri.parse('https://media.example');
const _streamUrl =
    'https://media.example/stream/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/file.mp4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('external handler and launch forward only scoped media URI and MIME',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'videoHandlers') {
        return [
          {'name': 'VLC', 'package': 'org.videolan.vlc'},
        ];
      }
      return null;
    });
    final service = NativePlatformService();
    addTearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(_channel, null);
    });
    final source = PlaybackSource(_streamUrl, serverOrigin: _origin);

    final handlers = await service.handlers(source, 'video/mp4');
    expect(
      handlers.map((handler) => (handler.name, handler.package)),
      [('VLC', 'org.videolan.vlc')],
    );
    await service.launchVideo(
      source,
      'video/mp4',
      package: 'org.videolan.vlc',
    );

    expect(calls.map((call) => call.method), ['videoHandlers', 'launchVideo']);
    expect(calls[0].arguments, {'url': _streamUrl, 'mime': 'video/mp4'});
    expect(calls[1].arguments, {
      'url': _streamUrl,
      'mime': 'video/mp4',
      'package': 'org.videolan.vlc',
    });
  });

  test('external launch omits package when user has not selected one', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? launch;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'launchVideo') launch = call;
      return null;
    });
    final service = NativePlatformService();
    addTearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(_channel, null);
    });
    await service.launchVideo(
      PlaybackSource(_streamUrl, serverOrigin: _origin),
      'video/x-matroska',
    );

    expect(launch?.arguments, {
      'url': _streamUrl,
      'mime': 'video/x-matroska',
    });
  });

  test('native audio focus events are forwarded and desktop focus is available',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (_) async => null);
    final service = NativePlatformService();
    addTearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(_channel, null);
    });
    final events = <String>[];
    final subscription = service.events.listen(events.add);
    const codec = StandardMethodCodec();

    await messenger.handlePlatformMessage(
      _channel.name,
      codec.encodeMethodCall(const MethodCall('audioFocus', 'ducked')),
      null,
    );
    await messenger.handlePlatformMessage(
      _channel.name,
      codec.encodeMethodCall(const MethodCall('externalReturned')),
      null,
    );
    expect(events, ['ducked', 'externalReturned']);

    final capabilities = await service.capabilities();
    expect(capabilities.television, isFalse);
    expect(capabilities.platform, Platform.operatingSystem);
    expect(await service.requestAudioFocus(), isA<bool>());
    await service.abandonAudioFocus();
    await subscription.cancel();
  });

  test('invalid unscoped URL is rejected before native channel invocation', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
    final service = NativePlatformService();
    addTearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(_channel, null);
    });

    expect(
      () => PlaybackSource(
        'https://other.example/private/video.mp4',
        serverOrigin: _origin,
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
}
