import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared keyboard/remote bindings for screens that must work with a D-pad.
/// Directional focus traversal and Back remain owned by Flutter's normal
/// focus and route systems.
class RemoteNavigationScope extends StatelessWidget {
  const RemoteNavigationScope({
    super.key,
    required this.child,
    this.television = false,
    this.onMediaPlayPause,
    this.onMediaPlay,
    this.onMediaPause,
  });

  final Widget child;
  final bool television;
  final VoidCallback? onMediaPlayPause;
  final VoidCallback? onMediaPlay;
  final VoidCallback? onMediaPause;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.gameButtonA):
          const ActivateIntent(),
      const _EnterOutsideText(LogicalKeyboardKey.enter): const ActivateIntent(),
      const _EnterOutsideText(LogicalKeyboardKey.numpadEnter):
          const ActivateIntent(),
    };
    if (television) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)] = const DirectionalFocusIntent(TraversalDirection.down, ignoreTextFields: false);
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)] = const DirectionalFocusIntent(TraversalDirection.up, ignoreTextFields: false);
    }
    if (onMediaPlayPause != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.mediaPlayPause)] =
          const _MediaPlayPauseIntent();
    }
    if (onMediaPlay != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.mediaPlay)] =
          const _MediaPlayIntent();
    }
    if (onMediaPause != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.mediaPause)] =
          const _MediaPauseIntent();
    }

    return FocusTraversalGroup(
      policy: television ? OrderedTraversalPolicy() : ReadingOrderTraversalPolicy(),
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: {
            if (television)
              ExtendSelectionVerticallyToAdjacentLineIntent: _TvVerticalTextAction(),
            if (onMediaPlayPause != null)
              _MediaPlayPauseIntent: CallbackAction<_MediaPlayPauseIntent>(
                onInvoke: (_) {
                  onMediaPlayPause!();
                  return null;
                },
              ),
            if (onMediaPlay != null)
              _MediaPlayIntent: CallbackAction<_MediaPlayIntent>(
                onInvoke: (_) {
                  onMediaPlay!();
                  return null;
                },
              ),
            if (onMediaPause != null)
              _MediaPauseIntent: CallbackAction<_MediaPauseIntent>(
                onInvoke: (_) {
                  onMediaPause!();
                  return null;
                },
              ),
          },
          child: child,
        ),
      ),
    );
  }
}

// EditableText's vertical cursor action otherwise consumes D-pad Up/Down
// inside a one-line TV form. Keep horizontal editing and multiline editing.
class _TvVerticalTextAction extends Action<ExtendSelectionVerticallyToAdjacentLineIntent> {
  @override
  Object? invoke(ExtendSelectionVerticallyToAdjacentLineIntent intent) {
    final focus = FocusManager.instance.primaryFocus;
    final editable = focus?.context?.findAncestorWidgetOfExactType<EditableText>();
    if (intent.collapseSelection && editable?.maxLines == 1) {
      if (intent.forward) { focus?.nextFocus(); } else { focus?.previousFocus(); }
      return null;
    }
    return callingAction?.invoke(intent);
  }
}

// Enter in a text field belongs to the platform text input, which turns it
// into the field's submit action or a newline. Mapping it to ActivateIntent
// there would instead "tap" an enclosing InkWell (SearchBar has one) and
// swallow the key, so onSubmitted would never fire.
class _EnterOutsideText implements ShortcutActivator {
  const _EnterOutsideText(this.key);

  final LogicalKeyboardKey key;

  @override
  Iterable<LogicalKeyboardKey> get triggers => [key];

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (!SingleActivator(key).accepts(event, state)) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus?.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  @override
  String debugDescribeKeys() => '${key.keyLabel} outside text fields';
}

class _MediaPlayPauseIntent extends Intent {
  const _MediaPlayPauseIntent();
}

class _MediaPlayIntent extends Intent {
  const _MediaPlayIntent();
}

class _MediaPauseIntent extends Intent {
  const _MediaPauseIntent();
}

/// Compact, remote-friendly primary navigation for TV layouts: a single row
/// of tabs across the top (the Google TV convention), leaving the rest of the
/// 16:9 screen for content.
class TvNavigationScaffold extends StatelessWidget {
  const TvNavigationScaffold({
    super.key,
    required this.index,
    required this.onSelected,
    required this.child,
    this.profile,
    this.account,
    this.destinations = const [
      TvNavigationDestination(Icons.video_library_outlined, 'Libraries'),
      TvNavigationDestination(Icons.travel_explore_outlined, 'Discover'),
      TvNavigationDestination(Icons.download_outlined, 'Downloads'),
    ],
  });

  final int index;
  final ValueChanged<int> onSelected;
  final Widget child;
  final Widget? profile;
  final Widget? account;
  final List<TvNavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: scheme.onPrimary, size: 28),
                ),
                const SizedBox(width: 20),
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _TvNavigationButton(
                    destination: destinations[i],
                    selected: i == index,
                    onPressed: () => onSelected(i),
                  ),
                ],
                const SizedBox(width: 16),
                // The server label takes only the space left by the tabs and
                // ellipsizes, so long names or large text never overflow.
                Expanded(
                  child: profile == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: DefaultTextStyle.merge(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            child: profile!,
                          ),
                        ),
                ),
                if (account != null) ...[const SizedBox(width: 12), account!],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class TvNavigationDestination {
  const TvNavigationDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _TvNavigationButton extends StatefulWidget {
  const _TvNavigationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });
  final TvNavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_TvNavigationButton> createState() => _TvNavigationButtonState();
}

class _TvNavigationButtonState extends State<_TvNavigationButton> {
  final _focusNode = FocusNode(debugLabel: 'TV navigation tab');
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected) {
      FocusManager.instance.addListener(_claimInitialFocus);
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimInitialFocus());
    } else {
      _settled = true;
    }
  }

  /// At launch the content route focuses its own empty scope, which wins
  /// over `autofocus` and leaves nothing visibly focused. Until a real
  /// control receives focus, the selected tab takes it so the first D-pad
  /// press starts from a known place. Later route changes are untouched.
  void _claimInitialFocus() {
    if (_settled) return;
    final primary = FocusManager.instance.primaryFocus;
    if (!mounted || (primary != null && primary is! FocusScopeNode)) {
      _stopClaiming();
      return;
    }
    if (widget.selected && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _stopClaiming() {
    if (_settled) return;
    _settled = true;
    FocusManager.instance.removeListener(_claimInitialFocus);
  }

  @override
  void dispose() {
    _stopClaiming();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final selected = widget.selected;
    final onPressed = widget.onPressed;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: FilledButton.icon(
        style: _tvButtonStyle(context).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? scheme.onSurface
                : selected
                ? scheme.secondaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? scheme.surface
                : selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        focusNode: _focusNode,
        autofocus: selected,
        onPressed: onPressed,
        icon: Icon(destination.icon),
        label: Text(destination.label),
      ),
    );
  }
}

/// Pure presentation controls; the owning playback feature supplies every
/// action and remains responsible for playback state and authorization.
///
/// Drawn as a bottom overlay on a gradient: title, progress with times and
/// one row of large focusable buttons. Focus is shown by inverting the
/// button and enlarging it, not by color alone.
class TvPlayerControls extends StatelessWidget {
  const TvPlayerControls({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onTracks,
    this.onOptions,
    this.title,
  });

  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback? onSeekBack;
  final VoidCallback? onSeekForward;
  final VoidCallback? onTracks;
  final VoidCallback? onOptions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximum = duration.inMilliseconds.clamp(0, 0x7fffffff);
    final value = position.inMilliseconds.clamp(0, maximum);
    final timeStyle = theme.textTheme.titleSmall?.copyWith(
      color: Colors.white.withValues(alpha: .85),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: .88),
              Colors.black.withValues(alpha: .6),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0, .55, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 64, 48, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  ExcludeSemantics(
                    child: Text(_format(position), style: timeStyle),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      label: 'Playback position',
                      value: '${_format(position)} of ${_format(duration)}',
                      child: LinearProgressIndicator(
                        // Unknown duration shows an empty track; buffering
                        // is reported separately by the player.
                        value: maximum == 0 ? 0 : value / maximum,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: theme.colorScheme.primary,
                        backgroundColor: Colors.white.withValues(alpha: .24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ExcludeSemantics(
                    child: Text(_format(duration), style: timeStyle),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (onSeekBack != null) ...[
                    _TvPlayerButton(
                      icon: Icons.replay_10_rounded,
                      label: 'Back 10 seconds',
                      iconOnly: true,
                      onPressed: onSeekBack!,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _TvPlayerButton(
                    icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    label: playing ? 'Pause' : 'Play',
                    autofocus: true,
                    onPressed: onPlayPause,
                  ),
                  if (onSeekForward != null) ...[
                    const SizedBox(width: 12),
                    _TvPlayerButton(
                      icon: Icons.forward_10_rounded,
                      label: 'Forward 10 seconds',
                      iconOnly: true,
                      onPressed: onSeekForward!,
                    ),
                  ],
                  const Spacer(),
                  if (onTracks != null)
                    _TvPlayerButton(
                      icon: Icons.subtitles_outlined,
                      label: 'Tracks',
                      onPressed: onTracks!,
                    ),
                  if (onOptions != null) ...[
                    const SizedBox(width: 12),
                    _TvPlayerButton(
                      icon: Icons.settings_outlined,
                      label: 'Playback options',
                      onPressed: onOptions!,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(Duration value) {
    final seconds = value.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}'
        : '${seconds ~/ 60}:${remainder.toString().padLeft(2, '0')}';
  }
}

/// A large pill (or round, for [iconOnly]) TV player button. Labelled
/// buttons show their text; icon-only ones expose [label] to semantics.
class _TvPlayerButton extends StatefulWidget {
  const _TvPlayerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconOnly = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool iconOnly;
  final bool autofocus;

  @override
  State<_TvPlayerButton> createState() => _TvPlayerButtonState();
}

class _TvPlayerButtonState extends State<_TvPlayerButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
      fixedSize: widget.iconOnly
          ? const WidgetStatePropertyAll(Size(56, 56))
          : null,
      padding: WidgetStatePropertyAll(
        widget.iconOnly
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24),
      ),
      shape: WidgetStatePropertyAll(
        widget.iconOnly ? const CircleBorder() : const StadiumBorder(),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? Colors.white
            : Colors.white.withValues(alpha: .16),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? Colors.black
            : Colors.white,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
      elevation: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? 6 : 0,
      ),
      iconSize: const WidgetStatePropertyAll(28),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    final button = FilledButton(
      style: style,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: widget.iconOnly
          ? Icon(widget.icon, semanticLabel: widget.label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon),
                const SizedBox(width: 10),
                Text(widget.label),
              ],
            ),
    );
    return AnimatedScale(
      scale: _focused ? 1.1 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.iconOnly
          ? Tooltip(message: widget.label, child: button)
          : button,
    );
  }
}

/// A modal, full-width panel whose route preserves and restores focus when
/// dismissed through its visible close action or the platform Back action.
class TvFocusPanel extends StatelessWidget {
  const TvFocusPanel({
    super.key,
    required this.title,
    required this.child,
    this.width = 720,
  });

  final String title;
  final Widget child;
  final double width;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
  }) =>
      showDialog<T>(
        context: context,
        builder: (context) => TvFocusPanel(
          title: title,
          child: Builder(builder: builder),
        ),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close $title',
                      autofocus: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
}

/// Stable identity and focus state for rows that are replaced by polling or
/// other asynchronous updates.
class TvFocusList<T> extends StatelessWidget {
  const TvFocusList({
    super.key,
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    this.padding,
  });

  final List<T> items;
  final Object Function(T item) itemKey;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final indexByKey = <Object, int>{
      for (var i = 0; i < items.length; i++) itemKey(items[i]): i,
    };
    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<Object> ? indexByKey[key.value] : null,
      itemBuilder: (context, index) {
        final item = items[index];
        return KeyedSubtree(
          key: ValueKey<Object>(itemKey(item)),
          child: itemBuilder(context, item, index),
        );
      },
    );
  }
}

ButtonStyle _tvButtonStyle(BuildContext context) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
  side: WidgetStateProperty.resolveWith((states) => BorderSide(
    width: states.contains(WidgetState.focused) ? 3 : 1,
    color: states.contains(WidgetState.focused) ? Theme.of(context).colorScheme.onSurface : Colors.transparent)),
  textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleMedium),
);
