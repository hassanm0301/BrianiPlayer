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
      const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
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

class _MediaPlayPauseIntent extends Intent {
  const _MediaPlayPauseIntent();
}

class _MediaPlayIntent extends Intent {
  const _MediaPlayIntent();
}

class _MediaPauseIntent extends Intent {
  const _MediaPauseIntent();
}

/// Full-width, remote-friendly primary navigation for TV layouts.
class TvNavigationScaffold extends StatelessWidget {
  const TvNavigationScaffold({
    super.key,
    required this.index,
    required this.onSelected,
    required this.child,
    this.profile,
    this.account,
    this.destinations = const [
      TvNavigationDestination(Icons.folder_outlined, 'Libraries'),
      TvNavigationDestination(Icons.search, 'Discover'),
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: profile ?? const Text('Briani Player'),
          actions: [?account],
        ),
        body: Column(
          children: [
            Material(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _TvNavigationButton(
                          destination: destinations[i],
                          selected: i == index,
                          onPressed: () => onSelected(i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
}

class TvNavigationDestination {
  const TvNavigationDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _TvNavigationButton extends StatelessWidget {
  const _TvNavigationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });
  final TvNavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        child: FilledButton.tonalIcon(
          style: _tvButtonStyle(context),
          autofocus: selected,
          onPressed: onPressed,
          icon: Icon(destination.icon),
          label: Text(destination.label),
        ),
      );
}

/// Pure presentation controls; the owning playback feature supplies every
/// action and remains responsible for playback state and authorization.
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
    final maximum = duration.inMilliseconds.clamp(0, 0x7fffffff);
    final value = position.inMilliseconds.clamp(0, maximum);
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
            ],
            Semantics(
              label: 'Playback position',
              value: '${_format(position)} of ${_format(duration)}',
              child: LinearProgressIndicator(
                value: maximum == 0 ? null : value / maximum,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (onSeekBack != null)
                  _control(context, Icons.replay_10, 'Back 10 seconds', onSeekBack!),
                _control(
                  context, playing ? Icons.pause : Icons.play_arrow,
                  playing ? 'Pause' : 'Play',
                  onPlayPause,
                  autofocus: true,
                ),
                if (onSeekForward != null)
                  _control(context, Icons.forward_10, 'Forward 10 seconds', onSeekForward!),
                if (onTracks != null)
                  _control(context, Icons.subtitles_outlined, 'Tracks', onTracks!),
                if (onOptions != null)
                  _control(context, Icons.settings_outlined, 'Playback options', onOptions!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _control(BuildContext context, IconData icon, String label, VoidCallback onPressed,
          {bool autofocus = false}) =>
      FilledButton.tonalIcon(
        style: _tvButtonStyle(context),
        autofocus: autofocus,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );

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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton(
                      tooltip: 'Close $title',
                      autofocus: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
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
