import 'dart:async';
import 'dart:io';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/playback/playback_adapter.dart';
import '../../core/playback/external_player.dart';
import '../../core/server_profiles/providers.dart';
import '../../core/server_profiles/server_profile.dart';
import '../../core/session/client_session.dart';
import '../../core/input/remote_navigation.dart';
import '../../core/input/tv_auto_hide_controls.dart';
import '../../core/widgets/playback_seek_bar.dart';
import '../../core/platform/platform_capabilities.dart';
import 'immersive.dart';

final playbackAdapterFactoryProvider = Provider<PlaybackAdapter Function()>(
  (ref) => () {
    final device = ref.read(devicePreferencesProvider);
    final user =
        ref.read(userPreferencesProvider).asData?.value ??
        defaultUserPreferences();
    return MediaKitPlaybackAdapter(
      cacheBytes: device.cacheBytes,
      hardwareDecoder: switch (device.hardwareDecoder) {
        DecoderPreference.disabled => 'no',
        DecoderPreference.safe => 'auto-safe',
        DecoderPreference.automatic => 'auto',
      },
      subtitleScale: user.subtitleScale ?? 1,
      audioLanguage: user.preferredAudioLanguage,
      subtitleLanguage: user.preferredSubtitleLanguage,
    );
  },
);

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.kind, required this.targetId});
  final String kind, targetId;
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver, AutoHideChrome {
  PlaybackAdapter? _player;
  PlaybackSession? _session;
  BrianiApi? _api;
  ClientSession? _account;
  PlaybackSource? _source;
  StreamSubscription<PlaybackState>? _subscription;
  StreamSubscription<String>? _platformEvents;
  NativePlatformService? _platform;
  Timer? _progressTimer, _retryTimer;
  final _cancel = CancelToken();
  PlaybackState _state = const PlaybackState();
  BoxFit _fit = BoxFit.contain;
  String? _error;
  Widget? _videoView;
  PlaybackAdapter? _viewPlayer;
  BoxFit? _viewFit;
  String _status = 'Preparing playback';
  int _progressVersion = 0, _retryCount = 0, _openEpoch = 0;
  bool _saving = false, _busy = false, _fullscreen = false, _closing = false;
  bool _saveAgain = false,
      _opened = false,
      _observedPlayback = false,
      _wasWatched = false;
  Duration _lastPosition = Duration.zero;
  String? _progressMediaId;
  bool _foreground = true, _audioAllowed = true, _preferExternal = false;
  // Presentation state only.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _pageFocus = FocusNode(debugLabel: 'player', skipTraversal: true);
  bool _television = false;
  bool? _observedMayHide;
  double? _volumeBeforeMute;

  /// A context below the player's dark theme, so dialogs and sheets opened
  /// from playback match it.
  BuildContext get _themed => _scaffoldKey.currentContext ?? context;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _platform = ref.read(nativePlatformProvider);
    _platformEvents = _platform!.events.listen((event) {
      if (!mounted || _closing) return;
      if (event == 'loss' || event == 'duck') {
        _audioAllowed = false;
        _pauseForInterruption();
      } else if (event == 'externalReturned') {
        _notice(
          'Returned from external playback. Resume internally or mark watched in the library.',
        );
        FocusScope.of(context).requestFocus();
      }
    });
    Future.microtask(_start);
  }

  Future<void> _start() async {
    if (_closing || !mounted) return;
    _account = ref.read(clientSessionProvider);
    if (_account == null) return;
    _api = _account!.api;
    if (!const ['media', 'downloadFile'].contains(widget.kind)) {
      if (mounted) setState(() => _error = 'Unknown media target.');
      return;
    }
    try {
      final mode =
          (ref.read(userPreferencesProvider).asData?.value ??
                  defaultUserPreferences())
              .playbackMode;
      _preferExternal = mode == UserPreferencesPlaybackModeEnum.external_;
      if (mode == UserPreferencesPlaybackModeEnum.ask) {
        final external = await showDialog<bool>(
          context: _themed,
          builder: (context) => AlertDialog(
            scrollable: true,
            icon: const Icon(Icons.play_circle_outline),
            title: const Text('Choose playback'),
            content: const Text(
              'Play in the built-in player, or open the file in another video app on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Play with…'),
              ),
              // The built-in player is the default: it is the primary
              // action and takes initial focus, so Enter/Select plays it.
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Embedded player'),
              ),
            ],
          ),
        );
        if (_closing || !mounted) return;
        if (external == null) {
          Navigator.of(context).maybePop();
          return;
        }
        _preferExternal = external;
      }
      _player = ref.read(playbackAdapterFactoryProvider)();
      _subscription = _player!.states.listen((state) {
        if (!mounted || _closing) return;
        if (_opened &&
            !_busy &&
            state.duration > Duration.zero &&
            (state.position > Duration.zero || _observedPlayback)) {
          _lastPosition = state.position;
          _observedPlayback = true;
        }
        setState(() => _state = state);
        if (state.error != null && !_busy) _recover();
      });
      var position = Duration.zero;
      if (widget.kind == 'media') {
        _progressMediaId = widget.targetId;
        final progress = (await _api!.getMediaApi().getPlaybackProgress(
          id: widget.targetId,
          cancelToken: _cancel,
        )).data!;
        if (_closing || !mounted) return;
        _progressVersion = progress.version;
        _wasWatched = progress.watched;
        final policy =
            (ref.read(userPreferencesProvider).asData?.value ??
                    defaultUserPreferences())
                .resumePolicy;
        if (progress.positionMs > 0 &&
            !progress.watched &&
            mounted &&
            policy != UserPreferencesResumePolicyEnum.never) {
          final resume = policy == UserPreferencesResumePolicyEnum.always
              ? true
              : await showDialog<bool>(
                  context: _themed,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    icon: const Icon(Icons.history),
                    title: const Text('Resume playback?'),
                    content: Text(
                      'You stopped at ${_time(Duration(milliseconds: progress.positionMs))}. Continue from there, or start again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Start from beginning'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Resume'),
                      ),
                    ],
                  ),
                );
          if (_closing || !mounted) return;
          if (resume == true) {
            position = Duration(milliseconds: progress.positionMs);
          }
        }
      }
      await _open(position);
      if (_closing || !mounted) return;
      _progressTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _saveProgress(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    }
  }

  Future<void> _open(Duration position) async {
    if (_closing || _api == null) return;
    final epoch = ++_openEpoch;
    _opened = false;
    _observedPlayback = false;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparing playback';
    });
    try {
      final old = _session;
      if (old != null) {
        try {
          await _api!.getPlaybackApi().revokePlaybackSession(id: old.id);
        } catch (_) {}
      }
      if (_closing || !mounted || epoch != _openEpoch) return;
      var session = (await _api!.getPlaybackApi().createPlaybackSession(
        playbackCreate: PlaybackCreate(
          (b) => b
            ..target.kind = widget.kind == 'media'
                ? PlaybackTargetKindEnum.media
                : PlaybackTargetKindEnum.downloadFile
            ..target.id = widget.targetId
            ..mode = _preferExternal
                ? PlaybackCreateModeEnum.external_
                : PlaybackCreateModeEnum.internal
            ..initialPositionMs = position.inMilliseconds,
        ),
        idempotencyKey: const Uuid().v4(),
        cancelToken: _cancel,
      )).data!;
      _session = session;
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (session.streamUrl == null && DateTime.now().isBefore(deadline)) {
        if (_closing || epoch != _openEpoch) return;
        if (session.state == PlaybackSessionStateEnum.expired ||
            session.state == PlaybackSessionStateEnum.revoked ||
            session.state == PlaybackSessionStateEnum.unavailable) {
          throw StateError('Media is unavailable.');
        }
        if (mounted) {
          setState(() {
            _session = session;
            _status = session.state == PlaybackSessionStateEnum.metadataPending
                ? 'Waiting for media metadata'
                : 'Waiting for verified media data';
          });
        }
        await Future<void>.delayed(
          Duration(seconds: (session.retryAfterSeconds ?? 2).clamp(1, 5)),
        );
        if (_closing || epoch != _openEpoch) return;
        session = (await _api!.getPlaybackApi().getPlaybackSession(
          id: session.id,
          cancelToken: _cancel,
        )).data!;
      }
      if (session.streamUrl == null) throw TimeoutException('Media not ready');
      if (_closing || epoch != _openEpoch) return;
      _session = session;
      try {
        _source = PlaybackSource(
          session.streamUrl!,
          serverOrigin: _account!.profile.origin,
        );
      } on FormatException {
        // An administrator may advertise a public origin for reverse-proxy
        // playback. Read it only from this authenticated profile's API; never
        // move API credentials or accept an origin advertised by media itself.
        final info = (await _api!.getServerApi().getServer(
          cancelToken: _cancel,
        )).data!;
        final public = ServerProfile.parseOrigin(
          info.publicBaseUrl ?? '',
          allowInsecureHttp: _account!.profile.allowInsecureHttp,
        );
        if (!const {'http', 'https'}.contains(public.scheme) ||
            public.host.isEmpty ||
            public.userInfo.isNotEmpty ||
            public.hasQuery ||
            public.hasFragment ||
            public.path != '/' && public.path.isNotEmpty ||
            (_account!.profile.origin.scheme == 'https' &&
                public.scheme != 'https')) {
          rethrow;
        }
        _source = PlaybackSource(session.streamUrl!, serverOrigin: public);
      }
      if (_preferExternal) {
        _preferExternal = false;
        if (mounted) setState(() => _status = 'Choose an external player');
        await _external();
        return;
      }
      _audioAllowed = true;
      if (!await _platform!.requestAudioFocus()) {
        throw StateError('Audio focus is unavailable.');
      }
      if (_closing || !mounted || epoch != _openEpoch) return;
      await _player!.open(_source!, startPosition: position);
      if (_closing || !mounted || epoch != _openEpoch) return;
      _opened = true;
      final preferences =
          ref.read(userPreferencesProvider).asData?.value ??
          defaultUserPreferences();
      await _player!.setSpeed(preferences.defaultPlaybackSpeed ?? 1);
      if (!_foreground || !_audioAllowed) {
        await _player!.pause();
        await _platform!.abandonAudioFocus();
      }
      if (ref.read(devicePreferencesProvider).fullscreenByDefault &&
          !_fullscreen) {
        await _toggleFullscreen();
      }
      if (mounted) {
        setState(
          () => _status = _foreground && _audioAllowed ? 'Playing' : 'Paused',
        );
      }
    } catch (error) {
      if (!_closing && mounted) {
        setState(
          () => _error = error is StateError
              ? 'Media is unavailable. Refresh the download or check your library access.'
              : clientError(error),
        );
      }
    } finally {
      if (!_closing && mounted) setState(() => _busy = false);
    }
  }

  void _recover() {
    if (_retryTimer != null || _closing) return;
    if (_lastPosition == Duration.zero || _retryCount >= 3) {
      setState(
        () => _error = 'Playback could not continue. Retry or choose an external player. The format may be unsupported.',
      );
      return;
    }
    final delay = Duration(seconds: 1 << _retryCount++);
    setState(
      () => _status =
          'Playback interrupted; retrying from ${_time(_lastPosition)}',
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _open(_lastPosition);
    });
  }

  Future<void> _saveProgress() async {
    if (_api == null || !_observedPlayback) return;
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saving = true;
    try {
      if (_progressMediaId == null &&
          widget.kind == 'downloadFile' &&
          _session != null) {
        final current = (await _api!.getPlaybackApi().getPlaybackSession(
          id: _session!.id,
        )).data!;
        _progressMediaId = current.importedMediaId;
        if (_progressMediaId != null) {
          final progress = (await _api!.getMediaApi().getPlaybackProgress(
            id: _progressMediaId!,
          )).data!;
          _progressVersion = progress.version;
          _wasWatched = progress.watched;
        }
      }
      final progressId = _progressMediaId;
      if (progressId == null) return;
      final duration = _state.duration.inMilliseconds;
      final plausible =
          duration > 0 && _lastPosition.inMilliseconds <= duration + 10000;
      final progress = (await _api!.getMediaApi().setPlaybackProgress(
        id: progressId,
        progressUpdate: ProgressUpdate(
          (b) => b
            ..positionMs = _lastPosition.inMilliseconds
            ..durationMs = plausible ? duration : null
            ..watched =
                _wasWatched ||
                (plausible && _lastPosition.inMilliseconds >= duration * .95)
            ..version = _progressVersion,
        ),
      )).data!;
      _progressVersion = progress.version;
      _wasWatched = progress.watched;
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        try {
          final current = (await _api!.getMediaApi().getPlaybackProgress(
            id: _progressMediaId!,
          )).data!;
          _progressVersion = current.version;
          _wasWatched = _wasWatched || current.watched;
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      _saving = false;
      if (_saveAgain) {
        _saveAgain = false;
        unawaited(_saveProgress());
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    try {
      if (Platform.isAndroid) {
        await SystemChrome.setEnabledSystemUIMode(
          _fullscreen ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
        );
      } else {
        await windowManager.setFullScreen(!_fullscreen);
      }
      if (mounted) setState(() => _fullscreen = !_fullscreen);
    } catch (_) {
      _notice('Fullscreen is unavailable on this display.');
    }
  }

  void _notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(_themed)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _control(Future<void> Function() action) async {
    if (_closing || _player == null || _busy) return;
    try {
      await action();
    } catch (_) {
      _notice('Playback control is unavailable. Retry playback.');
    }
  }

  Future<void> _playPause({bool? play}) => _control(() async {
    final shouldPlay = play ?? !_state.playing;
    if (shouldPlay) {
      if (!_foreground) return;
      if (!_opened) {
        await _open(_lastPosition);
        return;
      }
      if (await _platform!.requestAudioFocus() && !_closing && _foreground) {
        _audioAllowed = true;
        await _player!.play();
      } else if (!_closing) {
        _notice('Another application is using audio. Try again.');
      }
    } else {
      await _player!.pause();
      await _saveProgress();
      await _platform!.abandonAudioFocus();
    }
  });
  String get _videoMime =>
      (_session?.fileName ?? '').toLowerCase().endsWith('.mkv')
      ? 'video/x-matroska'
      : 'video/mp4';
  Future<void> _external() async {
    final source = _source;
    if (source == null) return;
    if (Platform.isAndroid) {
      try {
        final preferences = ref.read(devicePreferencesProvider);
        final handlers = await _platform!.handlers(source, _videoMime);
        if (!mounted || _closing) return;
        if (handlers.isEmpty) {
          _notice('No compatible video player is installed.');
          return;
        }
        final preferred = preferences.preferredPlayer;
        final chosen = await showDialog<AndroidVideoHandler>(
          context: _themed,
          builder: (context) => SimpleDialog(
            title: const Text('Play with'),
            children: [
              for (final handler in handlers)
                _ChooserOption(
                  icon: Icons.smart_display_outlined,
                  onPressed: () => Navigator.pop(context, handler),
                  label:
                      '${handler.name}${handler.package == preferred ? ' (preferred)' : ''}',
                ),
              const _ChooserNote(
                'External playback does not report progress automatically.',
              ),
            ],
          ),
        );
        if (chosen == null || _closing) return;
        await _player?.pause();
        await _saveProgress();
        await _platform!.abandonAudioFocus();
        await _platform!.launchVideo(
          source,
          _videoMime,
          package: chosen.package,
        );
        await ref
            .read(devicePreferencesProvider.notifier)
            .update(preferences.copyWith(preferredPlayer: chosen.package));
      } on PlatformException catch (error) {
        _notice(
          error.code == 'preferred_unavailable'
              ? 'The selected player is unavailable. Choose another player.'
              : 'The video player could not be opened.',
        );
      } catch (_) {
        _notice('External playback is unavailable.');
      }
      return;
    }
    final service = ExternalPlayerService(ref.read(sharedPreferencesProvider));
    final device = ref.read(devicePreferencesProvider);
    final preferred = device.executablePath == null
        ? null
        : ExternalPlayerProfile(
            name: device.preferredPlayer ?? 'Preferred player',
            executable: device.executablePath!,
            arguments: device.arguments,
            macApplication:
                Platform.isMacOS && device.executablePath!.endsWith('.app'),
          );
    final choices = service.installed();
    final chosen = await showDialog<ExternalPlayerProfile>(
      context: _themed,
      builder: (context) => SimpleDialog(
        title: const Text('Play with'),
        children: [
          if (preferred != null)
            _ChooserOption(
              icon: Icons.star_outline,
              onPressed: () => Navigator.pop(context, preferred),
              label: 'Preferred: ${preferred.name}',
            ),
          for (final choice in choices)
            _ChooserOption(
              icon: Icons.smart_display_outlined,
              onPressed: () => Navigator.pop(context, choice),
              label: choice.name,
            ),
          _ChooserOption(
            icon: Icons.folder_open_outlined,
            label: 'Choose installed player…',
            onPressed: () async {
              final result = await FilePicker.pickFiles(
                type: Platform.isWindows ? FileType.custom : FileType.any,
                allowedExtensions: Platform.isWindows ? ['exe'] : null,
              );
              final path = result.isEmpty ? null : result.single.path;
              if (path != null && context.mounted) {
                Navigator.pop(
                  context,
                  ExternalPlayerProfile(
                    name: File(path).uri.pathSegments.last,
                    executable: path,
                    macApplication: Platform.isMacOS && path.endsWith('.app'),
                  ),
                );
              }
            },
          ),
          const _ChooserNote(
            'External players may handle buffering differently. Playback progress is not reported automatically.',
          ),
        ],
      ),
    );
    if (chosen == null || _closing) return;
    try {
      await _player?.pause();
      await _saveProgress();
      await service.launch(chosen, source);
      await ref
          .read(devicePreferencesProvider.notifier)
          .update(
            device.copyWith(
              preferredPlayer: chosen.name,
              executablePath: chosen.executable,
              arguments: chosen.arguments,
            ),
          );
      _notice(
        'Player opened. Return here to retry or resume internal playback.',
      );
    } catch (error) {
      _notice(
        error is ExternalPlayerException
            ? error.message
            : 'The selected player could not be opened.',
      );
    }
  }

  Future<void> _copyUrl() async {
    if (_source == null) return;
    final copy = await showDialog<bool>(
      context: _themed,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.link),
        title: const Text('Copy playback URL?'),
        content: const Text(
          'Anyone holding this URL can play this file until the session expires or is revoked. It grants access only to this file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
    if (copy == true) {
      await Clipboard.setData(ClipboardData(text: _source!.uri.toString()));
      _notice('Playback URL copied.');
    }
  }

  void _pauseForInterruption() {
    // Interruption must be recorded even while open() owns the control lock.
    // Its completion observes these flags and pauses the newly opened player.
    unawaited(() async {
      try {
        await _player?.pause();
        await _saveProgress();
        await _platform?.abandonAudioFocus();
      } catch (_) {
        /* Opening may have been cancelled concurrently. */
      }
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _pauseForInterruption();
  }

  @override
  void dispose() {
    _closing = true;
    _openEpoch++;
    _cancel.cancel();
    _progressTimer?.cancel();
    _retryTimer?.cancel();
    _subscription?.cancel();
    _platformEvents?.cancel();
    _platform?.abandonAudioFocus().ignore();
    _saveProgress();
    _player?.dispose();
    final session = _session;
    if (session != null) {
      _api
          ?.getPlaybackApi()
          .revokePlaybackSession(id: session.id)
          .catchError(
            (_) => Response<void>(requestOptions: RequestOptions(path: '')),
          );
    }
    if (_fullscreen) {
      if (Platform.isAndroid) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        windowManager.setFullScreen(false);
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    _pageFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------

  static String _time(Duration d) => formatPlaybackTime(d);

  /// Desktop and phone controls hide after a quiet period only while video
  /// is actually playing; TV uses [TvAutoHideControls] instead.
  @override
  bool get chromeMayHide =>
      !_television &&
      _state.playing &&
      !_state.buffering &&
      !_busy &&
      _error == null;

  Future<void> _seekBy(Duration delta) {
    final s = _state;
    return _control(
      () => _player!.seek(
        Duration(
          milliseconds: (s.position + delta).inMilliseconds.clamp(
            0,
            s.duration.inMilliseconds > 0
                ? s.duration.inMilliseconds
                : 0x7fffffff,
          ),
        ),
      ),
    );
  }

  Future<void> _setVolume(double value) =>
      _control(() => _player!.setVolume(value.clamp(0, 100).toDouble()));

  Future<void> _toggleMute() {
    final volume = _state.volume;
    if (volume > 0) {
      _volumeBeforeMute = volume;
      return _setVolume(0);
    }
    return _setVolume(_volumeBeforeMute ?? 100);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      return KeyEventResult.ignored;
    }
    showChrome();
    // Keys that also operate a focused control (Space, arrows) act on the
    // player only while the player surface itself has focus.
    final surface = node.hasPrimaryFocus;
    final repeat = event is KeyRepeatEvent;
    final letters =
        ref
            .read(userPreferencesProvider)
            .asData
            ?.value
            .keyboardShortcutPreset !=
        UserPreferencesKeyboardShortcutPresetEnum.minimal;
    bool handled(void Function() action) {
      action();
      return true;
    }

    final done = switch (key) {
      LogicalKeyboardKey.space when surface && !repeat => handled(_playPause),
      LogicalKeyboardKey.keyK when letters && !repeat => handled(_playPause),
      LogicalKeyboardKey.arrowLeft when surface => handled(
        () => _seekBy(const Duration(seconds: -10)),
      ),
      LogicalKeyboardKey.keyJ when letters => handled(
        () => _seekBy(const Duration(seconds: -10)),
      ),
      LogicalKeyboardKey.arrowRight when surface => handled(
        () => _seekBy(const Duration(seconds: 10)),
      ),
      LogicalKeyboardKey.keyL when letters => handled(
        () => _seekBy(const Duration(seconds: 10)),
      ),
      LogicalKeyboardKey.arrowUp when surface => handled(
        () => _setVolume(_state.volume + 5),
      ),
      LogicalKeyboardKey.arrowDown when surface => handled(
        () => _setVolume(_state.volume - 5),
      ),
      LogicalKeyboardKey.keyM when letters && !repeat => handled(_toggleMute),
      LogicalKeyboardKey.keyF when letters && !repeat => handled(
        _toggleFullscreen,
      ),
      LogicalKeyboardKey.escape when _fullscreen && !repeat => handled(
        _toggleFullscreen,
      ),
      _ => false,
    };
    return done ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onSurfaceTap(PointerDeviceKind? kind) {
    _pageFocus.requestFocus();
    if (kind == PointerDeviceKind.mouse) {
      showChrome();
      if (_player != null && _error == null) _playPause();
    } else {
      toggleChrome();
    }
  }

  Future<void> _tvTracks() => _controlsPanel(
    title: 'Tracks',
    builder: (context) {
      final s = _state;
      final sidecars = _session?.sidecars ?? <PlaybackSidecar>[];
      if (s.audio.isEmpty && s.subtitles.isEmpty && sidecars.isEmpty) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Text('No audio or subtitle tracks are reported yet.'),
        );
      }
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (s.audio.isNotEmpty) ...[
            const _PanelSection('Audio'),
            for (final track in s.audio)
              _ChoiceRow(
                label: track.label,
                selected: track.id == s.audioId,
                onTap: () {
                  Navigator.pop(context);
                  _control(() => _player!.selectAudioTrack(track.id));
                },
              ),
          ],
          if (s.subtitles.isNotEmpty) ...[
            const _PanelSection('Subtitles'),
            for (final track in s.subtitles)
              _ChoiceRow(
                label: track.label,
                selected: track.id == s.subtitleId,
                onTap: () {
                  Navigator.pop(context);
                  _control(() => _player!.selectSubtitleTrack(track.id));
                },
              ),
          ],
          if (sidecars.isNotEmpty) ...[
            const _PanelSection('Subtitle files'),
            for (final sidecar in sidecars)
              _ChoiceRow(
                label: sidecar.name,
                detail: sidecar.language,
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  _control(
                    () => _player!.selectSidecar(
                      sidecar.url,
                      title: sidecar.name,
                      language: sidecar.language,
                    ),
                  );
                },
              ),
          ],
        ],
      );
    },
  );

  Future<void> _tvOptions() => _controlsPanel(
    title: 'Playback options',
    builder: (context) {
      final s = _state;
      Widget chips<T>(
        List<(String, T)> options, {
        required bool Function(T value) selected,
        required void Function(T value) onSelected,
      }) => Padding(
        padding: EdgeInsets.fromLTRB(_panelInset(context), 0, 20, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in options)
              ChoiceChip(
                label: Text(label),
                selected: selected(value),
                onSelected: (_) {
                  Navigator.pop(context);
                  onSelected(value);
                },
              ),
          ],
        ),
      );
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const _PanelSection('Speed'),
          chips<double>(
            [
              for (final speed in [.5, .75, 1.0, 1.25, 1.5, 2.0, 3.0])
                (speed == 1 ? 'Normal' : '${_number(speed)}×', speed),
            ],
            selected: (speed) => (s.speed - speed).abs() < .001,
            onSelected: (speed) => _control(() => _player!.setSpeed(speed)),
          ),
          const _PanelSection('Aspect'),
          chips<BoxFit>(
            const [
              ('Fit', BoxFit.contain),
              ('Fill', BoxFit.cover),
              ('Stretch', BoxFit.fill),
            ],
            selected: (fit) => fit == _fit,
            onSelected: (fit) => setState(() => _fit = fit),
          ),
          const _PanelSection('Subtitle delay'),
          chips<int>(
            [
              for (final ms in [-2000, -1000, -500, 0, 500, 1000, 2000])
                (
                  ms == 0
                      ? 'None'
                      : '${ms > 0 ? '+' : '−'}${_number(ms.abs() / 1000)} s',
                  ms,
                ),
            ],
            selected: (_) => false,
            onSelected: (ms) => _control(
              () => _player!.setSubtitleDelay(Duration(milliseconds: ms)),
            ),
          ),
          const _PanelSection('Volume'),
          chips<double>(
            [
              for (final volume in [0.0, 25.0, 50.0, 75.0, 100.0])
                (volume == 0 ? 'Mute' : '${volume.round()}%', volume),
            ],
            selected: (volume) => (s.volume - volume).abs() < .5,
            onSelected: (volume) => _control(() => _player!.setVolume(volume)),
          ),
          const SizedBox(height: 12),
          Divider(indent: _panelInset(context), endIndent: 20),
          const SizedBox(height: 4),
          ListTile(
            leading: Icon(
              _fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
            title: Text(_fullscreen ? 'Exit fullscreen' : 'Fullscreen'),
            onTap: () {
              Navigator.pop(context);
              _toggleFullscreen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Play with'),
            onTap: _source == null
                ? null
                : () {
                    Navigator.pop(context);
                    _external();
                  },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copy playback URL'),
            onTap: _source == null
                ? null
                : () {
                    Navigator.pop(context);
                    _copyUrl();
                  },
          ),
        ],
      );
    },
  );

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  /// TV gets a focus-preserving panel, wide windows a side sheet and phones
  /// a bottom sheet.
  Future<void> _controlsPanel({
    required String title,
    required WidgetBuilder builder,
  }) {
    final context = _themed;
    if (ref.read(deviceCapabilitiesProvider).value?.television == true) {
      return TvFocusPanel.show<void>(
        context: context,
        title: title,
        builder: builder,
      );
    }
    Widget header(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(_panelInset(context), 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(
            tooltip: 'Close $title',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    if (MediaQuery.sizeOf(context).width >= 840) {
      // General dialogs do not capture the caller's theme like showDialog.
      final theme = Theme.of(context);
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close $title',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => Theme(
          data: theme,
          child: Builder(
            builder: (context) => Align(
              alignment: Alignment.centerRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 380,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          header(context),
                          Flexible(child: builder(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.08, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(context),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    );
  }

  Widget _video() {
    if (_player == null) return const SizedBox.shrink();
    if (_videoView == null ||
        !identical(_viewPlayer, _player) ||
        _viewFit != _fit) {
      _viewPlayer = _player;
      _viewFit = _fit;
      _videoView = _player!.buildView(fit: _fit);
    }
    return _videoView!;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientSessionProvider, (old, current) {
      if (current == null) _player?.stop().ignore();
    });
    final television =
        ref.watch(deviceCapabilitiesProvider).value?.television == true;
    _television = television;
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final mayHide = chromeMayHide;
    if (mayHide != _observedMayHide) {
      _observedMayHide = mayHide;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) chromeConditionsChanged();
      });
    }
    final s = _state;
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: RemoteNavigationScope(
        television: television,
        onMediaPlayPause: () => _playPause(),
        onMediaPlay: () => _playPause(play: true),
        onMediaPause: () => _playPause(play: false),
        child: Theme(
          data: immersiveTheme(
            seed: accentSeed(preferences?.accentPreset),
            density: Theme.of(context).visualDensity,
            television: television,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.black,
              body: Builder(
                builder: (context) => television
                    ? _televisionLayout(context, s)
                    : _overlayLayout(s),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _televisionLayout(BuildContext context, PlaybackState s) => Stack(
    fit: StackFit.expand,
    children: [
      Center(child: _video()),
      _centerStatus(context, s),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: TvAutoHideControls(
          playing: s.playing,
          child: TvPlayerControls(
            playing: s.playing,
            position: s.position,
            duration: s.duration,
            title: _session?.fileName,
            onPlayPause: () => _playPause(),
            onSeekBack: () => _seekBy(const Duration(seconds: -10)),
            onSeekForward: () => _seekBy(const Duration(seconds: 10)),
            onTracks: () => _tvTracks(),
            onOptions: () => _tvOptions(),
          ),
        ),
      ),
    ],
  );

  Widget _overlayLayout(PlaybackState s) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      return Focus(
        focusNode: _pageFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => showChrome(),
          cursor: chromeVisible || !pointerPlatform
              ? MouseCursor.defer
              : SystemMouseCursors.none,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _onSurfaceTap(details.kind),
                onDoubleTap: pointerPlatform ? _toggleFullscreen : null,
                child: Center(child: _video()),
              ),
              _centerStatus(context, s),
              _chrome(Alignment.topCenter, _topBar(context)),
              _chrome(
                Alignment.bottomCenter,
                _bottomBar(context, s, compact: compact),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Wraps overlay chrome so it fades as one. Hidden controls ignore touch
  /// (the first tap reveals them); a mouse reveals them by hovering.
  Widget _chrome(Alignment alignment, Widget child) => Align(
    alignment: alignment,
    child: IgnorePointer(
      ignoring: !chromeVisible && !pointerPlatform,
      child: AnimatedOpacity(
        opacity: chromeVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Listener(
          onPointerDown: (_) => holdChrome(true),
          onPointerUp: (_) => holdChrome(false),
          onPointerCancel: (_) => holdChrome(false),
          child: MouseRegion(
            onEnter: (_) => hoverChrome(true),
            onExit: (_) => hoverChrome(false),
            child: child,
          ),
        ),
      ),
    ),
  );

  Widget _topBar(BuildContext context) {
    final theme = Theme.of(context);
    return ImmersiveScrim(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _session?.fileName ?? 'Playback',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              OverlayIconButton(
                tooltip: 'Play with',
                onPressed: _source == null ? null : _external,
                icon: Icons.open_in_new,
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                iconColor: Colors.white,
                position: PopupMenuPosition.under,
                onSelected: (value) {
                  if (value == 'copy') _copyUrl();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'copy',
                    enabled: _source != null,
                    child: const Row(
                      children: [
                        Icon(Icons.link, size: 20),
                        SizedBox(width: 12),
                        Text('Copy playback URL'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    PlaybackState s, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _player != null;
    final timeStyle = theme.textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: Colors.white.withValues(alpha: .28),
      thumbColor: scheme.primary,
      overlayColor: Colors.white.withValues(alpha: .14),
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final volume = s.volume;
    return ImmersiveScrim(
      fromTop: false,
      opacity: .8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 20,
            56,
            compact ? 8 : 20,
            compact ? 4 : 12,
          ),
          child: SliderTheme(
            data: sliderTheme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.duration > Duration.zero)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: PlaybackSeekBar(
                      position: s.position,
                      duration: s.duration,
                      showTimes: true,
                      timeStyle: timeStyle,
                      onSeek: _player == null
                          ? null
                          : (position) =>
                                _control(() => _player!.seek(position)),
                    ),
                  ),
                Row(
                  children: [
                    OverlayIconButton(
                      tooltip: s.playing ? 'Pause' : 'Play',
                      onPressed: enabled ? () => _playPause() : null,
                      icon: s.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                    ),
                    SizedBox(width: compact ? 0 : 4),
                    OverlayIconButton(
                      tooltip: 'Back 10 seconds',
                      onPressed: enabled
                          ? () => _seekBy(const Duration(seconds: -10))
                          : null,
                      icon: Icons.replay_10_rounded,
                    ),
                    OverlayIconButton(
                      tooltip: 'Forward 10 seconds',
                      onPressed: enabled
                          ? () => _seekBy(const Duration(seconds: 10))
                          : null,
                      icon: Icons.forward_10_rounded,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      OverlayIconButton(
                        tooltip: volume == 0 ? 'Unmute' : 'Mute',
                        onPressed: enabled ? _toggleMute : null,
                        icon: volume == 0
                            ? Icons.volume_off_rounded
                            : volume < 50
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                      ),
                      SizedBox(
                        width: 112,
                        child: Slider(
                          value: volume.clamp(0, 100),
                          max: 100,
                          label: 'Volume',
                          semanticFormatterCallback: (v) =>
                              'Volume ${v.round()}%',
                          onChanged: (v) => _player?.setVolume(v),
                        ),
                      ),
                    ],
                    if (s.duration <= Duration.zero &&
                        s.position > Duration.zero)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(_time(s.position), style: timeStyle),
                      ),
                    const Spacer(),
                    OverlayIconButton(
                      tooltip: 'Tracks',
                      onPressed: enabled ? _tvTracks : null,
                      icon: Icons.subtitles_outlined,
                    ),
                    SizedBox(width: compact ? 0 : 4),
                    OverlayIconButton(
                      tooltip: 'Playback options',
                      onPressed: enabled ? _tvOptions : null,
                      icon: Icons.settings_outlined,
                    ),
                    SizedBox(width: compact ? 0 : 4),
                    OverlayIconButton(
                      tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                      onPressed: _toggleFullscreen,
                      icon: _fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opening/buffering progress and playback errors, kept visible even when
  /// the rest of the chrome is hidden.
  Widget _centerStatus(BuildContext context, PlaybackState s) {
    final theme = Theme.of(context);
    if (_error != null) {
      // On TV the card sits above the bottom controls it would otherwise meet.
      return Align(
        alignment: _television ? const Alignment(0, -.45) : Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              color: theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 36,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (_source != null)
                          OutlinedButton.icon(
                            onPressed: _external,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Play with'),
                          ),
                        FilledButton.icon(
                          autofocus: _television,
                          onPressed: _busy
                              ? null
                              : () {
                                  _retryCount = 0;
                                  _open(_lastPosition);
                                },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final retrying = _retryTimer != null;
    final waiting = _player == null || _busy || retrying || s.buffering;
    if (!waiting) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .62),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _busy || retrying || _player == null
                        ? _status
                        : 'Buffering… Waiting for more downloaded data.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left inset that lines panel headings and chips up with list tile text.
double _panelInset(BuildContext context) =>
    8 +
    (ListTileTheme.of(context).contentPadding
            ?.resolve(TextDirection.ltr)
            .left ??
        16);

class _PanelSection extends StatelessWidget {
  const _PanelSection(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(_panelInset(context), 16, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ListTile(
      selected: selected,
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: detail == null ? null : Text(detail!),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    ),
  );
}

class _ChooserOption extends StatelessWidget {
  const _ChooserOption({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SimpleDialogOption(
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 16),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _ChooserNote extends StatelessWidget {
  const _ChooserNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
