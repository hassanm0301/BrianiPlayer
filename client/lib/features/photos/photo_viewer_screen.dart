import 'dart:async';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting/locale_formatters.dart';
import '../../core/input/remote_navigation.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/session/client_session.dart';
import '../../core/widgets/adaptive.dart';
import '../playback/immersive.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.mediaId,
    this.adjacentMediaIds = const [],
  });
  final String mediaId;
  final List<String> adjacentMediaIds;
  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen>
    with WidgetsBindingObserver, AutoHideChrome {
  late String _mediaId;
  Future<Media>? _mediaFuture;
  Future<Uint8List>? _imageFuture;
  Timer? _slideshow;
  bool _playing = false;
  int _index = 0;
  CancelToken? _loadCancel;
  String? _loadedId;
  // Not a traversal stop: D-pad/Tab move between controls, while arrow keys
  // on the stage itself browse photos.
  final _stageFocus = FocusNode(debugLabel: 'photo stage', skipTraversal: true);
  final _slideshowFocus = FocusNode(debugLabel: 'slideshow toggle');
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// A context below the immersive theme, so sheets and snack bars opened
  /// from this page are dark as well.
  BuildContext get _themed => _scaffoldKey.currentContext ?? context;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mediaId = widget.mediaId;
    _index = widget.adjacentMediaIds
        .indexOf(_mediaId)
        .clamp(
          0,
          widget.adjacentMediaIds.isEmpty
              ? 0
              : widget.adjacentMediaIds.length - 1,
        )
        .toInt();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _television = isTelevision(context);
    chromeConditionsChanged();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        !listEquals(oldWidget.adjacentMediaIds, widget.adjacentMediaIds)) {
      _stop();
      _mediaId = widget.mediaId;
      _index = widget.adjacentMediaIds
          .indexOf(_mediaId)
          .clamp(0, widget.adjacentMediaIds.length);
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isForegroundLifecycle(state)) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadCancel?.cancel();
    _slideshow?.cancel();
    _stageFocus.dispose();
    _slideshowFocus.dispose();
    super.dispose();
  }

  /// Desktop chrome hides when idle; touch and TV chrome hides only during
  /// a slideshow (a tap or key brings it back).
  @override
  bool get chromeMayHide => (pointerPlatform && !_television) || _playing;

  bool _television = false;

  void _load() {
    final api = requireActiveApi(ref).getMediaApi();
    _loadCancel?.cancel();
    final cancel = _loadCancel = CancelToken();
    final id = _mediaId;
    _loadedId = null;
    _mediaFuture = api
        .getMedia(id: id, cancelToken: cancel)
        .then((r) => r.data!);
    _imageFuture = api.getImage(id: id, cancelToken: cancel).then((r) {
      if (!cancel.isCancelled && mounted && _mediaId == id) _loadedId = id;
      return r.data!;
    });
    // Browsing quickly cancels requests nobody listens to any more; keep
    // their cancellation from surfacing as unhandled errors. The current
    // futures still report failures through their FutureBuilders.
    _mediaFuture!.ignore();
    _imageFuture!.ignore();
    if (mounted) setState(() {});
  }

  void _step(int delta) {
    if (widget.adjacentMediaIds.isEmpty) return;
    _index =
        (_index + delta + widget.adjacentMediaIds.length) %
        widget.adjacentMediaIds.length;
    _mediaId = widget.adjacentMediaIds[_index];
    _load();
  }

  void _toggleSlideshow(int intervalSeconds) {
    if (_playing) {
      _stop();
      return;
    }
    if (widget.adjacentMediaIds.length < 2) {
      ScaffoldMessenger.of(_themed).showSnackBar(
        const SnackBar(
          content: Text(
            'Open a folder with multiple photos to start a slideshow.',
          ),
        ),
      );
      return;
    }
    setState(() => _playing = true);
    chromeConditionsChanged();
    _slideshow = Timer.periodic(
      Duration(seconds: intervalSeconds.clamp(1, 3600).toInt()),
      (_) {
        if (_loadedId == _mediaId) _step(1);
      },
    );
  }

  void _stop() {
    _slideshow?.cancel();
    _slideshow = null;
    if (mounted && _playing) {
      setState(() => _playing = false);
      chromeConditionsChanged();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int interval) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // The system Back key always belongs to the route.
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      return KeyEventResult.ignored;
    }
    showChrome();
    // On TV, arrows browse only while the photo itself has focus; once the
    // top bar has focus they move between its buttons.
    final stage = node.hasPrimaryFocus;
    if (_television && !stage) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _stageFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (_television && key == LogicalKeyboardKey.arrowUp) {
      _slideshowFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && stage) {
      if (key == LogicalKeyboardKey.space) {
        _toggleSlideshow(interval);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showInfo() async {
    final future = _mediaFuture;
    if (future == null) return;
    final locale = ref.read(userPreferencesProvider).asData?.value.locale;
    Widget content(BuildContext context) =>
        _PhotoInfo(media: future, locale: locale);
    if (_television) {
      await TvFocusPanel.show<void>(
        context: _themed,
        title: 'Photo details',
        builder: content,
      );
    } else {
      await showModalBottomSheet<void>(
        context: _themed,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: content(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final intervalSeconds = preferences?.slideshowSeconds ?? 5;
    final theme = immersiveTheme(
      seed: accentSeed(preferences?.accentPreset),
      density: Theme.of(context).visualDensity,
      television: _television,
    );
    final multiple = widget.adjacentMediaIds.length > 1;
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          body: Focus(
            focusNode: _stageFocus,
            autofocus: true,
            onKeyEvent: (node, event) => _onKey(node, event, intervalSeconds),
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
                    onTap: pointerPlatform ? showChrome : toggleChrome,
                    child: _stage(),
                  ),
                  _chrome(
                    alignment: Alignment.topCenter,
                    child: _topBar(intervalSeconds),
                  ),
                  if (multiple) ...[
                    _chrome(
                      alignment: Alignment.centerLeft,
                      child: _edgeButton(
                        Icons.chevron_left_rounded,
                        'Previous photo',
                        () => _step(-1),
                      ),
                    ),
                    _chrome(
                      alignment: Alignment.centerRight,
                      child: _edgeButton(
                        Icons.chevron_right_rounded,
                        'Next photo',
                        () => _step(1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps an overlay control so it fades with the rest of the chrome. On
  /// touch screens hidden controls ignore taps, so the first tap only
  /// reveals them; hovering a control keeps the chrome visible.
  Widget _chrome({required Alignment alignment, required Widget child}) =>
      Align(
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

  Widget _edgeButton(IconData icon, String tooltip, VoidCallback onPressed) {
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OverlayIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        size: 32,
        filled: true,
      ),
    );
    // D-pad left/right already browse on TV; the buttons stay as visual
    // affordances without becoming extra focus stops.
    return _television ? ExcludeFocus(child: button) : SafeArea(child: button);
  }

  Widget _topBar(int intervalSeconds) {
    final theme = Theme.of(context);
    final count = widget.adjacentMediaIds.length;
    return ImmersiveScrim(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _television ? 24 : 8,
            _television ? 16 : 12,
            _television ? 24 : 8,
            32,
          ),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<Media>(
                  future: _mediaFuture,
                  builder: (context, snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.data?.name ?? 'Photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (count > 1)
                        Text(
                          '${_index + 1} / $count',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              OverlayIconButton(
                focusNode: _slideshowFocus,
                tooltip: _playing ? 'Stop slideshow' : 'Start slideshow',
                onPressed: () => _toggleSlideshow(intervalSeconds),
                icon: _playing
                    ? Icons.pause_circle_outline
                    : Icons.slideshow_outlined,
              ),
              OverlayIconButton(
                tooltip: 'Photo details',
                onPressed: _showInfo,
                icon: Icons.info_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() => FutureBuilder<Uint8List>(
    future: _imageFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        );
      }
      if (snapshot.hasError) {
        return _StageMessage(
          icon: Icons.broken_image_outlined,
          message: clientError(snapshot.error!),
          action: FilledButton.tonalIcon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty) {
        return const _StageMessage(
          icon: Icons.image_not_supported_outlined,
          message: 'The photo is empty or unavailable.',
        );
      }
      return InteractiveViewer(
        key: ValueKey(_mediaId),
        minScale: .5,
        maxScale: 8,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _StageMessage(
              icon: Icons.image_not_supported_outlined,
              message: 'This image format could not be displayed.',
            ),
          ),
        ),
      );
    },
  );
}

class _StageMessage extends StatelessWidget {
  const _StageMessage({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.white),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

/// Name, format, size and dimensions of the photo on screen.
class _PhotoInfo extends StatelessWidget {
  const _PhotoInfo({required this.media, required this.locale});

  final Future<Media> media;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<Media>(
      future: media,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: snapshot.hasError
                  ? Text(clientError(snapshot.error!))
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final rows = [
          ('Format', value.mimeType),
          ('Size', formatBytes(value.sizeBytes, locale: locale)),
          if (value.width != null && value.height != null)
            ('Dimensions', '${value.width} × ${value.height}'),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(value.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final (label, text) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(text, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
