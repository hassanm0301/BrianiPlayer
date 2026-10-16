import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

export '../../core/widgets/adaptive.dart' show pointerPlatform;


/// Formats a playback position as `m:ss`, or `h:mm:ss` from one hour.
String formatPlaybackTime(Duration value) {
  final seconds = value.isNegative ? 0 : value.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}

/// The dark theme used by full-screen media pages (player, photo viewer) so
/// their overlays, sheets and dialogs read well over black, while keeping the
/// user's accent, density and TV sizing.
ThemeData immersiveTheme({
  required Color seed,
  required VisualDensity density,
  required bool television,
}) {
  final key = (seed, density, television);
  final cached = _immersiveThemes[key];
  if (cached != null) return cached;
  final theme = buildAppTheme(
    seed: seed,
    brightness: Brightness.dark,
    density: density,
    television: television,
  );
  if (_immersiveThemes.length > 8) _immersiveThemes.clear();
  return _immersiveThemes[key] = theme;
}

final _immersiveThemes = <(Color, VisualDensity, bool), ThemeData>{};

/// A vertical black gradient behind overlay chrome so white controls stay
/// legible over bright video frames and photos.
class ImmersiveScrim extends StatelessWidget {
  const ImmersiveScrim({
    super.key,
    required this.child,
    this.fromTop = true,
    this.opacity = .72,
  });

  final Widget child;
  final bool fromTop;
  final double opacity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
        end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: opacity),
          Colors.black.withValues(alpha: opacity * .55),
          Colors.black.withValues(alpha: 0),
        ],
        stops: const [0, .55, 1],
      ),
    ),
    child: child,
  );
}

/// Shows overlay chrome on activity and hides it after a quiet period while
/// [chromeMayHide] allows it. Hovering the controls keeps them visible.
mixin AutoHideChrome<T extends StatefulWidget> on State<T> {
  bool chromeVisible = true;
  Timer? _chromeTimer;
  bool _chromeHovered = false;
  bool _chromeHeld = false;
  bool? _lastMayHide;

  Duration get chromeTimeout => const Duration(seconds: 3);

  /// Whether the chrome may currently hide (for example, while playing).
  bool get chromeMayHide;

  /// Reveal the chrome and restart the quiet period.
  void showChrome() {
    _restartChromeTimer();
    if (!chromeVisible && mounted) setState(() => chromeVisible = true);
  }

  /// A deliberate tap hides the chrome even when it would not auto-hide.
  void toggleChrome() {
    if (chromeVisible) {
      _chromeTimer?.cancel();
      setState(() => chromeVisible = false);
    } else {
      showChrome();
    }
  }

  void hoverChrome(bool hovered) {
    _chromeHovered = hovered;
    hovered ? _chromeTimer?.cancel() : _restartChromeTimer();
  }

  /// A pointer pressed on the controls (a touch on a button, or dragging the
  /// seek bar) keeps them visible until it is released; then the quiet
  /// period starts again. Touch has no hover, so this is its equivalent.
  void holdChrome(bool held) {
    _chromeHeld = held;
    if (held) {
      _chromeTimer?.cancel();
      if (!chromeVisible && mounted) setState(() => chromeVisible = true);
    } else {
      _restartChromeTimer();
    }
  }

  /// Call when an input to [chromeMayHide] may have changed. Only an actual
  /// change restarts the timer, so frequent position updates are cheap.
  void chromeConditionsChanged() {
    final mayHide = chromeMayHide;
    if (mayHide == _lastMayHide) return;
    _lastMayHide = mayHide;
    if (mayHide) {
      _restartChromeTimer();
    } else {
      _chromeTimer?.cancel();
      if (!chromeVisible && mounted) setState(() => chromeVisible = true);
    }
  }

  void _restartChromeTimer() {
    _chromeTimer?.cancel();
    if (!chromeMayHide || _chromeHovered || _chromeHeld) return;
    _chromeTimer = Timer(chromeTimeout, () {
      if (!mounted || !chromeMayHide || _chromeHovered || _chromeHeld) return;
      // Keep the chrome while a menu or sheet covers this page; it hides on
      // the next quiet period after the user returns.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _restartChromeTimer();
        return;
      }
      if (chromeVisible) setState(() => chromeVisible = false);
    });
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _chromeTimer = null;
    super.dispose();
  }
}

/// A translucent round icon button for controls drawn over media.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 24,
    this.filled = false,
    this.focusNode,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    focusNode: focusNode,
    onPressed: onPressed,
    iconSize: size,
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white38,
      // A dark grey disc stays visible over black letterboxing and over
      // bright media alike.
      backgroundColor: filled
          ? const Color(0xFF2A2A2E).withValues(alpha: .78)
          : null,
      hoverColor: Colors.white.withValues(alpha: .12),
      highlightColor: Colors.white.withValues(alpha: .16),
      focusColor: Colors.white.withValues(alpha: .16),
      padding: EdgeInsets.all(filled ? size * .45 : 8),
    ).merge(IconButtonTheme.of(context).style),
    icon: Icon(icon),
  );
}
