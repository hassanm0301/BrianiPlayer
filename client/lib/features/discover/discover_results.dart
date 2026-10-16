import 'package:briani_api/briani_api.dart' show DiscoveryResult;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting/locale_formatters.dart' show formatDateTime;
import '../../core/widgets/states.dart';
import '../downloads/download_formatters.dart';
import '../downloads/transfer_widgets.dart';

/// A configurable result column (the title is always shown).
@immutable
class DiscoveryColumn {
  const DiscoveryColumn(
    this.id,
    this.label,
    this.width, {
    this.numeric = false,
    this.sort,
    this.icon,
  });

  /// The `torrentColumns` preference value.
  final String id;
  final String label;
  final double width;
  final bool numeric;

  /// The discovery sort key, when results can be sorted by this column.
  final String? sort;

  /// Icon used in the compact metadata line.
  final IconData? icon;
}

const discoveryColumns = [
  DiscoveryColumn('size', 'Size', 96, numeric: true, sort: 'sizeBytes'),
  DiscoveryColumn(
    'seeders',
    'Seeders',
    96,
    numeric: true,
    sort: 'seeders',
    icon: Icons.arrow_upward,
  ),
  DiscoveryColumn(
    'leechers',
    'Leechers',
    96,
    numeric: true,
    sort: 'leechers',
    icon: Icons.arrow_downward,
  ),
  DiscoveryColumn(
    'peers',
    'Peers',
    88,
    numeric: true,
    sort: 'peers',
    icon: Icons.people_outline,
  ),
  DiscoveryColumn('provider', 'Indexer', 176, icon: Icons.dns_outlined),
  DiscoveryColumn(
    'publishedAt',
    'Published',
    112,
    sort: 'publishedAt',
    icon: Icons.schedule,
  ),
];

/// Width of the trailing add-action column.
const discoveryActionWidth = 56.0;

/// Minimum width the title column needs before the table layout is used.
const discoveryMinimumTitleWidth = 280.0;

List<DiscoveryColumn> visibleDiscoveryColumns(Set<String> configured) =>
    discoveryColumns.where((column) => configured.contains(column.id)).toList();

double discoveryFixedWidth(List<DiscoveryColumn> columns, double scale) =>
    columns.fold<double>(0, (sum, column) => sum + column.width * scale) +
    discoveryActionWidth +
    24;

String discoveryCellValue(
  DiscoveryResult result,
  String column,
  String? locale,
) => switch (column) {
  'size' => formatBytes(result.sizeBytes, locale: locale),
  'seeders' => formatCount(result.seeders, locale: locale),
  'leechers' => formatCount(result.leechers, locale: locale),
  'peers' => formatCount(result.peers, locale: locale),
  'provider' => result.providerName,
  'publishedAt' =>
    result.publishedAt == null
        ? '—'
        : formatAge(result.publishedAt!, locale: locale),
  _ => '',
};

Color? _cellColor(
  BuildContext context,
  DiscoveryResult result,
  String column,
) => column == 'seeders' && (result.seeders ?? 0) > 0
    ? StatusColors.of(context).success
    : null;

/// The add-to-downloads action shared by both result layouts.
class _AddAction extends StatelessWidget {
  const _AddAction({
    required this.result,
    required this.onAdd,
    required this.television,
  });

  final DiscoveryResult result;
  final VoidCallback? onAdd;
  final bool television;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    // On TV the whole row is the focus target and activates the same action.
    excluding: television,
    child: IconButton(
      tooltip: result.downloadable
          ? 'Add to downloads'
          : 'This source does not offer a downloadable torrent',
      onPressed: result.downloadable ? onAdd : null,
      icon: const Icon(Icons.download_outlined),
    ),
  );
}

/// Shared row chrome: hover/focus state layer, focus ring and divider.
class _ResultRowFrame extends StatelessWidget {
  const _ResultRowFrame({
    required this.onTap,
    required this.child,
    required this.divider,
    this.dividerInset = 12,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool divider;
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusOutline(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            ),
          ),
        ),
        if (divider)
          Divider(
            height: 1,
            indent: dividerInset,
            endIndent: dividerInset,
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
      ],
    );
  }
}

/// Two-line result row for compact and medium widths.
class DiscoveryResultTile extends StatelessWidget {
  const DiscoveryResultTile({
    super.key,
    required this.result,
    required this.columns,
    required this.locale,
    required this.onTap,
    required this.onAdd,
    required this.television,
    this.divider = true,
  });

  final DiscoveryResult result;
  final List<DiscoveryColumn> columns;
  final String? locale;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool television;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ResultRowFrame(
      onTap: onTap,
      divider: divider,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final column in columns)
                        IconMetric(
                          label: column.label,
                          icon: column.icon,
                          value: discoveryCellValue(result, column.id, locale),
                          color: _cellColor(context, result, column.id),
                          emphasize: column.id == 'size',
                        ),
                      if (result.stale)
                        const StatusPill(
                          label: 'Stale',
                          icon: Icons.history,
                          tone: PillTone.warning,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _AddAction(result: result, onAdd: onAdd, television: television),
          ],
        ),
      ),
    );
  }
}

/// A table row aligned with [DiscoveryTableHeader], for wide windows.
class DiscoveryTableRow extends StatelessWidget {
  const DiscoveryTableRow({
    super.key,
    required this.result,
    required this.columns,
    required this.scale,
    required this.locale,
    required this.onTap,
    required this.onAdd,
    required this.television,
    this.divider = true,
  });

  final DiscoveryResult result;
  final List<DiscoveryColumn> columns;
  final double scale;
  final String? locale;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool television;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cellStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: tabularFigures,
    );
    return _ResultRowFrame(
      onTap: onTap,
      divider: divider,
      dividerInset: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: (television ? 60 : 52) * scale),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (result.stale) ...[
                        const SizedBox(width: 8),
                        const StatusPill(
                          label: 'Stale',
                          icon: Icons.history,
                          tone: PillTone.warning,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              for (final column in columns)
                SizedBox(
                  width: column.width * scale,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: _cell(context, column, cellStyle),
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: discoveryActionWidth - 8,
                child: Center(
                  child: _AddAction(
                    result: result,
                    onAdd: onAdd,
                    television: television,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, DiscoveryColumn column, TextStyle? style) {
    final value = discoveryCellValue(result, column.id, locale);
    final color = _cellColor(context, result, column.id);
    Widget text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: column.numeric ? TextAlign.end : TextAlign.start,
      style: style?.copyWith(
        color: color,
        fontWeight: color != null ? FontWeight.w600 : null,
      ),
    );
    if (column.id == 'publishedAt' && result.publishedAt != null) {
      text = Tooltip(
        message: formatDateTime(result.publishedAt!, locale: locale),
        child: text,
      );
    }
    return Semantics(
      label: '${column.label} $value',
      excludeSemantics: true,
      child: text,
    );
  }
}

/// Pinned column header for the table layout. Sortable columns toggle the
/// order when already active.
class DiscoveryTableHeader extends SliverPersistentHeaderDelegate {
  DiscoveryTableHeader({
    required this.columns,
    required this.scale,
    required this.padding,
    required this.sort,
    required this.order,
    required this.onSort,
    required this.background,
  });

  final List<DiscoveryColumn> columns;
  final double scale;
  final EdgeInsets padding;
  final String sort;
  final String order;
  final ValueChanged<String>? onSort;
  final Color background;

  double get _height => 44 * scale;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(DiscoveryTableHeader oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: background,
      child: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            // Header labels carry 4dp of inner padding for their hover
            // shape, so the row starts 4dp earlier to align with the cells.
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _HeaderLabel(
                      label: 'Title',
                      sortKey: 'title',
                      sort: sort,
                      order: order,
                      onSort: onSort,
                    ),
                  ),
                ),
                for (final column in columns)
                  SizedBox(
                    width: column.width * scale,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Align(
                        alignment: column.numeric
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _HeaderLabel(
                          label: column.label,
                          sortKey: column.sort,
                          sort: sort,
                          order: order,
                          onSort: onSort,
                          numeric: column.numeric,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: discoveryActionWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({
    required this.label,
    required this.sortKey,
    required this.sort,
    required this.order,
    required this.onSort,
    this.numeric = false,
  });

  final String label;
  final String? sortKey;
  final String sort;
  final String order;
  final ValueChanged<String>? onSort;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = sortKey != null && sortKey == sort;
    final style = theme.textTheme.labelLarge?.copyWith(
      color: active ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    final arrow = Icon(
      order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
      size: 14,
      color: scheme.onSurface,
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active && numeric) ...[arrow, const SizedBox(width: 4)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (active && !numeric) ...[const SizedBox(width: 4), arrow],
      ],
    );
    if (sortKey == null || onSort == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: content,
      );
    }
    final orderName = order == 'asc' ? 'ascending' : 'descending';
    return Tooltip(
      message: active
          ? 'Sorted by ${label.toLowerCase()}, $orderName'
          : 'Sort by ${label.toLowerCase()}',
      child: InkWell(
        onTap: () => onSort!(sortKey!),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: content,
        ),
      ),
    );
  }
}
