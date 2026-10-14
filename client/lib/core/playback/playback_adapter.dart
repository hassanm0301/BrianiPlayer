import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'playback_relay.dart';

class PlaybackSource {
  PlaybackSource(String value, {required Uri serverOrigin}) : uri = validate(value, serverOrigin);
  final Uri uri;
  static Uri validate(String value, Uri origin) {
    final uri = Uri.tryParse(value);
    if (value.length > 4096 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value) ||
        uri == null || !const {'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        uri.scheme != origin.scheme || uri.host != origin.host || uri.port != origin.port ||
        !RegExp(r'^/stream/[A-Za-z0-9_-]{43}/[^/]+$').hasMatch(uri.path)) {
      throw const FormatException('Invalid server playback URL.');
    }
    return uri;
  }
  static Uri validateSidecar(String value, Uri origin) {
    final uri = Uri.tryParse(value);
    if (value.length > 4096 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value) ||
      uri == null || !const ['http', 'https'].contains(uri.scheme) || uri.userInfo.isNotEmpty ||
      uri.hasQuery || uri.hasFragment || uri.scheme != origin.scheme || uri.host != origin.host ||
      uri.port != origin.port || !RegExp(r'^/stream/s\.[a-f0-9]{32}\.[a-f0-9]{32}\.[a-fA-F0-9]{64}/[^/]+$').hasMatch(uri.path)) {
      throw const FormatException('Invalid scoped subtitle URL.');
    }
    return uri;
  }
}

class PlaybackTrack {
  const PlaybackTrack(this.id, this.title, this.language);
  final String id;
  final String? title, language;
  String get label => title ?? language ?? (id == 'no' ? 'Off' : id == 'auto' ? 'Automatic' : 'Track $id');
}

class PlaybackState {
  const PlaybackState({this.position = Duration.zero, this.duration = Duration.zero,
    this.playing = false, this.buffering = false, this.completed = false,
    this.volume = 100, this.speed = 1, this.audio = const [], this.subtitles = const [],
    this.audioId = 'auto', this.subtitleId = 'auto', this.error});
  final Duration position, duration;
  final bool playing, buffering, completed;
  final double volume, speed;
  final List<PlaybackTrack> audio, subtitles;
  final String audioId, subtitleId;
  final String? error;
}

abstract interface class PlaybackAdapter {
  Stream<PlaybackState> get states;
  PlaybackState get state;
  Widget buildView({BoxFit fit = BoxFit.contain});
  Future<void> open(PlaybackSource source, {Duration? startPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double value);
  Future<void> setSpeed(double value);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String? id);
  Future<void> selectSidecar(String url, {String? title, String? language});
  Future<void> setSubtitleDelay(Duration delay);
  Future<void> stop();
  Future<void> dispose();
}

class MediaKitPlaybackAdapter implements PlaybackAdapter {
  MediaKitPlaybackAdapter({bool headless = false, int? cacheBytes, String hardwareDecoder = 'auto', double subtitleScale = 1, String? audioLanguage, String? subtitleLanguage}) {
    if (!const {'auto-safe', 'auto', 'no'}.contains(hardwareDecoder) || !subtitleScale.isFinite || subtitleScale < .5 || subtitleScale > 3) throw const FormatException('Invalid playback preferences.');
    for (final language in [audioLanguage, subtitleLanguage]) {
      if (language != null && !RegExp(r'^[a-zA-Z0-9_-]{1,50}$').hasMatch(language)) throw const FormatException('Invalid language preference.');
    }
    mk.MediaKit.ensureInitialized();
    final budget = cacheBytes ?? (Platform.isAndroid ? 32 : 64) * 1024 * 1024;
    if (budget < 8 * 1024 * 1024 || budget > 64 * 1024 * 1024) {
      throw const FormatException('Invalid playback cache budget.');
    }
    player = mk.Player(configuration: mk.PlayerConfiguration(
      title: 'Briani Player', bufferSize: budget, vo: headless ? 'null' : null,
      logLevel: mk.MPVLogLevel.error, protocolWhitelist: const ['http', 'https', 'tcp', 'tls']));
    if (!headless) { controller = VideoController(player, configuration: VideoControllerConfiguration(
      enableHardwareAcceleration: hardwareDecoder != 'no', hwdec: hardwareDecoder == 'auto' ? null : hardwareDecoder)); }
    final streams = <Stream<Object?>>[player.stream.position, player.stream.duration,
      player.stream.playing, player.stream.buffering, player.stream.completed,
      player.stream.volume, player.stream.rate, player.stream.tracks, player.stream.track];
    for (final stream in streams) { _subscriptions.add(stream.listen((_) => _emit())); }
    _subscriptions.add(player.stream.error.listen((_) {
      // Native errors may contain ticket URLs; expose only safe client copy.
      _error = 'Playback was interrupted. Retry from the last position, or choose an external player.';
      _emit();
    }));
    _ready = _configure(budget, headless, subtitleScale, audioLanguage, subtitleLanguage);
    // Preserve the failure for open(), while preventing an unobserved eager error.
    _ready.ignore();
  }
  late final mk.Player player;
  VideoController? controller;
  late final Future<void> _ready;
  final _events = StreamController<PlaybackState>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? _error;
  Uri? _origin;
  PlaybackRelay? _relay;
  bool _disposed = false;
  Future<void> _lifecycle = Future<void>.value();
  Future<void> _serialize(Future<void> Function() action, {bool closing = false}) {
    final next = _lifecycle.then((_) async {
      if (_disposed && !closing) throw StateError('Playback is closed.');
      await action();
    });
    _lifecycle = next.catchError((_) {});
    return next;
  }
  Future<void> _configure(int budget, bool headless, double subtitleScale, String? audioLanguage, String? subtitleLanguage) async {
    final native = player.platform;
    if (native is! mk.NativePlayer) throw StateError('Native playback is required.');
    if (Platform.isAndroid && !headless) {
      // The locked video plugin already identifies emulators to disable their
      // hardware decoder. Gfxstream rejects the zero EGL context flags emitted
      // by this native mpv build; its supported debug bit restores the context.
      // Keep physical-device GPU configuration unchanged.
      final emulator = await const MethodChannel('com.alexmercerind/media_kit_video')
          .invokeMethod<bool>('Utils.IsEmulator').timeout(const Duration(seconds: 5));
      if (emulator == true) {
        await player.handle;
        await native.setProperty('gpu-debug', 'yes', waitForInitialization: false);
        if (await native.getProperty('options/gpu-debug', waitForInitialization: false) != 'yes') {
          throw StateError('The native emulator graphics configuration is unavailable.');
        }
      }
    }
    await native.setProperty('sub-scale', subtitleScale.toString());
    if (audioLanguage != null) await native.setProperty('alang', audioLanguage);
    if (subtitleLanguage != null) await native.setProperty('slang', subtitleLanguage);
    await native.setProperty('cache-on-disk', 'no');
    await native.setProperty('demuxer-max-back-bytes', (budget ~/ 4).toString());
    await native.setProperty('network-timeout', '125');
    await native.setProperty('sub-auto', 'no');
    await native.setProperty('audio-file-auto', 'no');
    await native.setProperty('access-references', 'no');
    await native.setProperty('ordered-chapters', 'no');
    await native.setProperty('autoload-files', 'no');
    if (headless) {
      await native.setProperty('ao', 'null');
      await native.setProperty('vid', 'auto');
    }
    for (final option in ['config', 'load-scripts', 'ytdl', 'access-references',
      'ordered-chapters', 'autoload-files', 'cache-on-disk']) {
      final value = await native.getProperty('options/$option');
      if (option == 'ytdl' && value.isEmpty) {
        // The locked Android build excludes Lua: upstream guards the entire
        // ytdl option/hook behind HAVE_LUA. Require a readable option inventory
        // proving the feature is absent; all script-loading flags still fail closed.
        final inventory = await native.getProperty('options');
        if (inventory.isNotEmpty && !RegExp(r'\bytdl(?:-format|-raw-options)?\b').hasMatch(inventory)) continue;
      }
      if (value != 'no') {
        throw StateError('The native player does not support required safe playback setting: $option.');
      }
    }
  }
  @override Stream<PlaybackState> get states => _events.stream;
  @override PlaybackState get state {
    final s = player.state;
    return PlaybackState(position: s.position, duration: s.duration, playing: s.playing,
      buffering: s.buffering, completed: s.completed, volume: s.volume, speed: s.rate,
      audio: s.tracks.audio.map((t) => PlaybackTrack(t.id, t.title, t.language)).toList(growable: false),
      subtitles: s.tracks.subtitle.map((t) => PlaybackTrack(t.id, t.title, t.language)).toList(growable: false),
      audioId: s.track.audio.id, subtitleId: s.track.subtitle.id, error: _error);
  }
  void _emit() { if (!_disposed) _events.add(state); }
  @override Widget buildView({BoxFit fit = BoxFit.contain}) => controller == null
    ? const SizedBox.shrink() : Video(controller: controller!, fit: fit, controls: NoVideoControls);
  @override Future<void> open(PlaybackSource source, {Duration? startPosition}) => _serialize(() async {
    await _ready;
    _error = null;
    _origin = source.uri;
    await _relay?.close();
    final relay = await PlaybackRelay.open(source.uri);
    if (_disposed) { await relay.close(); return; }
    _relay = relay;
    await player.open(mk.Media(relay.mediaUrl.toString(), start: startPosition));
  });
  @override Future<void> play() => player.play();
  @override Future<void> pause() => player.pause();
  @override Future<void> seek(Duration position) {
    if (position.isNegative) throw const FormatException('Invalid seek position.');
    return player.seek(position);
  }
  @override Future<void> setVolume(double value) {
    if (!value.isFinite || value < 0 || value > 100) throw const FormatException('Invalid volume.');
    return player.setVolume(value);
  }
  @override Future<void> setSpeed(double value) {
    if (!value.isFinite || value < .25 || value > 4) throw const FormatException('Invalid playback speed.');
    return player.setRate(value);
  }
  @override Future<void> selectAudioTrack(String id) {
    final track = player.state.tracks.audio.where((t) => t.id == id).firstOrNull;
    if (track == null) throw const FormatException('Unknown audio track.');
    return player.setAudioTrack(track);
  }
  @override Future<void> selectSubtitleTrack(String? id) {
    if (id == null) return player.setSubtitleTrack(mk.SubtitleTrack.no());
    final track = player.state.tracks.subtitle.where((t) => t.id == id).firstOrNull;
    if (track == null) throw const FormatException('Unknown subtitle track.');
    return player.setSubtitleTrack(track);
  }
  @override Future<void> selectSidecar(String url, {String? title, String? language}) => _serialize(() async {
    final origin = _origin;
    if (origin == null) throw StateError('Open a playback source first.');
    PlaybackSource.validateSidecar(url, origin);
    final relay = _relay;
    if (relay == null) throw StateError('Open a playback source first.');
    await player.setSubtitleTrack(mk.SubtitleTrack.uri(relay.subtitleUrl(Uri.parse(url)).toString(), title: title, language: language));
  });
  @override Future<void> setSubtitleDelay(Duration delay) async {
    if (delay.inMilliseconds.abs() > 600000) throw const FormatException('Invalid subtitle offset.');
    await (player.platform as mk.NativePlayer).setProperty('sub-delay', (delay.inMilliseconds / 1000).toString());
  }
  @override Future<void> stop() {
    // Interrupt an outstanding network read before queued native commands run.
    final interrupted = _relay?.close();
    return _serialize(() async {
      await interrupted; await _relay?.close(); _relay = null; await player.stop();
    });
  }
  @override Future<void> dispose() {
    if (_disposed) return _lifecycle;
    _disposed = true;
    final interrupted = _relay?.close();
    return _serialize(() async {
      for (final subscription in _subscriptions) { await subscription.cancel(); }
      await interrupted; await _relay?.close(); _relay = null;
      await player.dispose(); await _events.close();
    }, closing: true);
  }
}
