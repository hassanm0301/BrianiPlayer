import 'package:flutter/material.dart';

/// Dragging previews a position; only completing the gesture seeks the player.
class PlaybackSeekBar extends StatefulWidget {
  const PlaybackSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });
  final Duration position, duration;
  final ValueChanged<Duration>? onSeek;
  @override
  State<PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<PlaybackSeekBar> {
  double? _preview;
  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    if (max <= 0) return const SizedBox.shrink();
    String time(double value) {
      final seconds = value.round() ~/ 1000;
      return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    }

    return Slider(
      value: (_preview ?? widget.position.inMilliseconds.toDouble()).clamp(
        0,
        max,
      ),
      max: max,
      label: time(_preview ?? widget.position.inMilliseconds.toDouble()),
      semanticFormatterCallback: time,
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
  }
}
