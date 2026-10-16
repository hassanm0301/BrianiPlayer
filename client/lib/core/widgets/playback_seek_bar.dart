import 'package:flutter/material.dart';

/// Dragging previews a position; only completing the gesture seeks the player.
///
/// With [showTimes], the elapsed time (following the drag preview) and the
/// total duration are shown on either side of the track.
class PlaybackSeekBar extends StatefulWidget {
  const PlaybackSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.showTimes = false,
    this.timeStyle,
  });
  final Duration position, duration;
  final ValueChanged<Duration>? onSeek;
  final bool showTimes;
  final TextStyle? timeStyle;
  @override
  State<PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<PlaybackSeekBar> {
  double? _preview;

  static String _time(double value) {
    final seconds = (value < 0 ? 0 : value).round() ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
        : '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    if (max <= 0) return const SizedBox.shrink();
    final shown = _preview ?? widget.position.inMilliseconds.toDouble();
    final slider = Slider(
      value: shown.clamp(0, max),
      max: max,
      label: _time(shown),
      semanticFormatterCallback: _time,
      onChanged: widget.onSeek == null
          ? null
          : (value) => setState(() => _preview = value),
      onChangeEnd: widget.onSeek == null
          ? null
          : (value) {
              setState(() => _preview = null);
              widget.onSeek!(Duration(milliseconds: value.round()));
            },
    );
    if (!widget.showTimes) return slider;
    final style =
        widget.timeStyle ??
        Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Row(
      children: [
        ExcludeSemantics(child: Text(_time(shown.clamp(0, max)), style: style)),
        Expanded(child: slider),
        ExcludeSemantics(child: Text(_time(max), style: style)),
      ],
    );
  }
}
