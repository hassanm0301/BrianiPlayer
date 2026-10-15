import 'dart:async';
import 'dart:io';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

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
    with WidgetsBindingObserver {
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
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choose playback'),
            content: const Text(
              'Use the embedded player or choose an installed video application.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Embedded player'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Play with'),
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
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Resume playback?'),
                    content: Text(
                      'Continue from ${_time(Duration(milliseconds: progress.positionMs))}?',
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
      ScaffoldMessenger.of(context)
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
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Play with'),
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'External playback does not report progress automatically.',
                ),
              ),
              for (final handler in handlers)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, handler),
                  child: Text(
                    '${handler.name}${handler.package == preferred ? ' (preferred)' : ''}',
                  ),
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
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Play with'),
        children: [
          if (preferred != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, preferred),
              child: Text('Preferred: ${preferred.name}'),
            ),
          for (final choice in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, choice),
              child: Text(choice.name),
            ),
          SimpleDialogOption(
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
            child: const Text('Choose installed player…'),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'External players may handle buffering differently. Playback progress is not reported automatically.',
            ),
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
      context: context,
      builder: (context) => AlertDialog(
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
    super.dispose();
  }

  Future<void> _tvTracks() => _controlsPanel(
    title: 'Tracks',
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        for (final track in _state.audio)
          ListTile(
            title: Text('Audio: ${track.label}'),
            onTap: () {
              Navigator.pop(context);
              _control(() => _player!.selectAudioTrack(track.id));
            },
          ),
        for (final track in _state.subtitles)
          ListTile(
            title: Text('Subtitles: ${track.label}'),
            onTap: () {
              Navigator.pop(context);
              _control(() => _player!.selectSubtitleTrack(track.id));
            },
          ),
        for (final sidecar in _session?.sidecars ?? <PlaybackSidecar>[])
          ListTile(
            title: Text(sidecar.name),
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
    ),
  );
  Future<void> _tvOptions() => _controlsPanel(
    title: 'Playback options',
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        for (final speed in [.5, .75, 1.0, 1.25, 1.5, 2.0, 3.0])
          ListTile(
            title: Text('Speed $speed×'),
            onTap: () {
              Navigator.pop(context);
              _control(() => _player!.setSpeed(speed));
            },
          ),
        for (final volume in [0.0, 25.0, 50.0, 75.0, 100.0])
          ListTile(
            title: Text('Volume ${volume.round()}%'),
            onTap: () {
              Navigator.pop(context);
              _control(() => _player!.setVolume(volume));
            },
          ),
        for (final entry in {
          'Fit': BoxFit.contain,
          'Fill': BoxFit.cover,
          'Stretch': BoxFit.fill,
        }.entries)
          ListTile(
            title: Text(entry.key),
            onTap: () {
              Navigator.pop(context);
              setState(() => _fit = entry.value);
            },
          ),
        for (final ms in [-2000, -1000, -500, 0, 500, 1000, 2000])
          ListTile(
            title: Text('Subtitle delay ${ms / 1000}s'),
            onTap: () {
              Navigator.pop(context);
              _control(
                () => _player!.setSubtitleDelay(Duration(milliseconds: ms)),
              );
            },
          ),
        ListTile(
          title: Text(_fullscreen ? 'Exit fullscreen' : 'Fullscreen'),
          onTap: () {
            Navigator.pop(context);
            _toggleFullscreen();
          },
        ),
        ListTile(
          title: const Text('Play with'),
          onTap: _source == null
              ? null
              : () {
                  Navigator.pop(context);
                  _external();
                },
        ),
        ListTile(
          title: const Text('Copy playback URL'),
          onTap: _source == null
              ? null
              : () {
                  Navigator.pop(context);
                  _copyUrl();
                },
        ),
      ],
    ),
  );
  Future<void> _controlsPanel({
    required String title,
    required WidgetBuilder builder,
  }) {
    if (ref.read(deviceCapabilitiesProvider).value?.television == true) {
      return TvFocusPanel.show<void>(
        context: context,
        title: title,
        builder: builder,
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(child: builder(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _video() {
    if (_player == null) return const CircularProgressIndicator();
    if (_videoView == null ||
        !identical(_viewPlayer, _player) ||
        _viewFit != _fit) {
      _viewPlayer = _player;
      _viewFit = _fit;
      _videoView = _player!.buildView(fit: _fit);
    }
    return _videoView!;
  }

  static String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    ref.listen(clientSessionProvider, (old, current) {
      if (current == null) _player?.stop().ignore();
    });
    final television =
        ref.watch(deviceCapabilitiesProvider).value?.television == true;
    final s = _state;
    final max = s.duration.inMilliseconds.toDouble();
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
        child: Scaffold(
          appBar: _fullscreen
              ? null
              : AppBar(
                  title: Text(_session?.fileName ?? 'Playback'),
                  actions: [
                    IconButton(
                      tooltip: 'Play with',
                      onPressed: _source == null ? null : _external,
                      icon: const Icon(Icons.open_in_new),
                    ),
                    IconButton(
                      tooltip: 'Copy playback URL',
                      onPressed: _source == null ? null : _copyUrl,
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
          body: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(child: _video()),
                ),
              ),
              if (_busy || s.buffering)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _busy
                        ? _status
                        : 'Buffering… Waiting for more downloaded data.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _retryCount = 0;
                                _open(_lastPosition);
                              },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (television)
                TvAutoHideControls(
                  playing: s.playing,
                  child: TvPlayerControls(
                    playing: s.playing,
                    position: s.position,
                    duration: s.duration,
                    title: _session?.fileName,
                    onPlayPause: () => _playPause(),
                    onSeekBack: () => _control(
                      () => _player!.seek(
                        Duration(
                          milliseconds: (s.position.inMilliseconds - 10000)
                              .clamp(
                                0,
                                s.duration.inMilliseconds > 0
                                    ? s.duration.inMilliseconds
                                    : 0x7fffffff,
                              ),
                        ),
                      ),
                    ),
                    onSeekForward: () => _control(
                      () => _player!.seek(
                        Duration(
                          milliseconds: (s.position.inMilliseconds + 10000)
                              .clamp(
                                0,
                                s.duration.inMilliseconds > 0
                                    ? s.duration.inMilliseconds
                                    : 0x7fffffff,
                              ),
                        ),
                      ),
                    ),
                    onTracks: () => _tvTracks(),
                    onOptions: () => _tvOptions(),
                  ),
                ),
              if (!television && max > 0)
                PlaybackSeekBar(
                  position: s.position,
                  duration: s.duration,
                  onSeek: _player == null
                      ? null
                      : (position) => _control(() => _player!.seek(position)),
                ),
              if (!television)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: s.playing ? 'Pause' : 'Play',
                        onPressed: _player == null ? null : () => _playPause(),
                        icon: Icon(s.playing ? Icons.pause : Icons.play_arrow),
                      ),
                      Text('${_time(s.position)} / ${_time(s.duration)}'),
                      if (MediaQuery.sizeOf(context).width >= 600)
                        SizedBox(
                          width: 140,
                          child: Slider(
                            value: s.volume.clamp(0, 100),
                            max: 100,
                            label: 'Volume',
                            onChanged: (v) => _player?.setVolume(v),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Tracks',
                        onPressed: _player == null ? null : _tvTracks,
                        icon: const Icon(Icons.subtitles),
                      ),
                      IconButton(
                        tooltip: 'Playback options',
                        onPressed: _player == null ? null : _tvOptions,
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                        onPressed: _toggleFullscreen,
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
