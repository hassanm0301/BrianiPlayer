import 'package:flutter/foundation.dart';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/client_session.dart';
import 'states.dart';

/// A bounded, per-session memory cache of thumbnail bytes. It also records
/// media that have no thumbnail (HTTP 404), so revisiting a page does not
/// repeat requests the server already answered. A new session (API identity)
/// starts with an empty cache.
class ThumbnailCache {
  ThumbnailCache({this.maxEntries = 300, this.maxBytes = 24 * 1024 * 1024});

  final int maxEntries;
  final int maxBytes;
  final _entries = <String, Uint8List?>{};
  int _bytes = 0;

  bool contains(String mediaId) => _entries.containsKey(mediaId);

  /// The cached bytes, or null when the server reported no thumbnail.
  Uint8List? lookup(String mediaId) {
    final value = _entries.remove(mediaId);
    _entries[mediaId] = value;
    return value;
  }

  void store(String mediaId, Uint8List? bytes) {
    final previous = _entries.remove(mediaId);
    _bytes -= previous?.length ?? 0;
    _entries[mediaId] = bytes;
    _bytes += bytes?.length ?? 0;
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      final oldest = _entries.keys.first;
      _bytes -= _entries.remove(oldest)?.length ?? 0;
    }
  }
}

final thumbnailCacheProvider = Provider<ThumbnailCache>((ref) {
  ref.watch(activeApiProvider);
  return ThumbnailCache();
});

/// A server thumbnail fetched through the authorized media API. The request
/// is cancelled when the widget leaves the tree or its identity changes, so
/// fast scrolling does not queue thumbnails that are no longer visible.
class AuthorizedThumbnail extends ConsumerStatefulWidget {
  const AuthorizedThumbnail({
    super.key,
    required this.mediaId,
    this.fit = BoxFit.cover,
    this.cacheWidth = 480,
    this.placeholder,
  });

  final String mediaId;
  final BoxFit fit;
  final int cacheWidth;

  /// Shown while loading and when no image is available.
  final Widget? placeholder;

  @override
  ConsumerState<AuthorizedThumbnail> createState() =>
      _AuthorizedThumbnailState();
}

class _AuthorizedThumbnailState extends ConsumerState<AuthorizedThumbnail> {
  Future<Uint8List>? _future;
  BrianiApi? _api;
  String? _mediaId;
  CancelToken? _token;

  @override
  void dispose() {
    _token?.cancel('Thumbnail left the viewport');
    super.dispose();
  }

  static Future<Uint8List> _fetch(
    BrianiApi api,
    ThumbnailCache cache,
    String mediaId,
    CancelToken token,
  ) async {
    try {
      final bytes = (await api.getMediaApi().getThumbnail(
        id: mediaId,
        cancelToken: token,
      )).data!;
      cache.store(mediaId, bytes);
      return bytes;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) cache.store(mediaId, null);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(activeApiProvider);
    if (!identical(api, _api) || _mediaId != widget.mediaId) {
      _token?.cancel('Thumbnail identity changed');
      _api = api;
      _mediaId = widget.mediaId;
      final cache = ref.read(thumbnailCacheProvider);
      if (api == null) {
        _future = null;
      } else if (cache.contains(widget.mediaId)) {
        final bytes = cache.lookup(widget.mediaId);
        _future = bytes == null ? null : SynchronousFuture(bytes);
      } else {
        _future = _fetch(api, cache, widget.mediaId, _token = CancelToken());
      }
    }
    final placeholder = widget.placeholder ?? const SizedBox.expand();
    return FutureBuilder<Uint8List>(
      initialData: _future is SynchronousFuture<Uint8List>
          ? ref.read(thumbnailCacheProvider).lookup(widget.mediaId)
          : null,
      key: ValueKey((api, widget.mediaId)),
      future: _future,
      builder: (context, snapshot) => snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              fit: widget.fit,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: widget.cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}

/// Tonal artwork placeholder with a centered icon, used for folders and for
/// media without a thumbnail.
class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder({super.key, required this.icon, this.size = 36});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: size, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// A grid tile with artwork on top and a title block below. It is the shared
/// building block for folder grids and Continue watching rows.
///
/// [menu] is shown as a visible overflow button (required for TV and
/// keyboard users) and [onSecondaryTap] opens the same actions on right-click
/// or long-press.
class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.artwork,
    required this.title,
    this.subtitle,
    this.onTap,
    this.menu,
    this.onSecondaryTap,
    this.progress,
    this.badge,
    this.aspectRatio = 16 / 9,
    this.showPlayOnHover = false,
    this.autofocus = false,
    this.focusNode,
    this.semanticLabel,
  });

  final Widget artwork;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? menu;
  final VoidCallback? onSecondaryTap;

  /// Fraction 0–1 drawn as a bar along the bottom of the artwork.
  final double? progress;

  /// Small overlay label in the artwork's bottom-right corner (for example a
  /// duration).
  final String? badge;
  final double aspectRatio;
  final bool showPlayOnHover;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(14));
    final artworkStack = Stack(
      fit: StackFit.expand,
      children: [
        widget.artwork,
        if (widget.showPlayOnHover)
          AnimatedOpacity(
            opacity: _hovered ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: .28),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 30,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.badge != null)
          Positioned(
            right: 8,
            bottom: widget.progress == null ? 8 : 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .66),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  widget.badge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (widget.progress != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Watched',
              value: '${(widget.progress!.clamp(0.0, 1.0) * 100).round()}%',
              child: Container(
                height: 4,
                color: Colors.black.withValues(alpha: .4),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widget.progress!.clamp(0.0, 1.0),
                  child: ColoredBox(color: scheme.primary),
                ),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: FocusOutline(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            onTap: widget.onTap,
            onLongPress: widget.onSecondaryTap,
            onSecondaryTap: widget.onSecondaryTap,
            onHover: (hovered) => setState(() => _hovered = hovered),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // In a fixed-height cell (grids, rows) the artwork yields
                  // space so the text never overflows with taller fonts or
                  // large text; otherwise it keeps its aspect ratio.
                  final bounded = constraints.maxHeight.isFinite;
                  final artwork = ClipRRect(
                    borderRadius: radius,
                    child: bounded
                        ? artworkStack
                        : AspectRatio(
                            aspectRatio: widget.aspectRatio,
                            child: artworkStack,
                          ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      bounded ? Expanded(child: artwork) : artwork,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 0, 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (widget.menu != null)
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButtonTheme(
                                  data: IconButtonThemeData(
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      iconSize: 20,
                                      minimumSize: const Size.square(32),
                                    ).merge(IconButtonTheme.of(context).style),
                                  ),
                                  child: widget.menu!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
