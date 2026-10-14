import 'dart:io';
import 'package:briani_player/core/playback/external_player.dart';
import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final origin = Uri.parse('https://media.example');
  final ticket = List.filled(43, 'a').join();
  final source = PlaybackSource('https://media.example/stream/$ticket/Film%20%22café%22.mp4', serverOrigin: origin);
  test('spaces, Unicode and quotes remain a single literal URL argument', () {
    const profile = ExternalPlayerProfile(name: 'mpv', executable: '/opt/Media Player/mpv', arguments: ['--', '{url}']);
    expect(profile.argumentsFor(source), ['--', source.uri.toString()]);
  });
  test('rejects executable scripts on Windows and partial URL substitution', () {
    expect(() => const ExternalPlayerProfile(name: 'bad', executable: r'C:\player.cmd').argumentsFor(source, operatingSystem: 'windows'), throwsFormatException);
    expect(() => const ExternalPlayerProfile(name: 'bad', executable: '/usr/bin/mpv', arguments: ['--title={url}']).argumentsFor(source), throwsFormatException);
    expect(() => const ExternalPlayerProfile(name: 'bad', executable: '/usr/bin/mpv', arguments: ['{url}', '{url}']).argumentsFor(source), throwsFormatException);
    expect(() => const ExternalPlayerProfile(name: 'bad', executable: '/usr/bin/mpv', arguments: ['{url}', '\ncommand']).argumentsFor(source), throwsFormatException);
  });
  test('rejects credentials, foreign origins, non-HTTP protocols and arbitrary paths', () {
    for (final value in ['file:///tmp/movie.mp4', 'https://other.example/stream/$ticket/a.mp4',
      'https://token@media.example/stream/$ticket/a.mp4', 'https://media.example/stream/$ticket/a.mp4?accessToken=secret',
      'https://media.example/media/arbitrary.mp4', 'https://media.example/stream/$ticket/a\n.mp4']) {
      expect(() => PlaybackSource(value, serverOrigin: origin), throwsFormatException);
    }
  });
  test('macOS launches a chosen media application with explicit arguments', () {
    const profile = ExternalPlayerProfile(name: 'VLC', executable: '/Applications/VLC.app', macApplication: true);
    expect(profile.argumentsFor(source, operatingSystem: 'macos'), ['-a', '/Applications/VLC.app', '--args', source.uri.toString()]);
  });
  test('production uppercase subtitle signatures retain same-origin scope', () {
    final id = List.filled(32, 'a').join();
    final signature = List.filled(64, 'B').join();
    final url = 'https://media.example/stream/s.$id.$id.$signature/Film.srt';
    expect(PlaybackSource.validateSidecar(url, origin).host, origin.host);
    expect(() => PlaybackSource.validateSidecar(url.replaceFirst('media.example', 'foreign.example'), origin), throwsFormatException);
  });
  test('missing executable produces safe actionable error and no URL disclosure', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ExternalPlayerService(prefs, launch: (executable, arguments) async {
      throw ProcessException(executable, arguments, 'missing $ticket');
    });
    await expectLater(service.launch(const ExternalPlayerProfile(name: 'missing', executable: '/missing/player'), source),
      throwsA(isA<ExternalPlayerException>().having((e) => e.message, 'safe message', isNot(contains(ticket)))));
  });
}
