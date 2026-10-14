import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps TV controls mounted while temporarily taking them off stage.
///
/// The controls remain in Flutter's focus tree while hidden. This lets the
/// first D-pad/select event both wake the overlay and continue through normal
/// Flutter focus/action dispatch instead of requiring a second key press.
/// Back and media keys are left to the route and playback bindings.
class TvAutoHideControls extends StatefulWidget {
  const TvAutoHideControls({
    super.key,
    required this.playing,
    required this.child,
    this.timeout = const Duration(seconds: 8),
  }) : assert(timeout > Duration.zero);

  final bool playing;
  final Widget child;
  final Duration timeout;

  @override
  State<TvAutoHideControls> createState() => _TvAutoHideControlsState();
}

class _TvAutoHideControlsState extends State<TvAutoHideControls> {
  Timer? _hideTimer;
  ModalRoute<dynamic>? _route;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _updateTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_routeIsCurrent) {
      _restartTimer();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  @override
  void didUpdateWidget(covariant TvAutoHideControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.timeout != widget.timeout) {
      _updateTimer();
    }
  }

  bool get _routeIsCurrent => _route?.isCurrent ?? true;

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || !_routeIsCurrent || event is KeyUpEvent) return false;

    final key = event.logicalKey;
    // Preserve route handling for Back/Escape, and playback bindings for media
    // buttons. In particular, the overlay must never turn Back into Wake.
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      return false;
    }

    if (_isNavigationKey(key)) {
      _showAndRestartTimer();
    } else if (_visible && widget.playing) {
      _restartTimer();
    }
    // Let Focus/Shortcuts/Actions handle this same event after waking.
    return false;
  }

  bool _isNavigationKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter;

  void _showAndRestartTimer() {
    if (!_visible) setState(() => _visible = true);
    _restartTimer();
  }

  void _updateTimer() {
    _hideTimer?.cancel();
    if (!widget.playing) {
      if (!_visible && mounted) setState(() => _visible = true);
      return;
    }
    _restartTimer();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    if (!widget.playing || !_routeIsCurrent) return;
    _hideTimer = Timer(widget.timeout, () {
      if (mounted && widget.playing && _routeIsCurrent && _visible) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _hideTimer?.cancel();
    _hideTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
        key: const ValueKey<String>('tv-auto-hide-controls'),
        offstage: !_visible,
        child: widget.child,
      );
}
