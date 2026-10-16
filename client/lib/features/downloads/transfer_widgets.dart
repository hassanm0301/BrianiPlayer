import 'package:briani_api/briani_api.dart'
    show DownloadFilePlaybackStateEnum, DownloadFileKindEnum, DownloadStateEnum;
import 'package:flutter/material.dart';

import '../../core/widgets/states.dart';
import 'download_formatters.dart';

/// Figures that change while polling (sizes, speeds, counts) use tabular
/// digits so their width does not jitter.
const tabularFigures = [FontFeature.tabularFigures()];

/// A small icon + value pair for quiet metadata lines, announced to screen
/// readers as "[label] [value]" (for example "Seeders —" when unknown).
class IconMetric extends StatelessWidget {
  const IconMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.emphasize = false,
    this.style,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool emphasize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    final textStyle = (style ?? theme.textTheme.bodyMedium)?.copyWith(
      color: foreground,
      fontFeatures: tabularFigures,
      fontWeight: emphasize ? FontWeight.w600 : null,
    );
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled figure in a summary grid ("Download speed / 8.2 MiB/s").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// How a download state is presented: label, tone and icon.
typedef StatePresentation = ({String label, PillTone tone, IconData icon});

StatePresentation downloadStatePresentation(DownloadStateEnum state) =>
    switch (state) {
      DownloadStateEnum.downloading => (
        label: 'Downloading',
        tone: PillTone.active,
        icon: Icons.arrow_downward,
      ),
      DownloadStateEnum.queued => (
        label: 'Queued',
        tone: PillTone.neutral,
        icon: Icons.schedule,
      ),
      DownloadStateEnum.resolving => (
        label: 'Resolving',
        tone: PillTone.neutral,
        icon: Icons.sync,
      ),
      DownloadStateEnum.metadataPending => (
        label: 'Fetching metadata',
        tone: PillTone.warning,
        icon: Icons.hourglass_empty,
      ),
      DownloadStateEnum.awaitingSelection => (
        label: 'Awaiting selection',
        tone: PillTone.warning,
        icon: Icons.checklist,
      ),
      DownloadStateEnum.paused => (
        label: 'Paused',
        tone: PillTone.neutral,
        icon: Icons.pause,
      ),
      DownloadStateEnum.stalled => (
        label: 'Stalled',
        tone: PillTone.warning,
        icon: Icons.warning_amber_rounded,
      ),
      DownloadStateEnum.completeSelected => (
        label: 'Selected files complete',
        tone: PillTone.success,
        icon: Icons.check,
      ),
      DownloadStateEnum.importing => (
        label: 'Importing',
        tone: PillTone.active,
        icon: Icons.drive_file_move_outlined,
      ),
      DownloadStateEnum.seeding => (
        label: 'Seeding',
        tone: PillTone.success,
        icon: Icons.arrow_upward,
      ),
      DownloadStateEnum.completed => (
        label: 'Completed',
        tone: PillTone.success,
        icon: Icons.check_circle_outline,
      ),
      DownloadStateEnum.removing => (
        label: 'Removing',
        tone: PillTone.neutral,
        icon: Icons.delete_outline,
      ),
      DownloadStateEnum.removed => (
        label: 'Removed',
        tone: PillTone.neutral,
        icon: Icons.remove_circle_outline,
      ),
      DownloadStateEnum.failed => (
        label: 'Failed',
        tone: PillTone.error,
        icon: Icons.error_outline,
      ),
      _ => (
        label: stateLabel(state.name),
        tone: PillTone.neutral,
        icon: Icons.circle_outlined,
      ),
    };

/// The pill for a file's playback availability, or null when the state adds
/// nothing (an unselected file in a list of checkboxes).
StatePresentation? filePlaybackPresentation(
  DownloadFilePlaybackStateEnum state,
) => switch (state) {
  DownloadFilePlaybackStateEnum.eligible => (
    label: 'Ready to play',
    tone: PillTone.active,
    icon: Icons.play_circle_outline,
  ),
  DownloadFilePlaybackStateEnum.complete => (
    label: 'Complete',
    tone: PillTone.success,
    icon: Icons.check,
  ),
  DownloadFilePlaybackStateEnum.waitingForData => (
    label: 'Waiting for data',
    tone: PillTone.neutral,
    icon: Icons.hourglass_empty,
  ),
  DownloadFilePlaybackStateEnum.metadataPending => (
    label: 'Waiting for metadata',
    tone: PillTone.neutral,
    icon: Icons.hourglass_empty,
  ),
  DownloadFilePlaybackStateEnum.unsupported => (
    label: 'Unsupported',
    tone: PillTone.neutral,
    icon: Icons.block,
  ),
  DownloadFilePlaybackStateEnum.unavailable => (
    label: 'Unavailable',
    tone: PillTone.warning,
    icon: Icons.warning_amber_rounded,
  ),
  _ => null,
};

IconData fileKindIcon(DownloadFileKindEnum kind) => switch (kind) {
  DownloadFileKindEnum.video => Icons.movie_outlined,
  DownloadFileKindEnum.photo => Icons.image_outlined,
  DownloadFileKindEnum.subtitle => Icons.subtitles_outlined,
  _ => Icons.insert_drive_file_outlined,
};

String fileKindLabel(DownloadFileKindEnum kind) => switch (kind) {
  DownloadFileKindEnum.video => 'Video',
  DownloadFileKindEnum.photo => 'Photo',
  DownloadFileKindEnum.subtitle => 'Subtitle',
  _ => 'Other file',
};

/// The primary progress bar used for downloads.
class TransferProgressBar extends StatelessWidget {
  const TransferProgressBar({
    super.key,
    required this.value,
    this.minHeight = 6,
    this.color,
  });

  final double value;
  final double minHeight;
  final Color? color;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: minHeight,
    color: color,
    borderRadius: BorderRadius.circular(4),
  );
}

/// Small rounded tag label.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: tag, icon: Icons.sell_outlined, dense: true);
}
