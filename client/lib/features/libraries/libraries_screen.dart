import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/client_session.dart';
import '../../core/input/route_activity.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/media_tile.dart';
import '../../core/widgets/states.dart';

class LibrariesScreen extends ConsumerStatefulWidget {
  const LibrariesScreen({super.key});

  @override
  ConsumerState<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends ConsumerState<LibrariesScreen> {
  Object? _apiIdentity;
  Future<List<ModelLibrary>>? _librariesFuture;
  List<ModelLibrary>? _lastLibraries;
  int _refreshGeneration = 0;
  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = RouteActivity.isVisible(context);
    if (_wasVisible == false && visible) ++_refreshGeneration;
    _wasVisible = visible;
  }

  Future<void> _refresh(BrianiApi api) async {
    final future = api.getLibrariesApi().listLibraries().then(
      (r) => r.data?.toList() ?? const <ModelLibrary>[],
    );
    setState(() {
      _librariesFuture = future;
      ++_refreshGeneration;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the failure with the last loaded contents.
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(activeApiProvider);
    if (api == null) {
      _apiIdentity = null;
      _librariesFuture = null;
      _lastLibraries = null;
      return const SizedBox.shrink();
    }
    if (!identical(_apiIdentity, api)) {
      _apiIdentity = api;
      _lastLibraries = null;
      _librariesFuture = api.getLibrariesApi().listLibraries().then(
        (r) => r.data?.toList() ?? const [],
      );
    }
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final gutters = pageGutters(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),
        actions: [
          IconButton(
            tooltip: 'Refresh libraries',
            onPressed: () => _refresh(api),
            icon: const Icon(Icons.refresh),
          ),
          ?ShellLayout.headerAccountButton(context),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ModelLibrary>>(
        key: ValueKey(api),
        future: _librariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lastLibraries == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _lastLibraries == null) {
            return EmptyState.error(
              title: 'Libraries are unavailable',
              message: clientError(snapshot.error!),
              onRetry: () => _refresh(api),
            );
          }
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            _lastLibraries = snapshot.data;
          }
          final libraries = _lastLibraries ?? const <ModelLibrary>[];
          final pinnedIds =
              preferences?.pinnedLibraryIds?.toSet() ?? <String>{};
          final orderedLibraries = [...libraries]
            ..sort((a, b) {
              final aPinned = pinnedIds.contains(a.id);
              final bPinned = pinnedIds.contains(b.id);
              return aPinned == bPinned
                  ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
                  : aPinned
                  ? -1
                  : 1;
            });
          final grid = preferences?.libraryLayout?.name == 'grid';
          return RefreshIndicator(
            onRefresh: () => _refresh(api),
            child: CustomScrollView(
              key: const PageStorageKey('libraries'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (snapshot.hasError)
                  SliverPadding(
                    padding: gutters.add(const EdgeInsets.only(top: 8)),
                    sliver: SliverToBoxAdapter(
                      child: NoticeBanner(
                        tone: NoticeTone.error,
                        message: clientError(snapshot.error!),
                        action: TextButton(
                          onPressed: () => _refresh(api),
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                  ),
                if (preferences?.showContinueWatching != false)
                  SliverToBoxAdapter(
                    child: _ContinueWatching(
                      key: ValueKey(api),
                      refreshGeneration: _refreshGeneration,
                      padding: gutters,
                    ),
                  ),
                SliverPadding(
                  padding: gutters.add(const EdgeInsets.only(top: 12)),
                  sliver: const SliverToBoxAdapter(
                    child: SectionHeader(title: 'Your libraries'),
                  ),
                ),
                if (libraries.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.video_library_outlined,
                      title: 'No libraries yet',
                      message: 'No libraries are available to this account.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: gutters.add(const EdgeInsets.only(bottom: 24)),
                    sliver: grid
                        ? SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  (constraints.crossAxisExtent / 300)
                                      .floor()
                                      .clamp(1, 6);
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      mainAxisExtent:
                                          96 *
                                          MediaQuery.textScalerOf(context)
                                              .scale(1)
                                              .clamp(1, 2),
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _libraryTile(
                                    orderedLibraries[index],
                                    grid: true,
                                    pinned: pinnedIds.contains(
                                      orderedLibraries[index].id,
                                    ),
                                  ),
                                  childCount: orderedLibraries.length,
                                  findChildIndexCallback: (key) =>
                                      _libraryIndex(orderedLibraries, key),
                                ),
                              );
                            },
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                // The row carries the identity key so
                                // findChildIndexCallback can match it.
                                key: ValueKey(
                                  'library-${orderedLibraries[index].id}',
                                ),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _libraryTile(
                                  orderedLibraries[index],
                                  pinned: pinnedIds.contains(
                                    orderedLibraries[index].id,
                                  ),
                                ),
                              ),
                              childCount: orderedLibraries.length,
                              findChildIndexCallback: (key) =>
                                  _libraryIndex(orderedLibraries, key),
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  int? _libraryIndex(List<ModelLibrary> libraries, Key key) {
    final index = libraries.indexWhere(
      (library) => ValueKey('library-${library.id}') == key,
    );
    return index < 0 ? null : index;
  }

  Widget _libraryTile(
    ModelLibrary library, {
    bool grid = false,
    bool pinned = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = _libraryColors(scheme, library.name);
    final description = library.description.isEmpty
        ? 'Browse media'
        : library.description;
    final icon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_libraryIcon(library.name), color: foreground),
    );
    return FocusOutline(
      key: grid ? ValueKey('library-${library.id}') : null,
      child: Card(
        child: InkWell(
          onTap: () =>
              context.push('/libraries/${Uri.encodeComponent(library.id)}'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              library.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (pinned) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.push_pin,
                              size: 16,
                              semanticLabel: 'Pinned',
                              color: scheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        library.readOnly
                            ? '$description · Read-only'
                            : description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks a stable tonal color pair per library so libraries are easy to tell
/// apart at a glance without relying on artwork.
(Color, Color) _libraryColors(ColorScheme scheme, String name) {
  final pairs = [
    (scheme.primaryContainer, scheme.onPrimaryContainer),
    (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    (scheme.secondaryContainer, scheme.onSecondaryContainer),
  ];
  final hash = name.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return pairs[hash % pairs.length];
}

IconData _libraryIcon(String name) {
  final lower = name.toLowerCase();
  if (RegExp(r'photo|picture|image|camera|album').hasMatch(lower)) {
    return Icons.photo_library_outlined;
  }
  if (RegExp(r'show|series|tv|episode').hasMatch(lower)) {
    return Icons.live_tv_outlined;
  }
  if (RegExp(r'music|audio|song').hasMatch(lower)) {
    return Icons.library_music_outlined;
  }
  if (RegExp(r'download').hasMatch(lower)) return Icons.download_done_outlined;
  return Icons.movie_outlined;
}

class _ContinueWatching extends ConsumerStatefulWidget {
  const _ContinueWatching({
    super.key,
    required this.refreshGeneration,
    required this.padding,
  });
  final int refreshGeneration;
  final EdgeInsets padding;
  @override
  ConsumerState<_ContinueWatching> createState() => _ContinueWatchingState();
}

class _ContinueWatchingState extends ConsumerState<_ContinueWatching> {
  late Future<ContinueWatchingPage?> _future;
  ContinueWatchingPage? _lastPage;
  void _load() =>
      _future = requireActiveApi(ref)
          .getMediaApi()
          .listContinueWatching(limit: 20)
          .then((r) => r.data);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ContinueWatching oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshGeneration != oldWidget.refreshGeneration) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ContinueWatchingPage?>(
    future: _future,
    builder: (context, snapshot) {
      final errorNotice = snapshot.hasError
          ? Padding(
              padding: widget.padding.add(const EdgeInsets.only(top: 12)),
              child: NoticeBanner(
                tone: NoticeTone.warning,
                message:
                    'Continue watching is unavailable. ${clientError(snapshot.error!)}',
                action: IconButton(
                  tooltip: 'Retry Continue watching',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(_load),
                ),
              ),
            )
          : null;
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        _lastPage = snapshot.data;
      }
      final items = _lastPage?.items.toList() ?? <ContinueWatching>[];
      if (items.isEmpty) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        return errorNotice ?? const SizedBox.shrink();
      }
      final television = isTelevision(context);
      final tileWidth = television ? 300.0 : 280.0;
      final textScale = MediaQuery.textScalerOf(context)
          .scale(1)
          .clamp(1.0, 2.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?errorNotice,
          Padding(
            padding: widget.padding.add(const EdgeInsets.only(top: 16)),
            child: const SectionHeader(title: 'Continue watching'),
          ),
          SizedBox(
            height: (tileWidth - 8) * 9 / 16 + 8 + 64 * textScale,
            child: ListView.separated(
              key: const PageStorageKey('continue-watching'),
              scrollDirection: Axis.horizontal,
              padding: widget.padding.copyWith(left: widget.padding.left - 4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final media = item.media;
                final progress = item.progress;
                final duration = progress.durationMs;
                final fraction = duration == null || duration <= 0
                    ? 0.0
                    : (progress.positionMs / duration)
                          .clamp(0.0, 1.0)
                          .toDouble();
                return SizedBox(
                  key: ValueKey('continue-${media.id}'),
                  width: tileWidth,
                  child: MediaTile(
                    artwork: AuthorizedThumbnail(
                      mediaId: media.id,
                      cacheWidth: 600,
                      placeholder: const ArtworkPlaceholder(
                        icon: Icons.movie_outlined,
                      ),
                    ),
                    title: media.name,
                    subtitle: duration == null
                        ? 'Resume'
                        : '${_time(duration - progress.positionMs)} left',
                    progress: fraction,
                    showPlayOnHover: true,
                    semanticLabel: 'Resume ${media.name}',
                    onTap: () => context.push(
                      '/play/media/${Uri.encodeComponent(media.id)}',
                    ),
                    menu: PopupMenuButton<String>(
                      tooltip: 'Progress options',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) =>
                          _updateProgress(media, progress, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'watched',
                          child: Text('Mark watched'),
                        ),
                        PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear progress'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );

  Future<void> _updateProgress(
    Media media,
    PlaybackProgress progress,
    String action,
  ) async {
    try {
      await requireActiveApi(ref).getMediaApi().setPlaybackProgress(
        id: media.id,
        progressUpdate: ProgressUpdate(
          (b) => b
            ..positionMs = action == 'clear'
                ? 0
                : (progress.durationMs ?? progress.positionMs)
            ..durationMs = progress.durationMs
            ..watched = action == 'watched' ? true : false
            ..version = progress.version,
        ),
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    }
  }
}

String _time(int ms) {
  final seconds = (ms < 0 ? 0 : ms) ~/ 1000;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}
