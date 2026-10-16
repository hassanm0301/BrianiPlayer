part of 'folder_screen.dart';

/// The folder path as tappable ancestor segments followed by the current
/// folder. Long paths scroll horizontally and start scrolled to the end, so
/// the current folder is always visible; a fade marks hidden ancestors.
class _BreadcrumbTrail extends StatefulWidget {
  const _BreadcrumbTrail({
    required this.path,
    required this.onSelected,
    required this.prominent,
  });

  final List<FolderBreadcrumb> path;
  final ValueChanged<int> onSelected;

  /// Title-sized current segment for use as an app bar title.
  final bool prominent;

  @override
  State<_BreadcrumbTrail> createState() => _BreadcrumbTrailState();
}

class _BreadcrumbTrailState extends State<_BreadcrumbTrail> {
  bool _hiddenStart = false;

  bool _onMetrics(ScrollMetrics metrics) {
    final hidden = metrics.maxScrollExtent - metrics.pixels > 1;
    if (hidden != _hiddenStart) setState(() => _hiddenStart = hidden);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = DefaultTextStyle.of(context).style;
    final ancestorStyle =
        (widget.prominent
                ? theme.textTheme.titleMedium
                : theme.textTheme.labelLarge)
            ?.copyWith(fontWeight: FontWeight.w500);
    final currentStyle = widget.prominent
        ? titleStyle
        : theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          );
    final path = widget.path;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < path.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.chevron_right,
              size: widget.prominent ? 20 : 18,
              color: scheme.onSurfaceVariant,
            ),
          if (i == path.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(path[i].name, maxLines: 1, style: currentStyle),
            )
          else
            TextButton(
              onPressed: () => widget.onSelected(i),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: ancestorStyle,
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(path[i].name, maxLines: 1),
            ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scroller = NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: row,
              ),
            ),
          ),
        );
        // The mask is always present (only its gradient changes) so the
        // scroll position and the crumbs' focus survive the fade toggling.
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              _hiddenStart ? Colors.transparent : Colors.black,
              Colors.black,
            ],
            stops: [0, (32 / bounds.width).clamp(0.0, 1.0)],
          ).createShader(bounds),
          child: scroller,
        );
      },
    );
  }
}

/// The breadcrumb trail as an app bar `bottom` on compact windows.
class _BreadcrumbBar extends StatelessWidget implements PreferredSizeWidget {
  const _BreadcrumbBar({
    required this.path,
    required this.padding,
    required this.onSelected,
    required this.textScale,
  });

  final List<FolderBreadcrumb> path;
  final EdgeInsets padding;
  final ValueChanged<int> onSelected;

  /// The clamped text scale, so the bar grows with the user's text size.
  final double textScale;

  @override
  Size get preferredSize => Size.fromHeight(44 * textScale);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding.left - 8, 0, padding.right - 8, 4),
        child: _BreadcrumbTrail(
          path: path,
          prominent: false,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

/// A compact tonal card for a subfolder in grid layout.
class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(14));
    return FocusOutline(
      borderRadius: radius,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, color: scheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _entryIcon(EntryKindEnum kind) => switch (kind) {
  EntryKindEnum.folder => Icons.folder_outlined,
  EntryKindEnum.video => Icons.movie_outlined,
  EntryKindEnum.photo => Icons.image_outlined,
  EntryKindEnum.subtitle => Icons.subtitles_outlined,
  _ => Icons.insert_drive_file_outlined,
};

String _entryKindLabel(EntryKindEnum kind) => switch (kind) {
  EntryKindEnum.folder => 'Folder',
  EntryKindEnum.video => 'Video',
  EntryKindEnum.photo => 'Photo',
  EntryKindEnum.subtitle => 'Subtitle',
  _ => kind.name,
};

/// The entry's authorized thumbnail, or a tonal placeholder for its type.
class _EntryArtwork extends StatelessWidget {
  const _EntryArtwork({
    required this.entry,
    required this.cacheWidth,
    this.iconSize = 36,
  });

  final Entry entry;
  final int cacheWidth;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ArtworkPlaceholder(
      icon: _entryIcon(entry.kind),
      size: iconSize,
    );
    final mediaId = entry.mediaId;
    if (!entry.thumbnailAvailable || mediaId == null) return placeholder;
    return AuthorizedThumbnail(
      key: ValueKey(mediaId),
      mediaId: mediaId,
      cacheWidth: cacheWidth,
      placeholder: placeholder,
    );
  }
}

const _sizeColumn = 104.0;
const _dateColumn = 136.0;

/// Column widths grow with the user's text size so values are not cut off.
double _columnScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
const _menuColumn = 48.0;
const _columnGap = 32.0;
const _leadingWidth = 56.0;

/// Column titles for the wide list layout; each one sorts by its column.
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.sort,
    required this.order,
    required this.onSort,
  });

  final String sort, order;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget column(String label, String key, String next) {
      final active = sort == key;
      return Tooltip(
        message: 'Sort by ${label.toLowerCase()}',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSort(next),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: active
                        ? style?.copyWith(color: scheme.onSurface)
                        : style,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 4),
                  Icon(
                    order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: scheme.onSurface,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        // Matches _EntryRow's geometry; each header cell carries 8dp of
        // inner padding, so its text lines up with the row values.
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 4),
        child: Row(
          children: [
            const SizedBox(width: _leadingWidth + 16 - 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: column(
                  'Name',
                  'name',
                  sort == 'name' && order == 'asc' ? 'name:desc' : 'name:asc',
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: _sizeColumn * _columnScale(context) + 8,
              child: Align(
                alignment: Alignment.centerRight,
                child: column('Size', 'size', 'size:desc'),
              ),
            ),
            const SizedBox(width: _columnGap - 16),
            SizedBox(
              width: _dateColumn * _columnScale(context) + 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: column('Modified', 'date', 'date:desc'),
              ),
            ),
            const SizedBox(width: _menuColumn),
          ],
        ),
      ),
    );
  }
}

/// One list row: thumbnail, name and either aligned Size/Modified columns
/// (wide windows) or a single metadata line (compact windows).
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.name,
    required this.wide,
    required this.size,
    required this.modified,
    required this.meta,
    required this.onTap,
    this.onSecondaryTap,
    this.menu,
  });

  final Entry entry;
  final String name;
  final bool wide;
  final String size, modified;
  final String? meta;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folder = entry.kind == EntryKindEnum.folder;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    const radius = BorderRadius.all(Radius.circular(12));
    final leading = SizedBox(
      width: _leadingWidth,
      height: 32,
      child: folder
          ? Icon(Icons.folder_rounded, color: scheme.primary)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _EntryArtwork(entry: entry, cacheWidth: 160, iconSize: 18),
            ),
    );
    final title = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    );
    final trailing = SizedBox(
      width: _menuColumn,
      child:
          menu ??
          (wide
              ? null
              : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
    );
    final content = wide
        ? Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(child: title),
              const SizedBox(width: 16),
              SizedBox(
                width: _sizeColumn * _columnScale(context),
                child: Text(
                  size,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ),
              const SizedBox(width: _columnGap),
              SizedBox(
                width: _dateColumn * _columnScale(context),
                child: Text(
                  modified,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ),
              trailing,
            ],
          )
        : Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (meta != null)
                      Text(
                        meta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          );
    return FocusOutline(
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onSecondaryTap,
          onSecondaryTap: onSecondaryTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, wide ? 4 : 8, 0, wide ? 4 : 8),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// File details: a thumbnail header, then aligned key/value rows. Media
/// metadata is fetched once when the sheet opens.
class _EntryDetails extends StatefulWidget {
  const _EntryDetails({
    required this.entry,
    required this.api,
    required this.locale,
  });

  final Entry entry;
  final BrianiApi api;
  final String? locale;

  @override
  State<_EntryDetails> createState() => _EntryDetailsState();
}

class _EntryDetailsState extends State<_EntryDetails> {
  Future<Media?>? _media;

  @override
  void initState() {
    super.initState();
    final mediaId = widget.entry.mediaId;
    _media = mediaId == null
        ? null
        : widget.api.getMediaApi().getMedia(id: mediaId).then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = widget.entry;
    final locale = widget.locale;
    final mediaId = entry.mediaId;
    final header = entry.thumbnailAvailable && mediaId != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: (constraints.maxWidth * 9 / 16).clamp(0, 220),
                    child: AuthorizedThumbnail(
                      mediaId: mediaId,
                      cacheWidth: 960,
                      placeholder: ArtworkPlaceholder(
                        icon: _entryIcon(entry.kind),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(entry.name, style: theme.textTheme.titleLarge),
            ],
          )
        : Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _entryIcon(entry.kind),
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(entry.name, style: theme.textTheme.titleLarge),
              ),
            ],
          );
    return FutureBuilder<Media?>(
      future: _media,
      builder: (context, snapshot) {
        final media = snapshot.data;
        final rows = <(String, String)>[
          ('Type', _entryKindLabel(entry.kind)),
          if (entry.sizeBytes != null)
            ('Size', formatBytes(entry.sizeBytes, locale: locale)),
          if (entry.modifiedAt != null)
            ('Modified', formatDateTime(entry.modifiedAt!, locale: locale)),
          if (media != null) ...[
            ('Format', media.mimeType),
            if (media.durationMs != null)
              ('Duration', _duration(media.durationMs!)),
            if (media.width != null && media.height != null)
              ('Dimensions', '${media.width} × ${media.height}'),
          ],
        ];
        final probeNote = switch (media?.probeState) {
          MediaProbeStateEnum.unsupported => (
            NoticeTone.warning,
            'This file format is not supported for playback.',
          ),
          MediaProbeStateEnum.pending => (
            NoticeTone.info,
            'Media details are still being checked.',
          ),
          MediaProbeStateEnum.failed => (
            NoticeTone.warning,
            'Media details could not be read.',
          ),
          _ => null,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (snapshot.connectionState == ConnectionState.waiting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading media details…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (snapshot.hasError)
              NoticeBanner(
                tone: NoticeTone.error,
                message: clientError(snapshot.error!),
                margin: const EdgeInsets.only(top: 12),
              ),
            if (probeNote != null)
              NoticeBanner(
                tone: probeNote.$1,
                message: probeNote.$2,
                margin: const EdgeInsets.only(top: 12),
              ),
          ],
        );
      },
    );
  }
}
